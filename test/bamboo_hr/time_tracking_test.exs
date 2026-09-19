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
end
