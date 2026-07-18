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

    test "does not retry POST on transport errors" do
      err = %Req.TransportError{reason: :timeout}
      refute ReqClient.retry?(%Req.Request{method: :post}, err)
    end

    test "does not retry on non-transient statuses" do
      refute ReqClient.retry?(%Req.Request{method: :get}, %Req.Response{status: 400})
      refute ReqClient.retry?(%Req.Request{method: :get}, %Req.Response{status: 404})
    end
  end

  describe "request/1 retry behaviour" do
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
