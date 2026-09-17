defmodule BambooHR.OAuthTest do
  use ExUnit.Case, async: true

  setup do
    bypass = Bypass.open()
    token_url = "http://localhost:#{bypass.port}/token.php?request=token"

    {:ok, bypass: bypass, token_url: token_url}
  end

  describe "refresh_token/1" do
    test "exchanges a refresh token for a new pair", %{bypass: bypass, token_url: token_url} do
      tokens = %{
        "access_token" => "new-access-token",
        "refresh_token" => "new-refresh-token",
        "token_type" => "Bearer",
        "expires_in" => 3600
      }

      Bypass.expect_once(bypass, "POST", "/token.php", fn conn ->
        conn = Plug.Conn.fetch_query_params(conn)
        assert conn.query_params == %{"request" => "token"}

        {:ok, body, conn} = Plug.Conn.read_body(conn)

        assert URI.decode_query(body) == %{
                 "grant_type" => "refresh_token",
                 "refresh_token" => "old-refresh-token",
                 "client_id" => "client-id",
                 "client_secret" => "secret"
               }

        assert Plug.Conn.get_req_header(conn, "content-type") == [
                 "application/x-www-form-urlencoded"
               ]

        conn
        |> Plug.Conn.put_resp_header("content-type", "application/json")
        |> Plug.Conn.resp(200, Jason.encode!(tokens))
      end)

      assert {:ok, ^tokens} =
               BambooHR.OAuth.refresh_token(
                 company_domain: "acme",
                 client_id: "client-id",
                 client_secret: "secret",
                 refresh_token: "old-refresh-token",
                 token_url: token_url
               )
    end

    test "returns an error for a rejected refresh token", %{
      bypass: bypass,
      token_url: token_url
    } do
      Bypass.expect_once(bypass, "POST", "/token.php", fn conn ->
        Plug.Conn.resp(conn, 401, ~s({"error":"invalid_grant"}))
      end)

      assert {:error, %BambooHR.Error{reason: :unauthorized, status: 401}} =
               BambooHR.OAuth.refresh_token(
                 company_domain: "acme",
                 client_id: "client-id",
                 client_secret: "secret",
                 refresh_token: "expired",
                 token_url: token_url
               )
    end

    test "sends no Authorization header", %{bypass: bypass, token_url: token_url} do
      Bypass.expect_once(bypass, "POST", "/token.php", fn conn ->
        assert Plug.Conn.get_req_header(conn, "authorization") == []

        conn
        |> Plug.Conn.put_resp_header("content-type", "application/json")
        |> Plug.Conn.resp(200, Jason.encode!(%{"access_token" => "t"}))
      end)

      assert {:ok, %{"access_token" => "t"}} =
               BambooHR.OAuth.refresh_token(
                 company_domain: "acme",
                 client_id: "client-id",
                 client_secret: "secret",
                 refresh_token: "refresh",
                 token_url: token_url
               )
    end
  end

  describe "required options" do
    test "rejects a missing option" do
      assert_raise ArgumentError, ~r/:refresh_token/, fn ->
        BambooHR.OAuth.refresh_token(
          company_domain: "acme",
          client_id: "client-id",
          client_secret: "secret"
        )
      end
    end

    test "rejects an empty option" do
      assert_raise ArgumentError, ~r/:company_domain/, fn ->
        BambooHR.OAuth.refresh_token(
          company_domain: "",
          client_id: "client-id",
          client_secret: "secret",
          refresh_token: "refresh"
        )
      end
    end
  end

  describe "default token URL" do
    defmodule CaptureHTTPClient do
      @behaviour BambooHR.HTTPClient

      @impl true
      def request(opts) do
        send(self(), {:request_opts, opts})
        {:ok, %{}}
      end
    end

    test "points at the company's own subdomain" do
      BambooHR.OAuth.refresh_token(
        company_domain: "acme",
        client_id: "client-id",
        client_secret: "secret",
        refresh_token: "refresh",
        http_client: CaptureHTTPClient
      )

      assert_received {:request_opts, opts}
      assert opts[:url] == "https://acme.bamboohr.com/token.php?request=token"
      assert opts[:receive_timeout] == 15_000
    end

    test "honours a custom timeout" do
      BambooHR.OAuth.refresh_token(
        company_domain: "acme",
        client_id: "client-id",
        client_secret: "secret",
        refresh_token: "refresh",
        http_client: CaptureHTTPClient,
        timeout: 5_000
      )

      assert_received {:request_opts, opts}
      assert opts[:receive_timeout] == 5_000
    end
  end
end
