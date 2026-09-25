defmodule BambooHR.ErrorTest do
  use ExUnit.Case, async: true

  alias BambooHR.Error

  describe "from_response/3" do
    test "maps known statuses to reasons" do
      for {status, reason} <- [
            {400, :bad_request},
            {401, :unauthorized},
            {403, :forbidden},
            {404, :not_found},
            {406, :not_acceptable},
            {409, :conflict},
            {410, :gone},
            {412, :precondition_failed},
            {415, :unsupported_media_type},
            {422, :unprocessable_entity},
            {429, :rate_limited}
          ] do
        assert %Error{reason: ^reason, status: ^status} = Error.from_response(status, "")
      end
    end

    test "falls back to ranges for other statuses" do
      assert %Error{reason: :client_error} = Error.from_response(418, "")
      assert %Error{reason: :server_error} = Error.from_response(500, "")
      assert %Error{reason: :server_error} = Error.from_response(503, "")
      assert %Error{reason: :http_error} = Error.from_response(302, "")
    end

    test "keeps the raw body" do
      assert %Error{body: ~s({"error":"nope"})} =
               Error.from_response(400, ~s({"error":"nope"}))
    end

    test "picks up BambooHR's diagnostic headers" do
      headers = %{
        "x-bamboohr-error-message" => ["Employee photo not found"],
        "x-request-id" => ["abc-123"]
      }

      assert %Error{message: "Employee photo not found", request_id: "abc-123"} =
               Error.from_response(404, "", headers)
    end

    test "also reads the X-BambooHR-Message spelling" do
      headers = %{"x-bamboohr-message" => ["Directory disabled for this account"]}

      assert %Error{message: "Directory disabled for this account"} =
               Error.from_response(403, "", headers)
    end

    test "accepts a header given as a bare string" do
      assert %Error{request_id: "req-1"} =
               Error.from_response(500, "", %{"x-request-id" => "req-1"})
    end

    test "leaves header fields nil when absent" do
      assert %Error{message: nil, request_id: nil} = Error.from_response(500, "")
    end
  end

  describe "from_exception/1" do
    test "wraps a transport failure" do
      exception = %Req.TransportError{reason: :econnrefused}

      assert %Error{reason: :transport_error, status: nil, exception: ^exception} =
               Error.from_exception(exception)
    end
  end

  describe "from_decode_error/3" do
    test "wraps an undecodable success body" do
      {:error, exception} = Jason.decode("not json")

      assert %Error{reason: :decode_error, status: 200, body: "not json", exception: ^exception} =
               Error.from_decode_error(exception, "not json")
    end
  end

  describe "message/1" do
    test "describes a status error with BambooHR's own message" do
      error =
        Error.from_response(404, "", %{"x-bamboohr-error-message" => ["Employee not found"]})

      assert Exception.message(error) == "BambooHR returned 404 not_found: Employee not found"
    end

    test "falls back to the body when there is no header" do
      error = Error.from_response(400, ~s({"error":"bad"}))

      assert Exception.message(error) == ~s(BambooHR returned 400 bad_request: {"error":"bad"})
    end

    test "says so when there is no detail at all" do
      assert Exception.message(Error.from_response(500, "")) ==
               "BambooHR returned 500 server_error: no further detail"
    end

    test "describes a transport error without a status" do
      error = Error.from_exception(%Req.TransportError{reason: :econnrefused})

      assert Exception.message(error) ==
               "BambooHR request failed (transport_error): connection refused"
    end

    test "includes the request id when present" do
      error = Error.from_response(422, "", %{"x-request-id" => ["req-9"]})

      assert Exception.message(error) =~ "(request id req-9)"
    end
  end

  test "is an exception that can be raised" do
    error = Error.from_response(403, "", %{"x-bamboohr-error-message" => ["Denied"]})

    assert_raise Error, "BambooHR returned 403 forbidden: Denied", fn -> raise error end
  end
end
