defmodule BambooHR.TimeOffTest do
  use BambooHR.BypassCase, async: true

  # Deprecated functions are called through apply/3 so their deprecation
  # warnings do not fail the --warnings-as-errors build.
  # credo:disable-for-next-line Credo.Check.Refactor.Apply
  defp deprecated(fun, args), do: apply(BambooHR.TimeOff, fun, args)

  describe "get_employee_policies/2" do
    test "successfully retrieves assigned policies", %{bypass: bypass, config: config} do
      policies_data = [
        %{"timeOffPolicyId" => 4, "timeOffTypeId" => 1, "accrualStartDate" => "2024-02-01"}
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
               BambooHR.TimeOff.assign_employee_policies(config, 123, policies)
    end
  end

  describe "get_employee_policies_v1_1/2 (deprecated)" do
    test "delegates to get_employee_policies/2", %{
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

      assert {:ok, ^policies_data} =
               deprecated(:get_employee_policies_v1_1, [config, 123])
    end
  end

  describe "assign_employee_policies_v1_1/3 (deprecated)" do
    test "delegates to assign_employee_policies/3", %{
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
               deprecated(:assign_employee_policies_v1_1, [config, 123, policies])
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

  describe "approve_request/3" do
    test "successfully approves a request", %{bypass: bypass, config: config} do
      response_data = %{"id" => 1348, "status" => "APPROVED"}

      Bypass.expect_once(
        bypass,
        "POST",
        "/api/gateway.php/test_company/v1/time-off/requests/1348/approvals",
        fn conn ->
          {:ok, body, conn} = Plug.Conn.read_body(conn)
          assert Jason.decode!(body) == %{"managerNote" => "Enjoy!"}

          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(200, Jason.encode!(response_data))
        end
      )

      assert {:ok, ^response_data} =
               BambooHR.TimeOff.approve_request(config, 1348, %{"managerNote" => "Enjoy!"})
    end

    test "sends an empty body when no approval data is given", %{bypass: bypass, config: config} do
      Bypass.expect_once(
        bypass,
        "POST",
        "/api/gateway.php/test_company/v1/time-off/requests/1348/approvals",
        fn conn ->
          {:ok, body, conn} = Plug.Conn.read_body(conn)
          assert Jason.decode!(body) == %{}

          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(200, Jason.encode!(%{"id" => 1348}))
        end
      )

      assert {:ok, %{"id" => 1348}} = BambooHR.TimeOff.approve_request(config, 1348)
    end

    test "handles conflict error", %{bypass: bypass, config: config} do
      Bypass.expect_once(
        bypass,
        "POST",
        "/api/gateway.php/test_company/v1/time-off/requests/1348/approvals",
        fn conn -> Plug.Conn.resp(conn, 409, "") end
      )

      assert {:error, %{status: 409}} = BambooHR.TimeOff.approve_request(config, 1348)
    end
  end

  describe "deny_request/3" do
    test "successfully denies a request", %{bypass: bypass, config: config} do
      response_data = %{"id" => 1348, "status" => "DENIED"}

      Bypass.expect_once(
        bypass,
        "POST",
        "/api/gateway.php/test_company/v1/time-off/requests/1348/denials",
        fn conn ->
          {:ok, body, conn} = Plug.Conn.read_body(conn)
          assert Jason.decode!(body) == %{"bypass" => true}

          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(200, Jason.encode!(response_data))
        end
      )

      assert {:ok, ^response_data} =
               BambooHR.TimeOff.deny_request(config, 1348, %{"bypass" => true})
    end
  end

  describe "cancel_request/2" do
    test "successfully cancels a request", %{bypass: bypass, config: config} do
      response_data = %{"id" => 1348, "status" => "CANCELED"}

      Bypass.expect_once(
        bypass,
        "POST",
        "/api/gateway.php/test_company/v1/time-off/requests/1348/cancellations",
        fn conn ->
          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(200, Jason.encode!(response_data))
        end
      )

      assert {:ok, ^response_data} = BambooHR.TimeOff.cancel_request(config, 1348)
    end
  end

  describe "change_request_status/3 (deprecated)" do
    test "routes an approval to the approvals endpoint", %{bypass: bypass, config: config} do
      response_data = %{"id" => 1348, "status" => "APPROVED"}

      Bypass.expect_once(
        bypass,
        "POST",
        "/api/gateway.php/test_company/v1/time-off/requests/1348/approvals",
        fn conn ->
          {:ok, body, conn} = Plug.Conn.read_body(conn)
          assert Jason.decode!(body) == %{"managerNote" => "Looks good"}

          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(200, Jason.encode!(response_data))
        end
      )

      status_data = %{"status" => "approved", "note" => "Looks good"}

      assert {:ok, ^response_data} =
               deprecated(:change_request_status, [config, 1348, status_data])
    end

    test "routes a denial to the denials endpoint", %{bypass: bypass, config: config} do
      Bypass.expect_once(
        bypass,
        "POST",
        "/api/gateway.php/test_company/v1/time-off/requests/1348/denials",
        fn conn ->
          {:ok, body, conn} = Plug.Conn.read_body(conn)
          assert Jason.decode!(body) == %{}

          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(200, Jason.encode!(%{"status" => "DENIED"}))
        end
      )

      assert {:ok, %{"status" => "DENIED"}} =
               deprecated(:change_request_status, [config, 1348, %{"status" => "declined"}])
    end

    test "routes a cancellation to the cancellations endpoint", %{bypass: bypass, config: config} do
      Bypass.expect_once(
        bypass,
        "POST",
        "/api/gateway.php/test_company/v1/time-off/requests/1348/cancellations",
        fn conn ->
          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(200, Jason.encode!(%{"status" => "CANCELED"}))
        end
      )

      assert {:ok, %{"status" => "CANCELED"}} =
               deprecated(:change_request_status, [config, 1348, %{"status" => "cancelled"}])
    end

    test "returns an error for an unrecognised status", %{config: config} do
      assert {:error, {:invalid_status, "pending"}} =
               deprecated(:change_request_status, [config, 1348, %{"status" => "pending"}])
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
