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
          |> Plug.Conn.put_resp_header("x-request-id", "req-207")
          |> Plug.Conn.resp(207, Jason.encode!(response))
        end
      )

      assert {:error,
              %BambooHR.Error{
                reason: :partial_publish,
                status: 207,
                body: body,
                request_id: "req-207"
              }} = BambooHR.Scheduling.publish_shifts(config, [@shift_id, "2b77cd31"])

      assert Jason.decode!(body) == response
    end

    test "returns an error when every shift conflicts", %{bypass: bypass, config: config} do
      Bypass.expect_once(
        bypass,
        "POST",
        "/api/gateway.php/test_company/v1/scheduling/shifts/publish",
        fn conn ->
          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(409, Jason.encode!(response_409()))
        end
      )

      assert {:error, %BambooHR.Error{reason: :conflict, status: 409, body: body}} =
               BambooHR.Scheduling.publish_shifts(config, [@shift_id])

      assert Jason.decode!(body) == response_409()
    end

    defmodule IgnoresPartialSuccess do
      @behaviour BambooHR.HTTPClient

      # Returns the decoded body, as a custom client that does not know
      # about :partial_success would.
      @impl true
      def request(_opts) do
        {:ok,
         %{
           "published" => [%{"id" => "w"}],
           "failed" => [%{"shiftId" => "x", "reason" => "y"}]
         }}
      end
    end

    defmodule CleanPublish do
      @behaviour BambooHR.HTTPClient

      @impl true
      def request(_opts), do: {:ok, %{"published" => [%{"id" => "w"}], "failed" => []}}
    end

    test "still returns an error when a custom client ignores partial_success" do
      config =
        BambooHR.Client.new(
          company_domain: "test_company",
          api_key: "test_key",
          http_client: IgnoresPartialSuccess
        )

      assert {:error, %BambooHR.Error{reason: :partial_publish, status: 207, body: body}} =
               BambooHR.Scheduling.publish_shifts(config, ["w", "x"])

      # Both lists survive, re-encoded from what the client handed back.
      assert Jason.decode!(body) == %{
               "published" => [%{"id" => "w"}],
               "failed" => [%{"shiftId" => "x", "reason" => "y"}]
             }
    end

    test "leaves a custom client's clean publish as a success" do
      config =
        BambooHR.Client.new(
          company_domain: "test_company",
          api_key: "test_key",
          http_client: CleanPublish
        )

      assert {:ok, %{"failed" => []}} = BambooHR.Scheduling.publish_shifts(config, ["w"])
    end

    defp response_409 do
      %{"published" => [], "failed" => [%{"shiftId" => @shift_id, "reason" => "Overlaps."}]}
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
        fn conn -> Plug.Conn.resp(conn, 422, "") end
      )

      assert {:error, %BambooHR.Error{reason: :unprocessable_entity}} =
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

    test "reads a Date as midnight UTC and keeps a DateTime's offset", %{
      bypass: bypass,
      config: config
    } do
      Bypass.expect_once(
        bypass,
        "GET",
        "/api/gateway.php/test_company/v1/scheduling/shifts",
        fn conn ->
          conn = Plug.Conn.fetch_query_params(conn)
          assert conn.query_params["start"] == "2024-01-01T00:00:00Z"
          assert conn.query_params["end"] == "2024-01-07T17:00:00-05:00"

          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(200, Jason.encode!(%{"data" => []}))
        end
      )

      end_at =
        DateTime.new!(~D[2024-01-07], ~T[17:00:00], "Etc/UTC")
        |> Map.merge(%{utc_offset: -18_000, zone_abbr: "EST", time_zone: "America/New_York"})

      assert {:ok, %{"data" => []}} =
               BambooHR.Scheduling.list_shifts(config,
                 start: ~D[2024-01-01],
                 end: end_at,
                 schedule_ids: [@schedule_id]
               )
    end

    test "sends a DateTime in whole seconds", %{bypass: bypass, config: config} do
      Bypass.expect_once(
        bypass,
        "GET",
        "/api/gateway.php/test_company/v1/scheduling/shifts",
        fn conn ->
          conn = Plug.Conn.fetch_query_params(conn)
          assert conn.query_params["start"] == "2024-01-01T12:00:00Z"

          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(200, Jason.encode!(%{"data" => []}))
        end
      )

      assert {:ok, %{"data" => []}} =
               BambooHR.Scheduling.list_shifts(config,
                 start: ~U[2024-01-01 12:00:00.123456Z],
                 schedule_ids: [@schedule_id]
               )
    end

    test "reads a Date as :end as the end of that day", %{bypass: bypass, config: config} do
      Bypass.expect_once(
        bypass,
        "GET",
        "/api/gateway.php/test_company/v1/scheduling/shifts",
        fn conn ->
          conn = Plug.Conn.fetch_query_params(conn)
          assert conn.query_params["start"] == "2024-01-01T00:00:00Z"
          assert conn.query_params["end"] == "2024-01-07T23:59:59Z"

          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(200, Jason.encode!(%{"data" => []}))
        end
      )

      assert {:ok, %{"data" => []}} =
               BambooHR.Scheduling.list_shifts(config,
                 start: ~D[2024-01-01],
                 end: ~D[2024-01-07],
                 schedule_ids: [@schedule_id]
               )
    end

    test "sends nil in the PDF's repeated employee IDs as the open-shift filter", %{
      bypass: bypass,
      config: config
    } do
      Bypass.expect_once(
        bypass,
        "GET",
        "/api/gateway.php/test_company/v1/scheduling/schedules/#{@schedule_id}/pdf",
        fn conn ->
          conn = Plug.Conn.fetch_query_params(conn)
          assert conn.query_params["employeeIds"] == ["123", "null"]

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
                 employee_ids: [123, nil]
               )
    end

    test "does not send a request when a list filter is empty", %{config: config} do
      # No Bypass expectation: a request reaching it would fail the test.
      for opts <- [
            [ids: [], schedule_ids: [@schedule_id]],
            [start: "2024-01-01T00:00:00Z", schedule_ids: [@schedule_id], employee_ids: []],
            [schedule_ids: []],
            [schedule_ids: [@schedule_id], statuses: []]
          ] do
        assert {:error, %BambooHR.Error{reason: :empty_filter, status: nil, message: message}} =
                 BambooHR.Scheduling.list_shifts(config, opts)

        assert message =~ "is an empty list"
      end
    end

    test "names the empty option in the error", %{config: config} do
      assert {:error, %BambooHR.Error{reason: :empty_filter, message: message}} =
               BambooHR.Scheduling.list_shifts(config, employee_ids: [])

      assert message =~ ":employee_ids"
    end

    test "does not render a PDF for an empty employee list", %{config: config} do
      assert {:error, %BambooHR.Error{reason: :empty_filter, message: message}} =
               BambooHR.Scheduling.get_schedule_pdf(
                 config,
                 @schedule_id,
                 "2024-01-01",
                 "2024-01-07",
                 employee_ids: []
               )

      assert message =~ ":employee_ids"
    end

    test "treats a bare nil for employee_ids as no filter", %{bypass: bypass, config: config} do
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
               BambooHR.Scheduling.list_shifts(config,
                 employee_ids: nil,
                 schedule_ids: [@schedule_id]
               )
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

    test "does not retry a failed render by default", %{bypass: bypass, config: config} do
      # Bypass.expect_once fails the test on a second request.
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
                 "2024-01-07"
               )
    end

    test "passes a retry function Req accepts on to Req", %{bypass: bypass, config: config} do
      Bypass.expect_once(
        bypass,
        "GET",
        "/api/gateway.php/test_company/v1/scheduling/schedules/#{@schedule_id}/pdf",
        fn conn -> Plug.Conn.resp(conn, 500, "Failed to render PDF") end
      )

      test_pid = self()

      retry = fn _request, _response ->
        send(test_pid, :retry_called)
        false
      end

      assert {:error, %BambooHR.Error{status: 500}} =
               BambooHR.Scheduling.get_schedule_pdf(
                 config,
                 @schedule_id,
                 "2024-01-01",
                 "2024-01-07",
                 retry: retry
               )

      assert_received :retry_called
    end

    test "ignores a retry value Req does not accept, with a warning", %{
      bypass: bypass,
      config: config
    } do
      Bypass.expect_once(
        bypass,
        "GET",
        "/api/gateway.php/test_company/v1/scheduling/schedules/#{@schedule_id}/pdf",
        fn conn ->
          conn
          |> Plug.Conn.put_resp_header("content-type", "application/pdf")
          |> Plug.Conn.resp(200, "%PDF-")
        end
      )

      log =
        ExUnit.CaptureLog.capture_log(fn ->
          assert {:ok, %{body: "%PDF-"}} =
                   BambooHR.Scheduling.get_schedule_pdf(
                     config,
                     @schedule_id,
                     "2024-01-01",
                     "2024-01-07",
                     retry: true
                   )
        end)

      assert log =~ "ignoring retry: true"
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

      log =
        ExUnit.CaptureLog.capture_log(fn ->
          assert {:ok, %{body: "%PDF-"}} =
                   BambooHR.Scheduling.get_schedule_pdf(
                     config,
                     @schedule_id,
                     "2024-01-01",
                     "2024-01-07",
                     include_holiday: true
                   )
        end)

      assert log =~ "ignoring unknown options [:include_holiday]"
    end

    test "does not let an api_version option through", %{bypass: bypass, config: config} do
      # Client raises on an unknown :api_version, so it is never passed on.
      # The v1 path proves it did not arrive.
      Bypass.expect_once(
        bypass,
        "GET",
        "/api/gateway.php/test_company/v1/scheduling/schedules/#{@schedule_id}/pdf",
        fn conn ->
          conn
          |> Plug.Conn.put_resp_header("content-type", "application/pdf")
          |> Plug.Conn.resp(200, "%PDF-")
        end
      )

      log =
        ExUnit.CaptureLog.capture_log(fn ->
          assert {:ok, %{body: "%PDF-"}} =
                   BambooHR.Scheduling.get_schedule_pdf(
                     config,
                     @schedule_id,
                     "2024-01-01",
                     "2024-01-07",
                     api_version: "v2"
                   )
        end)

      assert log =~ "ignoring unknown options [:api_version]"
    end

    defmodule CaptureRetry do
      @behaviour BambooHR.HTTPClient

      @impl true
      def request(opts) do
        send(self(), {:retry_opt, Keyword.fetch(opts, :retry)})
        {:ok, %{body: "%PDF-", headers: %{}}}
      end
    end

    test "forwards the caller's retry value, and :unprocessed without one" do
      config =
        BambooHR.Client.new(
          company_domain: "test_company",
          api_key: "test_key",
          http_client: CaptureRetry
        )

      BambooHR.Scheduling.get_schedule_pdf(config, @schedule_id, "2024-01-01", "2024-01-07")
      assert_received {:retry_opt, {:ok, :unprocessed}}

      for retry <- [false, :safe_transient, :transient, :unprocessed] do
        BambooHR.Scheduling.get_schedule_pdf(config, @schedule_id, "2024-01-01", "2024-01-07",
          retry: retry
        )

        assert_received {:retry_opt, {:ok, ^retry}}
      end

      BambooHR.Scheduling.get_schedule_pdf(config, @schedule_id, "2024-01-01", "2024-01-07",
        retry: nil
      )

      assert_received {:retry_opt, {:ok, :unprocessed}}
    end

    test "hands Req a retry function that cannot raise or return junk" do
      config =
        BambooHR.Client.new(
          company_domain: "test_company",
          api_key: "test_key",
          http_client: CaptureRetry
        )

      wrapped = fn retry ->
        BambooHR.Scheduling.get_schedule_pdf(config, @schedule_id, "2024-01-01", "2024-01-07",
          retry: retry
        )

        assert_received {:retry_opt, {:ok, wrapped}}
        wrapped
      end

      assert wrapped.(fn _request, _response -> true end).(:request, :response) == true
      assert wrapped.(fn _request, _response -> nil end).(:request, :response) == false

      log =
        ExUnit.CaptureLog.capture_log(fn ->
          thrower = wrapped.(fn _request, _response -> throw(:stop) end)
          assert thrower.(:request, :response) == false

          negative = wrapped.(fn _request, _response -> {:delay, -1} end)
          assert negative.(:request, :response) == false
        end)

      assert log =~ "the :retry function throw :stop"
      assert log =~ "the :retry function returned {:delay, -1}"
    end

    test "retries a rate-limited render by default", %{bypass: bypass, config: config} do
      counter = :counters.new(1, [])

      Bypass.expect(
        bypass,
        "GET",
        "/api/gateway.php/test_company/v1/scheduling/schedules/#{@schedule_id}/pdf",
        fn conn ->
          :counters.add(counter, 1, 1)

          case :counters.get(counter, 1) do
            1 ->
              conn
              |> Plug.Conn.put_resp_header("retry-after", "0")
              |> Plug.Conn.resp(429, "")

            _ ->
              conn
              |> Plug.Conn.put_resp_header("content-type", "application/pdf")
              |> Plug.Conn.resp(200, "%PDF-")
          end
        end
      )

      # Req logs each retry.
      ExUnit.CaptureLog.capture_log(fn ->
        assert {:ok, %{body: "%PDF-"}} =
                 BambooHR.Scheduling.get_schedule_pdf(
                   config,
                   @schedule_id,
                   "2024-01-01",
                   "2024-01-07"
                 )
      end)

      assert :counters.get(counter, 1) == 2
    end

    test "does not retry at all with retry: false", %{bypass: bypass, config: config} do
      # Bypass.expect_once fails the test on a second request. A 429 is
      # retried by default, so one request proves `retry: false` arrived.
      Bypass.expect_once(
        bypass,
        "GET",
        "/api/gateway.php/test_company/v1/scheduling/schedules/#{@schedule_id}/pdf",
        fn conn ->
          conn
          |> Plug.Conn.put_resp_header("retry-after", "0")
          |> Plug.Conn.resp(429, "")
        end
      )

      assert {:error, %BambooHR.Error{reason: :rate_limited}} =
               BambooHR.Scheduling.get_schedule_pdf(
                 config,
                 @schedule_id,
                 "2024-01-01",
                 "2024-01-07",
                 retry: false
               )
    end

    test "reads a bad result from a retry function as no retry", %{
      bypass: bypass,
      config: config
    } do
      Bypass.expect_once(
        bypass,
        "GET",
        "/api/gateway.php/test_company/v1/scheduling/schedules/#{@schedule_id}/pdf",
        fn conn -> Plug.Conn.resp(conn, 500, "Failed to render PDF") end
      )

      # Req has no clause for an integer here and would raise.
      log =
        ExUnit.CaptureLog.capture_log(fn ->
          assert {:error, %BambooHR.Error{status: 500}} =
                   BambooHR.Scheduling.get_schedule_pdf(
                     config,
                     @schedule_id,
                     "2024-01-01",
                     "2024-01-07",
                     retry: fn _request, response -> response.status end
                   )
        end)

      assert log =~ "the :retry function returned 500"
    end

    test "reads a retry function that raises as no retry", %{bypass: bypass, config: config} do
      Bypass.expect_once(
        bypass,
        "GET",
        "/api/gateway.php/test_company/v1/scheduling/schedules/#{@schedule_id}/pdf",
        fn conn -> Plug.Conn.resp(conn, 500, "Failed to render PDF") end
      )

      log =
        ExUnit.CaptureLog.capture_log(fn ->
          assert {:error, %BambooHR.Error{status: 500}} =
                   BambooHR.Scheduling.get_schedule_pdf(
                     config,
                     @schedule_id,
                     "2024-01-01",
                     "2024-01-07",
                     retry: fn _request, _response -> raise "boom" end
                   )
        end)

      assert log =~ "the :retry function raised boom"
    end

    test "passes a delay from a retry function on to Req", %{bypass: bypass, config: config} do
      counter = :counters.new(1, [])

      Bypass.expect(
        bypass,
        "GET",
        "/api/gateway.php/test_company/v1/scheduling/schedules/#{@schedule_id}/pdf",
        fn conn ->
          :counters.add(counter, 1, 1)

          case :counters.get(counter, 1) do
            1 ->
              Plug.Conn.resp(conn, 500, "Failed to render PDF")

            _ ->
              conn
              |> Plug.Conn.put_resp_header("content-type", "application/pdf")
              |> Plug.Conn.resp(200, "%PDF-")
          end
        end
      )

      ExUnit.CaptureLog.capture_log(fn ->
        assert {:ok, %{body: "%PDF-"}} =
                 BambooHR.Scheduling.get_schedule_pdf(
                   config,
                   @schedule_id,
                   "2024-01-01",
                   "2024-01-07",
                   # Req asks about every response, the 200 included.
                   retry: fn
                     _request, %{status: 500} -> {:delay, 0}
                     _request, _response -> false
                   end
                 )
      end)

      assert :counters.get(counter, 1) == 2
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

  describe "IDs in the request path" do
    test "keeps an ID with reserved characters to one path segment", %{
      bypass: bypass,
      config: config
    } do
      test_pid = self()

      Bypass.expect(bypass, fn conn ->
        send(test_pid, {:request, conn.method, conn.request_path, conn.query_string})
        Plug.Conn.resp(conn, 204, "")
      end)

      prefix = "/api/gateway.php/test_company/v1/scheduling"

      BambooHR.Scheduling.delete_shift(config, "abc?recurrenceEditOption=all")
      assert_received {:request, "DELETE", path, ""}
      assert path == prefix <> "/shifts/abc%3FrecurrenceEditOption%3Dall"

      BambooHR.Scheduling.get_schedule(config, "x/pdf")
      assert_received {:request, "GET", path, ""}
      assert path == prefix <> "/schedules/x%2Fpdf"

      BambooHR.Scheduling.get_shift(config, "a#b")
      assert_received {:request, "GET", path, ""}
      assert path == prefix <> "/shifts/a%23b"
    end

    test "leaves a UUID and a composite recurrence ID as they are", %{
      bypass: bypass,
      config: config
    } do
      composite = "3fa85f64-5717-4562-b3fc-2c963f66afa6_20240101T093000"

      Bypass.expect_once(
        bypass,
        "GET",
        "/api/gateway.php/test_company/v1/scheduling/shifts/#{composite}",
        fn conn ->
          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(200, Jason.encode!(%{"id" => composite}))
        end
      )

      assert {:ok, %{"id" => ^composite}} = BambooHR.Scheduling.get_shift(config, composite)
    end
  end

  describe "options that are not a keyword list" do
    test "reads a map, and nil, without raising", %{bypass: bypass, config: config} do
      Bypass.expect(
        bypass,
        "GET",
        "/api/gateway.php/test_company/v1/scheduling/shifts",
        fn conn ->
          conn = Plug.Conn.fetch_query_params(conn)

          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(200, Jason.encode!(%{"data" => [], "query" => conn.query_params}))
        end
      )

      assert {:ok,
              %{"query" => %{"scheduleIds" => @schedule_id, "end" => "2024-01-07T23:59:59Z"}}} =
               BambooHR.Scheduling.list_shifts(config, %{
                 schedule_ids: [@schedule_id],
                 end: ~D[2024-01-07]
               })

      assert {:ok, %{"query" => query}} = BambooHR.Scheduling.list_shifts(config, nil)
      assert query == %{}
    end

    test "reads a map for the PDF options", %{bypass: bypass, config: config} do
      Bypass.expect_once(
        bypass,
        "GET",
        "/api/gateway.php/test_company/v1/scheduling/schedules/#{@schedule_id}/pdf",
        fn conn ->
          conn = Plug.Conn.fetch_query_params(conn)
          assert conn.query_params["includeHolidays"] == "true"

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
                 %{include_holidays: true, retry: false}
               )
    end
  end
end
