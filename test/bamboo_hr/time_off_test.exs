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

  describe "list_requests/2" do
    test "lists requests with filter, sort and actions", %{bypass: bypass, config: config} do
      page = %{
        "data" => [%{"id" => 1348, "status" => "REQUESTED"}],
        "meta" => %{"page" => 1, "pageSize" => 100, "totalItems" => 1, "totalPages" => 1}
      }

      Bypass.expect_once(
        bypass,
        "GET",
        "/api/gateway.php/test_company/v1/time-off/requests",
        fn conn ->
          conn = Plug.Conn.fetch_query_params(conn)

          assert conn.query_params == %{
                   "filter" => "status eq 'REQUESTED'",
                   "orderBy" => "startDate asc",
                   "returnActions" => "true"
                 }

          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(200, Jason.encode!(page))
        end
      )

      assert {:ok, ^page} =
               BambooHR.TimeOff.list_requests(config,
                 filter: "status eq 'REQUESTED'",
                 order_by: "startDate asc",
                 return_actions: true
               )
    end

    test "sends no query params by default", %{bypass: bypass, config: config} do
      Bypass.expect_once(
        bypass,
        "GET",
        "/api/gateway.php/test_company/v1/time-off/requests",
        fn conn ->
          assert conn.query_string == ""

          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(200, Jason.encode!(%{"data" => []}))
        end
      )

      assert {:ok, %{"data" => []}} = BambooHR.TimeOff.list_requests(config)
    end
  end

  describe "create_request/3" do
    test "creates a request", %{bypass: bypass, config: config} do
      request_data = %{
        "employeeId" => 123,
        "categoryId" => 4,
        "startDate" => "2024-02-01",
        "endDate" => "2024-02-02",
        "amount" => 16
      }

      Bypass.expect_once(
        bypass,
        "POST",
        "/api/gateway.php/test_company/v1/time-off/requests",
        fn conn ->
          assert conn.query_string == ""
          {:ok, body, conn} = Plug.Conn.read_body(conn)
          assert Jason.decode!(body) == request_data

          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(201, Jason.encode!(%{"id" => 1348, "status" => "REQUESTED"}))
        end
      )

      assert {:ok, %{"id" => 1348, "status" => "REQUESTED"}} =
               BambooHR.TimeOff.create_request(config, request_data)
    end

    test "surfaces sending both amount and dailyAmounts", %{bypass: bypass, config: config} do
      Bypass.expect_once(
        bypass,
        "POST",
        "/api/gateway.php/test_company/v1/time-off/requests",
        fn conn -> Plug.Conn.resp(conn, 422, "") end
      )

      assert {:error, %BambooHR.Error{reason: :unprocessable_entity}} =
               BambooHR.TimeOff.create_request(config, %{"amount" => 8, "dailyAmounts" => []})
    end
  end

  describe "get_request/3" do
    test "retrieves a request with its actions", %{bypass: bypass, config: config} do
      Bypass.expect_once(
        bypass,
        "GET",
        "/api/gateway.php/test_company/v1/time-off/requests/1348",
        fn conn ->
          conn = Plug.Conn.fetch_query_params(conn)
          assert conn.query_params == %{"returnActions" => "true"}

          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(200, Jason.encode!(%{"id" => 1348, "_links" => %{}}))
        end
      )

      assert {:ok, %{"id" => 1348}} =
               BambooHR.TimeOff.get_request(config, 1348, return_actions: true)
    end

    test "reports a replaced id as gone", %{bypass: bypass, config: config} do
      Bypass.expect_once(
        bypass,
        "GET",
        "/api/gateway.php/test_company/v1/time-off/requests/1348",
        fn conn -> Plug.Conn.resp(conn, 410, "") end
      )

      assert {:error, %BambooHR.Error{reason: :gone, status: 410}} =
               BambooHR.TimeOff.get_request(config, 1348)
    end
  end

  describe "update_request/4" do
    test "returns the replacement id for an edited pending request", %{
      bypass: bypass,
      config: config
    } do
      Bypass.expect_once(
        bypass,
        "PATCH",
        "/api/gateway.php/test_company/v1/time-off/requests/1348",
        fn conn ->
          {:ok, body, conn} = Plug.Conn.read_body(conn)
          assert Jason.decode!(body) == %{"employeeNote" => "Family trip"}

          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(200, Jason.encode!(%{"id" => 1351, "status" => "REQUESTED"}))
        end
      )

      # The id in the response replaces the one in the path.
      assert {:ok, %{"id" => 1351}} =
               BambooHR.TimeOff.update_request(config, 1348, %{"employeeNote" => "Family trip"})
    end

    test "clears the note with an explicit null", %{bypass: bypass, config: config} do
      Bypass.expect_once(
        bypass,
        "PATCH",
        "/api/gateway.php/test_company/v1/time-off/requests/1348",
        fn conn ->
          {:ok, body, conn} = Plug.Conn.read_body(conn)
          assert Jason.decode!(body) == %{"employeeNote" => nil}

          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(200, Jason.encode!(%{"id" => 1348, "employeeNote" => nil}))
        end
      )

      assert {:ok, %{"employeeNote" => nil}} =
               BambooHR.TimeOff.update_request(config, 1348, %{"employeeNote" => nil})
    end

    test "surfaces an edit to a closed request", %{bypass: bypass, config: config} do
      Bypass.expect_once(
        bypass,
        "PATCH",
        "/api/gateway.php/test_company/v1/time-off/requests/1348",
        fn conn -> Plug.Conn.resp(conn, 409, "") end
      )

      assert {:error, %BambooHR.Error{reason: :conflict}} =
               BambooHR.TimeOff.update_request(config, 1348, %{"employeeNote" => "x"})
    end
  end

  describe "request comments" do
    test "lists comments", %{bypass: bypass, config: config} do
      Bypass.expect_once(
        bypass,
        "GET",
        "/api/gateway.php/test_company/v1/time-off/requests/1348/comments",
        fn conn ->
          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(200, Jason.encode!(%{"data" => [%{"id" => 7}]}))
        end
      )

      assert {:ok, %{"data" => [%{"id" => 7}]}} =
               BambooHR.TimeOff.list_request_comments(config, 1348)
    end

    test "adds a comment", %{bypass: bypass, config: config} do
      Bypass.expect_once(
        bypass,
        "POST",
        "/api/gateway.php/test_company/v1/time-off/requests/1348/comments",
        fn conn ->
          {:ok, body, conn} = Plug.Conn.read_body(conn)
          assert Jason.decode!(body) == %{"comment" => "Covered by Sam."}

          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(201, Jason.encode!(%{"id" => 7, "comment" => "Covered by Sam."}))
        end
      )

      assert {:ok, %{"id" => 7}} =
               BambooHR.TimeOff.create_request_comment(config, 1348, "Covered by Sam.")
    end
  end

  describe "list_whos_out/4" do
    test "sends the range and options", %{bypass: bypass, config: config} do
      Bypass.expect_once(
        bypass,
        "GET",
        "/api/gateway.php/test_company/v1/whos-out",
        fn conn ->
          conn = Plug.Conn.fetch_query_params(conn)

          assert conn.query_params == %{
                   "start" => "2024-02-01",
                   "end" => "2024-02-07",
                   "filter" => "department eq 3",
                   "directReportsOnly" => "true",
                   "includePersons" => "true"
                 }

          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(200, Jason.encode!(%{"data" => [], "persons" => %{}}))
        end
      )

      assert {:ok, %{"data" => [], "persons" => %{}}} =
               BambooHR.TimeOff.list_whos_out(config, "2024-02-01", "2024-02-07",
                 filter: "department eq 3",
                 direct_reports_only: true,
                 include_persons: true
               )
    end

    test "sends only the range by default", %{bypass: bypass, config: config} do
      Bypass.expect_once(
        bypass,
        "GET",
        "/api/gateway.php/test_company/v1/whos-out",
        fn conn ->
          assert conn.query_string == "start=2024-02-01&end=2024-02-07"

          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(200, Jason.encode!(%{"data" => []}))
        end
      )

      assert {:ok, %{"data" => []}} =
               BambooHR.TimeOff.list_whos_out(config, "2024-02-01", "2024-02-07")
    end

    test "surfaces a range longer than 366 days", %{bypass: bypass, config: config} do
      Bypass.expect_once(
        bypass,
        "GET",
        "/api/gateway.php/test_company/v1/whos-out",
        fn conn -> Plug.Conn.resp(conn, 422, "") end
      )

      assert {:error, %BambooHR.Error{reason: :unprocessable_entity}} =
               BambooHR.TimeOff.list_whos_out(config, "2024-01-01", "2025-06-01")
    end
  end
end
