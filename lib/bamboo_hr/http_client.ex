defmodule BambooHR.HTTPClient do
  @moduledoc """
  Behaviour for HTTP clients.
  """

  @callback request(keyword()) :: {:ok, map()} | {:error, any()}
end
