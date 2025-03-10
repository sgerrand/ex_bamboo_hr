defmodule BambooHR.Employee do
  @moduledoc """
  Functions for interacting with employee resources in the BambooHR API.
  """

  alias BambooHR.Client

  @doc """
  Retrieves information about a specific employee.

  ## Parameters

    * `client` - Client configuration created with `BambooHR.Client.new/1`
    * `employee_id` - The ID of the employee to retrieve
    * `fields` - List of field names to retrieve (e.g., ["firstName", "lastName", "jobTitle"])

  ## Examples

      iex> BambooHR.Employee.get(client, 123, ["firstName", "lastName", "jobTitle"])
      {:ok, %{
        "firstName" => "John",
        "lastName" => "Doe",
        "jobTitle" => "Software Engineer"
      }}
  """
  @spec get(Client.t(), integer(), list(String.t())) :: Client.response()
  def get(client, employee_id, fields) when is_integer(employee_id) do
    Client.get("/employees/#{employee_id}", client, params: [fields: Enum.join(fields, ",")])
  end

  @doc """
  Adds a new employee.

  ## Parameters

    * `client` - Client configuration created with `BambooHR.Client.new/1`
    * `employee_data` - Map containing the employee information (firstName and lastName are required)

  ## Examples

      iex> employee_data = %{"firstName" => "Jane", "lastName" => "Smith"}
      iex> BambooHR.Employee.add(client, employee_data)
      {:ok, %{"id" => 124}}
  """
  @spec add(Client.t(), map()) :: Client.response()
  def add(client, employee_data) do
    Client.post("/employees", client, json: employee_data)
  end

  @doc """
  Updates information for an existing employee.

  ## Parameters

    * `client` - Client configuration created with `BambooHR.Client.new/1`
    * `employee_id` - The ID of the employee to update
    * `employee_data` - Map containing the updated employee information

  ## Examples

      iex> update_data = %{"firstName" => "Jane", "lastName" => "Smith-Jones"}
      iex> BambooHR.Employee.update(client, 124, update_data)
      {:ok, %{}}
  """
  @spec update(Client.t(), integer(), map()) :: Client.response()
  def update(client, employee_id, employee_data) when is_integer(employee_id) do
    Client.post("/employees/#{employee_id}", client, json: employee_data)
  end

  @doc """
  Retrieves the company's employee directory.

  Returns a list of all employees with basic information like name and contact details.

  ## Parameters

    * `client` - Client configuration created with `BambooHR.Client.new/1`

  ## Examples

      iex> BambooHR.Employee.get_directory(client)
      {:ok, %{
        "employees" => [
          %{
            "id" => 123,
            "displayName" => "John Doe",
            "jobTitle" => "Developer",
            "workEmail" => "john@example.com"
          }
        ]
      }}
  """
  @spec get_directory(Client.t()) :: Client.response()
  def get_directory(client) do
    Client.get("/employees/directory", client)
  end
end
