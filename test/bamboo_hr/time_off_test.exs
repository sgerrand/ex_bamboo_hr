defmodule BambooHR.TimeOffTest do
  use BambooHR.BypassCase, async: true

  describe "get_employee_policies/2" do
    test "successfully retrieves assigned policies", %{bypass: bypass, config: config} do
      policies_data = [
        %{"timeOffPolicyId" => 4, "timeOffTypeId" => 1, "accrualStartDate" => "2024-02-01"}
      ]

      Bypass.expect_once(
        bypass,
        "GET",
        "/api/gateway.php/test_company/v1/employees/123/time_off/policies",
        fn conn ->
          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(200, Jason.encode!(policies_data))
        end
      )

      assert {:ok, ^policies_data} = BambooHR.TimeOff.get_employee_policies(config, 123)
    end
  end

  describe "assign_employee_policies/3" do
    test "successfully assigns policies", %{bypass: bypass, config: config} do
      policies = [%{"timeOffPolicyId" => 4, "accrualStartDate" => "2024-02-01"}]
      response_data = [%{"timeOffPolicyId" => 4, "timeOffTypeId" => 1}]

      Bypass.expect_once(
        bypass,
        "PUT",
        "/api/gateway.php/test_company/v1/employees/123/time_off/policies",
        fn conn ->
          {:ok, body, conn} = Plug.Conn.read_body(conn)
          assert Jason.decode!(body) == policies

          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(200, Jason.encode!(response_data))
        end
      )

      assert {:ok, ^response_data} =
               BambooHR.TimeOff.assign_employee_policies(config, 123, policies)
    end
  end

  describe "get_employee_policies_v1_1/2" do
    test "successfully retrieves assigned policies including manual/unlimited types", %{
      bypass: bypass,
      config: config
    } do
      policies_data = [
        %{"timeOffPolicyId" => 4, "timeOffTypeId" => 1, "accrualStartDate" => nil}
      ]

      Bypass.expect_once(
        bypass,
        "GET",
        "/api/gateway.php/test_company/v1_1/employees/123/time_off/policies",
        fn conn ->
          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(200, Jason.encode!(policies_data))
        end
      )

      assert {:ok, ^policies_data} = BambooHR.TimeOff.get_employee_policies_v1_1(config, 123)
    end
  end

  describe "assign_employee_policies_v1_1/3" do
    test "successfully assigns policies including manual/unlimited types", %{
      bypass: bypass,
      config: config
    } do
      policies = [%{"timeOffPolicyId" => 4, "accrualStartDate" => "2024-02-01"}]
      response_data = [%{"timeOffPolicyId" => 4, "timeOffTypeId" => 1}]

      Bypass.expect_once(
        bypass,
        "PUT",
        "/api/gateway.php/test_company/v1_1/employees/123/time_off/policies",
        fn conn ->
          {:ok, body, conn} = Plug.Conn.read_body(conn)
          assert Jason.decode!(body) == policies

          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(200, Jason.encode!(response_data))
        end
      )

      assert {:ok, ^response_data} =
               BambooHR.TimeOff.assign_employee_policies_v1_1(config, 123, policies)
    end
  end

  describe "calculate_balances/3" do
    test "successfully retrieves balances", %{bypass: bypass, config: config} do
      balance_data = [
        %{"timeOffType" => "1", "name" => "Vacation", "units" => "hours", "balance" => "24.50"}
      ]

      Bypass.expect_once(
        bypass,
        "GET",
        "/api/gateway.php/test_company/v1/employees/123/time_off/calculator",
        fn conn ->
          assert conn.query_string == ""

          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(200, Jason.encode!(balance_data))
        end
      )

      assert {:ok, ^balance_data} = BambooHR.TimeOff.calculate_balances(config, 123)
    end

    test "forwards optional query params", %{bypass: bypass, config: config} do
      Bypass.expect_once(
        bypass,
        "GET",
        "/api/gateway.php/test_company/v1/employees/123/time_off/calculator",
        fn conn ->
          assert conn.query_string == "end=2024-12-31&precision=4"

          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(200, Jason.encode!([]))
        end
      )

      assert {:ok, []} =
               BambooHR.TimeOff.calculate_balances(config, 123, %{
                 "end" => "2024-12-31",
                 "precision" => 4
               })
    end
  end

  describe "add_time_off_history/3" do
    test "successfully creates a history item", %{bypass: bypass, config: config} do
      history_data = %{"timeOffRequestId" => 1348}

      Bypass.expect_once(
        bypass,
        "PUT",
        "/api/gateway.php/test_company/v1/employees/123/time_off/history",
        fn conn ->
          {:ok, body, conn} = Plug.Conn.read_body(conn)
          assert Jason.decode!(body) == history_data

          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(201, "")
        end
      )

      assert {:ok, nil} = BambooHR.TimeOff.add_time_off_history(config, 123, history_data)
    end
  end

  describe "adjust_time_off_balance/3" do
    test "successfully adjusts balance", %{bypass: bypass, config: config} do
      adjustment_data = %{"timeOffTypeId" => 1, "amount" => 8, "date" => "2024-01-15"}

      Bypass.expect_once(
        bypass,
        "PUT",
        "/api/gateway.php/test_company/v1/employees/123/time_off/balance_adjustment",
        fn conn ->
          {:ok, body, conn} = Plug.Conn.read_body(conn)
          assert Jason.decode!(body) == adjustment_data

          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(201, "")
        end
      )

      assert {:ok, nil} =
               BambooHR.TimeOff.adjust_time_off_balance(config, 123, adjustment_data)
    end
  end

  describe "create_time_off_request/3" do
    test "successfully creates a request", %{bypass: bypass, config: config} do
      request_data = %{"status" => "approved", "start" => "2024-02-01", "end" => "2024-02-03"}

      Bypass.expect_once(
        bypass,
        "PUT",
        "/api/gateway.php/test_company/v1/employees/123/time_off/request",
        fn conn ->
          {:ok, body, conn} = Plug.Conn.read_body(conn)
          assert Jason.decode!(body) == request_data

          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(201, "")
        end
      )

      assert {:ok, nil} = BambooHR.TimeOff.create_time_off_request(config, 123, request_data)
    end
  end

  describe "change_request_status/3" do
    test "successfully updates request status", %{bypass: bypass, config: config} do
      status_data = %{"status" => "approved"}

      Bypass.expect_once(
        bypass,
        "PUT",
        "/api/gateway.php/test_company/v1/time_off/requests/1348/status",
        fn conn ->
          {:ok, body, conn} = Plug.Conn.read_body(conn)
          assert Jason.decode!(body) == status_data

          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(200, "")
        end
      )

      assert {:ok, nil} = BambooHR.TimeOff.change_request_status(config, 1348, status_data)
    end
  end

  describe "get_time_off_requests/2" do
    test "successfully retrieves requests", %{bypass: bypass, config: config} do
      requests_data = [%{"id" => 1348, "employeeId" => 5}]

      Bypass.expect_once(
        bypass,
        "GET",
        "/api/gateway.php/test_company/v1/time_off/requests",
        fn conn ->
          assert conn.query_string == "end=2024-01-31&start=2024-01-01"

          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(200, Jason.encode!(requests_data))
        end
      )

      assert {:ok, ^requests_data} =
               BambooHR.TimeOff.get_time_off_requests(config, %{
                 "start" => "2024-01-01",
                 "end" => "2024-01-31"
               })
    end

    test "handles error response", %{bypass: bypass, config: config} do
      error_response = %{"error" => "Invalid or missing start/end date."}

      Bypass.expect_once(
        bypass,
        "GET",
        "/api/gateway.php/test_company/v1/time_off/requests",
        fn conn ->
          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(400, Jason.encode!(error_response))
        end
      )

      assert {:error, %{status: 400, body: body}} =
               BambooHR.TimeOff.get_time_off_requests(config, %{})

      assert Jason.decode!(body) == error_response
    end
  end

  describe "get_who_is_out/2" do
    test "successfully retrieves who's out with no params", %{bypass: bypass, config: config} do
      whos_out_data = [%{"id" => 1, "type" => "timeOff", "employeeId" => 5, "name" => "Jane"}]

      Bypass.expect_once(
        bypass,
        "GET",
        "/api/gateway.php/test_company/v1/time_off/whos_out",
        fn conn ->
          assert conn.query_string == ""

          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(200, Jason.encode!(whos_out_data))
        end
      )

      assert {:ok, ^whos_out_data} = BambooHR.TimeOff.get_who_is_out(config)
    end

    test "forwards optional query params", %{bypass: bypass, config: config} do
      Bypass.expect_once(
        bypass,
        "GET",
        "/api/gateway.php/test_company/v1/time_off/whos_out",
        fn conn ->
          assert conn.query_string == "end=2024-02-14&start=2024-02-01"

          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(200, Jason.encode!([]))
        end
      )

      assert {:ok, []} =
               BambooHR.TimeOff.get_who_is_out(config, %{
                 "start" => "2024-02-01",
                 "end" => "2024-02-14"
               })
    end
  end
end
