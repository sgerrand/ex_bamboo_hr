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

  ## API versions

  Every request targets BambooHR's `v1` API by default. Some endpoints (for
  example the Datasets API used by `BambooHR.Datasets`) live under a
  different version segment. Pass `api_version:` in the `opts` of
  `get/3`, `post/3`, `put/3`, or `delete/3` to target one of those instead —
  one of `"v1"` (default), `"v1_1"`, `"v1_2"`, or `"v2"`.

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

    * `:method` — `:get`, `:post`, `:patch`, `:put`, or `:delete`
    * `:path` — request path passed to the resource module
    * `:url` — fully-qualified request URL (no credentials)

  Stop metadata additionally includes:

    * `:result` — `:ok` or `:error`
    * `:status` — HTTP status integer, or `nil` when the request never got
      a response
    * `:reason` — the `BambooHR.Error` reason atom, e.g. `:not_found` or
      `:transport_error`
  """

  @type t :: %__MODULE__{
          company_domain: String.t(),
          auth: auth(),
          base_url: String.t(),
          http_client: module(),
          timeout: non_neg_integer()
        }

  @typedoc """
  How requests are authenticated.

  `{:api_key, key}` sends HTTP Basic auth, as `key:x`. `{:bearer, token}`
  sends an OAuth 2.0 access token as a bearer token.
  """
  @type auth :: {:api_key, String.t()} | {:bearer, String.t()}

  @typedoc """
  Result returned by client request functions.

  The `:ok` payload is whatever `Jason.decode/1` produced from the response
  body — typically a map, but it may also be a list, scalar, or `nil` when the
  upstream returns an empty 2xx body. Passing `raw_response: true` skips JSON
  decoding (needed for binary responses like file downloads), and passing
  `expose_headers: true` wraps the payload as `%{body: body, headers:
  headers}` — see `BambooHR.HTTPClient`.

  The `:error` payload is always a `BambooHR.Error` struct, whether the
  request came back non-2xx, never reached BambooHR, or returned a body
  that was not valid JSON. Match on its `:reason` — see `BambooHR.Error`.
  """
  @type response :: {:ok, term()} | {:error, BambooHR.Error.t()}

  @derive {Inspect, except: [:auth]}
  defstruct [:company_domain, :auth, :base_url, :http_client, :timeout]

  @doc """
  Creates a new client configuration.

  ## Options

    * `:company_domain` - Your company's subdomain
    * `:api_key` - Your API key. Shorthand for `auth: {:api_key, key}`.
    * `:auth` - Optional. `{:api_key, key}` or `{:bearer, token}`, where
      the token is an OAuth 2.0 access token. Give either this or
      `:api_key`, not both.
    * `:base_url` - Optional. Custom base URL. The default depends on the
      auth method — see "Base URLs" below.
    * `:http_client` - Optional. Module that implements the `HTTPClient` behavior. Defaults to `BambooHR.HTTPClient.Req`.
    * `:timeout` - Optional. HTTP receive timeout in milliseconds. Defaults to `15_000`.

  ## Base URLs

  The two auth methods use different hosts and URL shapes, so a
  `:base_url` written for one will not work for the other.

  With an API key, requests go to the gateway host and the company
  domain is part of the path:

      https://api.bamboohr.com/api/gateway.php/{company_domain}/v1/employees

  With a bearer token, requests go to the company's own subdomain, which
  is the only server listed in BambooHR's OpenAPI spec and what
  BambooHR's own SDKs use:

      https://{company_domain}.bamboohr.com/api/v1/employees

  ## Examples

      iex> client = BambooHR.Client.new(company_domain: "acme", api_key: "api_key_123")
      iex> {client.company_domain, client.base_url, client.timeout}
      {"acme", "https://api.bamboohr.com/api/gateway.php", 15_000}

      iex> client = BambooHR.Client.new(company_domain: "acme", auth: {:bearer, "token_123"})
      iex> {client.auth, client.base_url}
      {{:bearer, "token_123"}, "https://acme.bamboohr.com/api"}

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
    auth = build_auth(opts)

    base_url =
      opts
      |> Keyword.get(:base_url, default_base_url(auth, company_domain))
      |> String.trim_trailing("/")

    http_client = Keyword.get(opts, :http_client, BambooHR.HTTPClient.Req)
    timeout = Keyword.get(opts, :timeout, 15_000)

    %__MODULE__{
      company_domain: company_domain,
      auth: auth,
      base_url: base_url,
      http_client: http_client,
      timeout: timeout
    }
  end

  defp build_auth(opts) do
    case {Keyword.fetch(opts, :auth), Keyword.fetch(opts, :api_key)} do
      {{:ok, _auth}, {:ok, _api_key}} ->
        raise ArgumentError, "expected either :auth or :api_key, got both"

      {{:ok, {kind, credential}}, :error} when kind in [:api_key, :bearer] ->
        {kind, validate_non_empty!(credential, kind)}

      {{:ok, auth}, :error} ->
        raise ArgumentError,
              "expected :auth to be {:api_key, key} or {:bearer, token}, got: #{inspect(auth)}"

      {:error, {:ok, api_key}} ->
        {:api_key, validate_non_empty!(api_key, :api_key)}

      {:error, :error} ->
        raise ArgumentError, "expected :auth or :api_key to be given"
    end
  end

  defp default_base_url({:bearer, _token}, company_domain),
    do: "https://#{company_domain}.bamboohr.com/api"

  defp default_base_url({:api_key, _key}, _company_domain),
    do: "https://api.bamboohr.com/api/gateway.php"

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
  through this argument. `opts` may also include `api_version:` — see
  "API versions" above — plus `content_type:` and `idempotency_key:`, which
  add those two headers. They are named individually rather than accepting
  arbitrary headers, so nothing can displace the `Authorization` header.
  Either may be `nil`, which sends no header; any other non-string raises
  `ArgumentError` rather than being dropped silently.
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
  through this argument. `opts` may also include `api_version:` — see
  "API versions" above — plus `content_type:` and `idempotency_key:`, which
  add those two headers. They are named individually rather than accepting
  arbitrary headers, so nothing can displace the `Authorization` header.
  Either may be `nil`, which sends no header; any other non-string raises
  `ArgumentError` rather than being dropped silently.
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
  through this argument. `opts` may also include `api_version:` — see
  "API versions" above — plus `content_type:` and `idempotency_key:`, which
  add those two headers. They are named individually rather than accepting
  arbitrary headers, so nothing can displace the `Authorization` header.
  Either may be `nil`, which sends no header; any other non-string raises
  `ArgumentError` rather than being dropped silently.
  """
  @spec put(String.t(), t(), keyword()) :: response()
  def put(path, %__MODULE__{} = client, opts) do
    request(:put, path, client, opts)
  end

  @doc """
  Makes a PATCH request to the BambooHR API.

  This function is meant to be used by resource modules. `opts` are forwarded
  to the underlying HTTP client; keys controlled by the client itself —
  `:method`, `:url`, `:headers`, `:receive_timeout` — cannot be overridden
  through this argument. `opts` may also include `api_version:` — see
  "API versions" above — plus `content_type:` and `idempotency_key:`, which
  add those two headers. They are named individually rather than accepting
  arbitrary headers, so nothing can displace the `Authorization` header.
  Either may be `nil`, which sends no header; any other non-string raises
  `ArgumentError` rather than being dropped silently.
  """
  @spec patch(String.t(), t(), keyword()) :: response()
  def patch(path, %__MODULE__{} = client, opts) do
    request(:patch, path, client, opts)
  end

  @doc """
  Makes a DELETE request to the BambooHR API.

  This function is meant to be used by resource modules. `opts` are forwarded
  to the underlying HTTP client; keys controlled by the client itself —
  `:method`, `:url`, `:headers`, `:receive_timeout` — cannot be overridden
  through this argument. `opts` may also include `api_version:` — see
  "API versions" above — plus `content_type:` and `idempotency_key:`, which
  add those two headers. They are named individually rather than accepting
  arbitrary headers, so nothing can displace the `Authorization` header.
  Either may be `nil`, which sends no header; any other non-string raises
  `ArgumentError` rather than being dropped silently.
  """
  @spec delete(String.t(), t(), keyword()) :: response()
  def delete(path, %__MODULE__{} = client, opts \\ []) do
    request(:delete, path, client, opts)
  end

  @known_api_versions ~w(v1 v1_1 v1_2 v2)

  defp request(method, path, client, opts) do
    {version, opts} = Keyword.pop(opts, :api_version, "v1")
    {content_type, opts} = Keyword.pop(opts, :content_type)
    {idempotency_key, opts} = Keyword.pop(opts, :idempotency_key)
    url = build_url(client, path, version)

    headers =
      build_headers(client.auth, Keyword.get(opts, :raw_response, false)) ++
        optional_headers(content_type, idempotency_key)

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

  defp result_metadata({:error, %BambooHR.Error{} = error}),
    do: %{result: :error, status: error.status, reason: error.reason}

  defp result_metadata({:error, reason}), do: %{result: :error, reason: reason}

  # An API key request carries the company domain in its path; a bearer
  # request is already on the company's own subdomain, so it does not.
  defp build_url(%{auth: {:api_key, _key}} = client, path, version) do
    validate_api_version!(version)
    "#{client.base_url}/#{client.company_domain}/#{version}#{normalize_path(path)}"
  end

  defp build_url(%{auth: {:bearer, _token}} = client, path, version) do
    validate_api_version!(version)
    "#{client.base_url}/#{version}#{normalize_path(path)}"
  end

  defp validate_api_version!(version) when version in @known_api_versions, do: :ok

  defp validate_api_version!(version) do
    raise ArgumentError,
          "expected :api_version to be one of #{inspect(@known_api_versions)}, got: #{inspect(version)}"
  end

  defp normalize_path("/" <> _ = path), do: path
  defp normalize_path(path), do: "/" <> path

  # A silently dropped Idempotency-Key would let a retry create a second
  # resource, which is the thing the option exists to prevent, so a value
  # that is neither nil nor a string is a mistake worth reporting.
  defp optional_headers(content_type, idempotency_key) do
    for {name, opt, value} <- [
          {"Content-Type", :content_type, content_type},
          {"Idempotency-Key", :idempotency_key, idempotency_key}
        ],
        value != nil do
      {name, validate_header!(opt, value)}
    end
  end

  defp validate_header!(_opt, value) when is_binary(value), do: value

  defp validate_header!(opt, value) do
    raise ArgumentError,
          "expected #{inspect(opt)} to be a string, got: #{inspect(value)}"
  end

  defp build_headers(auth, raw_response) do
    accept = if raw_response, do: "*/*", else: "application/json"

    [
      {"Authorization", authorization(auth)},
      {"Accept", accept}
    ]
  end

  defp authorization({:api_key, api_key}), do: "Basic " <> Base.encode64("#{api_key}:x")
  defp authorization({:bearer, token}), do: "Bearer " <> token
end
