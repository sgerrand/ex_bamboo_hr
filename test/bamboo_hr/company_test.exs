defmodule BambooHR.CompanyTest do
  use ExUnit.Case, async: true

  setup do
    bypass = Bypass.open()
    base_url = "http://localhost:#{bypass.port}/api/gateway.php"

    config =
      BambooHR.Client.new(company_domain: "test_company", api_key: "test_key", base_url: base_url)

    [bypass: bypass, config: config]
  end

  describe "get_information/1" do
    test "successfully retrieves company information", %{bypass: bypass, config: config} do
      company_info = %{
        "name" => "Test Company",
        "employeeCount" => 100
      }

      Bypass.expect_once(
        bypass,
        "GET",
        "/api/gateway.php/test_company/v1/company_information",
        fn conn ->
          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(200, Jason.encode!(company_info))
        end
      )

      assert {:ok, ^company_info} = BambooHR.Company.get_information(config)
    end

    test "handles error response", %{bypass: bypass, config: config} do
      error_response = %{"error" => "Unauthorized"}

      Bypass.expect_once(
        bypass,
        "GET",
        "/api/gateway.php/test_company/v1/company_information",
        fn conn ->
          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(401, Jason.encode!(error_response))
        end
      )

      assert {:error, %{status: 401, body: ^error_response}} =
               BambooHR.Company.get_information(config)
    end

    test "handles unexpected error", %{bypass: bypass, config: config} do
      Bypass.expect_once(
        bypass,
        "GET",
        "/api/gateway.php/test_company/v1/company_information",
        fn conn ->
          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(200, "bad")
        end
      )

      assert {:error, %Jason.DecodeError{}} =
               BambooHR.Company.get_information(config)
    end
  end

  describe "get_eins/1" do
    test "successfully retrieves company EINs", %{bypass: bypass, config: config} do
      eins_data = %{
        "eins" => [
          %{
            "ein" => "12-3456789",
            "name" => "Main Company"
          },
          %{
            "ein" => "98-7654321",
            "name" => "Subsidiary"
          }
        ]
      }

      Bypass.expect_once(
        bypass,
        "GET",
        "/api/gateway.php/test_company/v1/company_eins",
        fn conn ->
          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(200, Jason.encode!(eins_data))
        end
      )

      assert {:ok, ^eins_data} = BambooHR.Company.get_eins(config)
    end

    test "handles error response for EINs", %{bypass: bypass, config: config} do
      error_response = %{"error" => "Forbidden"}

      Bypass.expect_once(
        bypass,
        "GET",
        "/api/gateway.php/test_company/v1/company_eins",
        fn conn ->
          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(403, Jason.encode!(error_response))
        end
      )

      assert {:error, %{status: 403, body: ^error_response}} =
               BambooHR.Company.get_eins(config)
    end
  end
end
