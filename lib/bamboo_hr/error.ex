defmodule BambooHR.Error do
  @moduledoc """
  The error returned by every function in this client.

  A failed call returns `{:error, %BambooHR.Error{}}`. That covers four
  cases:

    * BambooHR answered with a non-2xx status
    * the request failed on the way, so no answer came back
    * BambooHR answered with a 2xx that was still not a clean success: a
      body that was not the JSON it claimed to be, or a `207` where only
      part of the work was done
    * the client did not send the request, because an argument could not
      be used

  Match on `:reason` rather than on the status code:

      case BambooHR.Employee.get(client, 123, ["firstName"]) do
        {:ok, employee} -> employee
        {:error, %BambooHR.Error{reason: :not_found}} -> nil
        {:error, %BambooHR.Error{reason: :rate_limited}} -> retry_later()
        {:error, error} -> Logger.error(Exception.message(error))
      end

  ## Fields

    * `:reason` - What went wrong, as an atom. See "Reasons" below.
    * `:status` - HTTP status, or `nil` when there was no response. That
      is true of a request that failed on the way (`:transport_error`)
      and of one that was never sent (`:empty_filter`,
      `:invalid_argument`). Only the first can work on another try, so
      check `:reason` before retrying on a `nil` status.
    * `:body` - Raw response body, undecoded. `nil` when there was no
      response. `:partial_publish` is the one exception: it is spotted
      after the body has been decoded, so `:body` is that result encoded
      as JSON again. The content is the same, but key order and number
      formatting may differ from what BambooHR sent.
    * `:message` - BambooHR's own description of the failure, from the
      `x-bamboohr-error-message` or `X-BambooHR-Message` header. These
      distinguish cases the status code alone does not — a `404` on an
      employee photo means "no photo on file", "no such employee", or
      "not a valid size", and only the header says which. For a request
      that was never sent, the client's own note on which argument
      stopped it.
    * `:request_id` - Value of the `X-Request-ID` header, which some
      endpoints return. Worth quoting in a support ticket.
    * `:exception` - The underlying exception for `:transport_error` and
      `:decode_error`, such as `%Req.TransportError{}` or
      `%Jason.DecodeError{}`. `nil` otherwise.

  ## Reasons

  From a non-2xx response:

    * `:bad_request` (400), `:unauthorized` (401), `:forbidden` (403),
      `:not_found` (404), `:not_acceptable` (406), `:conflict` (409),
      `:precondition_failed` (412), `:unsupported_media_type` (415),
      `:unprocessable_entity` (422), `:rate_limited` (429)
    * `:client_error` - any other 4xx
    * `:server_error` - any 5xx
    * `:http_error` - a non-2xx status outside those ranges

  From a 2xx response:

    * `:decode_error` - the body was not valid JSON
    * `:partial_publish` - a `207` from
      `BambooHR.Scheduling.publish_shifts/2`: some shifts published and
      some did not. `:body` holds both lists, as JSON. `:status` is
      always `207`, the status BambooHR documents for this, because the
      HTTP client does not hand back the status of a 2xx. Part of the work is done, so do not send the same call again
      without reading them

  With no response:

    * `:transport_error` - the request never completed (connection
      refused, timeout, DNS failure)

  Never sent, so trying again with the same arguments gives the same
  error:

    * `:empty_filter` - a filter was given as an empty list, an empty
      string, or a list holding an empty string, so the request was
      **not sent**. Left out of the request, the filter would match
      everything, where an empty value most likely means nothing.
      `:message` names the option. Pass `nil` to mean no filter
    * `:invalid_argument` - an argument could not be used, so the request
      was **not sent**: an option the function does not know, a value
      that cannot go in a query string, an empty value for an option
      that is not a filter, or an ID that is empty, `"."` or `".."`.
      `:message` says which one and why

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
          | :empty_filter
          | :invalid_argument

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
  @unsent_reasons [:empty_filter, :invalid_argument]

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

  A 2xx like this is not a clean success, so the resource module that
  spots one in the result turns it into an error and names the
  `reason`, e.g. `:partial_publish` in
  `BambooHR.Scheduling.publish_shifts/2`.
  """
  @spec from_partial_success(reason(), non_neg_integer(), binary() | nil, map()) :: t()
  def from_partial_success(reason, status, body, headers \\ %{}) do
    %{from_response(status, body, headers) | reason: reason}
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

  `status` is the 2xx status that came back; it defaults to `200`.
  """
  @spec from_decode_error(Exception.t(), binary(), map(), non_neg_integer()) :: t()
  def from_decode_error(exception, body, headers \\ %{}, status \\ 200) do
    %__MODULE__{
      reason: :decode_error,
      status: status,
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

  # The client turned these away itself, so nothing reached BambooHR.
  # Saying "failed" would read like a network or server fault.
  defp status_part(%{status: nil, reason: reason}) when reason in @unsent_reasons,
    do: "BambooHR request not sent (#{reason}):"

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
