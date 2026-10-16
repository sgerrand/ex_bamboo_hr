defmodule BambooHR.PathSegment do
  @moduledoc false

  @doc """
  Turns a caller's string ID into one path segment, whatever it holds.

  Returns `{:ok, segment}`, percent-encoded so a `/`, `?` or `#` cannot
  change the endpoint or add query params. Encoding cannot help with
  three values, so for an empty ID, `"."` or `".."` it returns
  `{:error, %BambooHR.Error{reason: :invalid_argument}}`. An empty ID
  leaves the path ending in `/`, which a router may serve as the list
  endpoint, and a proxy may resolve the dots as path steps.

  The module is internal: it is shared by resource modules and is not
  part of the public API.
  """
  @spec encode(String.t()) :: {:ok, String.t()} | {:error, BambooHR.Error.t()}
  def encode(id) when is_binary(id) do
    if String.trim(id) == "" or id in [".", ".."] do
      {:error,
       %BambooHR.Error{
         reason: :invalid_argument,
         message: "#{inspect(id)} cannot be used as an ID, so the request was not sent."
       }}
    else
      {:ok, URI.encode(id, &URI.char_unreserved?/1)}
    end
  end
end
