defmodule BambooHR.TimeTrackingTest do
  use ExUnit.Case, async: true

  setup do
    bypass = Bypass.open()
    base_url = "http://localhost:#{bypass.port}/api/gateway.php"
    config = BambooHR.Client.new("test_company", "test_key", base_url)
    {:ok, bypass: bypass, config: config}
  end

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

      assert {:error, %{status: 400, body: ^error_response}} =
               BambooHR.TimeTracking.get_timesheet_entries(config, params)
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

      assert {:error, %{status: 400, body: ^error_response}} =
               BambooHR.TimeTracking.store_clock_entries(config, entries)
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

      assert {:error, %{status: 400, body: ^error_response}} =
               BambooHR.TimeTracking.clock_in(config, employee_id, clock_data)
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

      assert {:error, %{status: 400, body: ^error_response}} =
               BambooHR.TimeTracking.clock_out(config, employee_id, clock_data)
    end
  end
end
