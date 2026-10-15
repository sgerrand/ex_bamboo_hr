defmodule BambooHR.HTTPClient.Req do
  @moduledoc """
  HTTP client implementation using `Req`.

  ## Retry policy

  Unless the caller passes `:retry` explicitly, requests use a custom retry
  policy via `retry?/2`:

    * HTTP 429 responses are retried for **all** methods. BambooHR rate
      limits apply per-key regardless of verb, and 429 means the request
      was not processed so retrying a POST is safe. The `Retry-After`
      header is honoured by Req's default `:retry_delay`.
    * GET and HEAD additionally retry on 408/500/502/503/504 and the
      same transient transport errors as Req's `:safe_transient` mode.
    * POST is **not** retried on 5xx — those could indicate partial
      processing.

  Callers can override by passing `retry:` in `opts`: `false` to
  disable, `:safe_transient` or `:transient` for Req's own policies, or
  a 2-arity function. `retry_unprocessed?/2` is one, for a request that
  must not run twice. `nil` means this client's own policy.

  Req checks `:retry` only once a response or error is in, and raises
  on a value it does not accept, by then too late for the request to be
  taken back. So a value it does not accept counts as `false`, with a
  warning. A function is guarded the same way: a result other than
  `true`, `false`, `nil` or `{:delay, milliseconds}`, or a raise, counts
  as `false`, with a warning. `{:delay, milliseconds}` with
  `:retry_delay` also set counts as `true`, so `:retry_delay` decides
  the wait.
  """

  require Logger

  @behaviour BambooHR.HTTPClient

  @transient_statuses [408, 500, 502, 503, 504]
  @transient_transport_reasons [:timeout, :econnrefused, :closed]

  @impl true
  def request(opts) do
    {expose_headers, opts} = Keyword.pop(opts, :expose_headers, false)
    {raw_response, opts} = Keyword.pop(opts, :raw_response, false)

    opts =
      opts
      |> Keyword.put(:decode_body, false)
      |> Keyword.put(:retry, retry_option(opts[:retry], opts[:retry_delay] != nil))

    case Req.request(opts) do
      {:ok, %{status: status, body: body, headers: headers}} when status in 200..299 ->
        decode_success(body, status, headers, expose_headers, raw_response)

      {:ok, %{status: status, body: body, headers: headers}} ->
        {:error, BambooHR.Error.from_response(status, body, headers)}

      {:error, exception} ->
        {:error, BambooHR.Error.from_exception(exception)}
    end
  end

  defp retry_option(nil, _retry_delay?), do: &__MODULE__.retry?/2

  defp retry_option(retry, _retry_delay?) when retry in [false, :safe_transient, :transient],
    do: retry

  defp retry_option(retry, retry_delay?) when is_function(retry, 2),
    do: guard_retry(retry, retry_delay?)

  defp retry_option(retry, _retry_delay?) do
    Logger.warning(
      "BambooHR.HTTPClient.Req: ignoring retry: #{inspect(retry)}, expected false, " <>
        ":safe_transient, :transient or a 2-arity function; not retrying"
    )

    false
  end

  # Req raises on any other result, or when the function raises, after
  # the response is in. It also raises on `{:delay, ms}` when
  # `:retry_delay` is set.
  defp guard_retry(retry, retry_delay?) do
    fn request, response_or_exception ->
      try do
        retry_result(retry.(request, response_or_exception), retry_delay?)
      rescue
        exception -> warn_bad_retry("raised #{Exception.message(exception)}")
      catch
        kind, value -> warn_bad_retry("#{kind} #{inspect(value)}")
      end
    end
  end

  defp retry_result(result, _retry_delay?) when is_boolean(result), do: result
  defp retry_result(nil, _retry_delay?), do: false

  defp retry_result({:delay, ms} = delay, retry_delay?) when is_integer(ms) and ms >= 0,
    do: if(retry_delay?, do: true, else: delay)

  defp retry_result(other, _retry_delay?), do: warn_bad_retry("returned #{inspect(other)}")

  defp warn_bad_retry(what) do
    Logger.warning("BambooHR.HTTPClient.Req: the :retry function #{what}; not retrying")
    false
  end

  defp decode_success(body, _status, headers, expose_headers, true) do
    wrap_success(body, headers, expose_headers)
  end

  defp decode_success(body, status, headers, expose_headers, false) do
    case decode_body(body) do
      {:ok, decoded} ->
        wrap_success(decoded, headers, expose_headers)

      {:error, exception} ->
        {:error, BambooHR.Error.from_decode_error(exception, body, headers, status)}
    end
  end

  defp wrap_success(payload, headers, true), do: {:ok, %{body: payload, headers: headers}}
  defp wrap_success(payload, _headers, false), do: {:ok, payload}

  @doc """
  Retry predicate passed to `Req`. Returns `true` to retry, `false` otherwise.
  """
  @spec retry?(Req.Request.t(), Req.Response.t() | Exception.t()) :: boolean()
  def retry?(_request, %Req.Response{status: 429}), do: true

  def retry?(%Req.Request{method: method}, response_or_exception)
      when method in [:get, :head] do
    case response_or_exception do
      %Req.Response{status: status} when status in @transient_statuses -> true
      %Req.TransportError{reason: reason} when reason in @transient_transport_reasons -> true
      _ -> false
    end
  end

  def retry?(_request, _response_or_exception), do: false

  @doc """
  Retry predicate for a request that must not run twice.

  Retries only when BambooHR certainly did not process the request: a
  `429`, which it turns away before doing any work, a refused
  connection, which never reached it, and the two HTTP/2 errors that
  mean the request was never sent (`:unprocessed`, when the server
  closed the connection before taking it, and `:pool_not_available`).
  A `5xx` or a timeout is not retried, because the work may have been
  done.
  """
  @spec retry_unprocessed?(Req.Request.t(), Req.Response.t() | Exception.t()) :: boolean()
  def retry_unprocessed?(_request, %Req.Response{status: 429}), do: true
  def retry_unprocessed?(_request, %Req.TransportError{reason: :econnrefused}), do: true

  def retry_unprocessed?(_request, %Req.HTTPError{protocol: :http2, reason: reason})
      when reason in [:unprocessed, :pool_not_available],
      do: true

  def retry_unprocessed?(_request, _response_or_exception), do: false

  defp decode_body(""), do: {:ok, nil}
  defp decode_body(body), do: Jason.decode(body)
end
