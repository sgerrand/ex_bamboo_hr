defmodule BambooHR.HTTPClient.ReqTest do
  use BambooHR.BypassCase, async: true

  alias BambooHR.HTTPClient.Req, as: ReqClient

  describe "retry?/2" do
    test "retries any method on 429" do
      get_req = %Req.Request{method: :get}
      post_req = %Req.Request{method: :post}
      response_429 = %Req.Response{status: 429}

      assert ReqClient.retry?(get_req, response_429)
      assert ReqClient.retry?(post_req, response_429)
    end

    test "retries GET/HEAD on transient 5xx statuses" do
      for status <- [408, 500, 502, 503, 504] do
        assert ReqClient.retry?(%Req.Request{method: :get}, %Req.Response{status: status}),
               "expected GET retry on status #{status}"
      end
    end

    test "does not retry POST on 5xx" do
      refute ReqClient.retry?(%Req.Request{method: :post}, %Req.Response{status: 500})
      refute ReqClient.retry?(%Req.Request{method: :post}, %Req.Response{status: 503})
    end

    test "retries GET on transient transport errors" do
      for reason <- [:timeout, :econnrefused, :closed] do
        err = %Req.TransportError{reason: reason}
        assert ReqClient.retry?(%Req.Request{method: :get}, err)
      end
    end

    test "retries any method on the HTTP/2 errors that mean the request was never sent" do
      for method <- [:get, :post], reason <- [:unprocessed, :pool_not_available] do
        assert ReqClient.retry?(
                 %Req.Request{method: method},
                 %Req.HTTPError{protocol: :http2, reason: reason}
               ),
               "expected a #{method} retry on #{reason}"
      end
    end

    test "does not retry POST on transport errors" do
      err = %Req.TransportError{reason: :timeout}
      refute ReqClient.retry?(%Req.Request{method: :post}, err)
    end

    test "does not retry on non-transient statuses" do
      refute ReqClient.retry?(%Req.Request{method: :get}, %Req.Response{status: 400})
      refute ReqClient.retry?(%Req.Request{method: :get}, %Req.Response{status: 404})
    end
  end

  describe "retry_unprocessed?/2" do
    test "retries a 429 and a refused connection" do
      request = %Req.Request{method: :get}

      assert ReqClient.retry_unprocessed?(request, %Req.Response{status: 429})
      assert ReqClient.retry_unprocessed?(request, %Req.TransportError{reason: :econnrefused})
    end

    test "retries a host name that did not resolve" do
      assert ReqClient.retry_unprocessed?(
               %Req.Request{method: :get},
               %Req.TransportError{reason: :nxdomain}
             )
    end

    test "retries the HTTP/2 errors that mean the request was never sent" do
      request = %Req.Request{method: :get}

      for reason <- [:unprocessed, :pool_not_available] do
        assert ReqClient.retry_unprocessed?(
                 request,
                 %Req.HTTPError{protocol: :http2, reason: reason}
               ),
               "expected a retry on #{reason}"
      end

      refute ReqClient.retry_unprocessed?(
               request,
               %Req.HTTPError{protocol: :http2, reason: :closed}
             )
    end

    test "does not retry anything BambooHR may have started work on" do
      request = %Req.Request{method: :get}

      for status <- [408, 500, 502, 503, 504] do
        refute ReqClient.retry_unprocessed?(request, %Req.Response{status: status}),
               "expected no retry on status #{status}"
      end

      for reason <- [:timeout, :closed] do
        refute ReqClient.retry_unprocessed?(request, %Req.TransportError{reason: reason}),
               "expected no retry on #{reason}"
      end
    end
  end

  describe "request/1 retry behaviour" do
    test "retry_unprocessed?/2 does not retry a GET on 500", %{bypass: bypass, config: config} do
      # The default policy would retry this GET; expect_once fails the test
      # on a second request.
      Bypass.expect_once(bypass, "GET", "/api/gateway.php/test_company/v1/path", fn conn ->
        Plug.Conn.resp(conn, 500, "")
      end)

      assert {:error, %BambooHR.Error{status: 500}} =
               BambooHR.Client.get("/path", config, retry: &ReqClient.retry_unprocessed?/2)
    end

    test "retry_unprocessed?/2 retries a 429", %{bypass: bypass, config: config} do
      counter = :counters.new(1, [])

      Bypass.expect(bypass, "GET", "/api/gateway.php/test_company/v1/path", fn conn ->
        :counters.add(counter, 1, 1)

        case :counters.get(counter, 1) do
          1 ->
            conn
            |> Plug.Conn.put_resp_header("retry-after", "0")
            |> Plug.Conn.resp(429, "")

          _ ->
            conn
            |> Plug.Conn.put_resp_header("content-type", "application/json")
            |> Plug.Conn.resp(200, Jason.encode!(%{"ok" => true}))
        end
      end)

      assert {:ok, %{"ok" => true}} =
               BambooHR.Client.get("/path", config,
                 retry: &ReqClient.retry_unprocessed?/2,
                 retry_delay: 0,
                 retry_log_level: false
               )

      assert :counters.get(counter, 1) == 2
    end

    test "retries POST on 429 then succeeds", %{bypass: bypass, config: config} do
      counter = :counters.new(1, [])

      Bypass.expect(bypass, "POST", "/api/gateway.php/test_company/v1/path", fn conn ->
        :counters.add(counter, 1, 1)

        case :counters.get(counter, 1) do
          1 ->
            conn
            |> Plug.Conn.put_resp_header("retry-after", "0")
            |> Plug.Conn.resp(429, "")

          _ ->
            conn
            |> Plug.Conn.put_resp_header("content-type", "application/json")
            |> Plug.Conn.resp(200, Jason.encode!(%{"ok" => true}))
        end
      end)

      assert {:ok, %{"ok" => true}} =
               BambooHR.Client.post("/path", config,
                 json: %{},
                 retry_delay: 0,
                 retry_log_level: false
               )

      assert :counters.get(counter, 1) == 2
    end

    test "does not retry POST on 500", %{bypass: bypass, config: config} do
      counter = :counters.new(1, [])

      Bypass.expect(bypass, "POST", "/api/gateway.php/test_company/v1/path", fn conn ->
        :counters.add(counter, 1, 1)

        conn
        |> Plug.Conn.put_resp_header("content-type", "application/json")
        |> Plug.Conn.resp(500, Jason.encode!(%{"error" => "boom"}))
      end)

      assert {:error, %{status: 500}} =
               BambooHR.Client.post("/path", config,
                 json: %{},
                 retry_delay: 0,
                 retry_log_level: false
               )

      assert :counters.get(counter, 1) == 1
    end

    test "retries GET on 500 then succeeds", %{bypass: bypass, config: config} do
      counter = :counters.new(1, [])

      Bypass.expect(bypass, "GET", "/api/gateway.php/test_company/v1/path", fn conn ->
        :counters.add(counter, 1, 1)

        case :counters.get(counter, 1) do
          1 ->
            Plug.Conn.resp(conn, 500, "")

          _ ->
            conn
            |> Plug.Conn.put_resp_header("content-type", "application/json")
            |> Plug.Conn.resp(200, Jason.encode!(%{"ok" => true}))
        end
      end)

      assert {:ok, %{"ok" => true}} =
               BambooHR.Client.get("/path", config, retry_delay: 0, retry_log_level: false)

      assert :counters.get(counter, 1) == 2
    end

    test "caller can disable retry via retry: false", %{bypass: bypass, config: config} do
      counter = :counters.new(1, [])

      Bypass.expect(bypass, "GET", "/api/gateway.php/test_company/v1/path", fn conn ->
        :counters.add(counter, 1, 1)

        conn
        |> Plug.Conn.put_resp_header("retry-after", "0")
        |> Plug.Conn.resp(429, "")
      end)

      assert {:error, %{status: 429}} = BambooHR.Client.get("/path", config, retry: false)

      assert :counters.get(counter, 1) == 1
    end

    test "uses its own policy for retry: nil", %{bypass: bypass, config: config} do
      counter = :counters.new(1, [])

      Bypass.expect(bypass, "GET", "/api/gateway.php/test_company/v1/path", fn conn ->
        :counters.add(counter, 1, 1)
        Plug.Conn.resp(conn, 500, "")
      end)

      assert {:error, %{status: 500}} =
               BambooHR.Client.get("/path", config,
                 retry: nil,
                 retry_delay: 0,
                 max_retries: 1,
                 retry_log_level: false
               )

      assert :counters.get(counter, 1) == 2
    end

    test "does not retry or raise on a retry value Req does not accept", %{
      bypass: bypass,
      config: config
    } do
      # Req would raise on these, but only after the response is in.
      for retry <- [true, :never, "false"] do
        Bypass.expect_once(bypass, "GET", "/api/gateway.php/test_company/v1/path", fn conn ->
          Plug.Conn.resp(conn, 500, "")
        end)

        log =
          ExUnit.CaptureLog.capture_log(fn ->
            assert {:error, %{status: 500}} = BambooHR.Client.get("/path", config, retry: retry)
          end)

        assert log =~ "ignoring retry: #{inspect(retry)}"
      end
    end

    test "reads a retry function's bad result, or a raise, as no retry", %{
      bypass: bypass,
      config: config
    } do
      bad = [
        {fn _request, _response -> :maybe end, "returned :maybe"},
        {fn _request, _response -> {:delay, -1} end, "returned {:delay, -1}"},
        {fn _request, _response -> raise "boom" end, "raised boom"},
        {fn _request, _response -> throw(:stop) end, "throw :stop"}
      ]

      for {retry, logged} <- bad do
        Bypass.expect_once(bypass, "GET", "/api/gateway.php/test_company/v1/path", fn conn ->
          Plug.Conn.resp(conn, 500, "")
        end)

        log =
          ExUnit.CaptureLog.capture_log(fn ->
            assert {:error, %{status: 500}} = BambooHR.Client.get("/path", config, retry: retry)
          end)

        assert log =~ "the :retry function #{logged}"
      end
    end

    test "reads nil from a retry function as no retry, quietly", %{
      bypass: bypass,
      config: config
    } do
      Bypass.expect_once(bypass, "GET", "/api/gateway.php/test_company/v1/path", fn conn ->
        Plug.Conn.resp(conn, 500, "")
      end)

      log =
        ExUnit.CaptureLog.capture_log(fn ->
          assert {:error, %{status: 500}} =
                   BambooHR.Client.get("/path", config, retry: fn _request, _response -> nil end)
        end)

      refute log =~ ":retry function"
    end

    test "lets :retry_delay decide the wait when a retry function returns a delay", %{
      bypass: bypass,
      config: config
    } do
      counter = :counters.new(1, [])

      Bypass.expect(bypass, "GET", "/api/gateway.php/test_company/v1/path", fn conn ->
        :counters.add(counter, 1, 1)

        case :counters.get(counter, 1) do
          1 -> Plug.Conn.resp(conn, 500, "")
          _ -> Plug.Conn.resp(conn, 200, "{}")
        end
      end)

      # Req raises when both are set.
      assert {:ok, %{}} =
               BambooHR.Client.get("/path", config,
                 retry: fn
                   _request, %{status: 500} -> {:delay, 60_000}
                   _request, _response -> false
                 end,
                 retry_delay: 0,
                 retry_log_level: false
               )

      assert :counters.get(counter, 1) == 2
    end
  end

  describe "request/1 decode errors" do
    test "keeps the request ID when a 2xx body is not valid JSON", %{
      bypass: bypass,
      config: config
    } do
      Bypass.expect_once(bypass, "GET", "/api/gateway.php/test_company/v1/thing", fn conn ->
        conn
        |> Plug.Conn.put_resp_header("content-type", "application/json")
        |> Plug.Conn.put_resp_header("x-request-id", "req-123")
        |> Plug.Conn.resp(200, "not json")
      end)

      assert {:error, %BambooHR.Error{reason: :decode_error, request_id: "req-123"}} =
               BambooHR.Client.get("/thing", config)
    end
  end

  describe "request/1 decode errors with a non-200 status" do
    test "keeps the real 2xx status", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "POST", "/api/gateway.php/test_company/v1/thing", fn conn ->
        conn
        |> Plug.Conn.put_resp_header("content-type", "application/json")
        |> Plug.Conn.resp(201, "not json")
      end)

      assert {:error, %BambooHR.Error{reason: :decode_error, status: 201}} =
               BambooHR.Client.post("/thing", config, json: %{})
    end
  end

  describe "request/1 raw_response and expose_headers" do
    test "raw_response: true skips JSON decoding", %{bypass: bypass, config: config} do
      binary_content = <<0xFF, 0xD8, 0xFF, 0xE0>>

      Bypass.expect_once(bypass, "GET", "/api/gateway.php/test_company/v1/file", fn conn ->
        conn
        |> Plug.Conn.put_resp_header("content-type", "application/octet-stream")
        |> Plug.Conn.resp(200, binary_content)
      end)

      assert {:ok, ^binary_content} =
               BambooHR.Client.get("/file", config, raw_response: true)
    end

    test "raw_response and expose_headers compose", %{bypass: bypass, config: config} do
      binary_content = <<0xFF, 0xD8, 0xFF, 0xE0>>

      Bypass.expect_once(bypass, "GET", "/api/gateway.php/test_company/v1/file", fn conn ->
        conn
        |> Plug.Conn.put_resp_header("content-disposition", ~s(attachment; filename="a.jpg"))
        |> Plug.Conn.resp(200, binary_content)
      end)

      assert {:ok, %{body: ^binary_content, headers: headers}} =
               BambooHR.Client.get("/file", config, raw_response: true, expose_headers: true)

      assert headers["content-disposition"] == [~s(attachment; filename="a.jpg")]
    end

    test "raw_response: true sends Accept: */* instead of application/json", %{
      bypass: bypass,
      config: config
    } do
      Bypass.expect_once(bypass, "GET", "/api/gateway.php/test_company/v1/file", fn conn ->
        assert Plug.Conn.get_req_header(conn, "accept") == ["*/*"]
        Plug.Conn.resp(conn, 200, <<1, 2, 3>>)
      end)

      assert {:ok, _} = BambooHR.Client.get("/file", config, raw_response: true)
    end

    test "without raw_response, Accept stays application/json", %{
      bypass: bypass,
      config: config
    } do
      Bypass.expect_once(bypass, "GET", "/api/gateway.php/test_company/v1/file", fn conn ->
        assert Plug.Conn.get_req_header(conn, "accept") == ["application/json"]

        conn
        |> Plug.Conn.put_resp_header("content-type", "application/json")
        |> Plug.Conn.resp(200, "{}")
      end)

      assert {:ok, %{}} = BambooHR.Client.get("/file", config)
    end
  end
end
