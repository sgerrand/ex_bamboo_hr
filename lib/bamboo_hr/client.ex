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
  upstream returns an empty 2xx body.

  The `:error` payload is one of:

    * `%{status: integer(), body: binary()}` — non-2xx HTTP response
    * `%Jason.DecodeError{}` — a 2xx response whose body was not valid JSON
    * a transport exception (e.g. `%Req.TransportError{}`)
  """
  @type response :: {:ok, term()} | {:error, term()}

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

      iex> BambooHR.Client.new(company_domain: "acme", api_key: "api_key_123")
      %BambooHR.Client{
        company_domain: "acme",
        api_key: "api_key_123",
        base_url: "https://api.bamboohr.com/api/gateway.php",
        http_client: BambooHR.HTTPClient.Req,
        timeout: 15_000
      }

      iex> BambooHR.Client.new(
      ...>   company_domain: "acme",
      ...>   api_key: "api_key_123",
      ...>   base_url: "https://custom-api.example.com",
      ...>   timeout: 30_000
      ...> )
      %BambooHR.Client{
        company_domain: "acme",
        api_key: "api_key_123",
        base_url: "https://custom-api.example.com",
        http_client: BambooHR.HTTPClient.Req,
        timeout: 30_000
      }
  """
  @spec new(Keyword.t()) :: t()
  def new(opts) do
    company_domain = Keyword.fetch!(opts, :company_domain)
    api_key = Keyword.fetch!(opts, :api_key)
    base_url = Keyword.get(opts, :base_url, "https://api.bamboohr.com/api/gateway.php")
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

    client.http_client.request(req_opts)
  end

  defp build_url(client, path) do
    "#{client.base_url}/#{client.company_domain}/v1#{path}"
  end

  defp build_headers(api_key) do
    [
      {"Authorization", "Basic " <> Base.encode64("#{api_key}:x")},
      {"Accept", "application/json"}
    ]
  end
end
