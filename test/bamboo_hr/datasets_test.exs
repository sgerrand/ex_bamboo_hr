defmodule BambooHR.DatasetsTest do
  use BambooHR.BypassCase, async: true

  describe "list_datasets/1" do
    test "successfully retrieves the dataset catalog", %{bypass: bypass, config: config} do
      datasets_data = %{"datasets" => [%{"name" => "employee", "label" => "Employee"}]}

      Bypass.expect_once(
        bypass,
        "GET",
        "/api/gateway.php/test_company/v1_2/datasets",
        fn conn ->
          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(200, Jason.encode!(datasets_data))
        end
      )

      assert {:ok, ^datasets_data} = BambooHR.Datasets.list_datasets(config)
    end

    test "handles forbidden error (problem+json)", %{bypass: bypass, config: config} do
      error_response = %{"title" => "Forbidden", "status" => 403}

      Bypass.expect_once(
        bypass,
        "GET",
        "/api/gateway.php/test_company/v1_2/datasets",
        fn conn ->
          conn
          |> Plug.Conn.put_resp_header("content-type", "application/problem+json")
          |> Plug.Conn.resp(403, Jason.encode!(error_response))
        end
      )

      assert {:error, %{status: 403, body: body}} = BambooHR.Datasets.list_datasets(config)
      assert Jason.decode!(body) == error_response
    end
  end

  describe "get_dataset_fields/3" do
    test "successfully retrieves field descriptors with no params", %{
      bypass: bypass,
      config: config
    } do
      fields_data = %{
        "name" => "employee",
        "fields" => [%{"name" => "status", "label" => "Status"}]
      }

      Bypass.expect_once(
        bypass,
        "GET",
        "/api/gateway.php/test_company/v1_2/datasets/employee/fields",
        fn conn ->
          assert conn.query_string == ""

          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(200, Jason.encode!(fields_data))
        end
      )

      assert {:ok, ^fields_data} = BambooHR.Datasets.get_dataset_fields(config, "employee")
    end

    test "forwards optional pagination params", %{bypass: bypass, config: config} do
      Bypass.expect_once(
        bypass,
        "GET",
        "/api/gateway.php/test_company/v1_2/datasets/employee/fields",
        fn conn ->
          assert conn.query_string == "page=2&page_size=100"

          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(200, Jason.encode!(%{"fields" => []}))
        end
      )

      assert {:ok, %{"fields" => []}} =
               BambooHR.Datasets.get_dataset_fields(config, "employee", %{
                 "page" => 2,
                 "page_size" => 100
               })
    end

    test "handles dataset-not-found error", %{bypass: bypass, config: config} do
      error_response = %{"title" => "Not Found", "code" => "DATASET_NOT_FOUND"}

      Bypass.expect_once(
        bypass,
        "GET",
        "/api/gateway.php/test_company/v1_2/datasets/bogus/fields",
        fn conn ->
          conn
          |> Plug.Conn.put_resp_header("content-type", "application/problem+json")
          |> Plug.Conn.resp(422, Jason.encode!(error_response))
        end
      )

      assert {:error, %{status: 422, body: body}} =
               BambooHR.Datasets.get_dataset_fields(config, "bogus")

      assert Jason.decode!(body) == error_response
    end
  end

  describe "get_field_options/4" do
    test "successfully retrieves field options with just fields", %{
      bypass: bypass,
      config: config
    } do
      options_data = %{"status" => [%{"id" => "Active", "value" => "Active"}]}

      Bypass.expect_once(
        bypass,
        "POST",
        "/api/gateway.php/test_company/v1_2/datasets/employee/field-options",
        fn conn ->
          {:ok, body, conn} = Plug.Conn.read_body(conn)
          assert Jason.decode!(body) == %{"fields" => ["status"]}

          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(200, Jason.encode!(options_data))
        end
      )

      assert {:ok, ^options_data} =
               BambooHR.Datasets.get_field_options(config, "employee", ["status"])
    end

    test "forwards optional filters and dependent_fields", %{bypass: bypass, config: config} do
      filters = %{"match" => "all", "filters" => [%{"field" => "status", "operator" => "eq"}]}
      dependent_fields = %{"field_name1" => [%{"field" => "field_name2", "value" => 123}]}

      Bypass.expect_once(
        bypass,
        "POST",
        "/api/gateway.php/test_company/v1_2/datasets/employee/field-options",
        fn conn ->
          {:ok, body, conn} = Plug.Conn.read_body(conn)

          assert Jason.decode!(body) == %{
                   "fields" => ["status"],
                   "filters" => filters,
                   "dependentFields" => dependent_fields
                 }

          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(200, Jason.encode!(%{}))
        end
      )

      assert {:ok, %{}} =
               BambooHR.Datasets.get_field_options(config, "employee", ["status"],
                 filters: filters,
                 dependent_fields: dependent_fields
               )
    end

    test "handles bad-request error", %{bypass: bypass, config: config} do
      error_response = %{"title" => "Bad Request"}

      Bypass.expect_once(
        bypass,
        "POST",
        "/api/gateway.php/test_company/v1_2/datasets/employee/field-options",
        fn conn ->
          conn
          |> Plug.Conn.put_resp_header("content-type", "application/problem+json")
          |> Plug.Conn.resp(400, Jason.encode!(error_response))
        end
      )

      assert {:error, %{status: 400, body: body}} =
               BambooHR.Datasets.get_field_options(config, "employee", ["status"])

      assert Jason.decode!(body) == error_response
    end
  end

  describe "get_dataset_data/4" do
    test "successfully queries dataset records with just fields", %{
      bypass: bypass,
      config: config
    } do
      data = %{
        "data" => [%{"fields" => %{"firstName" => "Jane", "status" => "Active"}}],
        "meta" => %{"page" => 1}
      }

      Bypass.expect_once(
        bypass,
        "POST",
        "/api/gateway.php/test_company/v2/datasets/employee/data",
        fn conn ->
          {:ok, body, conn} = Plug.Conn.read_body(conn)
          assert Jason.decode!(body) == %{"fields" => ["firstName", "status"]}

          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(200, Jason.encode!(data))
        end
      )

      assert {:ok, ^data} =
               BambooHR.Datasets.get_dataset_data(config, "employee", ["firstName", "status"])
    end

    test "forwards optional filter, order_by, page, and page_size", %{
      bypass: bypass,
      config: config
    } do
      Bypass.expect_once(
        bypass,
        "POST",
        "/api/gateway.php/test_company/v2/datasets/employee/data",
        fn conn ->
          {:ok, body, conn} = Plug.Conn.read_body(conn)

          assert Jason.decode!(body) == %{
                   "fields" => ["firstName"],
                   "filter" => "status eq 'Active'",
                   "orderBy" => "firstName asc",
                   "page" => 2,
                   "pageSize" => 25
                 }

          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(200, Jason.encode!(%{"data" => []}))
        end
      )

      assert {:ok, %{"data" => []}} =
               BambooHR.Datasets.get_dataset_data(config, "employee", ["firstName"],
                 filter: "status eq 'Active'",
                 order_by: "firstName asc",
                 page: 2,
                 page_size: 25
               )
    end

    test "handles internal-server-error", %{bypass: bypass, config: config} do
      error_response = %{"title" => "Internal Server Error"}

      Bypass.expect_once(
        bypass,
        "POST",
        "/api/gateway.php/test_company/v2/datasets/employee/data",
        fn conn ->
          conn
          |> Plug.Conn.put_resp_header("content-type", "application/problem+json")
          |> Plug.Conn.resp(500, Jason.encode!(error_response))
        end
      )

      assert {:error, %{status: 500, body: body}} =
               BambooHR.Datasets.get_dataset_data(config, "employee", ["firstName"])

      assert Jason.decode!(body) == error_response
    end
  end
end
