defmodule BambooHR.EmployeeTest do
  use BambooHR.BypassCase, async: true

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

    test "rejects empty fields list", %{config: config} do
      assert_raise FunctionClauseError, fn ->
        BambooHR.Employee.get(config, 123, dynamic_empty_list())
      end
    end
  end

  describe "add/2" do
    test "returns the Location header pointing to the new employee", %{
      bypass: bypass,
      config: config
    } do
      employee_data = %{
        "firstName" => "Jane",
        "lastName" => "Smith"
      }

      location = "https://test_company.bamboohr.com/employees/employee.php?id=124"

      Bypass.expect_once(bypass, "POST", "/api/gateway.php/test_company/v1/employees", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        assert Jason.decode!(body) == employee_data

        conn
        |> Plug.Conn.put_resp_header("location", location)
        |> Plug.Conn.resp(201, "")
      end)

      assert {:ok, %{"location" => ^location}} = BambooHR.Employee.add(config, employee_data)
    end

    test "returns an empty map when no Location header is present", %{
      bypass: bypass,
      config: config
    } do
      employee_data = %{"firstName" => "Jane", "lastName" => "Smith"}

      Bypass.expect_once(bypass, "POST", "/api/gateway.php/test_company/v1/employees", fn conn ->
        Plug.Conn.resp(conn, 201, "")
      end)

      assert {:ok, %{}} = BambooHR.Employee.add(config, employee_data)
    end

    test "handles error response", %{bypass: bypass, config: config} do
      employee_data = %{"firstName" => "Jane", "lastName" => "Smith"}
      error_response = %{"error" => "Invalid request"}

      Bypass.expect_once(bypass, "POST", "/api/gateway.php/test_company/v1/employees", fn conn ->
        conn
        |> Plug.Conn.put_resp_header("content-type", "application/json")
        |> Plug.Conn.resp(400, Jason.encode!(error_response))
      end)

      assert {:error, %{status: 400, body: body}} = BambooHR.Employee.add(config, employee_data)
      assert Jason.decode!(body) == error_response
    end

    defmodule IgnoresExposeHeaders do
      @behaviour BambooHR.HTTPClient

      @impl true
      def request(_opts), do: {:ok, %{"id" => 1}}
    end

    test "does not raise when http_client ignores expose_headers" do
      config =
        BambooHR.Client.new(
          company_domain: "test_company",
          api_key: "test_key",
          http_client: IgnoresExposeHeaders
        )

      assert {:ok, %{}} = BambooHR.Employee.add(config, %{"firstName" => "Jane"})
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

      assert {:ok, nil} = BambooHR.Employee.update(config, employee_id, update_data)
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

      assert {:error, %{status: 404, body: body}} =
               BambooHR.Employee.update(config, employee_id, update_data)

      assert Jason.decode!(body) == error_response
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

      assert {:error, %{status: 401, body: body}} =
               BambooHR.Employee.get_directory(config)

      assert Jason.decode!(body) == error_response
    end
  end

  describe "list/2" do
    test "retrieves a page of employees", %{bypass: bypass, config: config} do
      page = %{
        "data" => [%{"employeeId" => "123", "firstName" => "John"}],
        "meta" => %{"total" => 1, "page" => %{"limit" => 250, "nextCursor" => nil}},
        "_links" => %{"self" => %{"href" => "https://api.bamboohr.com/employees"}}
      }

      Bypass.expect_once(
        bypass,
        "GET",
        "/api/gateway.php/test_company/v1/employees",
        fn conn ->
          assert conn.query_string == ""

          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(200, Jason.encode!(page))
        end
      )

      assert {:ok, ^page} = BambooHR.Employee.list(config)
    end

    test "sends filters, sort, fields, and pagination as query params", %{
      bypass: bypass,
      config: config
    } do
      Bypass.expect_once(
        bypass,
        "GET",
        "/api/gateway.php/test_company/v1/employees",
        fn conn ->
          conn = Plug.Conn.fetch_query_params(conn)

          assert conn.query_params == %{
                   "filter" => %{"city" => "Austin", "ids" => "123,124"},
                   "page" => %{"limit" => "2", "after" => "cursor-1"},
                   "sort" => "lastName,-firstName",
                   "fields" => "workEmail,mobilePhone"
                 }

          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(200, Jason.encode!(%{"data" => []}))
        end
      )

      assert {:ok, %{"data" => []}} =
               BambooHR.Employee.list(config,
                 filter: %{"city" => "Austin", "ids" => ["123", "124"]},
                 sort: ["lastName", "-firstName"],
                 fields: ["workEmail", "mobilePhone"],
                 limit: 2,
                 after: "cursor-1"
               )
    end

    test "handles error response", %{bypass: bypass, config: config} do
      Bypass.expect_once(
        bypass,
        "GET",
        "/api/gateway.php/test_company/v1/employees",
        fn conn -> Plug.Conn.resp(conn, 422, "") end
      )

      assert {:error, %{status: 422}} =
               BambooHR.Employee.list(config, filter: %{"ssn" => "123"})
    end
  end

  describe "stream/2" do
    test "follows the cursor across pages", %{bypass: bypass, config: config} do
      Bypass.expect(bypass, "GET", "/api/gateway.php/test_company/v1/employees", fn conn ->
        conn = Plug.Conn.fetch_query_params(conn)

        body =
          case conn.query_params["page"] do
            nil ->
              %{
                "data" => [%{"employeeId" => "1"}, %{"employeeId" => "2"}],
                "meta" => %{"total" => 3, "page" => %{"nextCursor" => "cursor-2"}}
              }

            %{"after" => "cursor-2"} ->
              %{
                "data" => [%{"employeeId" => "3"}],
                "meta" => %{"total" => 3, "page" => %{"nextCursor" => nil}}
              }
          end

        conn
        |> Plug.Conn.put_resp_header("content-type", "application/json")
        |> Plug.Conn.resp(200, Jason.encode!(body))
      end)

      assert [
               {:ok, %{"employeeId" => "1"}},
               {:ok, %{"employeeId" => "2"}},
               {:ok, %{"employeeId" => "3"}}
             ] = config |> BambooHR.Employee.stream() |> Enum.to_list()
    end

    test "requests pages lazily", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/api/gateway.php/test_company/v1/employees", fn conn ->
        body = %{
          "data" => [%{"employeeId" => "1"}, %{"employeeId" => "2"}],
          "meta" => %{"page" => %{"nextCursor" => "cursor-2"}}
        }

        conn
        |> Plug.Conn.put_resp_header("content-type", "application/json")
        |> Plug.Conn.resp(200, Jason.encode!(body))
      end)

      assert [{:ok, %{"employeeId" => "1"}}] =
               config |> BambooHR.Employee.stream() |> Enum.take(1)
    end

    test "emits the error and stops when a page fails", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/api/gateway.php/test_company/v1/employees", fn conn ->
        Plug.Conn.resp(conn, 401, "")
      end)

      assert [{:error, %{status: 401}}] =
               config |> BambooHR.Employee.stream() |> Enum.to_list()
    end

    test "ignores cursor options", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/api/gateway.php/test_company/v1/employees", fn conn ->
        conn = Plug.Conn.fetch_query_params(conn)
        assert conn.query_params == %{"fields" => "workEmail"}

        conn
        |> Plug.Conn.put_resp_header("content-type", "application/json")
        |> Plug.Conn.resp(200, Jason.encode!(%{"data" => [], "meta" => %{}}))
      end)

      assert [] =
               config
               |> BambooHR.Employee.stream(fields: ["workEmail"], after: "x", before: "y")
               |> Enum.to_list()
    end
  end

  defp dynamic_empty_list, do: Enum.to_list(1..0//1)
end
