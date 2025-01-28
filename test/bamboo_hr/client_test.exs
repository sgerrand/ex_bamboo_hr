defmodule BambooHR.ClientTest do
  use ExUnit.Case, async: true

  setup do
    bypass = Bypass.open()
    base_url = "http://localhost:#{bypass.port}/api/gateway.php"
    config = BambooHR.Client.new("test_company", "test_key", base_url)
    {:ok, bypass: bypass, config: config}
  end

  describe "new/3" do
    test "creates config with default base URL" do
      config = BambooHR.Client.new("test_company", "test_key")
      assert config.company_domain == "test_company"
      assert config.api_key == "test_key"
      assert config.base_url == "https://api.bamboohr.com/api/gateway.php"
    end

    test "creates config with custom base URL" do
      custom_url = "https://custom-bamboohr.example.com"
      config = BambooHR.Client.new("test_company", "test_key", custom_url)
      assert config.company_domain == "test_company"
      assert config.api_key == "test_key"
      assert config.base_url == custom_url
    end
  end

  describe "get_company_information/1" do
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

      assert {:ok, ^company_info} = BambooHR.Client.get_company_information(config)
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
               BambooHR.Client.get_company_information(config)
    end
  end

  describe "get_company_eins/1" do
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

      assert {:ok, ^eins_data} = BambooHR.Client.get_company_eins(config)
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
               BambooHR.Client.get_company_eins(config)
    end
  end

  describe "get_employee/3" do
    test "successfully retrieves employee information", %{bypass: bypass, config: config} do
      employee_id = 123
      fields = ["firstName", "lastName", "jobTitle"]

      employee_data = %{
        "firstName" => "John",
        "lastName" => "Doe",
        "jobTitle" => "Developer"
      }

      Bypass.expect_once(
        bypass,
        "GET",
        "/api/gateway.php/test_company/v1/employees/#{employee_id}",
        fn conn ->
          assert conn.query_string == "fields=firstName%2ClastName%2CjobTitle"

          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(200, Jason.encode!(employee_data))
        end
      )

      assert {:ok, ^employee_data} = BambooHR.Client.get_employee(config, employee_id, fields)
    end
  end

  describe "add_employee/2" do
    test "successfully adds a new employee", %{bypass: bypass, config: config} do
      employee_data = %{
        "firstName" => "Jane",
        "lastName" => "Smith"
      }

      Bypass.expect_once(bypass, "POST", "/api/gateway.php/test_company/v1/employees", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        assert Jason.decode!(body) == employee_data

        conn
        |> Plug.Conn.put_resp_header("content-type", "application/json")
        |> Plug.Conn.resp(201, Jason.encode!(%{id: 1}))
      end)

      assert {:ok, %{"id" => 1}} = BambooHR.Client.add_employee(config, employee_data)
    end
  end

  describe "update_employee/3" do
    test "successfully updates an employee", %{bypass: bypass, config: config} do
      employee_id = 123

      update_data = %{
        "firstName" => "Jane",
        "lastName" => "Doe",
        "department" => "Engineering"
      }

      Bypass.expect_once(
        bypass,
        "POST",
        "/api/gateway.php/test_company/v1/employees/#{employee_id}",
        fn conn ->
          {:ok, body, conn} = Plug.Conn.read_body(conn)
          assert Jason.decode!(body) == update_data

          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(200, "")
        end
      )

      assert {:ok, _} = BambooHR.Client.update_employee(config, employee_id, update_data)
    end

    test "handles error when updating employee", %{bypass: bypass, config: config} do
      employee_id = 999

      update_data = %{
        "firstName" => "Jane",
        "lastName" => "Doe"
      }

      error_response = %{"error" => "Employee not found"}

      Bypass.expect_once(
        bypass,
        "POST",
        "/api/gateway.php/test_company/v1/employees/#{employee_id}",
        fn conn ->
          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(404, Jason.encode!(error_response))
        end
      )

      assert {:error, %{status: 404, body: ^error_response}} =
               BambooHR.Client.update_employee(config, employee_id, update_data)
    end
  end

  describe "get_employee_directory/1" do
    test "successfully retrieves employee directory", %{bypass: bypass, config: config} do
      directory_data = %{
        "employees" => [
          %{
            "id" => 123,
            "displayName" => "John Doe",
            "jobTitle" => "Developer",
            "workEmail" => "john.doe@example.com",
            "workPhone" => "555-0123"
          },
          %{
            "id" => 124,
            "displayName" => "Jane Smith",
            "jobTitle" => "Designer",
            "workEmail" => "jane.smith@example.com",
            "workPhone" => "555-0124"
          }
        ]
      }

      Bypass.expect_once(
        bypass,
        "GET",
        "/api/gateway.php/test_company/v1/employees/directory",
        fn conn ->
          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(200, Jason.encode!(directory_data))
        end
      )

      assert {:ok, ^directory_data} = BambooHR.Client.get_employee_directory(config)
    end

    test "handles error when retrieving directory", %{bypass: bypass, config: config} do
      error_response = %{"error" => "Unauthorized"}

      Bypass.expect_once(
        bypass,
        "GET",
        "/api/gateway.php/test_company/v1/employees/directory",
        fn conn ->
          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(401, Jason.encode!(error_response))
        end
      )

      assert {:error, %{status: 401, body: ^error_response}} =
               BambooHR.Client.get_employee_directory(config)
    end
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

      assert {:ok, ^timesheet_data} = BambooHR.Client.get_timesheet_entries(config, params)
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
               BambooHR.Client.get_timesheet_entries(config, params)
    end
  end

  describe "store_timesheet_clock_entries/2" do
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
               BambooHR.Client.store_timesheet_clock_entries(config, entries)
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
               BambooHR.Client.store_timesheet_clock_entries(config, entries)
    end
  end

  describe "clock_in_employee/3" do
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
               BambooHR.Client.clock_in_employee(config, employee_id, clock_data)
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
               BambooHR.Client.clock_in_employee(config, employee_id, clock_data)
    end
  end
end
