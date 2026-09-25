defmodule BambooHR.HTTPClient do
  @moduledoc """
  Behaviour for HTTP clients used by `BambooHR.Client`.

  Implementations receive a keyword list of `Req`-style options assembled by
  `BambooHR.Client` and must return `{:ok, decoded_body}` for 2xx responses
  (where `decoded_body` is the JSON-decoded payload, or `nil` for an empty
  body) or `{:error, %BambooHR.Error{}}` otherwise. `BambooHR.Error` has
  constructors for each failure kind — `from_response/3`,
  `from_exception/1`, `from_decode_error/4`, and `from_partial_success/4`.
  See `t:BambooHR.Client.response/0` for the full shape.

  New options can be added to the list below. An implementation must
  drop any option it does not recognise rather than pass it on — `Req`,
  for one, raises on an option it does not know.

  ## Options passed to `request/1`

    * `:method` — `:get`, `:post`, `:patch`, `:put`, or `:delete`
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
    * `:partial_success` — a map of 2xx status to `BambooHR.Error`
      reason, e.g. `%{207 => :partial_publish}`. A response with one of
      those statuses comes back as `{:error, error}`, built with
      `BambooHR.Error.from_partial_success/4` from the raw body and
      headers. Defaults to `%{}`. Needed where a 2xx is not a clean
      success — e.g. `POST /scheduling/shifts/publish`, which answers
      `207` when only some shifts published.
    * `:raw_response` — when `true`, a 2xx response body is returned as-is
      instead of being JSON-decoded. Defaults to `false`. Required for
      binary downloads (e.g. file content), which are not JSON. Composes
      with `:expose_headers` to also get the response headers (e.g. to
      read `Content-Type` / `Content-Disposition` for a downloaded file).
  """

  @callback request(keyword()) :: {:ok, term()} | {:error, BambooHR.Error.t()}
end
