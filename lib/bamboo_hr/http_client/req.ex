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

    opts =
      opts
      |> Keyword.put(:decode_body, false)
      |> Keyword.put_new(:retry, &__MODULE__.retry?/2)

    case Req.request(opts) do
      {:ok, %{status: status, body: body, headers: headers}} when status in 200..299 ->
        decode_success(body, headers, expose_headers)

      {:ok, %{status: status, body: body}} ->
        {:error, %{status: status, body: body}}

      {:error, error} ->
        {:error, error}
    end
  end

  defp decode_success(body, headers, expose_headers) do
    with {:ok, decoded} <- decode_body(body) do
      if expose_headers do
        {:ok, %{body: decoded, headers: headers}}
      else
        {:ok, decoded}
      end
    end
  end

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
