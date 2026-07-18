defmodule BambooHR.HiringTest do
  use BambooHR.BypassCase, async: true

  describe "get_applications/2" do
    test "successfully retrieves applications with no params", %{
      bypass: bypass,
      config: config
    } do
      applications_data = %{
        "paginationComplete" => true,
        "nextPageUrl" => nil,
        "applications" => []
      }

      Bypass.expect_once(
        bypass,
        "GET",
        "/api/gateway.php/test_company/v1/applicant_tracking/applications",
        fn conn ->
          assert conn.query_string == ""

          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(200, Jason.encode!(applications_data))
        end
      )

      assert {:ok, ^applications_data} = BambooHR.Hiring.get_applications(config)
    end

    test "forwards optional query params", %{bypass: bypass, config: config} do
      Bypass.expect_once(
        bypass,
        "GET",
        "/api/gateway.php/test_company/v1/applicant_tracking/applications",
        fn conn ->
          assert conn.query_string == "jobId=7&page=2"

          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(200, Jason.encode!(%{"applications" => []}))
        end
      )

      assert {:ok, %{"applications" => []}} =
               BambooHR.Hiring.get_applications(config, %{"page" => 2, "jobId" => 7})
    end
  end

  describe "get_application/2" do
    test "successfully retrieves application details", %{bypass: bypass, config: config} do
      application_data = %{"id" => 42, "applicant" => %{"firstName" => "Jane"}}

      Bypass.expect_once(
        bypass,
        "GET",
        "/api/gateway.php/test_company/v1/applicant_tracking/applications/42",
        fn conn ->
          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(200, Jason.encode!(application_data))
        end
      )

      assert {:ok, ^application_data} = BambooHR.Hiring.get_application(config, 42)
    end

    test "handles not-found error", %{bypass: bypass, config: config} do
      Bypass.expect_once(
        bypass,
        "GET",
        "/api/gateway.php/test_company/v1/applicant_tracking/applications/999",
        fn conn -> Plug.Conn.resp(conn, 404, "") end
      )

      assert {:error, %{status: 404}} = BambooHR.Hiring.get_application(config, 999)
    end
  end

  describe "get_applicant_statuses/1" do
    test "successfully retrieves statuses", %{bypass: bypass, config: config} do
      statuses_data = [%{"id" => "1", "name" => "New", "enabled" => true}]

      Bypass.expect_once(
        bypass,
        "GET",
        "/api/gateway.php/test_company/v1/applicant_tracking/statuses",
        fn conn ->
          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(200, Jason.encode!(statuses_data))
        end
      )

      assert {:ok, ^statuses_data} = BambooHR.Hiring.get_applicant_statuses(config)
    end
  end

  describe "get_company_locations/1" do
    test "successfully retrieves locations", %{bypass: bypass, config: config} do
      locations_data = [%{"id" => 1, "name" => "HQ"}]

      Bypass.expect_once(
        bypass,
        "GET",
        "/api/gateway.php/test_company/v1/applicant_tracking/locations",
        fn conn ->
          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(200, Jason.encode!(locations_data))
        end
      )

      assert {:ok, ^locations_data} = BambooHR.Hiring.get_company_locations(config)
    end
  end

  describe "get_hiring_leads/1" do
    test "successfully retrieves hiring leads", %{bypass: bypass, config: config} do
      leads_data = [%{"employeeId" => 123, "preferredFullName" => "Jane Smith"}]

      Bypass.expect_once(
        bypass,
        "GET",
        "/api/gateway.php/test_company/v1/applicant_tracking/hiring_leads",
        fn conn ->
          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(200, Jason.encode!(leads_data))
        end
      )

      assert {:ok, ^leads_data} = BambooHR.Hiring.get_hiring_leads(config)
    end
  end

  describe "get_job_summaries/2" do
    test "successfully retrieves job summaries with no params", %{
      bypass: bypass,
      config: config
    } do
      jobs_data = [%{"id" => 7, "title" => %{"label" => "Engineer"}}]

      Bypass.expect_once(
        bypass,
        "GET",
        "/api/gateway.php/test_company/v1/applicant_tracking/jobs",
        fn conn ->
          assert conn.query_string == ""

          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(200, Jason.encode!(jobs_data))
        end
      )

      assert {:ok, ^jobs_data} = BambooHR.Hiring.get_job_summaries(config)
    end

    test "forwards optional query params", %{bypass: bypass, config: config} do
      Bypass.expect_once(
        bypass,
        "GET",
        "/api/gateway.php/test_company/v1/applicant_tracking/jobs",
        fn conn ->
          assert conn.query_string == "statusGroups=Open"

          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(200, Jason.encode!([]))
        end
      )

      assert {:ok, []} =
               BambooHR.Hiring.get_job_summaries(config, %{"statusGroups" => "Open"})
    end
  end

  describe "create_candidate/5" do
    test "successfully creates a candidate", %{bypass: bypass, config: config} do
      response_data = %{"result" => "success", "candidateId" => 99}

      Bypass.expect_once(
        bypass,
        "POST",
        "/api/gateway.php/test_company/v1/applicant_tracking/application",
        fn conn ->
          {:ok, body, conn} = Plug.Conn.read_body(conn)
          assert body =~ "Jane"
          assert body =~ "Doe"
          assert [content_type] = Plug.Conn.get_req_header(conn, "content-type")
          assert content_type =~ "multipart/form-data"

          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(200, Jason.encode!(response_data))
        end
      )

      assert {:ok, ^response_data} =
               BambooHR.Hiring.create_candidate(config, "Jane", "Doe", 7,
                 email: "jane@example.com"
               )
    end

    test "handles unprocessable-entity error", %{bypass: bypass, config: config} do
      Bypass.expect_once(
        bypass,
        "POST",
        "/api/gateway.php/test_company/v1/applicant_tracking/application",
        fn conn -> Plug.Conn.resp(conn, 422, "") end
      )

      assert {:error, %{status: 422}} =
               BambooHR.Hiring.create_candidate(config, "Jane", "Doe", 7)
    end
  end

  describe "create_job_opening/7" do
    test "successfully creates a job opening", %{bypass: bypass, config: config} do
      response_data = %{"result" => "success", "jobOpeningId" => "42"}

      Bypass.expect_once(
        bypass,
        "POST",
        "/api/gateway.php/test_company/v1/applicant_tracking/job_opening",
        fn conn ->
          {:ok, body, conn} = Plug.Conn.read_body(conn)
          assert body =~ "Engineer"

          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(200, Jason.encode!(response_data))
        end
      )

      assert {:ok, ^response_data} =
               BambooHR.Hiring.create_job_opening(
                 config,
                 "Engineer",
                 "Open",
                 123,
                 "Full-Time",
                 "Build things"
               )
    end
  end

  describe "create_application_comment/3" do
    test "successfully adds a comment", %{bypass: bypass, config: config} do
      comment_data = %{"comment" => "Great fit"}
      response_data = %{"type" => "comment", "id" => 55}

      Bypass.expect_once(
        bypass,
        "POST",
        "/api/gateway.php/test_company/v1/applicant_tracking/applications/42/comments",
        fn conn ->
          {:ok, body, conn} = Plug.Conn.read_body(conn)
          assert Jason.decode!(body) == comment_data

          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(200, Jason.encode!(response_data))
        end
      )

      assert {:ok, ^response_data} =
               BambooHR.Hiring.create_application_comment(config, 42, comment_data)
    end
  end

  describe "update_applicant_status/3" do
    test "successfully updates status", %{bypass: bypass, config: config} do
      Bypass.expect_once(
        bypass,
        "POST",
        "/api/gateway.php/test_company/v1/applicant_tracking/applications/42/status",
        fn conn ->
          {:ok, body, conn} = Plug.Conn.read_body(conn)
          assert Jason.decode!(body) == %{"status" => 2}
          Plug.Conn.resp(conn, 200, "")
        end
      )

      assert {:ok, nil} = BambooHR.Hiring.update_applicant_status(config, 42, 2)
    end

    test "handles forbidden error", %{bypass: bypass, config: config} do
      Bypass.expect_once(
        bypass,
        "POST",
        "/api/gateway.php/test_company/v1/applicant_tracking/applications/42/status",
        fn conn -> Plug.Conn.resp(conn, 403, "") end
      )

      assert {:error, %{status: 403}} = BambooHR.Hiring.update_applicant_status(config, 42, 2)
    end
  end
end
