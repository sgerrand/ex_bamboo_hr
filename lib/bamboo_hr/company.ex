defmodule BambooHR.Company do
  @moduledoc """
  Functions for interacting with company information in the BambooHR API.
  """

  alias BambooHR.Client

  @doc """
  Retrieves company information.

  Returns basic company details including name, address, and employee count.

  ## Parameters

    * `client` - Client configuration created with `BambooHR.Client.new/1`

  ## Examples

      iex> BambooHR.Company.get_information(client)
      {:ok, %{
        "name" => "Acme Corp",
        "employeeCount" => 100,
        "city" => "San Francisco"
      }}
  """
  @spec get_information(client :: Client.t()) :: Client.response()
  def get_information(client) do
    Client.get("/company_information", client)
  end
end
