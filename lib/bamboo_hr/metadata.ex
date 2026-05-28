defmodule BambooHR.Metadata do
  @moduledoc """
  Functions for retrieving metadata about fields available in the BambooHR
  API.

  These endpoints describe what fields exist on employees and other
  resources — useful for discovering field names to pass to
  `BambooHR.Employee.get/3`, building UIs, or auditing schema drift.
  """

  alias BambooHR.Client

  @doc """
  Retrieves metadata for available employee fields.

  Returns a map with a `"fields"` list; each entry describes a field's id,
  name, type, and description.

  ## Parameters

    * `client` - Client configuration created with `BambooHR.Client.new/1`

  ## Examples

      iex> BambooHR.Metadata.get_fields(client)
      {:ok, %{
        "fields" => [
          %{
            "id" => "1",
            "name" => "firstName",
            "type" => "text",
            "description" => "First name"
          }
        ]
      }}
  """
  @spec get_fields(Client.t()) :: Client.response()
  def get_fields(client) do
    Client.get("/meta/fields", client)
  end

  @doc """
  Retrieves metadata for available tabular fields.

  Tabular fields back tables on the employee record (employment history,
  compensation, etc.). Returns a map with a `"tabularFields"` list.

  ## Parameters

    * `client` - Client configuration created with `BambooHR.Client.new/1`

  ## Examples

      iex> BambooHR.Metadata.get_tabular_fields(client)
      {:ok, %{
        "tabularFields" => [
          %{
            "id" => "employmentStatus",
            "name" => "Employment Status",
            "type" => "list",
            "description" => "History of employment status changes"
          }
        ]
      }}
  """
  @spec get_tabular_fields(Client.t()) :: Client.response()
  def get_tabular_fields(client) do
    Client.get("/meta/tables", client)
  end

  @doc """
  Retrieves metadata for available list fields.

  List fields hold enumerated values (departments, divisions, etc.).
  Returns a map with an `"items"` list; each entry describes a list field's
  options.

  ## Parameters

    * `client` - Client configuration created with `BambooHR.Client.new/1`

  ## Examples

      iex> BambooHR.Metadata.get_lists(client)
      {:ok, %{
        "items" => [
          %{
            "fieldId" => "1610",
            "alias" => "department",
            "manageable" => "yes",
            "name" => "Department",
            "options" => [
              %{"id" => "1", "name" => "Engineering", "archived" => "no"}
            ]
          }
        ]
      }}
  """
  @spec get_lists(Client.t()) :: Client.response()
  def get_lists(client) do
    Client.get("/meta/lists", client)
  end
end
