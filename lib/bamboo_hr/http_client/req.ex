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
  to disable, or a custom function).
  """

  @behaviour BambooHR.HTTPClient

  @transient_statuses [408, 500, 502, 503, 504]
  @transient_transport_reasons [:timeout, :econnrefused, :closed]

  @impl true
  def request(opts) do
    {expose_headers, opts} = Keyword.pop(opts, :expose_headers, false)
    {expose_status, opts} = Keyword.pop(opts, :expose_status, false)
    {raw_response, opts} = Keyword.pop(opts, :raw_response, false)

    opts =
      opts
      |> Keyword.put(:decode_body, false)
      |> Keyword.put_new(:retry, &__MODULE__.retry?/2)

    case Req.request(opts) do
      {:ok, %{status: status, body: body, headers: headers}} when status in 200..299 ->
        extras = success_extras(headers, status, expose_headers, expose_status)
        decode_success(body, headers, extras, raw_response)

      {:ok, %{status: status, body: body, headers: headers}} ->
        {:error, BambooHR.Error.from_response(status, body, headers)}

      {:error, exception} ->
        {:error, BambooHR.Error.from_exception(exception)}
    end
  end

  defp decode_success(body, _headers, extras, true) do
    wrap_success(body, extras)
  end

  # `headers` is passed on its own, not read from `extras`: a decode error
  # needs the request ID even when the caller did not ask for headers.
  defp decode_success(body, headers, extras, false) do
    case decode_body(body) do
      {:ok, decoded} ->
        wrap_success(decoded, extras)

      {:error, exception} ->
        {:error, BambooHR.Error.from_decode_error(exception, body, headers)}
    end
  end

  defp success_extras(headers, status, expose_headers, expose_status) do
    extras = if expose_headers, do: %{headers: headers}, else: %{}

    if expose_status, do: Map.put(extras, :status, status), else: extras
  end

  defp wrap_success(payload, extras) when map_size(extras) == 0, do: {:ok, payload}
  defp wrap_success(payload, extras), do: {:ok, Map.put(extras, :body, payload)}

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

  defp decode_body(""), do: {:ok, nil}
  defp decode_body(body), do: Jason.decode(body)
end
