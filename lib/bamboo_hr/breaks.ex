defmodule BambooHR.Breaks do
  @moduledoc """
  Functions for meal and rest breaks in the BambooHR API.

  A break policy groups the breaks an employee is entitled to and the
  employees it applies to. A break assessment records whether an employee
  actually complied with their policy on a given day.

  These endpoints live under `/time-tracking/`, but they are kept out of
  `BambooHR.TimeTracking` because they are their own resource tree with
  their own pagination style.

  ## IDs

  Break and break policy IDs are UUID strings, not integers. Employee IDs
  are still integers.

  ## Paging and filtering

  Listing functions take `:offset` and `:limit`, unlike the clock and
  hour entry lists in `BambooHR.TimeTracking`, which page with `:page`
  and `:page_size`. Where a `:filter` is supported it is an OData v4
  string, passed straight through.
  """

  alias BambooHR.Client

  @doc """
  Lists break policies.

  ## Parameters

    * `client` - Client configuration created with `BambooHR.Client.new/1`
    * `opts` - Optional keyword list: `:offset`, `:limit`, `:filter`, and
      `:include_counts` to add employee and break counts per policy

  ## Examples

      iex> BambooHR.Breaks.list_policies(client, include_counts: true)
      {:ok, %{"data" => [%{"id" => "0f8c...", "name" => "California meal breaks"}]}}
  """
  @spec list_policies(Client.t(), keyword()) :: Client.response()
  def list_policies(client, opts \\ []) do
    Client.get("/time-tracking/break-policies", client, params: list_params(opts))
  end

  @doc """
  Creates a break policy.

  Breaks and employee assignments can be included here rather than added
  afterwards.

  ## Parameters

    * `client` - Client configuration created with `BambooHR.Client.new/1`
    * `policy_data` - Map with `"name"`, and optionally `"description"`,
      `"allEmployeesAssigned"`, `"breaks"`, `"employeeIds"`

  ## Examples

      iex> BambooHR.Breaks.create_policy(client, %{"name" => "California meal breaks"})
      {:ok, %{"id" => "0f8c...", "name" => "California meal breaks"}}
  """
  @spec create_policy(Client.t(), map()) :: Client.response()
  def create_policy(client, policy_data) when is_map(policy_data) do
    Client.post("/time-tracking/break-policies", client, json: policy_data)
  end

  @doc """
  Retrieves a break policy.

  ## Parameters

    * `client` - Client configuration created with `BambooHR.Client.new/1`
    * `policy_id` - The policy's UUID
    * `opts` - Optional keyword list: `:include_counts`

  ## Examples

      iex> BambooHR.Breaks.get_policy(client, "0f8c...")
      {:ok, %{"id" => "0f8c...", "name" => "California meal breaks"}}
  """
  @spec get_policy(Client.t(), String.t(), keyword()) :: Client.response()
  def get_policy(client, policy_id, opts \\ []) when is_binary(policy_id) do
    Client.get("/time-tracking/break-policies/#{policy_id}", client, params: list_params(opts))
  end

  @doc """
  Updates a break policy.

  Only the fields given are changed. Use `sync_policy/3` to replace a
  policy and everything attached to it.

  ## Parameters

    * `client` - Client configuration created with `BambooHR.Client.new/1`
    * `policy_id` - The policy's UUID
    * `changes` - Map of fields to change: `"name"`, `"description"`,
      `"allEmployeesAssigned"`

  ## Examples

      iex> BambooHR.Breaks.update_policy(client, "0f8c...", %{"description" => "Updated"})
      {:ok, %{"id" => "0f8c...", "description" => "Updated"}}
  """
  @spec update_policy(Client.t(), String.t(), map()) :: Client.response()
  def update_policy(client, policy_id, changes) when is_binary(policy_id) and is_map(changes) do
    Client.patch("/time-tracking/break-policies/#{policy_id}", client, json: changes)
  end

  @doc """
  Replaces a break policy and everything attached to it.

  Unlike `update_policy/3`, this is a full replacement: breaks and
  employee assignments left out of the payload are removed.

  ## Parameters

    * `client` - Client configuration created with `BambooHR.Client.new/1`
    * `policy_id` - The policy's UUID
    * `policy_data` - The complete policy: `"name"`, `"description"`,
      `"allEmployeesAssigned"`, `"breaks"`, `"employeeIds"`

  ## Examples

      iex> policy_data = %{"name" => "California meal breaks", "employeeIds" => [123]}
      iex> BambooHR.Breaks.sync_policy(client, "0f8c...", policy_data)
      {:ok, %{"id" => "0f8c...", "employeeIds" => [123]}}
  """
  @spec sync_policy(Client.t(), String.t(), map()) :: Client.response()
  def sync_policy(client, policy_id, policy_data)
      when is_binary(policy_id) and is_map(policy_data) do
    Client.put("/time-tracking/break-policies/#{policy_id}/sync", client, json: policy_data)
  end

  @doc """
  Deletes a break policy, along with its breaks and assignments.

  On success, returns `nil` (no response body).

  ## Parameters

    * `client` - Client configuration created with `BambooHR.Client.new/1`
    * `policy_id` - The policy's UUID

  ## Examples

      iex> BambooHR.Breaks.delete_policy(client, "0f8c...")
      {:ok, nil}
  """
  @spec delete_policy(Client.t(), String.t()) :: Client.response()
  def delete_policy(client, policy_id) when is_binary(policy_id) do
    Client.delete("/time-tracking/break-policies/#{policy_id}", client)
  end

  @doc """
  Asks BambooHR's AI agent to suggest break policies.

  It reads the existing policies and company context and returns
  structured recommendations, meant for pre-filling a form rather than
  being applied directly.

  ## Parameters

    * `client` - Client configuration created with `BambooHR.Client.new/1`
    * `prompt` - What to base the suggestions on

  ## Examples

      iex> BambooHR.Breaks.get_policy_suggestions(client, "California retail staff")
      {:ok, %{"suggestions" => [%{"name" => "Meal break", "duration" => 30}]}}
  """
  @spec get_policy_suggestions(Client.t(), String.t()) :: Client.response()
  def get_policy_suggestions(client, prompt) when is_binary(prompt) do
    Client.post("/time-tracking/break-policies/suggestions", client, json: %{"prompt" => prompt})
  end

  @doc """
  Lists the breaks belonging to a break policy.

  ## Parameters

    * `client` - Client configuration created with `BambooHR.Client.new/1`
    * `policy_id` - The policy's UUID
    * `opts` - Optional keyword list: `:offset`, `:limit`, `:filter`

  ## Examples

      iex> BambooHR.Breaks.list_policy_breaks(client, "0f8c...")
      {:ok, %{"data" => [%{"id" => "7b21...", "name" => "Meal break", "duration" => 30}]}}
  """
  @spec list_policy_breaks(Client.t(), String.t(), keyword()) :: Client.response()
  def list_policy_breaks(client, policy_id, opts \\ []) when is_binary(policy_id) do
    Client.get("/time-tracking/break-policies/#{policy_id}/breaks", client,
      params: list_params(opts)
    )
  end

  @doc """
  Creates a break on a break policy.

  ## Parameters

    * `client` - Client configuration created with `BambooHR.Client.new/1`
    * `policy_id` - The policy's UUID
    * `break_data` - Map with `"name"`, `"duration"`, `"paid"` and the
      `"availability*"` fields

  ## Examples

      iex> break_data = %{"name" => "Meal break", "duration" => 30, "paid" => false}
      iex> BambooHR.Breaks.create_policy_break(client, "0f8c...", break_data)
      {:ok, %{"id" => "7b21...", "name" => "Meal break"}}
  """
  @spec create_policy_break(Client.t(), String.t(), map()) :: Client.response()
  def create_policy_break(client, policy_id, break_data)
      when is_binary(policy_id) and is_map(break_data) do
    Client.post("/time-tracking/break-policies/#{policy_id}/breaks", client, json: break_data)
  end

  @doc """
  Replaces every break on a break policy.

  Breaks with an `"id"` are updated, those without are created, and any
  existing break left out of the list is deleted.

  ## Parameters

    * `client` - Client configuration created with `BambooHR.Client.new/1`
    * `policy_id` - The policy's UUID
    * `breaks` - The complete list of breaks for the policy

  ## Examples

      iex> breaks = [%{"name" => "Meal break", "duration" => 30, "paid" => false}]
      iex> BambooHR.Breaks.replace_policy_breaks(client, "0f8c...", breaks)
      {:ok, %{"data" => [%{"id" => "7b21...", "name" => "Meal break"}]}}
  """
  @spec replace_policy_breaks(Client.t(), String.t(), list(map())) :: Client.response()
  def replace_policy_breaks(client, policy_id, breaks)
      when is_binary(policy_id) and is_list(breaks) do
    Client.put("/time-tracking/break-policies/#{policy_id}/breaks", client, json: breaks)
  end

  @doc """
  Retrieves a break.

  ## Parameters

    * `client` - Client configuration created with `BambooHR.Client.new/1`
    * `break_id` - The break's UUID

  ## Examples

      iex> BambooHR.Breaks.get_break(client, "7b21...")
      {:ok, %{"id" => "7b21...", "name" => "Meal break", "duration" => 30}}
  """
  @spec get_break(Client.t(), String.t()) :: Client.response()
  def get_break(client, break_id) when is_binary(break_id) do
    Client.get("/time-tracking/breaks/#{break_id}", client)
  end

  @doc """
  Updates a break.

  Only the fields given are changed.

  ## Parameters

    * `client` - Client configuration created with `BambooHR.Client.new/1`
    * `break_id` - The break's UUID
    * `changes` - Map of fields to change: `"name"`, `"policyId"`,
      `"paid"`, `"duration"`, and the `"availability*"` fields

  ## Examples

      iex> BambooHR.Breaks.update_break(client, "7b21...", %{"duration" => 45})
      {:ok, %{"id" => "7b21...", "duration" => 45}}
  """
  @spec update_break(Client.t(), String.t(), map()) :: Client.response()
  def update_break(client, break_id, changes) when is_binary(break_id) and is_map(changes) do
    Client.patch("/time-tracking/breaks/#{break_id}", client, json: changes)
  end

  @doc """
  Deletes a break.

  The break is removed from any policy it belonged to. On success,
  returns `nil` (no response body).

  ## Parameters

    * `client` - Client configuration created with `BambooHR.Client.new/1`
    * `break_id` - The break's UUID

  ## Examples

      iex> BambooHR.Breaks.delete_break(client, "7b21...")
      {:ok, nil}
  """
  @spec delete_break(Client.t(), String.t()) :: Client.response()
  def delete_break(client, break_id) when is_binary(break_id) do
    Client.delete("/time-tracking/breaks/#{break_id}", client)
  end

  @doc """
  Lists the employees assigned to a break policy.

  A policy with no assignments returns an empty `"data"` list rather than
  an error.

  ## Parameters

    * `client` - Client configuration created with `BambooHR.Client.new/1`
    * `policy_id` - The policy's UUID
    * `opts` - Optional keyword list: `:offset`, `:limit`

  ## Examples

      iex> BambooHR.Breaks.list_policy_employees(client, "0f8c...")
      {:ok, %{"data" => [%{"employeeId" => 123}]}}
  """
  @spec list_policy_employees(Client.t(), String.t(), keyword()) :: Client.response()
  def list_policy_employees(client, policy_id, opts \\ []) when is_binary(policy_id) do
    Client.get("/time-tracking/break-policies/#{policy_id}/employees", client,
      params: list_params(opts)
    )
  end

  @doc """
  Adds employees to a break policy, keeping the existing assignments.

  On success, returns `nil` (no response body).

  ## Parameters

    * `client` - Client configuration created with `BambooHR.Client.new/1`
    * `policy_id` - The policy's UUID
    * `employee_ids` - List of employee IDs to add

  ## Examples

      iex> BambooHR.Breaks.assign_employees(client, "0f8c...", [123, 124])
      {:ok, nil}
  """
  @spec assign_employees(Client.t(), String.t(), list(integer())) :: Client.response()
  def assign_employees(client, policy_id, employee_ids)
      when is_binary(policy_id) and is_list(employee_ids) do
    Client.post("/time-tracking/break-policies/#{policy_id}/assign", client,
      json: %{"employeeIds" => employee_ids}
    )
  end

  @doc """
  Replaces the employees assigned to a break policy.

  Anyone not in `employee_ids` is unassigned. Use `assign_employees/3` to
  add without removing. On success, returns `nil` (no response body).

  ## Parameters

    * `client` - Client configuration created with `BambooHR.Client.new/1`
    * `policy_id` - The policy's UUID
    * `employee_ids` - The complete list of employee IDs for the policy

  ## Examples

      iex> BambooHR.Breaks.set_employees(client, "0f8c...", [123])
      {:ok, nil}
  """
  @spec set_employees(Client.t(), String.t(), list(integer())) :: Client.response()
  def set_employees(client, policy_id, employee_ids)
      when is_binary(policy_id) and is_list(employee_ids) do
    Client.put("/time-tracking/break-policies/#{policy_id}/assign", client,
      json: %{"employeeIds" => employee_ids}
    )
  end

  @doc """
  Removes employees from a break policy.

  Only works on policies that are not assigned to every employee. On
  success, returns `nil` (no response body).

  ## Parameters

    * `client` - Client configuration created with `BambooHR.Client.new/1`
    * `policy_id` - The policy's UUID
    * `employee_ids` - List of employee IDs to remove

  ## Examples

      iex> BambooHR.Breaks.unassign_employees(client, "0f8c...", [124])
      {:ok, nil}
  """
  @spec unassign_employees(Client.t(), String.t(), list(integer())) :: Client.response()
  def unassign_employees(client, policy_id, employee_ids)
      when is_binary(policy_id) and is_list(employee_ids) do
    Client.post("/time-tracking/break-policies/#{policy_id}/unassign", client,
      json: %{"employeeIds" => employee_ids}
    )
  end

  @doc """
  Lists the break policies assigned to an employee.

  Needs permission to view that employee as well as break access.

  ## Parameters

    * `client` - Client configuration created with `BambooHR.Client.new/1`
    * `employee_id` - The employee's ID
    * `opts` - Optional keyword list: `:offset`, `:limit`

  ## Examples

      iex> BambooHR.Breaks.list_employee_policies(client, 123)
      {:ok, %{"data" => [%{"id" => "0f8c...", "name" => "California meal breaks"}]}}
  """
  @spec list_employee_policies(Client.t(), integer(), keyword()) :: Client.response()
  def list_employee_policies(client, employee_id, opts \\ []) when is_integer(employee_id) do
    Client.get("/time-tracking/employees/#{employee_id}/break-policies", client,
      params: list_params(opts)
    )
  end

  @doc """
  Lists an employee's break availabilities.

  ## Parameters

    * `client` - Client configuration created with `BambooHR.Client.new/1`
    * `employee_id` - The employee's ID
    * `opts` - Optional keyword list: `:effective`, the date to report
      availability as of

  ## Examples

      iex> BambooHR.Breaks.list_employee_break_availabilities(client, 123)
      {:ok, %{"data" => [%{"breakId" => "7b21...", "available" => true}]}}
  """
  @spec list_employee_break_availabilities(Client.t(), integer(), keyword()) :: Client.response()
  def list_employee_break_availabilities(client, employee_id, opts \\ [])
      when is_integer(employee_id) do
    Client.get("/time-tracking/employees/#{employee_id}/break-availabilities", client,
      params: list_params(opts)
    )
  end

  @doc """
  Lists break assessments.

  An assessment records whether an employee complied with their break
  policy on a given day, along with any violations.

  ## Parameters

    * `client` - Client configuration created with `BambooHR.Client.new/1`
    * `opts` - Optional keyword list: `:offset`, `:limit`, `:filter`

  ## Examples

      iex> BambooHR.Breaks.list_assessments(client, filter: "employeeId eq 123")
      {:ok, %{"data" => [%{"employeeId" => 123, "date" => "2024-01-15", "result" => "COMPLIANT"}]}}
  """
  @spec list_assessments(Client.t(), keyword()) :: Client.response()
  def list_assessments(client, opts \\ []) do
    Client.get("/time-tracking/break-assessments", client, params: list_params(opts))
  end

  defp list_params(opts) do
    for {key, param} <- [
          offset: "offset",
          limit: "limit",
          filter: "filter",
          include_counts: "includeCounts",
          effective: "effective"
        ],
        value = opts[key] do
      {param, value}
    end
  end
end
