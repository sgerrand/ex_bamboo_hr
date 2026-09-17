defmodule BambooHR.CompanyTest do
  use BambooHR.BypassCase, async: true

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

      assert {:error, %{status: 401, body: body}} =
               BambooHR.Company.get_information(config)

      assert Jason.decode!(body) == error_response
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

      assert {:error, %BambooHR.Error{reason: :decode_error}} =
               BambooHR.Company.get_information(config)
    end
  end
end
