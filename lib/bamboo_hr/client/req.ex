defmodule BambooHR.Client.Req do
  @moduledoc false

  @callback get(path :: String.t(), config :: map(), opts :: keyword()) ::
              {:ok, Req.Response.t()} | {:error, Exception.t()}
  @callback post(path :: String.t(), config :: map(), opts :: keyword()) ::
              {:ok, Req.Response.t()} | {:error, Exception.t()}

  @spec get(path :: String.t(), config :: map(), opts :: keyword()) ::
          {:ok, Req.Response.t()} | {:error, Exception.t()}
  def get(path, config, opts \\ []) do
    request(:get, path, config, opts)
  end

  @spec post(path :: String.t(), config :: map(), opts :: keyword()) ::
          {:ok, Req.Response.t()} | {:error, Exception.t()}
  def post(path, config, opts) do
    request(:post, path, config, opts)
  end

  defp request(method, path, config, opts) do
    url = build_url(config, path)
    headers = build_headers(config.api_key)

    req_opts = Keyword.merge([headers: headers], opts)

    case Req.new(url: url)
         |> Req.merge(req_opts)
         |> Req.request(method: method) do
      {:ok, %{status: status, body: body}} when status in 200..299 ->
        {:ok, body}

      {:ok, %{status: status, body: body}} ->
        {:error, %{status: status, body: body}}

      {:error, error} ->
        {:error, error}
    end
  end

  defp build_url(config, path) do
    "#{config.base_url}/#{config.company_domain}/v1#{path}"
  end

  defp build_headers(api_key) do
    [
      {"Authorization", "Basic " <> Base.encode64("#{api_key}:x")},
      {"Accept", "application/json"}
    ]
  end
end
