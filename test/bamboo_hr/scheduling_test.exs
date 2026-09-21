defmodule BambooHR.SchedulingTest do
  use BambooHR.BypassCase, async: true

  @schedule_id "3fa85f64"
  @shift_id "9c14ab02"

  describe "schedules" do
    test "lists schedules", %{bypass: bypass, config: config} do
      Bypass.expect_once(
        bypass,
        "GET",
        "/api/gateway.php/test_company/v1/scheduling/schedules",
        fn conn ->
          conn = Plug.Conn.fetch_query_params(conn)
          assert conn.query_params == %{"page" => "2", "pageSize" => "25"}

          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(200, Jason.encode!(%{"data" => [%{"id" => @schedule_id}]}))
        end
      )

      assert {:ok, %{"data" => [%{"id" => @schedule_id}]}} =
               BambooHR.Scheduling.list_schedules(config, page: 2, page_size: 25)
    end

    test "creates a schedule", %{bypass: bypass, config: config} do
      schedule_data = %{"name" => "Store floor", "locationId" => 4, "startOfWeek" => "Monday"}

      Bypass.expect_once(
        bypass,
        "POST",
        "/api/gateway.php/test_company/v1/scheduling/schedules",
        fn conn ->
          {:ok, body, conn} = Plug.Conn.read_body(conn)
          assert Jason.decode!(body) == schedule_data

          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(201, Jason.encode!(%{"id" => @schedule_id}))
        end
      )

      assert {:ok, %{"id" => @schedule_id}} =
               BambooHR.Scheduling.create_schedule(config, schedule_data)
    end

    test "retrieves a schedule", %{bypass: bypass, config: config} do
      Bypass.expect_once(
        bypass,
        "GET",
        "/api/gateway.php/test_company/v1/scheduling/schedules/#{@schedule_id}",
        fn conn ->
          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(200, Jason.encode!(%{"id" => @schedule_id}))
        end
      )

      assert {:ok, %{"id" => @schedule_id}} =
               BambooHR.Scheduling.get_schedule(config, @schedule_id)
    end

    test "updates a schedule", %{bypass: bypass, config: config} do
      Bypass.expect_once(
        bypass,
        "PATCH",
        "/api/gateway.php/test_company/v1/scheduling/schedules/#{@schedule_id}",
        fn conn ->
          {:ok, body, conn} = Plug.Conn.read_body(conn)
          assert Jason.decode!(body) == %{"name" => "Shop floor"}

          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(200, Jason.encode!(%{"name" => "Shop floor"}))
        end
      )

      assert {:ok, %{"name" => "Shop floor"}} =
               BambooHR.Scheduling.update_schedule(config, @schedule_id, %{"name" => "Shop floor"})
    end

    test "deletes a schedule", %{bypass: bypass, config: config} do
      Bypass.expect_once(
        bypass,
        "DELETE",
        "/api/gateway.php/test_company/v1/scheduling/schedules/#{@schedule_id}",
        fn conn -> Plug.Conn.resp(conn, 204, "") end
      )

      assert {:ok, nil} = BambooHR.Scheduling.delete_schedule(config, @schedule_id)
    end

    test "lists timezones", %{bypass: bypass, config: config} do
      Bypass.expect_once(
        bypass,
        "GET",
        "/api/gateway.php/test_company/v1/scheduling/timezones",
        fn conn ->
          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(200, Jason.encode!(%{"data" => [%{"name" => "America/New_York"}]}))
        end
      )

      assert {:ok, %{"data" => [%{"name" => "America/New_York"}]}} =
               BambooHR.Scheduling.list_timezones(config)
    end
  end

  describe "get_schedule_pdf/5" do
    test "returns the PDF bytes and headers", %{bypass: bypass, config: config} do
      pdf = <<37, 80, 68, 70, 45>>

      Bypass.expect_once(
        bypass,
        "GET",
        "/api/gateway.php/test_company/v1/scheduling/schedules/#{@schedule_id}/pdf",
        fn conn ->
          conn = Plug.Conn.fetch_query_params(conn)

          # Plug parses the `[]` suffix into a list, which is what BambooHR
          # expects from repeated employeeIds[] parameters.
          assert conn.query_params == %{
                   "startYmd" => "2024-01-01",
                   "endYmd" => "2024-01-07",
                   "includeTimeOff" => "true",
                   "employeeIds" => ["123", "124"]
                 }

          assert Plug.Conn.get_req_header(conn, "accept") == ["*/*"]

          conn
          |> Plug.Conn.put_resp_header("content-type", "application/pdf")
          |> Plug.Conn.resp(200, pdf)
        end
      )

      assert {:ok, %{body: ^pdf, headers: headers}} =
               BambooHR.Scheduling.get_schedule_pdf(
                 config,
                 @schedule_id,
                 "2024-01-01",
                 "2024-01-07",
                 employee_ids: [123, 124],
                 include_time_off: true
               )

      assert headers["content-type"] == ["application/pdf"]
    end
  end

  describe "shifts" do
    test "lists shifts for a window", %{bypass: bypass, config: config} do
      Bypass.expect_once(
        bypass,
        "GET",
        "/api/gateway.php/test_company/v1/scheduling/shifts",
        fn conn ->
          conn = Plug.Conn.fetch_query_params(conn)

          assert conn.query_params == %{
                   "start" => "2024-01-01T00:00:00Z",
                   "end" => "2024-01-07T23:59:59Z",
                   "scheduleIds" => @schedule_id,
                   "statuses" => "planned,published"
                 }

          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(200, Jason.encode!(%{"data" => [%{"id" => @shift_id}]}))
        end
      )

      assert {:ok, %{"data" => [%{"id" => @shift_id}]}} =
               BambooHR.Scheduling.list_shifts(config,
                 start: "2024-01-01T00:00:00Z",
                 end: "2024-01-07T23:59:59Z",
                 schedule_ids: [@schedule_id],
                 statuses: ["planned", "published"]
               )
    end

    test "creates a shift", %{bypass: bypass, config: config} do
      shift_data = %{
        "scheduleId" => @schedule_id,
        "status" => "planned",
        "color" => "336699",
        "timezone" => "America/New_York",
        "start" => "2024-01-15T14:00:00Z",
        "end" => "2024-01-15T22:00:00Z"
      }

      Bypass.expect_once(
        bypass,
        "POST",
        "/api/gateway.php/test_company/v1/scheduling/shifts",
        fn conn ->
          {:ok, body, conn} = Plug.Conn.read_body(conn)
          assert Jason.decode!(body) == shift_data

          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(201, Jason.encode!(%{"id" => @shift_id}))
        end
      )

      assert {:ok, %{"id" => @shift_id}} = BambooHR.Scheduling.create_shift(config, shift_data)
    end

    test "retrieves a shift", %{bypass: bypass, config: config} do
      Bypass.expect_once(
        bypass,
        "GET",
        "/api/gateway.php/test_company/v1/scheduling/shifts/#{@shift_id}",
        fn conn ->
          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(200, Jason.encode!(%{"id" => @shift_id}))
        end
      )

      assert {:ok, %{"id" => @shift_id}} = BambooHR.Scheduling.get_shift(config, @shift_id)
    end

    test "updates a shift", %{bypass: bypass, config: config} do
      Bypass.expect_once(
        bypass,
        "PATCH",
        "/api/gateway.php/test_company/v1/scheduling/shifts/#{@shift_id}",
        fn conn ->
          {:ok, body, conn} = Plug.Conn.read_body(conn)
          assert Jason.decode!(body) == %{"capacity" => 3}

          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(200, Jason.encode!(%{"id" => @shift_id, "capacity" => 3}))
        end
      )

      assert {:ok, %{"capacity" => 3}} =
               BambooHR.Scheduling.update_shift(config, @shift_id, %{"capacity" => 3})
    end

    test "deletes a shift", %{bypass: bypass, config: config} do
      Bypass.expect_once(
        bypass,
        "DELETE",
        "/api/gateway.php/test_company/v1/scheduling/shifts/#{@shift_id}",
        fn conn ->
          assert conn.query_string == ""
          Plug.Conn.resp(conn, 204, "")
        end
      )

      assert {:ok, nil} = BambooHR.Scheduling.delete_shift(config, @shift_id)
    end

    test "deletes recurring shifts with a scope", %{bypass: bypass, config: config} do
      Bypass.expect_once(
        bypass,
        "DELETE",
        "/api/gateway.php/test_company/v1/scheduling/shifts/#{@shift_id}",
        fn conn ->
          conn = Plug.Conn.fetch_query_params(conn)
          assert conn.query_params == %{"recurrenceEditOption" => "future"}

          Plug.Conn.resp(conn, 204, "")
        end
      )

      assert {:ok, nil} =
               BambooHR.Scheduling.delete_shift(config, @shift_id,
                 recurrence_edit_option: "future"
               )
    end
  end

  describe "publish_shifts/2" do
    test "publishes shifts", %{bypass: bypass, config: config} do
      Bypass.expect_once(
        bypass,
        "POST",
        "/api/gateway.php/test_company/v1/scheduling/shifts/publish",
        fn conn ->
          {:ok, body, conn} = Plug.Conn.read_body(conn)
          assert Jason.decode!(body) == %{"shiftIds" => [@shift_id]}

          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(
            200,
            Jason.encode!(%{"published" => [%{"id" => @shift_id}], "failed" => []})
          )
        end
      )

      assert {:ok, %{"published" => [%{"id" => @shift_id}], "failed" => []}} =
               BambooHR.Scheduling.publish_shifts(config, [@shift_id])
    end

    test "returns an error when only some shifts published", %{
      bypass: bypass,
      config: config
    } do
      response = %{
        "published" => [%{"id" => @shift_id, "status" => "published"}],
        "failed" => [
          %{
            "shiftId" => "2b77cd31",
            "reason" => "Employee is already assigned to an overlapping shift."
          }
        ]
      }

      Bypass.expect_once(
        bypass,
        "POST",
        "/api/gateway.php/test_company/v1/scheduling/shifts/publish",
        fn conn ->
          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(207, Jason.encode!(response))
        end
      )

      assert {:error, %BambooHR.Error{reason: :partial_publish, status: 207, body: body}} =
               BambooHR.Scheduling.publish_shifts(config, [@shift_id, "2b77cd31"])

      assert Jason.decode!(body) == response
    end

    test "returns an error when every shift conflicts", %{bypass: bypass, config: config} do
      Bypass.expect_once(
        bypass,
        "POST",
        "/api/gateway.php/test_company/v1/scheduling/shifts/publish",
        fn conn -> Plug.Conn.resp(conn, 409, "") end
      )

      assert {:error, %BambooHR.Error{reason: :conflict}} =
               BambooHR.Scheduling.publish_shifts(config, [@shift_id])
    end
  end

  describe "list_shift_assessments/2" do
    test "passes the required filter", %{bypass: bypass, config: config} do
      Bypass.expect_once(
        bypass,
        "GET",
        "/api/gateway.php/test_company/v1/scheduling/shift-assessments",
        fn conn ->
          conn = Plug.Conn.fetch_query_params(conn)
          assert conn.query_params == %{"filter" => "employeeId eq 123"}

          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(200, Jason.encode!(%{"data" => []}))
        end
      )

      assert {:ok, %{"data" => []}} =
               BambooHR.Scheduling.list_shift_assessments(config, filter: "employeeId eq 123")
    end

    test "surfaces a missing filter as an error", %{bypass: bypass, config: config} do
      Bypass.expect_once(
        bypass,
        "GET",
        "/api/gateway.php/test_company/v1/scheduling/shift-assessments",
        fn conn -> Plug.Conn.resp(conn, 400, "") end
      )

      assert {:error, %BambooHR.Error{reason: :bad_request}} =
               BambooHR.Scheduling.list_shift_assessments(config)
    end
  end

  describe "query param formatting" do
    test "renders a DateTime window as an ISO-8601 date-time", %{bypass: bypass, config: config} do
      Bypass.expect_once(
        bypass,
        "GET",
        "/api/gateway.php/test_company/v1/scheduling/shifts",
        fn conn ->
          assert conn.query_string ==
                   "start=2024-01-01T00%3A00%3A00Z&end=2024-01-07T23%3A59%3A59Z&scheduleIds=#{@schedule_id}"

          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(200, Jason.encode!(%{"data" => []}))
        end
      )

      assert {:ok, %{"data" => []}} =
               BambooHR.Scheduling.list_shifts(config,
                 start: ~U[2024-01-01 00:00:00Z],
                 end: ~N[2024-01-07 23:59:59],
                 schedule_ids: [@schedule_id]
               )
    end

    test "omits an empty list rather than sending an empty value", %{
      bypass: bypass,
      config: config
    } do
      Bypass.expect_once(
        bypass,
        "GET",
        "/api/gateway.php/test_company/v1/scheduling/shifts",
        fn conn ->
          assert conn.query_string == "scheduleIds=#{@schedule_id}"

          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(200, Jason.encode!(%{"data" => []}))
        end
      )

      assert {:ok, %{"data" => []}} =
               BambooHR.Scheduling.list_shifts(config, ids: [], schedule_ids: [@schedule_id])
    end

    test "sends nil in a list as the open-shift filter", %{bypass: bypass, config: config} do
      Bypass.expect_once(
        bypass,
        "GET",
        "/api/gateway.php/test_company/v1/scheduling/shifts",
        fn conn ->
          conn = Plug.Conn.fetch_query_params(conn)
          assert conn.query_params["employeeIds"] == "123,null"

          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(200, Jason.encode!(%{"data" => []}))
        end
      )

      assert {:ok, %{"data" => []}} =
               BambooHR.Scheduling.list_shifts(config, employee_ids: [123, nil])
    end

    test "accepts a Date for the PDF window", %{bypass: bypass, config: config} do
      Bypass.expect_once(
        bypass,
        "GET",
        "/api/gateway.php/test_company/v1/scheduling/schedules/#{@schedule_id}/pdf",
        fn conn ->
          assert conn.query_string == "startYmd=2024-01-01&endYmd=2024-01-07"

          conn
          |> Plug.Conn.put_resp_header("content-type", "application/pdf")
          |> Plug.Conn.resp(200, "%PDF-")
        end
      )

      assert {:ok, %{body: "%PDF-"}} =
               BambooHR.Scheduling.get_schedule_pdf(
                 config,
                 @schedule_id,
                 ~D[2024-01-01],
                 ~D[2024-01-07]
               )
    end

    test "ignores an unrecognised option rather than raising", %{bypass: bypass, config: config} do
      Bypass.expect_once(
        bypass,
        "GET",
        "/api/gateway.php/test_company/v1/scheduling/schedules/#{@schedule_id}/pdf",
        fn conn ->
          assert conn.query_string == "startYmd=2024-01-01&endYmd=2024-01-07"

          conn
          |> Plug.Conn.put_resp_header("content-type", "application/pdf")
          |> Plug.Conn.resp(200, "%PDF-")
        end
      )

      assert {:ok, %{body: "%PDF-"}} =
               BambooHR.Scheduling.get_schedule_pdf(
                 config,
                 @schedule_id,
                 "2024-01-01",
                 "2024-01-07",
                 include_holiday: true
               )
    end

    test "forwards unknown options to the HTTP client", %{bypass: bypass, config: config} do
      # Bypass.expect_once fails the test on a second request, so this
      # only passes if `retry: false` reached Req.
      Bypass.expect_once(
        bypass,
        "GET",
        "/api/gateway.php/test_company/v1/scheduling/schedules/#{@schedule_id}/pdf",
        fn conn -> Plug.Conn.resp(conn, 500, "Failed to render PDF") end
      )

      assert {:error, %BambooHR.Error{status: 500}} =
               BambooHR.Scheduling.get_schedule_pdf(
                 config,
                 @schedule_id,
                 "2024-01-01",
                 "2024-01-07",
                 retry: false
               )
    end

    test "keeps a flag that was explicitly set to false", %{bypass: bypass, config: config} do
      Bypass.expect_once(
        bypass,
        "GET",
        "/api/gateway.php/test_company/v1/scheduling/schedules/#{@schedule_id}/pdf",
        fn conn ->
          conn = Plug.Conn.fetch_query_params(conn)
          assert conn.query_params["includeHolidays"] == "false"

          conn
          |> Plug.Conn.put_resp_header("content-type", "application/pdf")
          |> Plug.Conn.resp(200, "%PDF-")
        end
      )

      assert {:ok, %{body: "%PDF-"}} =
               BambooHR.Scheduling.get_schedule_pdf(
                 config,
                 @schedule_id,
                 "2024-01-01",
                 "2024-01-07",
                 include_holidays: false
               )
    end
  end

  describe "calling without options" do
    test "omits optional query params", %{bypass: bypass, config: config} do
      for path <- ["/scheduling/schedules", "/scheduling/shifts"] do
        Bypass.expect_once(bypass, "GET", "/api/gateway.php/test_company/v1" <> path, fn conn ->
          assert conn.query_string == ""

          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(200, Jason.encode!(%{"data" => []}))
        end)
      end

      Bypass.expect_once(
        bypass,
        "GET",
        "/api/gateway.php/test_company/v1/scheduling/schedules/#{@schedule_id}/pdf",
        fn conn ->
          assert conn.query_string == "startYmd=2024-01-01&endYmd=2024-01-07"

          conn
          |> Plug.Conn.put_resp_header("content-type", "application/pdf")
          |> Plug.Conn.resp(200, "%PDF-")
        end
      )

      assert {:ok, %{"data" => []}} = BambooHR.Scheduling.list_schedules(config)
      assert {:ok, %{"data" => []}} = BambooHR.Scheduling.list_shifts(config)

      assert {:ok, %{body: "%PDF-"}} =
               BambooHR.Scheduling.get_schedule_pdf(
                 config,
                 @schedule_id,
                 "2024-01-01",
                 "2024-01-07"
               )
    end
  end
end
