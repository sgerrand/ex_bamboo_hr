defmodule BambooHR.EmployeeTest do
  use ExUnit.Case, async: true

  setup do
    bypass = Bypass.open()
    base_url = "http://localhost:#{bypass.port}/api/gateway.php"
    config = BambooHR.Client.new("test_company", "test_key", base_url)
    [bypass: bypass, config: config]
  end

  describe "get/3" do
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

      assert {:ok, ^employee_data} = BambooHR.Employee.get(config, employee_id, fields)
    end
  end

  describe "add/2" do
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

      assert {:ok, %{"id" => 1}} = BambooHR.Employee.add(config, employee_data)
    end
  end

  describe "update/3" do
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

      assert {:ok, _} = BambooHR.Employee.update(config, employee_id, update_data)
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
               BambooHR.Employee.update(config, employee_id, update_data)
    end
  end

  describe "get_directory/1" do
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

      assert {:ok, ^directory_data} = BambooHR.Employee.get_directory(config)
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
               BambooHR.Employee.get_directory(config)
    end
  end
end
