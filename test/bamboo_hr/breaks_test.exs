defmodule BambooHR.BreaksTest do
  use BambooHR.BypassCase, async: true

  describe "break policies" do
    test "lists policies with counts", %{bypass: bypass, config: config} do
      Bypass.expect_once(
        bypass,
        "GET",
        "/api/gateway.php/test_company/v1/time-tracking/break-policies",
        fn conn ->
          conn = Plug.Conn.fetch_query_params(conn)
          assert conn.query_params == %{"includeCounts" => "true", "limit" => "10"}

          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(200, Jason.encode!(%{"data" => [%{"id" => "0f8c1c2e"}]}))
        end
      )

      assert {:ok, %{"data" => [%{"id" => "0f8c1c2e"}]}} =
               BambooHR.Breaks.list_policies(config, include_counts: true, limit: 10)
    end

    test "creates a policy", %{bypass: bypass, config: config} do
      Bypass.expect_once(
        bypass,
        "POST",
        "/api/gateway.php/test_company/v1/time-tracking/break-policies",
        fn conn ->
          {:ok, body, conn} = Plug.Conn.read_body(conn)
          assert Jason.decode!(body) == %{"name" => "California meal breaks"}

          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(201, Jason.encode!(%{"id" => "0f8c1c2e"}))
        end
      )

      assert {:ok, %{"id" => "0f8c1c2e"}} =
               BambooHR.Breaks.create_policy(config, %{"name" => "California meal breaks"})
    end

    test "retrieves a policy", %{bypass: bypass, config: config} do
      Bypass.expect_once(
        bypass,
        "GET",
        "/api/gateway.php/test_company/v1/time-tracking/break-policies/0f8c1c2e",
        fn conn ->
          conn = Plug.Conn.fetch_query_params(conn)
          assert conn.query_params == %{}

          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(200, Jason.encode!(%{"id" => "0f8c1c2e"}))
        end
      )

      assert {:ok, %{"id" => "0f8c1c2e"}} = BambooHR.Breaks.get_policy(config, "0f8c1c2e")
    end

    test "updates a policy", %{bypass: bypass, config: config} do
      Bypass.expect_once(
        bypass,
        "PATCH",
        "/api/gateway.php/test_company/v1/time-tracking/break-policies/0f8c1c2e",
        fn conn ->
          {:ok, body, conn} = Plug.Conn.read_body(conn)
          assert Jason.decode!(body) == %{"description" => "Updated"}

          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(200, Jason.encode!(%{"description" => "Updated"}))
        end
      )

      assert {:ok, %{"description" => "Updated"}} =
               BambooHR.Breaks.update_policy(config, "0f8c1c2e", %{"description" => "Updated"})
    end

    test "syncs a policy", %{bypass: bypass, config: config} do
      Bypass.expect_once(
        bypass,
        "PUT",
        "/api/gateway.php/test_company/v1/time-tracking/break-policies/0f8c1c2e/sync",
        fn conn ->
          {:ok, body, conn} = Plug.Conn.read_body(conn)
          assert Jason.decode!(body) == %{"name" => "Meal breaks", "employeeIds" => [123]}

          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(200, Jason.encode!(%{"id" => "0f8c1c2e"}))
        end
      )

      assert {:ok, %{"id" => "0f8c1c2e"}} =
               BambooHR.Breaks.sync_policy(config, "0f8c1c2e", %{
                 "name" => "Meal breaks",
                 "employeeIds" => [123]
               })
    end

    test "deletes a policy", %{bypass: bypass, config: config} do
      Bypass.expect_once(
        bypass,
        "DELETE",
        "/api/gateway.php/test_company/v1/time-tracking/break-policies/0f8c1c2e",
        fn conn ->
          Plug.Conn.resp(conn, 204, "")
        end
      )

      assert {:ok, nil} = BambooHR.Breaks.delete_policy(config, "0f8c1c2e")
    end

    test "asks for policy suggestions", %{bypass: bypass, config: config} do
      Bypass.expect_once(
        bypass,
        "POST",
        "/api/gateway.php/test_company/v1/time-tracking/break-policies/suggestions",
        fn conn ->
          {:ok, body, conn} = Plug.Conn.read_body(conn)
          assert Jason.decode!(body) == %{"prompt" => "California retail staff"}

          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(200, Jason.encode!(%{"suggestedPolicies" => []}))
        end
      )

      assert {:ok, %{"suggestedPolicies" => []}} =
               BambooHR.Breaks.get_policy_suggestions(config, "California retail staff")
    end
  end

  describe "breaks" do
    test "lists a policy's breaks", %{bypass: bypass, config: config} do
      Bypass.expect_once(
        bypass,
        "GET",
        "/api/gateway.php/test_company/v1/time-tracking/break-policies/0f8c1c2e/breaks",
        fn conn ->
          conn = Plug.Conn.fetch_query_params(conn)
          assert conn.query_params == %{"offset" => "20", "limit" => "10"}

          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(200, Jason.encode!(%{"data" => []}))
        end
      )

      assert {:ok, %{"data" => []}} =
               BambooHR.Breaks.list_policy_breaks(config, "0f8c1c2e", offset: 20, limit: 10)
    end

    test "creates a break on a policy", %{bypass: bypass, config: config} do
      Bypass.expect_once(
        bypass,
        "POST",
        "/api/gateway.php/test_company/v1/time-tracking/break-policies/0f8c1c2e/breaks",
        fn conn ->
          {:ok, body, conn} = Plug.Conn.read_body(conn)
          assert Jason.decode!(body) == %{"name" => "Meal break", "duration" => 30}

          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(201, Jason.encode!(%{"id" => "7b21aa10"}))
        end
      )

      assert {:ok, %{"id" => "7b21aa10"}} =
               BambooHR.Breaks.create_policy_break(config, "0f8c1c2e", %{
                 "name" => "Meal break",
                 "duration" => 30
               })
    end

    test "replaces a policy's breaks", %{bypass: bypass, config: config} do
      Bypass.expect_once(
        bypass,
        "PUT",
        "/api/gateway.php/test_company/v1/time-tracking/break-policies/0f8c1c2e/breaks",
        fn conn ->
          {:ok, body, conn} = Plug.Conn.read_body(conn)
          assert Jason.decode!(body) == [%{"name" => "Meal break", "duration" => 30}]

          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(200, Jason.encode!([%{"id" => "7b21aa10"}]))
        end
      )

      assert {:ok, [%{"id" => "7b21aa10"}]} =
               BambooHR.Breaks.replace_policy_breaks(config, "0f8c1c2e", [
                 %{"name" => "Meal break", "duration" => 30}
               ])
    end

    test "retrieves a break", %{bypass: bypass, config: config} do
      Bypass.expect_once(
        bypass,
        "GET",
        "/api/gateway.php/test_company/v1/time-tracking/breaks/7b21aa10",
        fn conn ->
          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(200, Jason.encode!(%{"id" => "7b21aa10"}))
        end
      )

      assert {:ok, %{"id" => "7b21aa10"}} = BambooHR.Breaks.get_break(config, "7b21aa10")
    end

    test "updates a break", %{bypass: bypass, config: config} do
      Bypass.expect_once(
        bypass,
        "PATCH",
        "/api/gateway.php/test_company/v1/time-tracking/breaks/7b21aa10",
        fn conn ->
          {:ok, body, conn} = Plug.Conn.read_body(conn)
          assert Jason.decode!(body) == %{"duration" => 45}

          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(200, Jason.encode!(%{"duration" => 45}))
        end
      )

      assert {:ok, %{"duration" => 45}} =
               BambooHR.Breaks.update_break(config, "7b21aa10", %{"duration" => 45})
    end

    test "deletes a break", %{bypass: bypass, config: config} do
      Bypass.expect_once(
        bypass,
        "DELETE",
        "/api/gateway.php/test_company/v1/time-tracking/breaks/7b21aa10",
        fn conn ->
          Plug.Conn.resp(conn, 204, "")
        end
      )

      assert {:ok, nil} = BambooHR.Breaks.delete_break(config, "7b21aa10")
    end
  end

  describe "employee assignments" do
    test "lists a policy's employees", %{bypass: bypass, config: config} do
      Bypass.expect_once(
        bypass,
        "GET",
        "/api/gateway.php/test_company/v1/time-tracking/break-policies/0f8c1c2e/employees",
        fn conn ->
          conn = Plug.Conn.fetch_query_params(conn)
          assert conn.query_params == %{}

          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(200, Jason.encode!(%{"data" => []}))
        end
      )

      assert {:ok, %{"data" => []}} = BambooHR.Breaks.list_policy_employees(config, "0f8c1c2e")
    end

    test "adds employees to a policy", %{bypass: bypass, config: config} do
      Bypass.expect_once(
        bypass,
        "POST",
        "/api/gateway.php/test_company/v1/time-tracking/break-policies/0f8c1c2e/assign",
        fn conn ->
          {:ok, body, conn} = Plug.Conn.read_body(conn)
          assert Jason.decode!(body) == %{"employeeIds" => [123, 124]}

          Plug.Conn.resp(conn, 204, "")
        end
      )

      assert {:ok, nil} = BambooHR.Breaks.assign_employees(config, "0f8c1c2e", [123, 124])
    end

    test "replaces a policy's employees", %{bypass: bypass, config: config} do
      Bypass.expect_once(
        bypass,
        "PUT",
        "/api/gateway.php/test_company/v1/time-tracking/break-policies/0f8c1c2e/assign",
        fn conn ->
          {:ok, body, conn} = Plug.Conn.read_body(conn)
          assert Jason.decode!(body) == %{"employeeIds" => [123]}

          Plug.Conn.resp(conn, 204, "")
        end
      )

      assert {:ok, nil} = BambooHR.Breaks.set_employees(config, "0f8c1c2e", [123])
    end

    test "removes employees from a policy", %{bypass: bypass, config: config} do
      Bypass.expect_once(
        bypass,
        "POST",
        "/api/gateway.php/test_company/v1/time-tracking/break-policies/0f8c1c2e/unassign",
        fn conn ->
          {:ok, body, conn} = Plug.Conn.read_body(conn)
          assert Jason.decode!(body) == %{"employeeIds" => [124]}

          Plug.Conn.resp(conn, 204, "")
        end
      )

      assert {:ok, nil} = BambooHR.Breaks.unassign_employees(config, "0f8c1c2e", [124])
    end

    test "rejects unassigning from an all-employee policy", %{bypass: bypass, config: config} do
      Bypass.expect_once(
        bypass,
        "POST",
        "/api/gateway.php/test_company/v1/time-tracking/break-policies/0f8c1c2e/unassign",
        fn conn ->
          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(422, Jason.encode!(%{}))
        end
      )

      assert {:error, %BambooHR.Error{reason: :unprocessable_entity}} =
               BambooHR.Breaks.unassign_employees(config, "0f8c1c2e", [124])
    end
  end

  describe "employee views and assessments" do
    test "lists an employee's policies", %{bypass: bypass, config: config} do
      Bypass.expect_once(
        bypass,
        "GET",
        "/api/gateway.php/test_company/v1/time-tracking/employees/123/break-policies",
        fn conn ->
          conn = Plug.Conn.fetch_query_params(conn)
          assert conn.query_params == %{}

          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(200, Jason.encode!(%{"data" => []}))
        end
      )

      assert {:ok, %{"data" => []}} = BambooHR.Breaks.list_employee_policies(config, 123)
    end

    for {label, effective} <- [
          string: "2024-01-15T09:30:00",
          naive_date_time: ~N[2024-01-15 09:30:00.123456],
          date_time: DateTime.new!(~D[2024-01-15], ~T[09:30:00], "Etc/UTC"),
          date: ~D[2024-01-15]
        ] do
      test "lists an employee's break availabilities with a #{label} :effective", %{
        bypass: bypass,
        config: config
      } do
        expected =
          if unquote(label) == :date, do: "2024-01-15T00:00:00", else: "2024-01-15T09:30:00"

        Bypass.expect_once(
          bypass,
          "GET",
          "/api/gateway.php/test_company/v1/time-tracking/employees/123/break-availabilities",
          fn conn ->
            conn = Plug.Conn.fetch_query_params(conn)
            assert conn.query_params == %{"effective" => expected}

            conn
            |> Plug.Conn.put_resp_header("content-type", "application/json")
            |> Plug.Conn.resp(200, Jason.encode!([]))
          end
        )

        assert {:ok, []} =
                 BambooHR.Breaks.list_employee_break_availabilities(config, 123,
                   effective: unquote(Macro.escape(effective))
                 )
      end
    end

    test "lists assessments", %{bypass: bypass, config: config} do
      Bypass.expect_once(
        bypass,
        "GET",
        "/api/gateway.php/test_company/v1/time-tracking/break-assessments",
        fn conn ->
          conn = Plug.Conn.fetch_query_params(conn)
          assert conn.query_params == %{"filter" => "employeeId eq 123"}

          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(200, Jason.encode!(%{"data" => []}))
        end
      )

      assert {:ok, %{"data" => []}} =
               BambooHR.Breaks.list_assessments(config, filter: "employeeId eq 123")
    end
  end

  describe "listing without options" do
    test "omits query params entirely", %{bypass: bypass, config: config} do
      for path <- [
            "/time-tracking/break-policies",
            "/time-tracking/break-assessments",
            "/time-tracking/break-policies/0f8c1c2e/breaks",
            "/time-tracking/employees/123/break-availabilities"
          ] do
        Bypass.expect_once(bypass, "GET", "/api/gateway.php/test_company/v1" <> path, fn conn ->
          assert conn.query_string == ""

          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(200, Jason.encode!(%{"data" => []}))
        end)
      end

      assert {:ok, %{"data" => []}} = BambooHR.Breaks.list_policies(config)
      assert {:ok, %{"data" => []}} = BambooHR.Breaks.list_assessments(config)
      assert {:ok, %{"data" => []}} = BambooHR.Breaks.list_policy_breaks(config, "0f8c1c2e")

      assert {:ok, %{"data" => []}} =
               BambooHR.Breaks.list_employee_break_availabilities(config, 123)
    end
  end
end
