defmodule BambooHR.WebhooksTest do
  use BambooHR.BypassCase, async: true

  describe "list/1" do
    test "successfully lists webhooks", %{bypass: bypass, config: config} do
      webhooks_data = %{
        "webhooks" => [
          %{
            "id" => "1",
            "name" => "Payroll sync",
            "url" => "https://example.com/hooks/bamboo",
            "created" => "2024-01-15 09:30:00",
            "lastSent" => "2024-02-01 11:05:12"
          }
        ]
      }

      Bypass.expect_once(bypass, "GET", "/api/gateway.php/test_company/v1/webhooks", fn conn ->
        conn
        |> Plug.Conn.put_resp_header("content-type", "application/json")
        |> Plug.Conn.resp(200, Jason.encode!(webhooks_data))
      end)

      assert {:ok, ^webhooks_data} = BambooHR.Webhooks.list(config)
    end

    test "handles error response", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/api/gateway.php/test_company/v1/webhooks", fn conn ->
        Plug.Conn.resp(conn, 401, "")
      end)

      assert {:error, %{status: 401}} = BambooHR.Webhooks.list(config)
    end
  end

  describe "get/2" do
    test "successfully retrieves a webhook", %{bypass: bypass, config: config} do
      webhook_data = %{
        "id" => "1",
        "name" => "Payroll sync",
        "url" => "https://example.com/hooks/bamboo",
        "format" => "json",
        "monitorFields" => ["firstName", "lastName"],
        "events" => ["employee_with_fields.updated"]
      }

      Bypass.expect_once(bypass, "GET", "/api/gateway.php/test_company/v1/webhooks/1", fn conn ->
        conn
        |> Plug.Conn.put_resp_header("content-type", "application/json")
        |> Plug.Conn.resp(200, Jason.encode!(webhook_data))
      end)

      assert {:ok, ^webhook_data} = BambooHR.Webhooks.get(config, 1)
    end

    test "handles a webhook owned by another user", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/api/gateway.php/test_company/v1/webhooks/2", fn conn ->
        Plug.Conn.resp(conn, 403, "")
      end)

      assert {:error, %{status: 403}} = BambooHR.Webhooks.get(config, 2)
    end
  end

  describe "create/2" do
    test "successfully creates a webhook", %{bypass: bypass, config: config} do
      webhook_data = %{
        "name" => "Payroll sync",
        "url" => "https://example.com/hooks/bamboo",
        "format" => "json",
        "monitorFields" => ["firstName", "lastName"]
      }

      response_data = %{"id" => "4", "name" => "Payroll sync", "privateKey" => "abc123"}

      Bypass.expect_once(bypass, "POST", "/api/gateway.php/test_company/v1/webhooks", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        assert Jason.decode!(body) == webhook_data

        conn
        |> Plug.Conn.put_resp_header("content-type", "application/json")
        |> Plug.Conn.resp(201, Jason.encode!(response_data))
      end)

      assert {:ok, ^response_data} = BambooHR.Webhooks.create(config, webhook_data)
    end

    test "handles validation error", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "POST", "/api/gateway.php/test_company/v1/webhooks", fn conn ->
        Plug.Conn.resp(conn, 400, "")
      end)

      assert {:error, %{status: 400}} = BambooHR.Webhooks.create(config, %{"name" => "Broken"})
    end
  end

  describe "update/3" do
    test "successfully replaces a webhook", %{bypass: bypass, config: config} do
      webhook_data = %{
        "name" => "Payroll sync",
        "url" => "https://example.com/hooks/v2",
        "format" => "json",
        "monitorFields" => ["firstName", "lastName"]
      }

      response_data = %{"id" => "1", "url" => "https://example.com/hooks/v2"}

      Bypass.expect_once(bypass, "PUT", "/api/gateway.php/test_company/v1/webhooks/1", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        assert Jason.decode!(body) == webhook_data

        conn
        |> Plug.Conn.put_resp_header("content-type", "application/json")
        |> Plug.Conn.resp(200, Jason.encode!(response_data))
      end)

      assert {:ok, ^response_data} = BambooHR.Webhooks.update(config, 1, webhook_data)
    end
  end

  describe "delete/2" do
    test "successfully deletes a webhook", %{bypass: bypass, config: config} do
      Bypass.expect_once(
        bypass,
        "DELETE",
        "/api/gateway.php/test_company/v1/webhooks/1",
        fn conn -> Plug.Conn.resp(conn, 200, "") end
      )

      assert {:ok, nil} = BambooHR.Webhooks.delete(config, 1)
    end

    test "handles a webhook owned by another user", %{bypass: bypass, config: config} do
      Bypass.expect_once(
        bypass,
        "DELETE",
        "/api/gateway.php/test_company/v1/webhooks/2",
        fn conn -> Plug.Conn.resp(conn, 403, "") end
      )

      assert {:error, %{status: 403}} = BambooHR.Webhooks.delete(config, 2)
    end
  end

  describe "list_logs/2" do
    test "successfully lists delivery logs", %{bypass: bypass, config: config} do
      logs_data = [
        %{
          "webhookId" => "1",
          "url" => "https://example.com/hooks/bamboo",
          "lastAttempted" => "2024-02-01 11:05:12",
          "lastSuccess" => "2024-02-01 11:05:12"
        }
      ]

      Bypass.expect_once(
        bypass,
        "GET",
        "/api/gateway.php/test_company/v1/webhooks/1/log",
        fn conn ->
          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(200, Jason.encode!(logs_data))
        end
      )

      assert {:ok, ^logs_data} = BambooHR.Webhooks.list_logs(config, 1)
    end
  end

  describe "list_monitor_fields/1" do
    test "successfully lists monitorable fields", %{bypass: bypass, config: config} do
      fields_data = %{"fields" => [%{"id" => "firstName", "name" => "First Name"}]}

      Bypass.expect_once(
        bypass,
        "GET",
        "/api/gateway.php/test_company/v1/webhooks/monitor_fields",
        fn conn ->
          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(200, Jason.encode!(fields_data))
        end
      )

      assert {:ok, ^fields_data} = BambooHR.Webhooks.list_monitor_fields(config)
    end
  end

  describe "verify_signature/4" do
    # Fixture generated independently of the implementation:
    #   python3 -c "import hmac,hashlib; print(hmac.new(b'private-key-123',
    #     b'{\"employees\":[{\"id\":\"123\"}]}' + b'2024-02-01T11:05:12Z',
    #     hashlib.sha256).hexdigest())"
    @payload ~s({"employees":[{"id":"123"}]})
    @timestamp "2024-02-01T11:05:12Z"
    @private_key "private-key-123"
    @signature "2e5fcc0ed9bfc4b23327543cafb3f59a552b8f8039e0ad24f6b86498f3557801"

    test "accepts a signature from BambooHR" do
      assert BambooHR.Webhooks.verify_signature(
               @payload,
               @signature,
               @timestamp,
               @private_key
             )
    end

    test "accepts an uppercase hex signature" do
      assert BambooHR.Webhooks.verify_signature(
               @payload,
               String.upcase(@signature),
               @timestamp,
               @private_key
             )
    end

    test "rejects a signature made with a different key" do
      wrong = "03a85ecc4d852d241ff09566d0b3ef53e091c6b131d819248b85d0fa69ade0f9"

      refute BambooHR.Webhooks.verify_signature(@payload, wrong, @timestamp, @private_key)
    end

    test "rejects a tampered payload" do
      refute BambooHR.Webhooks.verify_signature(
               ~s({"employees":[{"id":"456"}]}),
               @signature,
               @timestamp,
               @private_key
             )
    end

    test "rejects a replayed signature under a different timestamp" do
      refute BambooHR.Webhooks.verify_signature(
               @payload,
               @signature,
               "2024-02-01T11:05:13Z",
               @private_key
             )
    end

    test "rejects a signature of the wrong length without raising" do
      refute BambooHR.Webhooks.verify_signature(@payload, "abc123", @timestamp, @private_key)
    end

    test "rejects missing headers without raising" do
      refute BambooHR.Webhooks.verify_signature(@payload, nil, @timestamp, @private_key)
      refute BambooHR.Webhooks.verify_signature(@payload, @signature, nil, @private_key)
      refute BambooHR.Webhooks.verify_signature(nil, @signature, @timestamp, @private_key)
      refute BambooHR.Webhooks.verify_signature(@payload, @signature, @timestamp, nil)
    end
  end

  describe "get_post_fields/1" do
    test "successfully retrieves post fields", %{bypass: bypass, config: config} do
      fields_data = %{"fields" => [%{"id" => "firstName", "name" => "First Name"}]}

      Bypass.expect_once(
        bypass,
        "GET",
        "/api/gateway.php/test_company/v1/webhooks/post-fields",
        fn conn ->
          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(200, Jason.encode!(fields_data))
        end
      )

      assert {:ok, ^fields_data} = BambooHR.Webhooks.get_post_fields(config)
    end
  end
end
