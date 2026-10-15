defmodule BambooHR.PathSegment do
  @moduledoc false

  # Keeps a caller's string ID to one path segment, whatever it holds.
  # Encoding cannot help with three values, so they are turned away. An
  # empty ID leaves the path ending in `/`, which a router may serve as
  # the list endpoint: a blank ID would then delete or fetch at the wrong
  # level. `.` and `..` are unreserved, so they pass through as they are,
  # and a proxy may resolve them as path steps.

  @doc false
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
