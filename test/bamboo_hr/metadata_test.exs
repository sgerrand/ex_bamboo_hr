defmodule BambooHR.MetadataTest do
  use BambooHR.BypassCase, async: true

  describe "get_fields/1" do
    test "successfully retrieves field metadata", %{bypass: bypass, config: config} do
      fields_data = %{
        "fields" => [
          %{
            "id" => "1",
            "name" => "firstName",
            "type" => "text",
            "description" => "First name"
          },
          %{
            "id" => "2",
            "name" => "lastName",
            "type" => "text",
            "description" => "Last name"
          }
        ]
      }

      Bypass.expect_once(
        bypass,
        "GET",
        "/api/gateway.php/test_company/v1/meta/fields",
        fn conn ->
          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(200, Jason.encode!(fields_data))
        end
      )

      assert {:ok, ^fields_data} = BambooHR.Metadata.get_fields(config)
    end

    test "handles unauthorised error", %{bypass: bypass, config: config} do
      error_response = %{"error" => "Unauthorized"}

      Bypass.expect_once(
        bypass,
        "GET",
        "/api/gateway.php/test_company/v1/meta/fields",
        fn conn ->
          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(401, Jason.encode!(error_response))
        end
      )

      assert {:error, %{status: 401, body: body}} =
               BambooHR.Metadata.get_fields(config)

      assert Jason.decode!(body) == error_response
    end
  end

  describe "get_tabular_fields/1" do
    test "successfully retrieves tabular field metadata", %{bypass: bypass, config: config} do
      tabular_data = %{
        "tabularFields" => [
          %{
            "id" => "employmentStatus",
            "name" => "Employment Status",
            "type" => "list",
            "description" => "History of employment status changes"
          }
        ]
      }

      Bypass.expect_once(
        bypass,
        "GET",
        "/api/gateway.php/test_company/v1/meta/tables",
        fn conn ->
          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(200, Jason.encode!(tabular_data))
        end
      )

      assert {:ok, ^tabular_data} = BambooHR.Metadata.get_tabular_fields(config)
    end

    test "handles forbidden error", %{bypass: bypass, config: config} do
      error_response = %{"error" => "Forbidden"}

      Bypass.expect_once(
        bypass,
        "GET",
        "/api/gateway.php/test_company/v1/meta/tables",
        fn conn ->
          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(403, Jason.encode!(error_response))
        end
      )

      assert {:error, %{status: 403, body: body}} =
               BambooHR.Metadata.get_tabular_fields(config)

      assert Jason.decode!(body) == error_response
    end
  end

  describe "get_lists/1" do
    test "successfully retrieves list field metadata", %{bypass: bypass, config: config} do
      lists_data = %{
        "items" => [
          %{
            "fieldId" => "1610",
            "alias" => "department",
            "manageable" => "yes",
            "name" => "Department",
            "options" => [
              %{
                "id" => "1",
                "name" => "Engineering",
                "archived" => "no",
                "createdDate" => "2024-01-01"
              }
            ]
          }
        ]
      }

      Bypass.expect_once(
        bypass,
        "GET",
        "/api/gateway.php/test_company/v1/meta/lists",
        fn conn ->
          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(200, Jason.encode!(lists_data))
        end
      )

      assert {:ok, ^lists_data} = BambooHR.Metadata.get_lists(config)
    end

    test "handles not-found error", %{bypass: bypass, config: config} do
      error_response = %{"error" => "Not Found"}

      Bypass.expect_once(
        bypass,
        "GET",
        "/api/gateway.php/test_company/v1/meta/lists",
        fn conn ->
          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(404, Jason.encode!(error_response))
        end
      )

      assert {:error, %{status: 404, body: body}} =
               BambooHR.Metadata.get_lists(config)

      assert Jason.decode!(body) == error_response
    end
  end
end
