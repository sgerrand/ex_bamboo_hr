defmodule BambooHR.HTTPClient do
  @moduledoc """
  Behaviour for HTTP clients used by `BambooHR.Client`.

  Implementations receive a keyword list of `Req`-style options assembled by
  `BambooHR.Client` and must return `{:ok, decoded_body}` for 2xx responses
  (where `decoded_body` is the JSON-decoded payload, or `nil` for an empty
  body) or `{:error, reason}` otherwise. See `t:BambooHR.Client.response/0`
  for the full shape.

  ## Options passed to `request/1`

    * `:method` — `:get` or `:post`
    * `:url` — fully-qualified URL
    * `:headers` — list of `{name, value}` tuples (includes `Authorization`)
    * `:receive_timeout` — milliseconds
    * `:params` — query string parameters (optional)
    * `:json` — request body to JSON-encode (optional)
  """

  @callback request(keyword()) :: {:ok, term()} | {:error, term()}
end
