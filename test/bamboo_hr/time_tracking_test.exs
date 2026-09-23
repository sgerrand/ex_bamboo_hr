defmodule BambooHR.TimeTrackingTest do
  use BambooHR.BypassCase, async: true

  describe "get_timesheet_entries/2" do
    test "successfully retrieves timesheet entries", %{bypass: bypass, config: config} do
      params = %{
        "start" => "2024-01-01",
        "end" => "2024-01-31",
        "employeeIds" => "123,124"
      }

      timesheet_data = %{
        "entries" => [
          %{
            "id" => "1",
            "employeeId" => "123",
            "date" => "2024-01-15",
            "hours" => 8.0,
            "note" => "Regular work day"
          },
          %{
            "id" => "2",
            "employeeId" => "124",
            "date" => "2024-01-15",
            "hours" => 7.5,
            "note" => "Half day"
          }
        ]
      }

      Bypass.expect_once(
        bypass,
        "GET",
        "/api/gateway.php/test_company/v1/time_tracking/timesheet_entries",
        fn conn ->
          assert conn.query_string == "employeeIds=123%2C124&end=2024-01-31&start=2024-01-01"

          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(200, Jason.encode!(timesheet_data))
        end
      )

      assert {:ok, ^timesheet_data} = BambooHR.TimeTracking.get_timesheet_entries(config, params)
    end

    test "handles error when retrieving timesheet entries", %{bypass: bypass, config: config} do
      params = %{
        "start" => "2024-01-01",
        "end" => "2024-01-31"
      }

      error_response = %{"error" => "Invalid date range"}

      Bypass.expect_once(
        bypass,
        "GET",
        "/api/gateway.php/test_company/v1/time_tracking/timesheet_entries",
        fn conn ->
          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(400, Jason.encode!(error_response))
        end
      )

      assert {:error, %{status: 400, body: body}} =
               BambooHR.TimeTracking.get_timesheet_entries(config, params)

      assert Jason.decode!(body) == error_response
    end
  end

  describe "store_clock_entries/2" do
    test "successfully stores timesheet clock entries", %{bypass: bypass, config: config} do
      entries = [
        %{
          "employeeId" => "123",
          "date" => "2024-01-15",
          "start" => "09:00:00",
          "end" => "17:00:00",
          "note" => "Regular work day"
        },
        %{
          "employeeId" => "124",
          "date" => "2024-01-15",
          "start" => "09:00:00",
          "end" => "13:00:00",
          "note" => "Half day"
        }
      ]

      Bypass.expect_once(
        bypass,
        "POST",
        "/api/gateway.php/test_company/v1/time_tracking/clock_entries/store",
        fn conn ->
          {:ok, body, conn} = Plug.Conn.read_body(conn)
          assert Jason.decode!(body) == %{"items" => entries}

          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(200, Jason.encode!(%{"message" => "Entries stored successfully"}))
        end
      )

      assert {:ok, %{"message" => "Entries stored successfully"}} =
               BambooHR.TimeTracking.store_clock_entries(config, entries)
    end

    test "handles error when storing timesheet clock entries", %{bypass: bypass, config: config} do
      entries = [
        %{
          "employeeId" => "123",
          "date" => "2024-01-15",
          "start" => "invalid_time",
          "end" => "17:00:00"
        }
      ]

      error_response = %{"error" => "Invalid time format"}

      Bypass.expect_once(
        bypass,
        "POST",
        "/api/gateway.php/test_company/v1/time_tracking/clock_entries/store",
        fn conn ->
          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(400, Jason.encode!(error_response))
        end
      )

      assert {:error, %{status: 400, body: body}} =
               BambooHR.TimeTracking.store_clock_entries(config, entries)

      assert Jason.decode!(body) == error_response
    end
  end

  describe "clock_in/3" do
    test "successfully clocks in employee", %{bypass: bypass, config: config} do
      employee_id = 123

      clock_data = %{
        "date" => "2024-01-15",
        "start" => "09:00",
        "timezone" => "America/New_York",
        "projectId" => "456",
        "taskId" => "789",
        "note" => "Starting work on project X"
      }

      Bypass.expect_once(
        bypass,
        "POST",
        "/api/gateway.php/test_company/v1/time_tracking/employees/#{employee_id}/clock_in",
        fn conn ->
          {:ok, body, conn} = Plug.Conn.read_body(conn)
          assert Jason.decode!(body) == clock_data

          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(200, Jason.encode!(%{"message" => "Successfully clocked in"}))
        end
      )

      assert {:ok, %{"message" => "Successfully clocked in"}} =
               BambooHR.TimeTracking.clock_in(config, employee_id, clock_data)
    end

    test "handles error when clocking in employee", %{bypass: bypass, config: config} do
      employee_id = 123

      clock_data = %{
        "date" => "2024-01-15",
        "start" => "09:00",
        "timezone" => "Invalid/Timezone"
      }

      error_response = %{"error" => "Invalid timezone"}

      Bypass.expect_once(
        bypass,
        "POST",
        "/api/gateway.php/test_company/v1/time_tracking/employees/#{employee_id}/clock_in",
        fn conn ->
          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(400, Jason.encode!(error_response))
        end
      )

      assert {:error, %{status: 400, body: body}} =
               BambooHR.TimeTracking.clock_in(config, employee_id, clock_data)

      assert Jason.decode!(body) == error_response
    end
  end

  describe "clock_out/3" do
    test "successfully clocks out employee", %{bypass: bypass, config: config} do
      employee_id = 123

      clock_data = %{
        "date" => "2024-01-15",
        "end" => "17:00",
        "timezone" => "America/New_York"
      }

      Bypass.expect_once(
        bypass,
        "POST",
        "/api/gateway.php/test_company/v1/time_tracking/employees/#{employee_id}/clock_out",
        fn conn ->
          {:ok, body, conn} = Plug.Conn.read_body(conn)
          assert Jason.decode!(body) == clock_data

          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(200, Jason.encode!(%{"message" => "Successfully clocked out"}))
        end
      )

      assert {:ok, %{"message" => "Successfully clocked out"}} =
               BambooHR.TimeTracking.clock_out(config, employee_id, clock_data)
    end

    test "handles error when clocking out employee", %{bypass: bypass, config: config} do
      employee_id = 123

      clock_data = %{
        "date" => "2024-01-15",
        # Invalid time
        "end" => "25:00",
        "timezone" => "America/New_York"
      }

      error_response = %{"error" => "Invalid time format"}

      Bypass.expect_once(
        bypass,
        "POST",
        "/api/gateway.php/test_company/v1/time_tracking/employees/#{employee_id}/clock_out",
        fn conn ->
          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(400, Jason.encode!(error_response))
        end
      )

      assert {:error, %{status: 400, body: body}} =
               BambooHR.TimeTracking.clock_out(config, employee_id, clock_data)

      assert Jason.decode!(body) == error_response
    end
  end

  describe "list_clock_entries/2" do
    test "lists a page of clock entries", %{bypass: bypass, config: config} do
      page = %{
        "data" => [%{"id" => 1, "employeeId" => 123}],
        "meta" => %{"page" => 1, "pageSize" => 50, "totalItems" => 1, "totalPages" => 1}
      }

      Bypass.expect_once(
        bypass,
        "GET",
        "/api/gateway.php/test_company/v1/time-tracking/clock-entries",
        fn conn ->
          assert conn.query_string == ""

          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(200, Jason.encode!(page))
        end
      )

      assert {:ok, ^page} = BambooHR.TimeTracking.list_clock_entries(config)
    end

    test "passes filter, sort and paging as query params", %{bypass: bypass, config: config} do
      Bypass.expect_once(
        bypass,
        "GET",
        "/api/gateway.php/test_company/v1/time-tracking/clock-entries",
        fn conn ->
          conn = Plug.Conn.fetch_query_params(conn)

          assert conn.query_params == %{
                   "filter" => "employeeId eq 123",
                   "sort" => "start desc",
                   "page" => "2",
                   "pageSize" => "10"
                 }

          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(200, Jason.encode!(%{"data" => []}))
        end
      )

      assert {:ok, %{"data" => []}} =
               BambooHR.TimeTracking.list_clock_entries(config,
                 filter: "employeeId eq 123",
                 sort: "start desc",
                 page: 2,
                 page_size: 10
               )
    end
  end

  describe "create_clock_entry/2" do
    test "creates an entry", %{bypass: bypass, config: config} do
      entry_data = %{
        "employeeId" => 123,
        "start" => "2024-01-15T09:00:00-05:00",
        "end" => "2024-01-15T17:00:00-05:00",
        "timezone" => "America/New_York"
      }

      Bypass.expect_once(
        bypass,
        "POST",
        "/api/gateway.php/test_company/v1/time-tracking/clock-entries",
        fn conn ->
          {:ok, body, conn} = Plug.Conn.read_body(conn)
          assert Jason.decode!(body) == entry_data

          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(201, Jason.encode!(%{"id" => 1}))
        end
      )

      assert {:ok, %{"id" => 1}} = BambooHR.TimeTracking.create_clock_entry(config, entry_data)
    end

    test "surfaces a timesheet conflict", %{bypass: bypass, config: config} do
      Bypass.expect_once(
        bypass,
        "POST",
        "/api/gateway.php/test_company/v1/time-tracking/clock-entries",
        fn conn -> Plug.Conn.resp(conn, 409, "") end
      )

      assert {:error, %BambooHR.Error{reason: :conflict}} =
               BambooHR.TimeTracking.create_clock_entry(config, %{})
    end
  end

  describe "get_clock_entry/2" do
    test "retrieves an entry", %{bypass: bypass, config: config} do
      Bypass.expect_once(
        bypass,
        "GET",
        "/api/gateway.php/test_company/v1/time-tracking/clock-entries/1",
        fn conn ->
          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(200, Jason.encode!(%{"id" => 1}))
        end
      )

      assert {:ok, %{"id" => 1}} = BambooHR.TimeTracking.get_clock_entry(config, 1)
    end
  end

  describe "update_clock_entry/3" do
    test "sends a PATCH with only the changed fields", %{bypass: bypass, config: config} do
      Bypass.expect_once(
        bypass,
        "PATCH",
        "/api/gateway.php/test_company/v1/time-tracking/clock-entries/1",
        fn conn ->
          {:ok, body, conn} = Plug.Conn.read_body(conn)
          assert Jason.decode!(body) == %{"note" => "Corrected"}

          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(200, Jason.encode!(%{"id" => 1, "note" => "Corrected"}))
        end
      )

      assert {:ok, %{"note" => "Corrected"}} =
               BambooHR.TimeTracking.update_clock_entry(config, 1, %{"note" => "Corrected"})
    end
  end

  describe "delete_clock_entry/2" do
    test "deletes an entry", %{bypass: bypass, config: config} do
      Bypass.expect_once(
        bypass,
        "DELETE",
        "/api/gateway.php/test_company/v1/time-tracking/clock-entries/1",
        fn conn -> Plug.Conn.resp(conn, 204, "") end
      )

      assert {:ok, nil} = BambooHR.TimeTracking.delete_clock_entry(config, 1)
    end
  end

  describe "create_clock_in/2 and create_clock_out/2" do
    test "clocks an employee in", %{bypass: bypass, config: config} do
      clock_in_data = %{"employeeId" => 123, "timezone" => "America/New_York"}

      Bypass.expect_once(
        bypass,
        "POST",
        "/api/gateway.php/test_company/v1/time-tracking/clock-ins",
        fn conn ->
          {:ok, body, conn} = Plug.Conn.read_body(conn)
          assert Jason.decode!(body) == clock_in_data

          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(201, Jason.encode!(%{"id" => 1, "end" => nil}))
        end
      )

      assert {:ok, %{"id" => 1, "end" => nil}} =
               BambooHR.TimeTracking.create_clock_in(config, clock_in_data)
    end

    test "clocks an employee out", %{bypass: bypass, config: config} do
      Bypass.expect_once(
        bypass,
        "POST",
        "/api/gateway.php/test_company/v1/time-tracking/clock-outs",
        fn conn ->
          {:ok, body, conn} = Plug.Conn.read_body(conn)
          assert Jason.decode!(body) == %{"employeeId" => 123}

          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(200, Jason.encode!(%{"id" => 1}))
        end
      )

      assert {:ok, %{"id" => 1}} =
               BambooHR.TimeTracking.create_clock_out(config, %{"employeeId" => 123})
    end

    test "surfaces a conflict when the employee is not clocked in", %{
      bypass: bypass,
      config: config
    } do
      Bypass.expect_once(
        bypass,
        "POST",
        "/api/gateway.php/test_company/v1/time-tracking/clock-outs",
        fn conn -> Plug.Conn.resp(conn, 409, "") end
      )

      assert {:error, %BambooHR.Error{reason: :conflict}} =
               BambooHR.TimeTracking.create_clock_out(config, %{"employeeId" => 123})
    end
  end

  describe "hour entries" do
    test "lists hour entries", %{bypass: bypass, config: config} do
      Bypass.expect_once(
        bypass,
        "GET",
        "/api/gateway.php/test_company/v1/time-tracking/hour-entries",
        fn conn ->
          conn = Plug.Conn.fetch_query_params(conn)
          assert conn.query_params == %{"pageSize" => "10"}

          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(200, Jason.encode!(%{"data" => []}))
        end
      )

      assert {:ok, %{"data" => []}} =
               BambooHR.TimeTracking.list_hour_entries(config, page_size: 10)
    end

    test "creates an hour entry", %{bypass: bypass, config: config} do
      entry_data = %{"employeeId" => 123, "date" => "2024-01-15", "hours" => 8}

      Bypass.expect_once(
        bypass,
        "POST",
        "/api/gateway.php/test_company/v1/time-tracking/hour-entries",
        fn conn ->
          {:ok, body, conn} = Plug.Conn.read_body(conn)
          assert Jason.decode!(body) == entry_data

          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(201, Jason.encode!(%{"id" => 5}))
        end
      )

      assert {:ok, %{"id" => 5}} = BambooHR.TimeTracking.create_hour_entry(config, entry_data)
    end

    test "retrieves an hour entry", %{bypass: bypass, config: config} do
      Bypass.expect_once(
        bypass,
        "GET",
        "/api/gateway.php/test_company/v1/time-tracking/hour-entries/5",
        fn conn ->
          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(200, Jason.encode!(%{"id" => 5}))
        end
      )

      assert {:ok, %{"id" => 5}} = BambooHR.TimeTracking.get_hour_entry(config, 5)
    end

    test "updates an hour entry", %{bypass: bypass, config: config} do
      Bypass.expect_once(
        bypass,
        "PATCH",
        "/api/gateway.php/test_company/v1/time-tracking/hour-entries/5",
        fn conn ->
          {:ok, body, conn} = Plug.Conn.read_body(conn)
          assert Jason.decode!(body) == %{"hours" => 7.5}

          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(200, Jason.encode!(%{"id" => 5, "hours" => 7.5}))
        end
      )

      assert {:ok, %{"hours" => 7.5}} =
               BambooHR.TimeTracking.update_hour_entry(config, 5, %{"hours" => 7.5})
    end

    test "deletes an hour entry", %{bypass: bypass, config: config} do
      Bypass.expect_once(
        bypass,
        "DELETE",
        "/api/gateway.php/test_company/v1/time-tracking/hour-entries/5",
        fn conn -> Plug.Conn.resp(conn, 204, "") end
      )

      assert {:ok, nil} = BambooHR.TimeTracking.delete_hour_entry(config, 5)
    end
  end

  describe "timesheets" do
    test "lists timesheets", %{bypass: bypass, config: config} do
      Bypass.expect_once(
        bypass,
        "GET",
        "/api/gateway.php/test_company/v1/time-tracking/timesheets",
        fn conn ->
          conn = Plug.Conn.fetch_query_params(conn)
          assert conn.query_params == %{"filter" => "status eq 'OPEN'"}

          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(200, Jason.encode!(%{"data" => [%{"id" => 9}]}))
        end
      )

      assert {:ok, %{"data" => [%{"id" => 9}]}} =
               BambooHR.TimeTracking.list_timesheets(config, filter: "status eq 'OPEN'")
    end

    test "retrieves a timesheet", %{bypass: bypass, config: config} do
      Bypass.expect_once(
        bypass,
        "GET",
        "/api/gateway.php/test_company/v1/time-tracking/timesheets/9",
        fn conn ->
          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(200, Jason.encode!(%{"id" => 9}))
        end
      )

      assert {:ok, %{"id" => 9}} = BambooHR.TimeTracking.get_timesheet(config, 9)
    end

    test "retrieves a timesheet summary", %{bypass: bypass, config: config} do
      Bypass.expect_once(
        bypass,
        "GET",
        "/api/gateway.php/test_company/v1/time-tracking/timesheets/9/summary",
        fn conn ->
          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(200, Jason.encode!(%{"regularHours" => 40}))
        end
      )

      assert {:ok, %{"regularHours" => 40}} =
               BambooHR.TimeTracking.get_timesheet_summary(config, 9)
    end

    test "approves a timesheet", %{bypass: bypass, config: config} do
      Bypass.expect_once(
        bypass,
        "POST",
        "/api/gateway.php/test_company/v1/time-tracking/timesheet-approvals",
        fn conn ->
          {:ok, body, conn} = Plug.Conn.read_body(conn)

          assert Jason.decode!(body) == %{
                   "timesheetId" => 9,
                   "lastChangedAt" => "2024-01-15T17:00:00Z"
                 }

          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(200, Jason.encode!(%{"id" => 9, "status" => "APPROVED"}))
        end
      )

      assert {:ok, %{"status" => "APPROVED"}} =
               BambooHR.TimeTracking.approve_timesheet(config, 9, "2024-01-15T17:00:00Z")
    end

    test "surfaces a stale approval", %{bypass: bypass, config: config} do
      Bypass.expect_once(
        bypass,
        "POST",
        "/api/gateway.php/test_company/v1/time-tracking/timesheet-approvals",
        fn conn -> Plug.Conn.resp(conn, 409, "") end
      )

      assert {:error, %BambooHR.Error{reason: :conflict}} =
               BambooHR.TimeTracking.approve_timesheet(config, 9, "2024-01-15T16:00:00Z")
    end
  end

  describe "configurations" do
    test "lists configurations with orderBy and select", %{bypass: bypass, config: config} do
      Bypass.expect_once(
        bypass,
        "GET",
        "/api/gateway.php/test_company/v1/time-tracking/configurations",
        fn conn ->
          conn = Plug.Conn.fetch_query_params(conn)

          assert conn.query_params == %{
                   "filter" => "type eq 'GROUP'",
                   "orderBy" => "name asc",
                   "select" => "id,name",
                   "pageSize" => "20"
                 }

          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(200, Jason.encode!(%{"data" => [%{"id" => 2}]}))
        end
      )

      assert {:ok, %{"data" => [%{"id" => 2}]}} =
               BambooHR.TimeTracking.list_configurations(config,
                 filter: "type eq 'GROUP'",
                 order_by: "name asc",
                 select: "id,name",
                 page_size: 20
               )
    end

    test "creates a configuration", %{bypass: bypass, config: config} do
      configuration_data = %{"name" => "Warehouse", "timesheetType" => "CLOCK"}

      Bypass.expect_once(
        bypass,
        "POST",
        "/api/gateway.php/test_company/v1/time-tracking/configurations",
        fn conn ->
          {:ok, body, conn} = Plug.Conn.read_body(conn)
          assert Jason.decode!(body) == configuration_data
          assert Plug.Conn.get_req_header(conn, "idempotency-key") == []

          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(201, Jason.encode!(%{"id" => 2}))
        end
      )

      assert {:ok, %{"id" => 2}} =
               BambooHR.TimeTracking.create_configuration(config, configuration_data)
    end

    test "sends an idempotency key when given one", %{bypass: bypass, config: config} do
      Bypass.expect_once(
        bypass,
        "POST",
        "/api/gateway.php/test_company/v1/time-tracking/configurations",
        fn conn ->
          assert Plug.Conn.get_req_header(conn, "idempotency-key") == ["abc-123"]
          assert Plug.Conn.get_req_header(conn, "authorization") != []

          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(201, Jason.encode!(%{"id" => 2}))
        end
      )

      assert {:ok, %{"id" => 2}} =
               BambooHR.TimeTracking.create_configuration(config, %{"name" => "Warehouse"},
                 idempotency_key: "abc-123"
               )
    end

    test "retrieves a configuration", %{bypass: bypass, config: config} do
      Bypass.expect_once(
        bypass,
        "GET",
        "/api/gateway.php/test_company/v1/time-tracking/configurations/2",
        fn conn ->
          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(200, Jason.encode!(%{"id" => 2, "type" => "GROUP"}))
        end
      )

      assert {:ok, %{"id" => 2}} = BambooHR.TimeTracking.get_configuration(config, 2)
    end

    test "updates a configuration as a merge patch", %{bypass: bypass, config: config} do
      Bypass.expect_once(
        bypass,
        "PATCH",
        "/api/gateway.php/test_company/v1/time-tracking/configurations/2",
        fn conn ->
          assert Plug.Conn.get_req_header(conn, "content-type") == [
                   "application/merge-patch+json"
                 ]

          {:ok, body, conn} = Plug.Conn.read_body(conn)
          assert Jason.decode!(body) == %{"mobileEnabled" => false}

          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(200, Jason.encode!(%{"id" => 2, "mobileEnabled" => false}))
        end
      )

      assert {:ok, %{"mobileEnabled" => false}} =
               BambooHR.TimeTracking.update_configuration(config, 2, %{"mobileEnabled" => false})
    end

    test "clears a nullable field with an explicit null", %{bypass: bypass, config: config} do
      Bypass.expect_once(
        bypass,
        "PATCH",
        "/api/gateway.php/test_company/v1/time-tracking/configurations/2",
        fn conn ->
          {:ok, body, conn} = Plug.Conn.read_body(conn)
          assert Jason.decode!(body) == %{"approverUserId" => nil}

          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(200, Jason.encode!(%{"approverUserId" => nil}))
        end
      )

      assert {:ok, %{"approverUserId" => nil}} =
               BambooHR.TimeTracking.update_configuration(config, 2, %{"approverUserId" => nil})
    end

    test "deletes a configuration", %{bypass: bypass, config: config} do
      Bypass.expect_once(
        bypass,
        "DELETE",
        "/api/gateway.php/test_company/v1/time-tracking/configurations/2",
        fn conn -> Plug.Conn.resp(conn, 204, "") end
      )

      assert {:ok, nil} = BambooHR.TimeTracking.delete_configuration(config, 2)
    end

    test "surfaces a configuration that still has employees", %{bypass: bypass, config: config} do
      Bypass.expect_once(
        bypass,
        "DELETE",
        "/api/gateway.php/test_company/v1/time-tracking/configurations/2",
        fn conn -> Plug.Conn.resp(conn, 422, "") end
      )

      assert {:error, %BambooHR.Error{reason: :unprocessable_entity}} =
               BambooHR.TimeTracking.delete_configuration(config, 2)
    end
  end

  describe "employee enrolments" do
    test "lists enrolled employees", %{bypass: bypass, config: config} do
      Bypass.expect_once(
        bypass,
        "GET",
        "/api/gateway.php/test_company/v1/time-tracking/employees",
        fn conn ->
          conn = Plug.Conn.fetch_query_params(conn)
          assert conn.query_params == %{"filter" => "enabled eq true"}

          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(200, Jason.encode!(%{"data" => [%{"employeeId" => 123}]}))
        end
      )

      assert {:ok, %{"data" => [%{"employeeId" => 123}]}} =
               BambooHR.TimeTracking.list_enrolled_employees(config, filter: "enabled eq true")
    end

    test "retrieves an enrolment", %{bypass: bypass, config: config} do
      Bypass.expect_once(
        bypass,
        "GET",
        "/api/gateway.php/test_company/v1/time-tracking/employees/123",
        fn conn ->
          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(200, Jason.encode!(%{"employeeId" => 123, "enabled" => true}))
        end
      )

      assert {:ok, %{"employeeId" => 123}} =
               BambooHR.TimeTracking.get_employee_enrollment(config, 123)
    end

    test "updates an enrolment as a merge patch", %{bypass: bypass, config: config} do
      Bypass.expect_once(
        bypass,
        "PATCH",
        "/api/gateway.php/test_company/v1/time-tracking/employees/123",
        fn conn ->
          assert Plug.Conn.get_req_header(conn, "content-type") == [
                   "application/merge-patch+json"
                 ]

          {:ok, body, conn} = Plug.Conn.read_body(conn)
          assert Jason.decode!(body) == %{"enabled" => true}

          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(200, Jason.encode!(%{"employeeId" => 123, "enabled" => true}))
        end
      )

      assert {:ok, %{"enabled" => true}} =
               BambooHR.TimeTracking.update_employee_enrollment(config, 123, %{"enabled" => true})
    end

    test "surfaces a rejected content type", %{bypass: bypass, config: config} do
      Bypass.expect_once(
        bypass,
        "PATCH",
        "/api/gateway.php/test_company/v1/time-tracking/employees/123",
        fn conn -> Plug.Conn.resp(conn, 415, "") end
      )

      assert {:error, %BambooHR.Error{reason: :unsupported_media_type}} =
               BambooHR.TimeTracking.update_employee_enrollment(config, 123, %{"enabled" => true})
    end

    test "bulk upserts enrolments", %{bypass: bypass, config: config} do
      records = [%{"employeeId" => 123, "enabled" => true, "configurationId" => 2}]

      Bypass.expect_once(
        bypass,
        "POST",
        "/api/gateway.php/test_company/v1/time-tracking/employees/bulk-upsert",
        fn conn ->
          conn = Plug.Conn.fetch_query_params(conn)
          assert conn.query_params == %{}

          {:ok, body, conn} = Plug.Conn.read_body(conn)
          assert Jason.decode!(body) == records

          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(
            202,
            Jason.encode!(%{
              "requestId" => "8b3e1c2a",
              "message" => "Accepted; verify via GET /time-tracking/employees."
            })
          )
        end
      )

      # The 202 acknowledges the batch; it carries no per-record outcomes.
      assert {:ok, %{"requestId" => "8b3e1c2a", "message" => _}} =
               BambooHR.TimeTracking.bulk_upsert_employee_enrollments(config, records)
    end

    test "bulk upserts atomically with an idempotency key", %{bypass: bypass, config: config} do
      Bypass.expect_once(
        bypass,
        "POST",
        "/api/gateway.php/test_company/v1/time-tracking/employees/bulk-upsert",
        fn conn ->
          conn = Plug.Conn.fetch_query_params(conn)
          assert conn.query_params == %{"atomic" => "true"}
          assert Plug.Conn.get_req_header(conn, "idempotency-key") == ["batch-9"]

          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(
            202,
            Jason.encode!(%{
              "requestId" => "8b3e1c2a",
              "message" => "Accepted; verify via GET /time-tracking/employees."
            })
          )
        end
      )

      assert {:ok, %{"requestId" => "8b3e1c2a"}} =
               BambooHR.TimeTracking.bulk_upsert_employee_enrollments(
                 config,
                 [%{"employeeId" => 123}],
                 atomic: true,
                 idempotency_key: "batch-9"
               )
    end

    test "raises rather than silently dropping a non-boolean atomic", %{config: config} do
      assert_raise ArgumentError, ~r/:atomic to be a boolean/, fn ->
        BambooHR.TimeTracking.bulk_upsert_employee_enrollments(
          config,
          [%{"employeeId" => 123}],
          atomic: "true"
        )
      end
    end

    test "omits atomic when it is nil", %{bypass: bypass, config: config} do
      Bypass.expect_once(
        bypass,
        "POST",
        "/api/gateway.php/test_company/v1/time-tracking/employees/bulk-upsert",
        fn conn ->
          # An empty `atomic=` is a 422, so a nil must not reach the wire.
          assert conn.query_string == ""

          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(
            202,
            Jason.encode!(%{
              "requestId" => "8b3e1c2a",
              "message" => "Accepted; verify via GET /time-tracking/employees."
            })
          )
        end
      )

      assert {:ok, %{"requestId" => _}} =
               BambooHR.TimeTracking.bulk_upsert_employee_enrollments(
                 config,
                 [%{"employeeId" => 123}],
                 atomic: nil
               )
    end
  end

  describe "imports" do
    test "lists imports by status", %{bypass: bypass, config: config} do
      Bypass.expect_once(
        bypass,
        "GET",
        "/api/gateway.php/test_company/v1/time-tracking/imports",
        fn conn ->
          conn = Plug.Conn.fetch_query_params(conn)
          assert conn.query_params == %{"status" => "DRAFT"}

          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(200, Jason.encode!(%{"data" => [%{"id" => 4}]}))
        end
      )

      assert {:ok, %{"data" => [%{"id" => 4}]}} =
               BambooHR.TimeTracking.list_imports(config, status: "DRAFT")
    end

    test "uploads a CSV with a column mapping", %{bypass: bypass, config: config} do
      Bypass.expect_once(
        bypass,
        "POST",
        "/api/gateway.php/test_company/v1/time-tracking/imports",
        fn conn ->
          [content_type] = Plug.Conn.get_req_header(conn, "content-type")
          assert content_type =~ "multipart/form-data"

          {:ok, body, conn} = Plug.Conn.read_body(conn)
          assert body =~ ~s(filename="hours.csv")
          assert body =~ "employeeNumber,dateWorked"
          assert body =~ ~s({"dateWorked":1,"employeeNumber":0})

          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(201, Jason.encode!(%{"id" => 4, "status" => "DRAFT"}))
        end
      )

      assert {:ok, %{"id" => 4, "status" => "DRAFT"}} =
               BambooHR.TimeTracking.create_import(
                 config,
                 "hours.csv",
                 "employeeNumber,dateWorked\n123,2024-01-15\n",
                 column_mapping: %{"employeeNumber" => 0, "dateWorked" => 1}
               )
    end

    test "uploads a CSV without a column mapping", %{bypass: bypass, config: config} do
      Bypass.expect_once(
        bypass,
        "POST",
        "/api/gateway.php/test_company/v1/time-tracking/imports",
        fn conn ->
          {:ok, body, conn} = Plug.Conn.read_body(conn)
          refute body =~ "columnMapping"

          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(201, Jason.encode!(%{"id" => 4}))
        end
      )

      assert {:ok, %{"id" => 4}} =
               BambooHR.TimeTracking.create_import(config, "hours.csv", "a,b\n1,2\n")
    end

    test "surfaces a file that is too large", %{bypass: bypass, config: config} do
      Bypass.expect_once(
        bypass,
        "POST",
        "/api/gateway.php/test_company/v1/time-tracking/imports",
        fn conn -> Plug.Conn.resp(conn, 413, "") end
      )

      assert {:error, %BambooHR.Error{reason: :client_error, status: 413}} =
               BambooHR.TimeTracking.create_import(config, "hours.csv", "a,b\n1,2\n")
    end

    test "retrieves an import", %{bypass: bypass, config: config} do
      Bypass.expect_once(
        bypass,
        "GET",
        "/api/gateway.php/test_company/v1/time-tracking/imports/4",
        fn conn ->
          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(200, Jason.encode!(%{"id" => 4, "status" => "DRAFT"}))
        end
      )

      assert {:ok, %{"id" => 4}} = BambooHR.TimeTracking.get_import(config, 4)
    end

    test "deletes an import", %{bypass: bypass, config: config} do
      Bypass.expect_once(
        bypass,
        "DELETE",
        "/api/gateway.php/test_company/v1/time-tracking/imports/4",
        fn conn -> Plug.Conn.resp(conn, 204, "") end
      )

      assert {:ok, nil} = BambooHR.TimeTracking.delete_import(config, 4)
    end

    test "surfaces a delete during a running execute", %{bypass: bypass, config: config} do
      Bypass.expect_once(
        bypass,
        "DELETE",
        "/api/gateway.php/test_company/v1/time-tracking/imports/4",
        fn conn -> Plug.Conn.resp(conn, 409, "") end
      )

      assert {:error, %BambooHR.Error{reason: :conflict}} =
               BambooHR.TimeTracking.delete_import(config, 4)
    end

    test "executes an import", %{bypass: bypass, config: config} do
      Bypass.expect_once(
        bypass,
        "POST",
        "/api/gateway.php/test_company/v1/time-tracking/imports/4/execute",
        fn conn ->
          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(200, Jason.encode!(%{"id" => 4, "status" => "COMPLETE"}))
        end
      )

      assert {:ok, %{"status" => "COMPLETE"}} = BambooHR.TimeTracking.execute_import(config, 4)
    end

    test "surfaces rows that still fail validation", %{bypass: bypass, config: config} do
      body = Jason.encode!(%{"code" => "IMPORT_HAS_ERRORS", "errorRowIds" => [9]})

      Bypass.expect_once(
        bypass,
        "POST",
        "/api/gateway.php/test_company/v1/time-tracking/imports/4/execute",
        fn conn ->
          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(422, body)
        end
      )

      assert {:error, %BambooHR.Error{reason: :unprocessable_entity, body: ^body}} =
               BambooHR.TimeTracking.execute_import(config, 4)
    end

    test "lists rows with errors only", %{bypass: bypass, config: config} do
      Bypass.expect_once(
        bypass,
        "GET",
        "/api/gateway.php/test_company/v1/time-tracking/imports/4/rows",
        fn conn ->
          conn = Plug.Conn.fetch_query_params(conn)
          assert conn.query_params == %{"errorsOnly" => "true", "pageSize" => "50"}

          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(200, Jason.encode!(%{"data" => [%{"id" => 9}]}))
        end
      )

      assert {:ok, %{"data" => [%{"id" => 9}]}} =
               BambooHR.TimeTracking.list_import_rows(config, 4, errors_only: true, page_size: 50)
    end

    test "retrieves a row", %{bypass: bypass, config: config} do
      Bypass.expect_once(
        bypass,
        "GET",
        "/api/gateway.php/test_company/v1/time-tracking/imports/4/rows/9",
        fn conn ->
          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(200, Jason.encode!(%{"id" => 9, "importId" => 4}))
        end
      )

      assert {:ok, %{"id" => 9}} = BambooHR.TimeTracking.get_import_row(config, 4, 9)
    end

    test "corrects a row as a merge patch", %{bypass: bypass, config: config} do
      Bypass.expect_once(
        bypass,
        "PATCH",
        "/api/gateway.php/test_company/v1/time-tracking/imports/4/rows/9",
        fn conn ->
          assert Plug.Conn.get_req_header(conn, "content-type") == [
                   "application/merge-patch+json"
                 ]

          {:ok, body, conn} = Plug.Conn.read_body(conn)
          assert Jason.decode!(body) == %{"hoursWorked" => 7.5}

          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(
            200,
            Jason.encode!(%{"id" => 9, "hoursWorked" => 7.5, "errors" => []})
          )
        end
      )

      assert {:ok, %{"hoursWorked" => 7.5}} =
               BambooHR.TimeTracking.update_import_row(config, 4, 9, %{"hoursWorked" => 7.5})
    end

    test "surfaces a field that cannot be edited after completion", %{
      bypass: bypass,
      config: config
    } do
      Bypass.expect_once(
        bypass,
        "PATCH",
        "/api/gateway.php/test_company/v1/time-tracking/imports/4/rows/9",
        fn conn -> Plug.Conn.resp(conn, 422, "") end
      )

      assert {:error, %BambooHR.Error{reason: :unprocessable_entity}} =
               BambooHR.TimeTracking.update_import_row(config, 4, 9, %{"payRate" => 20})
    end
  end

  describe "kiosks" do
    @kiosk_id "f1d2c3b4"

    test "lists kiosks", %{bypass: bypass, config: config} do
      Bypass.expect_once(
        bypass,
        "GET",
        "/api/gateway.php/test_company/v1/time-tracking/kiosks",
        fn conn ->
          conn = Plug.Conn.fetch_query_params(conn)
          assert conn.query_params == %{"orderBy" => "name desc"}

          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(200, Jason.encode!(%{"data" => [%{"id" => @kiosk_id}]}))
        end
      )

      assert {:ok, %{"data" => [%{"id" => @kiosk_id}]}} =
               BambooHR.TimeTracking.list_kiosks(config, order_by: "name desc")
    end

    test "retrieves a kiosk", %{bypass: bypass, config: config} do
      Bypass.expect_once(
        bypass,
        "GET",
        "/api/gateway.php/test_company/v1/time-tracking/kiosks/#{@kiosk_id}",
        fn conn ->
          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(200, Jason.encode!(%{"id" => @kiosk_id, "name" => "Warehouse door"}))
        end
      )

      assert {:ok, %{"name" => "Warehouse door"}} =
               BambooHR.TimeTracking.get_kiosk(config, @kiosk_id)
    end

    test "renames a kiosk as a merge patch", %{bypass: bypass, config: config} do
      Bypass.expect_once(
        bypass,
        "PATCH",
        "/api/gateway.php/test_company/v1/time-tracking/kiosks/#{@kiosk_id}",
        fn conn ->
          assert Plug.Conn.get_req_header(conn, "content-type") == [
                   "application/merge-patch+json"
                 ]

          {:ok, body, conn} = Plug.Conn.read_body(conn)
          assert Jason.decode!(body) == %{"name" => "Loading bay"}

          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(200, Jason.encode!(%{"id" => @kiosk_id, "name" => "Loading bay"}))
        end
      )

      assert {:ok, %{"name" => "Loading bay"}} =
               BambooHR.TimeTracking.update_kiosk(config, @kiosk_id, %{"name" => "Loading bay"})
    end

    test "surfaces a name already in use", %{bypass: bypass, config: config} do
      Bypass.expect_once(
        bypass,
        "PATCH",
        "/api/gateway.php/test_company/v1/time-tracking/kiosks/#{@kiosk_id}",
        fn conn -> Plug.Conn.resp(conn, 409, "") end
      )

      assert {:error, %BambooHR.Error{reason: :conflict}} =
               BambooHR.TimeTracking.update_kiosk(config, @kiosk_id, %{"name" => "Front desk"})
    end

    test "deletes a kiosk", %{bypass: bypass, config: config} do
      Bypass.expect_once(
        bypass,
        "DELETE",
        "/api/gateway.php/test_company/v1/time-tracking/kiosks/#{@kiosk_id}",
        fn conn -> Plug.Conn.resp(conn, 204, "") end
      )

      assert {:ok, nil} = BambooHR.TimeTracking.delete_kiosk(config, @kiosk_id)
    end
  end

  describe "time clocks" do
    @time_clock_id "7a3e91cc"

    test "lists time clocks", %{bypass: bypass, config: config} do
      clock = %{"id" => @time_clock_id, "name" => "Front desk", "online" => true}

      Bypass.expect_once(
        bypass,
        "GET",
        "/api/gateway.php/test_company/v1/time-tracking/time-clocks",
        fn conn ->
          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(200, Jason.encode!(%{"data" => [clock]}))
        end
      )

      assert {:ok, %{"data" => [%{"online" => true}]}} =
               BambooHR.TimeTracking.list_time_clocks(config)
    end

    test "retrieves a time clock with unknown health flags", %{bypass: bypass, config: config} do
      Bypass.expect_once(
        bypass,
        "GET",
        "/api/gateway.php/test_company/v1/time-tracking/time-clocks/#{@time_clock_id}",
        fn conn ->
          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(200, Jason.encode!(%{"id" => @time_clock_id, "online" => nil}))
        end
      )

      # nil means "status unavailable", not "offline".
      assert {:ok, %{"online" => nil}} =
               BambooHR.TimeTracking.get_time_clock(config, @time_clock_id)
    end

    test "updates a time clock as a merge patch", %{bypass: bypass, config: config} do
      Bypass.expect_once(
        bypass,
        "PATCH",
        "/api/gateway.php/test_company/v1/time-tracking/time-clocks/#{@time_clock_id}",
        fn conn ->
          assert Plug.Conn.get_req_header(conn, "content-type") == [
                   "application/merge-patch+json"
                 ]

          {:ok, body, conn} = Plug.Conn.read_body(conn)
          assert Jason.decode!(body) == %{"timezone" => "America/New_York"}

          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(200, Jason.encode!(%{"id" => @time_clock_id}))
        end
      )

      assert {:ok, %{"id" => @time_clock_id}} =
               BambooHR.TimeTracking.update_time_clock(config, @time_clock_id, %{
                 "timezone" => "America/New_York"
               })
    end

    test "does not retry a write when the clock partner is unreachable", %{
      bypass: bypass,
      config: config
    } do
      Bypass.expect_once(
        bypass,
        "PATCH",
        "/api/gateway.php/test_company/v1/time-tracking/time-clocks/#{@time_clock_id}",
        fn conn ->
          conn
          |> Plug.Conn.put_resp_header("retry-after", "30")
          |> Plug.Conn.resp(503, "")
        end
      )

      # expect_once proves the PATCH was sent exactly once: writes are the
      # caller's to retry, after the Retry-After interval.
      assert {:error, %BambooHR.Error{reason: :server_error, status: 503}} =
               BambooHR.TimeTracking.update_time_clock(config, @time_clock_id, %{
                 "name" => "Reception"
               })
    end
  end

  describe "shift differentials" do
    test "lists shift differentials", %{bypass: bypass, config: config} do
      Bypass.expect_once(
        bypass,
        "GET",
        "/api/gateway.php/test_company/v1/time-tracking/shift-differentials",
        fn conn ->
          conn = Plug.Conn.fetch_query_params(conn)
          assert conn.query_params == %{"filter" => "archived eq true", "sort" => "name asc"}

          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(200, Jason.encode!(%{"data" => [%{"id" => 6}]}))
        end
      )

      assert {:ok, %{"data" => [%{"id" => 6}]}} =
               BambooHR.TimeTracking.list_shift_differentials(config,
                 filter: "archived eq true",
                 sort: "name asc"
               )
    end

    test "creates a shift differential", %{bypass: bypass, config: config} do
      differential_data = %{
        "name" => "Night shift",
        "rate" => "1.50",
        "rateType" => "AMOUNT",
        "times" => [
          %{"startDay" => "MONDAY", "endDay" => "TUESDAY", "start" => "22:00", "end" => "06:00"}
        ],
        "allowAllEmployees" => true
      }

      Bypass.expect_once(
        bypass,
        "POST",
        "/api/gateway.php/test_company/v1/time-tracking/shift-differentials",
        fn conn ->
          {:ok, body, conn} = Plug.Conn.read_body(conn)
          decoded = Jason.decode!(body)
          assert decoded == differential_data
          # The rate is a decimal string, not a number.
          assert is_binary(decoded["rate"])

          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(201, Jason.encode!(%{"id" => 6, "rate" => "1.50"}))
        end
      )

      assert {:ok, %{"id" => 6, "rate" => "1.50"}} =
               BambooHR.TimeTracking.create_shift_differential(config, differential_data)
    end

    test "surfaces a duplicate name", %{bypass: bypass, config: config} do
      Bypass.expect_once(
        bypass,
        "POST",
        "/api/gateway.php/test_company/v1/time-tracking/shift-differentials",
        fn conn -> Plug.Conn.resp(conn, 409, "") end
      )

      assert {:error, %BambooHR.Error{reason: :conflict}} =
               BambooHR.TimeTracking.create_shift_differential(config, %{"name" => "Night shift"})
    end

    test "retrieves a shift differential", %{bypass: bypass, config: config} do
      Bypass.expect_once(
        bypass,
        "GET",
        "/api/gateway.php/test_company/v1/time-tracking/shift-differentials/6",
        fn conn ->
          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(200, Jason.encode!(%{"id" => 6, "archivedAt" => nil}))
        end
      )

      assert {:ok, %{"id" => 6}} = BambooHR.TimeTracking.get_shift_differential(config, 6)
    end

    test "archives with a plain JSON patch", %{bypass: bypass, config: config} do
      Bypass.expect_once(
        bypass,
        "PATCH",
        "/api/gateway.php/test_company/v1/time-tracking/shift-differentials/6",
        fn conn ->
          # This endpoint takes application/json, not merge patch.
          assert Plug.Conn.get_req_header(conn, "content-type") == ["application/json"]

          {:ok, body, conn} = Plug.Conn.read_body(conn)
          assert Jason.decode!(body) == %{"archived" => true}

          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(200, Jason.encode!(%{"id" => 6, "archivedAt" => "2024-01-15"}))
        end
      )

      assert {:ok, %{"archivedAt" => "2024-01-15"}} =
               BambooHR.TimeTracking.update_shift_differential(config, 6, %{"archived" => true})
    end

    test "replaces every time window on update", %{bypass: bypass, config: config} do
      times = [
        %{"startDay" => "FRIDAY", "endDay" => "SATURDAY", "start" => "20:00", "end" => "04:00"}
      ]

      Bypass.expect_once(
        bypass,
        "PATCH",
        "/api/gateway.php/test_company/v1/time-tracking/shift-differentials/6",
        fn conn ->
          {:ok, body, conn} = Plug.Conn.read_body(conn)
          assert Jason.decode!(body) == %{"times" => times}

          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(200, Jason.encode!(%{"id" => 6, "times" => times}))
        end
      )

      assert {:ok, %{"times" => ^times}} =
               BambooHR.TimeTracking.update_shift_differential(config, 6, %{"times" => times})
    end

    test "surfaces an update with no fields", %{bypass: bypass, config: config} do
      Bypass.expect_once(
        bypass,
        "PATCH",
        "/api/gateway.php/test_company/v1/time-tracking/shift-differentials/6",
        fn conn -> Plug.Conn.resp(conn, 422, "") end
      )

      assert {:error, %BambooHR.Error{reason: :unprocessable_entity}} =
               BambooHR.TimeTracking.update_shift_differential(config, 6, %{})
    end

    test "deletes a shift differential", %{bypass: bypass, config: config} do
      Bypass.expect_once(
        bypass,
        "DELETE",
        "/api/gateway.php/test_company/v1/time-tracking/shift-differentials/6",
        fn conn -> Plug.Conn.resp(conn, 204, "") end
      )

      assert {:ok, nil} = BambooHR.TimeTracking.delete_shift_differential(config, 6)
    end
  end
end
