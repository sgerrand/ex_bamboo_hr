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
end
