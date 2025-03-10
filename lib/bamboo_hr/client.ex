defmodule BambooHR.Client do
  @moduledoc """
  Client for interacting with the BambooHR API.

  ## Configuration

  To use this client, you'll need information from BambooHR:
  - Your company's subdomain
  - An API key

  ## Usage

      client = BambooHR.Client.new(company_domain: "your_company", api_key: "your_api_key")
      {:ok, company_info} = BambooHR.Company.get_information(client)
  """

  @type t :: %__MODULE__{
          company_domain: String.t(),
          api_key: String.t(),
          base_url: String.t(),
          http_client: module()
        }

  @type response :: {:ok, map()} | {:error, any()}

  defstruct [:company_domain, :api_key, :base_url, :http_client]

  @doc """
  Creates a new client configuration.

  ## Options

    * `:company_domain` - Your company's subdomain
    * `:api_key` - Your API key
    * `:base_url` - Optional. Custom base URL for the API (defaults to BambooHR's standard API URL)
    * `:http_client` - Optional. Module that implements the `HTTPClient` behavior. Defaults to `BambooHR.HTTPClient.Req`.

  ## Examples

      iex> client = BambooHR.Client.new(company_domain: "acme", api_key: "api_key_123")
      %{
        company_domain: "acme",
        api_key: "api_key_123",
        base_url: "https://api.bamboohr.com/api/gateway.php",
        http_client: BambooHR.HTTPClient.Req
      }

      # With custom base URL
      iex> client = BambooHR.Client.new(company_domain: "acme", api_key: "api_key_123", base_url: "https://custom-api.example.com")
      %{
        company_domain: "acme",
        api_key: "api_key_123",
        base_url: "https://custom-api.example.com",
        http_client: BambooHR.HTTPClient.Req
      }
  """
  @spec new(Keyword.t()) :: t()
  def new(opts) do
    company_domain = Keyword.fetch!(opts, :company_domain)
    api_key = Keyword.fetch!(opts, :api_key)
    base_url = Keyword.get(opts, :base_url, "https://api.bamboohr.com/api/gateway.php")
    http_client = Keyword.get(opts, :http_client, BambooHR.HTTPClient.Req)

    %__MODULE__{
      company_domain: company_domain,
      api_key: api_key,
      base_url: base_url,
      http_client: http_client
    }
  end

  @doc """
  Makes a GET request to the BambooHR API.

  This function is meant to be used by resource modules.
  """
  @spec get(String.t(), t(), keyword()) :: response()
  def get(path, %__MODULE__{} = client, opts \\ []) do
    request(:get, path, client, opts)
  end

  @doc """
  Makes a POST request to the BambooHR API.

  This function is meant to be used by resource modules.
  """
  @spec post(String.t(), t(), keyword()) :: response()
  def post(path, %__MODULE__{} = client, opts) do
    request(:post, path, client, opts)
  end

  defp request(method, path, client, opts) do
    url = build_url(client, path)
    headers = build_headers(client.api_key)

    req_opts = Keyword.merge([headers: headers, method: method, url: url], opts)

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
