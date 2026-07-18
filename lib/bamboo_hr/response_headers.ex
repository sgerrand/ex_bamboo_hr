defmodule BambooHR.ResponseHeaders do
  @moduledoc false

  @doc """
  Extracts a `Location` header from an `expose_headers: true` response.

  Returns `%{"location" => url}` when present, `%{}` otherwise — including
  when `headers` doesn't look like the expected `expose_headers` shape at
  all, which happens if a caller-supplied `:http_client` doesn't honor that
  option.
  """
  @spec location(term()) :: %{optional(String.t()) => String.t()}
  def location(headers) when is_map(headers) do
    case Map.get(headers, "location") do
      [location | _] -> %{"location" => location}
      _ -> %{}
    end
  end

  def location(_headers), do: %{}
end
