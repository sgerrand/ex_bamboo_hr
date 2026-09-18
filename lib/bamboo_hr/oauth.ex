defmodule BambooHR.OAuth do
  @moduledoc """
  Helper for refreshing OAuth 2.0 access tokens.

  BambooHR issues access tokens that expire, plus a refresh token when the
  original authorization asked for the `offline_access` scope. This module
  exchanges a refresh token for a fresh pair.

  It holds no state. Storing tokens, deciding when to refresh, and
  retrying are the caller's job, which keeps this client free of
  background processes and of any opinion about where your secrets live:

      {:ok, %{"access_token" => access_token} = tokens} =
        BambooHR.OAuth.refresh_token(
          company_domain: "acme",
          client_id: client_id,
          client_secret: client_secret,
          refresh_token: refresh_token
        )

      :ok = MyApp.Tokens.store(tokens)

      client = BambooHR.Client.new(company_domain: "acme", auth: {:bearer, access_token})

  The response is BambooHR's own JSON, normally with `"access_token"`,
  `"refresh_token"`, `"expires_in"`, and `"token_type"`. A new refresh
  token may come back, so store the whole response rather than just the
  access token.
  """

  alias BambooHR.Client

  @doc """
  Exchanges a refresh token for a new access token.

  ## Options

    * `:company_domain` - Your company's subdomain. Required.
    * `:client_id` - Your OAuth application's client ID. Required.
    * `:client_secret` - Your OAuth application's client secret. Required.
    * `:refresh_token` - The refresh token from the original
      authorization. Required.
    * `:token_url` - Override the token endpoint. Defaults to
      `https://{company_domain}.bamboohr.com/token.php?request=token`.
    * `:http_client` - Module implementing `BambooHR.HTTPClient`.
      Defaults to `BambooHR.HTTPClient.Req`.
    * `:timeout` - HTTP receive timeout in milliseconds. Defaults to
      `15_000`.

  Raises `ArgumentError` when a required option is missing or is not a
  non-empty string. That is a mistake in your code rather than a failed
  request, so it is raised rather than returned, the same way
  `BambooHR.Client.new/1` behaves.

  ## Examples

      iex> BambooHR.OAuth.refresh_token(
      ...>   company_domain: "acme",
      ...>   client_id: "client-id",
      ...>   client_secret: "secret",
      ...>   refresh_token: "refresh-token"
      ...> )
      {:ok, %{
        "access_token" => "new-access-token",
        "refresh_token" => "new-refresh-token",
        "token_type" => "Bearer",
        "expires_in" => 3600
      }}
  """
  @spec refresh_token(keyword()) :: Client.response()
  def refresh_token(opts) when is_list(opts) do
    company_domain = fetch_required!(opts, :company_domain)
    client_id = fetch_required!(opts, :client_id)
    client_secret = fetch_required!(opts, :client_secret)
    refresh_token = fetch_required!(opts, :refresh_token)

    http_client = Keyword.get(opts, :http_client, BambooHR.HTTPClient.Req)
    url = Keyword.get(opts, :token_url, default_token_url(company_domain))

    http_client.request(
      method: :post,
      url: url,
      headers: [{"Accept", "application/json"}],
      receive_timeout: Keyword.get(opts, :timeout, 15_000),
      form: [
        grant_type: "refresh_token",
        refresh_token: refresh_token,
        client_id: client_id,
        client_secret: client_secret
      ]
    )
  end

  defp fetch_required!(opts, key) do
    case Keyword.get(opts, key) do
      value when is_binary(value) and byte_size(value) > 0 ->
        value

      value ->
        raise ArgumentError,
              "expected #{inspect(key)} to be a non-empty string, got: #{inspect(value)}"
    end
  end

  defp default_token_url(company_domain),
    do: "https://#{company_domain}.bamboohr.com/token.php?request=token"
end
