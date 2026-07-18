defmodule BambooHR.ReportsTest do
  use BambooHR.BypassCase, async: true

  describe "list_reports/2" do
    test "successfully retrieves reports with no params", %{bypass: bypass, config: config} do
      reports_data = %{
        "reports" => [%{"id" => 42, "name" => "Headcount by Department"}],
        "pagination" => %{
          "total_records" => 1,
          "current_page" => 1,
          "total_pages" => 1,
          "next_page" => nil,
          "prev_page" => nil
        }
      }

      Bypass.expect_once(
        bypass,
        "GET",
        "/api/gateway.php/test_company/v1/custom-reports",
        fn conn ->
          assert conn.query_string == ""

          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(200, Jason.encode!(reports_data))
        end
      )

      assert {:ok, ^reports_data} = BambooHR.Reports.list_reports(config)
    end

    test "forwards optional pagination params", %{bypass: bypass, config: config} do
      Bypass.expect_once(
        bypass,
        "GET",
        "/api/gateway.php/test_company/v1/custom-reports",
        fn conn ->
          assert conn.query_string == "page=2&page_size=100"

          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(200, Jason.encode!(%{"reports" => []}))
        end
      )

      assert {:ok, %{"reports" => []}} =
               BambooHR.Reports.list_reports(config, %{"page" => 2, "page_size" => 100})
    end

    test "handles feature-disabled error", %{bypass: bypass, config: config} do
      error_response = %{"error" => "Feature not enabled"}

      Bypass.expect_once(
        bypass,
        "GET",
        "/api/gateway.php/test_company/v1/custom-reports",
        fn conn ->
          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(403, Jason.encode!(error_response))
        end
      )

      assert {:error, %{status: 403, body: body}} = BambooHR.Reports.list_reports(config)
      assert Jason.decode!(body) == error_response
    end
  end

  describe "get_report/3" do
    test "successfully retrieves report data", %{bypass: bypass, config: config} do
      report_data = %{
        "data" => [%{"firstName" => "John", "status" => "Active"}],
        "aggregations" => []
      }

      Bypass.expect_once(
        bypass,
        "GET",
        "/api/gateway.php/test_company/v1/custom-reports/42",
        fn conn ->
          assert conn.query_string == ""

          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(200, Jason.encode!(report_data))
        end
      )

      assert {:ok, ^report_data} = BambooHR.Reports.get_report(config, 42)
    end

    test "forwards optional pagination params", %{bypass: bypass, config: config} do
      Bypass.expect_once(
        bypass,
        "GET",
        "/api/gateway.php/test_company/v1/custom-reports/42",
        fn conn ->
          assert conn.query_string == "page=2&page_size=100"

          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(200, Jason.encode!(%{"data" => []}))
        end
      )

      assert {:ok, %{"data" => []}} =
               BambooHR.Reports.get_report(config, 42, %{"page" => 2, "page_size" => 100})
    end

    test "handles not-found error", %{bypass: bypass, config: config} do
      error_response = %{"error" => "Report not found"}

      Bypass.expect_once(
        bypass,
        "GET",
        "/api/gateway.php/test_company/v1/custom-reports/999",
        fn conn ->
          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(404, Jason.encode!(error_response))
        end
      )

      assert {:error, %{status: 404, body: body}} = BambooHR.Reports.get_report(config, 999)
      assert Jason.decode!(body) == error_response
    end
  end
end
