defmodule BambooHR.FilesTest do
  use BambooHR.BypassCase, async: true

  describe "create_company_file_category/2" do
    test "successfully creates categories", %{bypass: bypass, config: config} do
      Bypass.expect_once(
        bypass,
        "POST",
        "/api/gateway.php/test_company/v1/files/categories",
        fn conn ->
          {:ok, body, conn} = Plug.Conn.read_body(conn)
          assert Jason.decode!(body) == ["Contracts"]
          Plug.Conn.resp(conn, 201, "")
        end
      )

      assert {:ok, nil} =
               BambooHR.Files.create_company_file_category(config, ["Contracts"])
    end
  end

  describe "create_employee_file_category/2" do
    test "successfully creates categories", %{bypass: bypass, config: config} do
      Bypass.expect_once(
        bypass,
        "POST",
        "/api/gateway.php/test_company/v1/employees/files/categories",
        fn conn ->
          {:ok, body, conn} = Plug.Conn.read_body(conn)
          assert Jason.decode!(body) == ["Certifications"]
          Plug.Conn.resp(conn, 201, "")
        end
      )

      assert {:ok, nil} =
               BambooHR.Files.create_employee_file_category(config, ["Certifications"])
    end

    test "handles error response", %{bypass: bypass, config: config} do
      error_response = %{"error" => "Category already exists"}

      Bypass.expect_once(
        bypass,
        "POST",
        "/api/gateway.php/test_company/v1/employees/files/categories",
        fn conn ->
          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(400, Jason.encode!(error_response))
        end
      )

      assert {:error, %{status: 400, body: body}} =
               BambooHR.Files.create_employee_file_category(config, ["Certifications"])

      assert Jason.decode!(body) == error_response
    end
  end

  describe "list_company_files/1" do
    test "successfully retrieves categories and files", %{bypass: bypass, config: config} do
      files_data = %{
        "categories" => [
          %{"id" => 1, "name" => "Policies", "canUploadFiles" => "yes", "files" => []}
        ]
      }

      Bypass.expect_once(
        bypass,
        "GET",
        "/api/gateway.php/test_company/v1/files/view",
        fn conn ->
          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(200, Jason.encode!(files_data))
        end
      )

      assert {:ok, ^files_data} = BambooHR.Files.list_company_files(config)
    end
  end

  describe "list_employee_files/2" do
    test "successfully retrieves employee categories and files", %{
      bypass: bypass,
      config: config
    } do
      files_data = %{"employee" => %{"id" => 123}, "categories" => []}

      Bypass.expect_once(
        bypass,
        "GET",
        "/api/gateway.php/test_company/v1/employees/123/files/view",
        fn conn ->
          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(200, Jason.encode!(files_data))
        end
      )

      assert {:ok, ^files_data} = BambooHR.Files.list_employee_files(config, 123)
    end

    test "handles not-found error", %{bypass: bypass, config: config} do
      error_response = %{"error" => "Not found"}

      Bypass.expect_once(
        bypass,
        "GET",
        "/api/gateway.php/test_company/v1/employees/123/files/view",
        fn conn ->
          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(404, Jason.encode!(error_response))
        end
      )

      assert {:error, %{status: 404, body: body}} =
               BambooHR.Files.list_employee_files(config, 123)

      assert Jason.decode!(body) == error_response
    end
  end

  describe "upload_company_file/5" do
    test "returns the Location header on success", %{bypass: bypass, config: config} do
      location = "https://test_company.bamboohr.com/files/789"

      Bypass.expect_once(bypass, "POST", "/api/gateway.php/test_company/v1/files", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        assert body =~ "handbook.pdf"
        assert body =~ "%PDF-1.4"
        assert [content_type] = Plug.Conn.get_req_header(conn, "content-type")
        assert content_type =~ "multipart/form-data"

        conn
        |> Plug.Conn.put_resp_header("location", location)
        |> Plug.Conn.resp(201, "")
      end)

      assert {:ok, %{"location" => ^location}} =
               BambooHR.Files.upload_company_file(config, "handbook.pdf", 3, "%PDF-1.4 binary")
    end

    test "returns an empty map when no Location header is present", %{
      bypass: bypass,
      config: config
    } do
      Bypass.expect_once(bypass, "POST", "/api/gateway.php/test_company/v1/files", fn conn ->
        Plug.Conn.resp(conn, 201, "")
      end)

      assert {:ok, %{}} =
               BambooHR.Files.upload_company_file(config, "handbook.pdf", 3, "%PDF-1.4 binary")
    end

    defmodule IgnoresExposeHeaders do
      @behaviour BambooHR.HTTPClient

      @impl true
      def request(_opts), do: {:ok, nil}
    end

    test "does not raise when http_client ignores expose_headers" do
      config =
        BambooHR.Client.new(
          company_domain: "test_company",
          api_key: "test_key",
          http_client: IgnoresExposeHeaders
        )

      assert {:ok, %{}} =
               BambooHR.Files.upload_company_file(config, "handbook.pdf", 3, "%PDF-1.4 binary")
    end
  end

  describe "upload_employee_file/6" do
    test "returns the Location header on success", %{bypass: bypass, config: config} do
      location = "https://test_company.bamboohr.com/employees/files/456"

      Bypass.expect_once(
        bypass,
        "POST",
        "/api/gateway.php/test_company/v1/employees/123/files",
        fn conn ->
          {:ok, body, conn} = Plug.Conn.read_body(conn)
          assert body =~ "resume.pdf"

          conn
          |> Plug.Conn.put_resp_header("location", location)
          |> Plug.Conn.resp(201, "")
        end
      )

      assert {:ok, %{"location" => ^location}} =
               BambooHR.Files.upload_employee_file(config, 123, "resume.pdf", 5, "%PDF binary")
    end
  end

  describe "get_company_file/2" do
    test "returns raw body and headers", %{bypass: bypass, config: config} do
      binary_content = <<0x25, 0x50, 0x44, 0x46>>

      Bypass.expect_once(
        bypass,
        "GET",
        "/api/gateway.php/test_company/v1/files/123",
        fn conn ->
          conn
          |> Plug.Conn.put_resp_header("content-type", "application/pdf")
          |> Plug.Conn.put_resp_header(
            "content-disposition",
            ~s(attachment; filename="handbook.pdf")
          )
          |> Plug.Conn.resp(200, binary_content)
        end
      )

      assert {:ok, %{body: ^binary_content, headers: headers}} =
               BambooHR.Files.get_company_file(config, 123)

      assert headers["content-type"] == ["application/pdf"]
    end

    test "handles not-found error", %{bypass: bypass, config: config} do
      Bypass.expect_once(
        bypass,
        "GET",
        "/api/gateway.php/test_company/v1/files/999",
        fn conn -> Plug.Conn.resp(conn, 404, "") end
      )

      assert {:error, %{status: 404}} = BambooHR.Files.get_company_file(config, 999)
    end
  end

  describe "get_employee_file/3" do
    test "returns raw body and headers", %{bypass: bypass, config: config} do
      binary_content = <<0x25, 0x50, 0x44, 0x46>>

      Bypass.expect_once(
        bypass,
        "GET",
        "/api/gateway.php/test_company/v1/employees/123/files/456",
        fn conn ->
          conn
          |> Plug.Conn.put_resp_header("content-type", "application/pdf")
          |> Plug.Conn.resp(200, binary_content)
        end
      )

      assert {:ok, %{body: ^binary_content, headers: headers}} =
               BambooHR.Files.get_employee_file(config, 123, 456)

      assert headers["content-type"] == ["application/pdf"]
    end
  end

  describe "update_company_file/3" do
    test "successfully updates file metadata", %{bypass: bypass, config: config} do
      update_data = %{"name" => "handbook-v2.pdf"}

      Bypass.expect_once(
        bypass,
        "POST",
        "/api/gateway.php/test_company/v1/files/123",
        fn conn ->
          {:ok, body, conn} = Plug.Conn.read_body(conn)
          assert Jason.decode!(body) == update_data
          Plug.Conn.resp(conn, 200, "")
        end
      )

      assert {:ok, nil} = BambooHR.Files.update_company_file(config, 123, update_data)
    end
  end

  describe "update_employee_file/4" do
    test "successfully updates file metadata", %{bypass: bypass, config: config} do
      update_data = %{"name" => "resume-2024.pdf"}

      Bypass.expect_once(
        bypass,
        "POST",
        "/api/gateway.php/test_company/v1/employees/123/files/456",
        fn conn ->
          {:ok, body, conn} = Plug.Conn.read_body(conn)
          assert Jason.decode!(body) == update_data
          Plug.Conn.resp(conn, 200, "")
        end
      )

      assert {:ok, nil} =
               BambooHR.Files.update_employee_file(config, 123, 456, update_data)
    end
  end

  describe "delete_company_file/2" do
    test "successfully deletes a file", %{bypass: bypass, config: config} do
      Bypass.expect_once(
        bypass,
        "DELETE",
        "/api/gateway.php/test_company/v1/files/123",
        fn conn -> Plug.Conn.resp(conn, 200, "") end
      )

      assert {:ok, nil} = BambooHR.Files.delete_company_file(config, 123)
    end
  end

  describe "delete_employee_file/3" do
    test "successfully deletes a file", %{bypass: bypass, config: config} do
      Bypass.expect_once(
        bypass,
        "DELETE",
        "/api/gateway.php/test_company/v1/employees/123/files/456",
        fn conn -> Plug.Conn.resp(conn, 200, "") end
      )

      assert {:ok, nil} = BambooHR.Files.delete_employee_file(config, 123, 456)
    end

    test "handles forbidden error", %{bypass: bypass, config: config} do
      error_response = %{"error" => "Forbidden"}

      Bypass.expect_once(
        bypass,
        "DELETE",
        "/api/gateway.php/test_company/v1/employees/123/files/456",
        fn conn ->
          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(403, Jason.encode!(error_response))
        end
      )

      assert {:error, %{status: 403, body: body}} =
               BambooHR.Files.delete_employee_file(config, 123, 456)

      assert Jason.decode!(body) == error_response
    end
  end
end
