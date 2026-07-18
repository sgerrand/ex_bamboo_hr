defmodule BambooHR.Client do
  @moduledoc """
  Client for interacting with the BambooHR API.

  ## Configuration

  To use this client, you'll need information from BambooHR:
  - Your company's subdomain
  - An API key

  Optional configuration:
  - `:base_url` — override the default API base URL
  - `:http_client` — swap in a custom HTTP client module
  - `:timeout` — HTTP receive timeout in milliseconds (default: `15_000`)

  ## Usage

      client = BambooHR.Client.new(company_domain: "your_company", api_key: "your_api_key")
      {:ok, company_info} = BambooHR.Company.get_information(client)

  ## Telemetry

  Every request emits a `:telemetry` span under the `[:bamboo_hr, :request]`
  prefix, producing three events:

    * `[:bamboo_hr, :request, :start]`
    * `[:bamboo_hr, :request, :stop]`
    * `[:bamboo_hr, :request, :exception]` (on raise)

  Measurements follow `:telemetry.span/3` conventions (`:system_time`,
  `:monotonic_time`, `:duration`).

  Metadata always includes:

    * `:method` — `:get`, `:post`, `:put`, or `:delete`
    * `:path` — request path passed to the resource module
    * `:url` — fully-qualified request URL (no credentials)

  Stop metadata additionally includes:

    * `:result` — `:ok` or `:error`
    * `:status` — HTTP status integer when the upstream returned a non-2xx
    * `:reason` — error term for transport / decoding failures
  """

  @type t :: %__MODULE__{
          company_domain: String.t(),
          api_key: String.t(),
          base_url: String.t(),
          http_client: module(),
          timeout: non_neg_integer()
        }

  @typedoc """
  Result returned by client request functions.

  The `:ok` payload is whatever `Jason.decode/1` produced from the response
  body — typically a map, but it may also be a list, scalar, or `nil` when the
  upstream returns an empty 2xx body. Passing `raw_response: true` skips JSON
  decoding (needed for binary responses like file downloads), and passing
  `expose_headers: true` wraps the payload as `%{body: body, headers:
  headers}` — see `BambooHR.HTTPClient`.

  The `:error` payload is one of:

    * `%{status: integer(), body: binary()}` — non-2xx HTTP response
    * `%Jason.DecodeError{}` — a 2xx response whose body was not valid JSON
    * a transport exception (e.g. `%Req.TransportError{}`)
  """
  @type response :: {:ok, term()} | {:error, term()}

  @derive {Inspect, except: [:api_key]}
  defstruct [:company_domain, :api_key, :base_url, :http_client, :timeout]

  @doc """
  Creates a new client configuration.

  ## Options

    * `:company_domain` - Your company's subdomain
    * `:api_key` - Your API key
    * `:base_url` - Optional. Custom base URL for the API (defaults to BambooHR's standard API URL)
    * `:http_client` - Optional. Module that implements the `HTTPClient` behavior. Defaults to `BambooHR.HTTPClient.Req`.
    * `:timeout` - Optional. HTTP receive timeout in milliseconds. Defaults to `15_000`.

  ## Examples

      iex> client = BambooHR.Client.new(company_domain: "acme", api_key: "api_key_123")
      iex> {client.company_domain, client.base_url, client.timeout}
      {"acme", "https://api.bamboohr.com/api/gateway.php", 15_000}

      iex> client =
      ...>   BambooHR.Client.new(
      ...>     company_domain: "acme",
      ...>     api_key: "api_key_123",
      ...>     base_url: "https://custom-api.example.com",
      ...>     timeout: 30_000
      ...>   )
      iex> {client.base_url, client.timeout}
      {"https://custom-api.example.com", 30_000}
  """
  @spec new(Keyword.t()) :: t()
  def new(opts) do
    company_domain = Keyword.fetch!(opts, :company_domain) |> validate_non_empty!(:company_domain)
    api_key = Keyword.fetch!(opts, :api_key) |> validate_non_empty!(:api_key)

    base_url =
      opts
      |> Keyword.get(:base_url, "https://api.bamboohr.com/api/gateway.php")
      |> String.trim_trailing("/")

    http_client = Keyword.get(opts, :http_client, BambooHR.HTTPClient.Req)
    timeout = Keyword.get(opts, :timeout, 15_000)

    %__MODULE__{
      company_domain: company_domain,
      api_key: api_key,
      base_url: base_url,
      http_client: http_client,
      timeout: timeout
    }
  end

  defp validate_non_empty!(value, _key) when is_binary(value) and byte_size(value) > 0, do: value

  defp validate_non_empty!(value, key) do
    raise ArgumentError,
          "expected #{inspect(key)} to be a non-empty string, got: #{inspect(value)}"
  end

  @doc """
  Makes a GET request to the BambooHR API.

  This function is meant to be used by resource modules. `opts` are forwarded
  to the underlying HTTP client; keys controlled by the client itself —
  `:method`, `:url`, `:headers`, `:receive_timeout` — cannot be overridden
  through this argument.
  """
  @spec get(String.t(), t(), keyword()) :: response()
  def get(path, %__MODULE__{} = client, opts \\ []) do
    request(:get, path, client, opts)
  end

  @doc """
  Makes a POST request to the BambooHR API.

  This function is meant to be used by resource modules. `opts` are forwarded
  to the underlying HTTP client; keys controlled by the client itself —
  `:method`, `:url`, `:headers`, `:receive_timeout` — cannot be overridden
  through this argument.
  """
  @spec post(String.t(), t(), keyword()) :: response()
  def post(path, %__MODULE__{} = client, opts) do
    request(:post, path, client, opts)
  end

  @doc """
  Makes a PUT request to the BambooHR API.

  This function is meant to be used by resource modules. `opts` are forwarded
  to the underlying HTTP client; keys controlled by the client itself —
  `:method`, `:url`, `:headers`, `:receive_timeout` — cannot be overridden
  through this argument.
  """
  @spec put(String.t(), t(), keyword()) :: response()
  def put(path, %__MODULE__{} = client, opts) do
    request(:put, path, client, opts)
  end

  @doc """
  Makes a DELETE request to the BambooHR API.

  This function is meant to be used by resource modules. `opts` are forwarded
  to the underlying HTTP client; keys controlled by the client itself —
  `:method`, `:url`, `:headers`, `:receive_timeout` — cannot be overridden
  through this argument.
  """
  @spec delete(String.t(), t(), keyword()) :: response()
  def delete(path, %__MODULE__{} = client, opts \\ []) do
    request(:delete, path, client, opts)
  end

  defp request(method, path, client, opts) do
    url = build_url(client, path)
    headers = build_headers(client.api_key)

    req_opts =
      Keyword.merge(opts,
        method: method,
        url: url,
        headers: headers,
        receive_timeout: client.timeout
      )

    start_metadata = %{method: method, path: path, url: url}

    :telemetry.span([:bamboo_hr, :request], start_metadata, fn ->
      result = client.http_client.request(req_opts)
      {result, Map.merge(start_metadata, result_metadata(result))}
    end)
  end

  defp result_metadata({:ok, _}), do: %{result: :ok}
  defp result_metadata({:error, %{status: status}}), do: %{result: :error, status: status}
  defp result_metadata({:error, reason}), do: %{result: :error, reason: reason}

  defp build_url(client, path) do
    "#{client.base_url}/#{client.company_domain}/v1#{normalize_path(path)}"
  end

  defp normalize_path("/" <> _ = path), do: path
  defp normalize_path(path), do: "/" <> path

  defp build_headers(api_key) do
    [
      {"Authorization", "Basic " <> Base.encode64("#{api_key}:x")},
      {"Accept", "application/json"}
    ]
  end
end
