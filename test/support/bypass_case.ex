defmodule BambooHR.BypassCase do
  @moduledoc """
  Shared `ExUnit.CaseTemplate` for resource modules that drive the API
  through a local Bypass instance.

  Each test gets:

    * `bypass` — a fresh `Bypass` instance on a random port
    * `config` — a `BambooHR.Client.t()` pointing at that Bypass

  Tests run `async: true`.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      import BambooHR.BypassCase, only: [bypass_url: 2]
    end
  end

  setup do
    bypass = Bypass.open()
    base_url = bypass_url(bypass, "/api/gateway.php")

    config =
      BambooHR.Client.new(
        company_domain: "test_company",
        api_key: "test_key",
        base_url: base_url
      )

    {:ok, bypass: bypass, config: config}
  end

  @doc "Builds an `http://localhost:PORT` URL for the given Bypass instance."
  @spec bypass_url(Bypass.t(), String.t()) :: String.t()
  def bypass_url(bypass, path), do: "http://localhost:#{bypass.port}#{path}"
end
