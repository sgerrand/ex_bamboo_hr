defmodule BambooHR.Error do
  @moduledoc """
  The error returned by every function in this client.

  A failed call returns `{:error, %BambooHR.Error{}}`, whether the request
  came back with a non-2xx status, never reached BambooHR, or returned a
  body that was not the JSON it claimed to be. Match on `:reason` rather
  than on the status code:

      case BambooHR.Employee.get(client, 123, ["firstName"]) do
        {:ok, employee} -> employee
        {:error, %BambooHR.Error{reason: :not_found}} -> nil
        {:error, %BambooHR.Error{reason: :rate_limited}} -> retry_later()
        {:error, error} -> Logger.error(Exception.message(error))
      end

  ## Fields

    * `:reason` - What went wrong, as an atom. See "Reasons" below.
    * `:status` - HTTP status, or `nil` when the request never got a
      response.
    * `:body` - Raw response body, undecoded. `nil` for transport
      failures.
    * `:message` - BambooHR's own description of the failure, from the
      `x-bamboohr-error-message` or `X-BambooHR-Message` header. These
      distinguish cases the status code alone does not — a `404` on an
      employee photo means "no photo on file", "no such employee", or
      "not a valid size", and only the header says which.
    * `:request_id` - Value of the `X-Request-ID` header, which some
      endpoints return. Worth quoting in a support ticket.
    * `:exception` - The underlying exception for `:transport_error` and
      `:decode_error`, such as `%Req.TransportError{}` or
      `%Jason.DecodeError{}`. `nil` otherwise.

  ## Reasons

    * `:bad_request` (400), `:unauthorized` (401), `:forbidden` (403),
      `:not_found` (404), `:not_acceptable` (406), `:conflict` (409),
      `:precondition_failed` (412), `:unsupported_media_type` (415),
      `:unprocessable_entity` (422), `:rate_limited` (429)
    * `:client_error` - any other 4xx
    * `:server_error` - any 5xx
    * `:http_error` - a non-2xx status outside those ranges
    * `:transport_error` - the request never completed (connection
      refused, timeout, DNS failure)
    * `:decode_error` - a 2xx response whose body was not valid JSON
    * `:partial_publish` - a 2xx response that reports partial success,
      which only `BambooHR.Scheduling.publish_shifts/2` returns

  This struct is also an exception, so `raise error` and
  `Exception.message/1` work on it. The client itself never raises.
  """

  @type reason ::
          :bad_request
          | :unauthorized
          | :forbidden
          | :not_found
          | :not_acceptable
          | :conflict
          | :precondition_failed
          | :unsupported_media_type
          | :unprocessable_entity
          | :rate_limited
          | :client_error
          | :server_error
          | :http_error
          | :transport_error
          | :decode_error
          | :partial_publish

  @type t :: %__MODULE__{
          reason: reason(),
          status: non_neg_integer() | nil,
          body: binary() | nil,
          message: String.t() | nil,
          request_id: String.t() | nil,
          exception: Exception.t() | nil
        }

  defexception [:reason, :status, :body, :message, :request_id, :exception]

  @reasons %{
    400 => :bad_request,
    401 => :unauthorized,
    403 => :forbidden,
    404 => :not_found,
    406 => :not_acceptable,
    409 => :conflict,
    412 => :precondition_failed,
    415 => :unsupported_media_type,
    422 => :unprocessable_entity,
    429 => :rate_limited
  }

  @message_headers ["x-bamboohr-error-message", "x-bamboohr-message"]
  @request_id_header "x-request-id"

  @doc """
  Builds an error from a non-2xx response.

  `headers` is `Req`'s shape — a map of downcased name to list of values.
  """
  @spec from_response(non_neg_integer(), binary() | nil, map()) :: t()
  def from_response(status, body, headers \\ %{}) do
    %__MODULE__{
      reason: reason_for_status(status),
      status: status,
      body: body,
      message: header(headers, @message_headers),
      request_id: header(headers, [@request_id_header])
    }
  end

  @doc """
  Builds an error from a 2xx response that reports partial success.

  `reason` says which kind of partial success it was — BambooHR has no
  single shape for these, so the caller names it.
  """
  @spec from_partial_success(reason(), non_neg_integer(), binary() | nil, map()) :: t()
  def from_partial_success(reason, status, body, headers \\ %{}) do
    %__MODULE__{
      reason: reason,
      status: status,
      body: body,
      message: header(headers, @message_headers),
      request_id: header(headers, [@request_id_header])
    }
  end

  @doc """
  Builds an error from a request that never produced a response.
  """
  @spec from_exception(Exception.t()) :: t()
  def from_exception(exception) do
    %__MODULE__{reason: :transport_error, exception: exception}
  end

  @doc """
  Builds an error from a 2xx response whose body was not valid JSON.
  """
  @spec from_decode_error(Exception.t(), binary(), map()) :: t()
  def from_decode_error(exception, body, headers \\ %{}) do
    %__MODULE__{
      reason: :decode_error,
      status: 200,
      body: body,
      exception: exception,
      request_id: header(headers, [@request_id_header])
    }
  end

  @impl true
  def message(%__MODULE__{} = error) do
    [status_part(error), detail(error), request_id_part(error)]
    |> Enum.reject(&is_nil/1)
    |> Enum.join(" ")
  end

  defp status_part(%{status: nil, reason: reason}), do: "BambooHR request failed (#{reason}):"

  defp status_part(%{status: status, reason: reason}),
    do: "BambooHR returned #{status} #{reason}:"

  defp detail(%{message: message}) when is_binary(message) and message != "", do: message

  defp detail(%{exception: exception}) when not is_nil(exception),
    do: Exception.message(exception)

  defp detail(%{body: body}) when is_binary(body) and body != "", do: body
  defp detail(_error), do: "no further detail"

  defp request_id_part(%{request_id: nil}), do: nil
  defp request_id_part(%{request_id: id}), do: "(request id #{id})"

  defp reason_for_status(status) when is_map_key(@reasons, status), do: @reasons[status]
  defp reason_for_status(status) when status in 500..599, do: :server_error
  defp reason_for_status(status) when status in 400..499, do: :client_error
  defp reason_for_status(_status), do: :http_error

  defp header(headers, names) do
    Enum.find_value(names, fn name ->
      case Map.get(headers, name) do
        [value | _] -> value
        value when is_binary(value) -> value
        _ -> nil
      end
    end)
  end
end
