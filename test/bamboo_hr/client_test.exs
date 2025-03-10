defmodule BambooHR.ClientTest do
  use ExUnit.Case, async: true

  setup do
    bypass = Bypass.open()
    base_url = "http://localhost:#{bypass.port}/api/gateway.php"

    config =
      BambooHR.Client.new(company_domain: "test_company", api_key: "test_key", base_url: base_url)

    {:ok, bypass: bypass, config: config}
  end

  describe "new/3" do
    test "creates config with default base URL" do
      config = BambooHR.Client.new(company_domain: "test_company", api_key: "test_key")
      assert config.company_domain == "test_company"
      assert config.api_key == "test_key"
      assert config.base_url == "https://api.bamboohr.com/api/gateway.php"
    end

    test "creates config with custom base URL" do
      custom_url = "https://custom-bamboohr.example.com"

      config =
        BambooHR.Client.new(
          company_domain: "test_company",
          api_key: "test_key",
          base_url: custom_url
        )

      assert config.company_domain == "test_company"
      assert config.api_key == "test_key"
      assert config.base_url == custom_url
    end
  end

  describe "get/3" do
    test "successfully makes GET request", %{bypass: bypass, config: config} do
      response_data = %{"key" => "value"}

      Bypass.expect_once(
        bypass,
        "GET",
        "/api/gateway.php/test_company/v1/test_path",
        fn conn ->
          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(200, Jason.encode!(response_data))
        end
      )

      assert {:ok, ^response_data} = BambooHR.Client.get("/test_path", config)
    end

    test "handles error response for GET", %{bypass: bypass, config: config} do
      error_response = %{"error" => "Not found"}

      Bypass.expect_once(
        bypass,
        "GET",
        "/api/gateway.php/test_company/v1/test_path",
        fn conn ->
          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(404, Jason.encode!(error_response))
        end
      )

      assert {:error, %{status: 404, body: ^error_response}} =
               BambooHR.Client.get("/test_path", config)
    end

    test "handles unexpected error for GET", %{bypass: bypass, config: config} do
      Bypass.expect_once(
        bypass,
        "GET",
        "/api/gateway.php/test_company/v1/test_path",
        fn conn ->
          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(200, "bad")
        end
      )

      assert {:error, %Jason.DecodeError{}} =
               BambooHR.Client.get("/test_path", config)
    end
  end

  describe "post/3" do
    test "successfully makes POST request", %{bypass: bypass, config: config} do
      request_data = %{"request" => "data"}
      response_data = %{"key" => "value"}

      Bypass.expect_once(
        bypass,
        "POST",
        "/api/gateway.php/test_company/v1/test_path",
        fn conn ->
          {:ok, body, conn} = Plug.Conn.read_body(conn)
          assert Jason.decode!(body) == request_data

          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(200, Jason.encode!(response_data))
        end
      )

      assert {:ok, ^response_data} =
               BambooHR.Client.post("/test_path", config, json: request_data)
    end

    test "handles error response for POST", %{bypass: bypass, config: config} do
      request_data = %{"request" => "data"}
      error_response = %{"error" => "Bad request"}

      Bypass.expect_once(
        bypass,
        "POST",
        "/api/gateway.php/test_company/v1/test_path",
        fn conn ->
          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(400, Jason.encode!(error_response))
        end
      )

      assert {:error, %{status: 400, body: ^error_response}} =
               BambooHR.Client.post("/test_path", config, json: request_data)
    end
  end
end
