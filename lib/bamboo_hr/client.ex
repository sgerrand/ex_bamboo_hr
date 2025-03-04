defmodule BambooHR.Client do
  @moduledoc """
  Client for interacting with the BambooHR API.

  ## Configuration

  To use this client, you'll need information from BambooHR:
  - Your company's subdomain
  - An API key

  ## Usage

      client = BambooHR.Client.new("your_company", "your_api_key")
  """

  @type config :: %{
          company_domain: String.t(),
          api_key: String.t(),
          base_url: String.t()
        }

  @type response :: {:ok, map()} | {:error, any()}

  @doc """
  Creates a new client configuration.

  ## Parameters

    * `company_domain` - Your company's subdomain
    * `api_key` - Your API key
    * `base_url` - Optional custom base URL for the API (defaults to BambooHR's standard API URL)

  ## Examples

      iex> config = BambooHR.Client.new("acme", "api_key_123")
      %{
        company_domain: "acme",
        api_key: "api_key_123",
        base_url: "https://api.bamboohr.com/api/gateway.php"
      }

      # With custom base URL
      iex> config = BambooHR.Client.new("acme", "api_key_123", "https://custom-api.example.com")
      %{
        company_domain: "acme",
        api_key: "api_key_123",
        base_url: "https://custom-api.example.com"
      }
  """
  @spec new(String.t(), String.t(), String.t() | nil) :: config()
  def new(company_domain, api_key, base_url \\ nil) do
    %{
      company_domain: company_domain,
      api_key: api_key,
      base_url: base_url || "https://api.bamboohr.com/api/gateway.php"
    }
  end

  @doc """
  Makes a GET request to the BambooHR API.

  This function is meant to be used by resource modules.
  """
  @spec get(String.t(), config(), keyword()) :: response()
  def get(path, config, opts \\ []) do
    request(:get, path, config, opts)
  end

  @doc """
  Makes a POST request to the BambooHR API.

  This function is meant to be used by resource modules.
  """
  @spec post(String.t(), config(), keyword()) :: response()
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
