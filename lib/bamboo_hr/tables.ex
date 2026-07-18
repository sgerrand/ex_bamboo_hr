defmodule BambooHR.Tables do
  @moduledoc """
  Functions for interacting with employee tabular data in the BambooHR API.

  Tabular fields back historical tables on the employee record (job info,
  compensation, employment status, custom tabular fields, etc.) — use
  `BambooHR.Metadata.get_tabular_fields/1` to discover available table
  names and their fields.
  """

  alias BambooHR.Client

  @doc """
  Retrieves all rows for a given employee and table combination.

  Fields the caller does not have access to are omitted from each row.

  ## Parameters

    * `client` - Client configuration created with `BambooHR.Client.new/1`
    * `employee_id` - The employee ID, or `"all"` to retrieve table data
      for all employees the API user has access to
    * `table` - The name of the table to retrieve (e.g. `"jobInfo"`,
      `"compensation"`)

  ## Examples

      iex> BambooHR.Tables.get_table_data(client, 123, "compensation")
      {:ok, [%{"id" => "1", "employeeId" => "123", "payRate" => "50000.00"}]}
  """
  @spec get_table_data(Client.t(), integer() | String.t(), String.t()) :: Client.response()
  def get_table_data(client, employee_id, table)
      when (is_integer(employee_id) or employee_id == "all") and is_binary(table) do
    Client.get("/employees/#{employee_id}/tables/#{table}", client)
  end

  @doc """
  Adds a new row to the specified employee table.

  On success, returns `nil` (no response body).

  ## Parameters

    * `client` - Client configuration created with `BambooHR.Client.new/1`
    * `employee_id` - The employee ID
    * `table` - The name of the table to add a row to (e.g. `"jobInfo"`,
      `"compensation"`)
    * `row_data` - Map of field name/value pairs for the new row

  ## Examples

      iex> row_data = %{"date" => "2024-01-15", "payRate" => "55000.00"}
      iex> BambooHR.Tables.create_table_row(client, 123, "compensation", row_data)
      {:ok, nil}
  """
  @spec create_table_row(Client.t(), integer(), String.t(), map()) :: Client.response()
  def create_table_row(client, employee_id, table, row_data)
      when is_integer(employee_id) and is_binary(table) do
    Client.post("/employees/#{employee_id}/tables/#{table}", client, json: row_data)
  end

  @doc """
  Updates an existing row in the specified employee table.

  Only the fields included in `row_data` are changed. On success, returns
  `nil` (no response body).

  ## Parameters

    * `client` - Client configuration created with `BambooHR.Client.new/1`
    * `employee_id` - The employee ID
    * `table` - The name of the table containing the row to update
    * `row_id` - The ID of the row to update
    * `row_data` - Map of field name/value pairs to change

  ## Examples

      iex> BambooHR.Tables.update_table_row(client, 123, "compensation", "1", %{"payRate" => "60000.00"})
      {:ok, nil}
  """
  @spec update_table_row(Client.t(), integer(), String.t(), String.t(), map()) ::
          Client.response()
  def update_table_row(client, employee_id, table, row_id, row_data)
      when is_integer(employee_id) and is_binary(table) and is_binary(row_id) do
    Client.post("/employees/#{employee_id}/tables/#{table}/#{row_id}", client, json: row_data)
  end

  @doc """
  Deletes a specific row from an employee's tabular data.

  Deletion fails with a `409` error if the row has pending approval
  changes, or `412` if the row is tied to an active pay schedule.

  ## Parameters

    * `client` - Client configuration created with `BambooHR.Client.new/1`
    * `employee_id` - The employee ID
    * `table` - The name of the table containing the row to delete
    * `row_id` - The ID of the row to delete

  ## Examples

      iex> BambooHR.Tables.delete_table_row(client, 123, "compensation", "1")
      {:ok, %{"success" => true}}
  """
  @spec delete_table_row(Client.t(), integer(), String.t(), String.t()) :: Client.response()
  def delete_table_row(client, employee_id, table, row_id)
      when is_integer(employee_id) and is_binary(table) and is_binary(row_id) do
    Client.delete("/employees/#{employee_id}/tables/#{table}/#{row_id}", client)
  end

  @doc """
  Retrieves table data for employees that have changed since a given
  timestamp.

  Operates on an employee-last-changed timestamp: a change to *any* field
  on the employee record causes all of that employee's rows for `table` to
  appear in the response, grouped by employee ID.

  ## Parameters

    * `client` - Client configuration created with `BambooHR.Client.new/1`
    * `table` - The name of the table to retrieve changed data for
    * `since` - ISO 8601 timestamp string; only employees changed since
      this time are included

  ## Examples

      iex> BambooHR.Tables.get_changed_table_data(client, "compensation", "2024-01-01T00:00:00Z")
      {:ok, %{"table" => "compensation", "employees" => %{}}}
  """
  @spec get_changed_table_data(Client.t(), String.t(), String.t()) :: Client.response()
  def get_changed_table_data(client, table, since) when is_binary(table) and is_binary(since) do
    Client.get("/employees/changed/tables/#{table}", client, params: [since: since])
  end
end
