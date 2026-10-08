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

  Callers can override by passing `retry:` in `opts` (e.g. `retry: false`
  to disable, or a custom function). `retry: :unprocessed` selects
  `retry_unprocessed?/2`, which retries only what BambooHR certainly did
  not process.
  """

  @behaviour BambooHR.HTTPClient

  @transient_statuses [408, 500, 502, 503, 504]
  @transient_transport_reasons [:timeout, :econnrefused, :closed]

  @impl true
  def request(opts) do
    {expose_headers, opts} = Keyword.pop(opts, :expose_headers, false)
    {raw_response, opts} = Keyword.pop(opts, :raw_response, false)
    {partial_success, opts} = Keyword.pop(opts, :partial_success, %{})
    partial_success = Map.new(partial_success || %{})

    opts =
      opts
      |> Keyword.put(:decode_body, false)
      |> Keyword.put_new(:retry, &__MODULE__.retry?/2)
      |> Keyword.update!(:retry, &retry_option/1)

    case Req.request(opts) do
      # Only a 2xx can be a partial success; a listed 4xx or 5xx keeps its
      # usual reason.
      {:ok, %{status: status, body: body, headers: headers}}
      when status in 200..299 and is_map_key(partial_success, status) ->
        reason = Map.fetch!(partial_success, status)
        {:error, BambooHR.Error.from_partial_success(reason, status, body, headers)}

      {:ok, %{status: status, body: body, headers: headers}} when status in 200..299 ->
        decode_success(body, status, headers, expose_headers, raw_response)

      {:ok, %{status: status, body: body, headers: headers}} ->
        {:error, BambooHR.Error.from_response(status, body, headers)}

      {:error, exception} ->
        {:error, BambooHR.Error.from_exception(exception)}
    end
  end

  # `:unprocessed` is this client's own name, not one Req knows.
  defp retry_option(:unprocessed), do: &__MODULE__.retry_unprocessed?/2
  defp retry_option(retry), do: retry

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
  `429`, which it turns away before doing any work, and a refused
  connection, which never reached it. A `5xx` or a timeout is not
  retried, because the work may have been done.
  """
  @spec retry_unprocessed?(Req.Request.t(), Req.Response.t() | Exception.t()) :: boolean()
  def retry_unprocessed?(_request, %Req.Response{status: 429}), do: true
  def retry_unprocessed?(_request, %Req.TransportError{reason: :econnrefused}), do: true
  def retry_unprocessed?(_request, _response_or_exception), do: false

  defp decode_body(""), do: {:ok, nil}
  defp decode_body(body), do: Jason.decode(body)
end
