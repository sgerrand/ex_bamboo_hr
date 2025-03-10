defmodule BambooHR.HTTPClient do
  @moduledoc """
  Behaviour for HTTP clients.
  """

  @callback request(keyword()) :: {:ok, map()} | {:error, any()}
end

defmodule BambooHR.HTTPClient.Req do
  @moduledoc """
  HTTP client implementation using `Req`.
  """

  @behaviour BambooHR.HTTPClient

  @impl true
  def request(opts) do
    case Req.request(opts) do
      {:ok, %{status: status, body: body}} when status in 200..299 ->
        {:ok, body}

      {:ok, %{status: status, body: body}} ->
        {:error, %{status: status, body: body}}

      {:error, error} ->
        {:error, error}
    end
  end
end
