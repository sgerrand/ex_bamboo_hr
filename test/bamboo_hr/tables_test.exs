defmodule BambooHR.TablesTest do
  use BambooHR.BypassCase, async: true

  describe "get_table_data/3" do
    test "successfully retrieves rows for an employee and table", %{
      bypass: bypass,
      config: config
    } do
      rows_data = [%{"id" => "1", "employeeId" => "123", "payRate" => "50000.00"}]

      Bypass.expect_once(
        bypass,
        "GET",
        "/api/gateway.php/test_company/v1/employees/123/tables/compensation",
        fn conn ->
          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(200, Jason.encode!(rows_data))
        end
      )

      assert {:ok, ^rows_data} = BambooHR.Tables.get_table_data(config, 123, "compensation")
    end

    test "accepts \"all\" as the employee ID", %{bypass: bypass, config: config} do
      Bypass.expect_once(
        bypass,
        "GET",
        "/api/gateway.php/test_company/v1/employees/all/tables/compensation",
        fn conn ->
          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(200, Jason.encode!([]))
        end
      )

      assert {:ok, []} = BambooHR.Tables.get_table_data(config, "all", "compensation")
    end

    test "handles not-found error", %{bypass: bypass, config: config} do
      Bypass.expect_once(
        bypass,
        "GET",
        "/api/gateway.php/test_company/v1/employees/123/tables/compensation",
        fn conn -> Plug.Conn.resp(conn, 404, "") end
      )

      assert {:error, %{status: 404}} =
               BambooHR.Tables.get_table_data(config, 123, "compensation")
    end
  end

  describe "create_table_row/4" do
    test "successfully adds a row", %{bypass: bypass, config: config} do
      row_data = %{"date" => "2024-01-15", "payRate" => "55000.00"}

      Bypass.expect_once(
        bypass,
        "POST",
        "/api/gateway.php/test_company/v1/employees/123/tables/compensation",
        fn conn ->
          {:ok, body, conn} = Plug.Conn.read_body(conn)
          assert Jason.decode!(body) == row_data
          Plug.Conn.resp(conn, 200, "")
        end
      )

      assert {:ok, nil} = BambooHR.Tables.create_table_row(config, 123, "compensation", row_data)
    end

    test "handles precondition-failed error", %{bypass: bypass, config: config} do
      Bypass.expect_once(
        bypass,
        "POST",
        "/api/gateway.php/test_company/v1/employees/123/tables/compensation",
        fn conn -> Plug.Conn.resp(conn, 412, "") end
      )

      assert {:error, %{status: 412}} =
               BambooHR.Tables.create_table_row(config, 123, "compensation", %{})
    end
  end

  describe "update_table_row/5" do
    test "successfully updates a row", %{bypass: bypass, config: config} do
      row_data = %{"payRate" => "60000.00"}

      Bypass.expect_once(
        bypass,
        "POST",
        "/api/gateway.php/test_company/v1/employees/123/tables/compensation/1",
        fn conn ->
          {:ok, body, conn} = Plug.Conn.read_body(conn)
          assert Jason.decode!(body) == row_data
          Plug.Conn.resp(conn, 200, "")
        end
      )

      assert {:ok, nil} =
               BambooHR.Tables.update_table_row(config, 123, "compensation", "1", row_data)
    end
  end

  describe "delete_table_row/4" do
    test "successfully deletes a row", %{bypass: bypass, config: config} do
      Bypass.expect_once(
        bypass,
        "DELETE",
        "/api/gateway.php/test_company/v1/employees/123/tables/compensation/1",
        fn conn ->
          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(200, Jason.encode!(%{"success" => true}))
        end
      )

      assert {:ok, %{"success" => true}} =
               BambooHR.Tables.delete_table_row(config, 123, "compensation", "1")
    end

    test "returns success: false when the row was not found", %{
      bypass: bypass,
      config: config
    } do
      response = %{"success" => false, "error" => "Row not found"}

      Bypass.expect_once(
        bypass,
        "DELETE",
        "/api/gateway.php/test_company/v1/employees/123/tables/compensation/999",
        fn conn ->
          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(200, Jason.encode!(response))
        end
      )

      assert {:ok, ^response} =
               BambooHR.Tables.delete_table_row(config, 123, "compensation", "999")
    end

    test "handles conflict error", %{bypass: bypass, config: config} do
      Bypass.expect_once(
        bypass,
        "DELETE",
        "/api/gateway.php/test_company/v1/employees/123/tables/compensation/1",
        fn conn -> Plug.Conn.resp(conn, 409, "") end
      )

      assert {:error, %{status: 409}} =
               BambooHR.Tables.delete_table_row(config, 123, "compensation", "1")
    end
  end

  describe "get_changed_table_data/3" do
    test "successfully retrieves changed table data", %{bypass: bypass, config: config} do
      changed_data = %{
        "table" => "compensation",
        "employees" => %{
          "123" => %{"lastChanged" => "2024-01-15T00:00:00Z", "rows" => []}
        }
      }

      Bypass.expect_once(
        bypass,
        "GET",
        "/api/gateway.php/test_company/v1/employees/changed/tables/compensation",
        fn conn ->
          assert conn.query_string == "since=2024-01-01T00%3A00%3A00Z"

          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(200, Jason.encode!(changed_data))
        end
      )

      assert {:ok, ^changed_data} =
               BambooHR.Tables.get_changed_table_data(
                 config,
                 "compensation",
                 "2024-01-01T00:00:00Z"
               )
    end

    test "handles bad-request error for invalid since", %{bypass: bypass, config: config} do
      Bypass.expect_once(
        bypass,
        "GET",
        "/api/gateway.php/test_company/v1/employees/changed/tables/compensation",
        fn conn -> Plug.Conn.resp(conn, 400, "") end
      )

      assert {:error, %{status: 400}} =
               BambooHR.Tables.get_changed_table_data(config, "compensation", "not-a-date")
    end
  end
end
