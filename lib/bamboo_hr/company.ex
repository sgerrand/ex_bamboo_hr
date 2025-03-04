defmodule BambooHR.Company do
  @moduledoc """
  Functions for interacting with company information in the BambooHR API.
  """

  alias BambooHR.Client

  @doc """
  Retrieves company information.

  Returns basic company details including name, address, and employee count.

  ## Parameters

    * `client` - Client configuration created with `BambooHR.Client.new/3`

  ## Examples

      iex> BambooHR.Company.get_information(client)
      {:ok, %{
        "name" => "Acme Corp",
        "employeeCount" => 100,
        "city" => "San Francisco"
      }}
  """
  @spec get_information(Client.config()) :: Client.response()
  def get_information(client) do
    Client.get("/company_information", client)
  end

  @doc """
  Retrieves company EINs (Employer Identification Numbers).

  Returns a list of EINs associated with the company.

  ## Parameters

    * `client` - Client configuration created with `BambooHR.Client.new/3`

  ## Examples

      iex> BambooHR.Company.get_eins(client)
      {:ok, %{
        "eins" => [
          %{"ein" => "12-3456789", "name" => "Acme Corp"},
          %{"ein" => "98-7654321", "name" => "Acme Subsidiary"}
        ]
      }}
  """
  @spec get_eins(Client.config()) :: Client.response()
  def get_eins(client) do
    Client.get("/company_eins", client)
  end
end
