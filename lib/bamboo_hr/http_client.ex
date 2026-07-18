defmodule BambooHR.HTTPClient do
  @moduledoc """
  Behaviour for HTTP clients used by `BambooHR.Client`.

  Implementations receive a keyword list of `Req`-style options assembled by
  `BambooHR.Client` and must return `{:ok, decoded_body}` for 2xx responses
  (where `decoded_body` is the JSON-decoded payload, or `nil` for an empty
  body) or `{:error, reason}` otherwise. See `t:BambooHR.Client.response/0`
  for the full shape.

  ## Options passed to `request/1`

    * `:method` — `:get`, `:post`, `:put`, or `:delete`
    * `:url` — fully-qualified URL
    * `:headers` — list of `{name, value}` tuples (includes `Authorization`
      and `Accept`; `BambooHR.Client` sets `Accept: application/json`
      normally, or `Accept: */*` when `:raw_response` is `true`, so binary
      downloads aren't forced into requesting a JSON representation)
    * `:receive_timeout` — milliseconds
    * `:params` — query string parameters (optional)
    * `:json` — request body to JSON-encode (optional)
    * `:form_multipart` — request body to encode as `multipart/form-data`,
      `Req`'s `:form_multipart` shape (optional)
    * `:expose_headers` — when `true`, the `:ok` payload for a 2xx response
      becomes `%{body: body, headers: headers}` instead of the bare body.
      `headers` is a map of downcased header name to a list of values
      (`Req`'s convention — a header may repeat). Defaults to `false`.
      Useful for endpoints that return no body and communicate their
      result through a header instead — e.g. `POST /employees`, whose
      `Location` header is the only way to identify the created employee.
    * `:raw_response` — when `true`, a 2xx response body is returned as-is
      instead of being JSON-decoded. Defaults to `false`. Required for
      binary downloads (e.g. file content), which are not JSON. Composes
      with `:expose_headers` to also get the response headers (e.g. to
      read `Content-Type` / `Content-Disposition` for a downloaded file).
  """

  @callback request(keyword()) :: {:ok, term()} | {:error, term()}
end
