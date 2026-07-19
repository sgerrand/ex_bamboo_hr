defmodule BambooHR.TimeOff do
  @moduledoc """
  Functions for interacting with time off resources in the BambooHR API.

  Covers employee time off policies, balances, requests, and history.
  Company-wide time off metadata (types, policy list) lives in
  `BambooHR.Metadata`.
  """

  alias BambooHR.Client

  @doc """
  Retrieves the time off policies currently assigned to an employee.

  ## Parameters

    * `client` - Client configuration created with `BambooHR.Client.new/1`
    * `employee_id` - The ID of the employee

  ## Examples

      iex> BambooHR.TimeOff.get_employee_policies(client, 123)
      {:ok, [%{"timeOffPolicyId" => 4, "timeOffTypeId" => 1, "accrualStartDate" => "2024-02-01"}]}
  """
  @spec get_employee_policies(Client.t(), integer()) :: Client.response()
  def get_employee_policies(client, employee_id) when is_integer(employee_id) do
    Client.get("/employees/#{employee_id}/time_off/policies", client)
  end

  @doc """
  Assigns time off policies to an employee.

  A `nil` `accrualStartDate` removes an existing assignment. On success,
  returns the current list of assigned policies.

  ## Parameters

    * `client` - Client configuration created with `BambooHR.Client.new/1`
    * `employee_id` - The ID of the employee to assign policies to
    * `policies` - List of maps with `"timeOffPolicyId"` and `"accrualStartDate"`

  ## Examples

      iex> policies = [%{"timeOffPolicyId" => 4, "accrualStartDate" => "2024-02-01"}]
      iex> BambooHR.TimeOff.assign_employee_policies(client, 123, policies)
      {:ok, [%{"timeOffPolicyId" => 4, "timeOffTypeId" => 1, "accrualStartDate" => "2024-02-01"}]}
  """
  @spec assign_employee_policies(Client.t(), integer(), list(map())) :: Client.response()
  def assign_employee_policies(client, employee_id, policies)
      when is_integer(employee_id) and is_list(policies) do
    Client.put("/employees/#{employee_id}/time_off/policies", client, json: policies)
  end

  @doc """
  Retrieves the time off policies currently assigned to an employee,
  including manual and unlimited policy types.

  Same endpoint as `get_employee_policies/2`, but the `v1.1` version — `v1`
  silently excludes manual and unlimited (non-accruing) policy types from
  the response; this includes them.

  ## Parameters

    * `client` - Client configuration created with `BambooHR.Client.new/1`
    * `employee_id` - The ID of the employee

  ## Examples

      iex> BambooHR.TimeOff.get_employee_policies_v1_1(client, 123)
      {:ok, [%{"timeOffPolicyId" => 4, "timeOffTypeId" => 1, "accrualStartDate" => nil}]}
  """
  @spec get_employee_policies_v1_1(Client.t(), integer()) :: Client.response()
  def get_employee_policies_v1_1(client, employee_id) when is_integer(employee_id) do
    Client.get("/employees/#{employee_id}/time_off/policies", client, api_version: "v1_1")
  end

  @doc """
  Assigns time off policies to an employee, including manual and unlimited
  policy types.

  Same endpoint as `assign_employee_policies/3`, but the `v1.1` version —
  `v1` silently excludes manual and unlimited (non-accruing) policy types
  from the response; this includes them. A `nil` `accrualStartDate` removes
  an existing assignment. On success, returns the current list of assigned
  policies.

  ## Parameters

    * `client` - Client configuration created with `BambooHR.Client.new/1`
    * `employee_id` - The ID of the employee to assign policies to
    * `policies` - List of maps with `"timeOffPolicyId"` and `"accrualStartDate"`

  ## Examples

      iex> policies = [%{"timeOffPolicyId" => 4, "accrualStartDate" => "2024-02-01"}]
      iex> BambooHR.TimeOff.assign_employee_policies_v1_1(client, 123, policies)
      {:ok, [%{"timeOffPolicyId" => 4, "timeOffTypeId" => 1, "accrualStartDate" => "2024-02-01"}]}
  """
  @spec assign_employee_policies_v1_1(Client.t(), integer(), list(map())) :: Client.response()
  def assign_employee_policies_v1_1(client, employee_id, policies)
      when is_integer(employee_id) and is_list(policies) do
    Client.put("/employees/#{employee_id}/time_off/policies", client,
      json: policies,
      api_version: "v1_1"
    )
  end

  @doc """
  Calculates an employee's time off balances across all assigned categories.

  ## Parameters

    * `client` - Client configuration created with `BambooHR.Client.new/1`
    * `employee_id` - The ID of the employee
    * `params` - Optional query params: `"end"` (date to calculate as of, defaults
      to today) and `"precision"` (decimal places, 0-4, defaults to 2)

  ## Examples

      iex> BambooHR.TimeOff.calculate_balances(client, 123)
      {:ok, [%{"timeOffType" => "1", "name" => "Vacation", "units" => "hours", "balance" => "24.50"}]}
  """
  @spec calculate_balances(Client.t(), integer(), map()) :: Client.response()
  def calculate_balances(client, employee_id, params \\ %{}) when is_integer(employee_id) do
    Client.get("/employees/#{employee_id}/time_off/calculator", client, params: params)
  end

  @doc """
  Creates a time off history item for an employee.

  For `"used"` entries, `"timeOffRequestId"` referencing an approved request
  is required. For override (balance adjustment) entries submitted via this
  path, provide `"amount"` and `"timeOffTypeId"` directly.

  ## Parameters

    * `client` - Client configuration created with `BambooHR.Client.new/1`
    * `employee_id` - The ID of the employee
    * `history_data` - Map describing the history item

  ## Examples

      iex> history_data = %{"timeOffRequestId" => 1348}
      iex> BambooHR.TimeOff.add_time_off_history(client, 123, history_data)
      {:ok, %{}}
  """
  @spec add_time_off_history(Client.t(), integer(), map()) :: Client.response()
  def add_time_off_history(client, employee_id, history_data) when is_integer(employee_id) do
    Client.put("/employees/#{employee_id}/time_off/history", client, json: history_data)
  end

  @doc """
  Creates a balance adjustment for an employee's time off type.

  The adjustment is recorded as an override history item. Cannot adjust
  balances for discretionary (unlimited) time off types.

  ## Parameters

    * `client` - Client configuration created with `BambooHR.Client.new/1`
    * `employee_id` - The ID of the employee
    * `adjustment_data` - Map describing the adjustment (time off type, amount, date)

  ## Examples

      iex> adjustment_data = %{"timeOffTypeId" => 1, "amount" => 8, "date" => "2024-01-15"}
      iex> BambooHR.TimeOff.adjust_time_off_balance(client, 123, adjustment_data)
      {:ok, %{}}
  """
  @spec adjust_time_off_balance(Client.t(), integer(), map()) :: Client.response()
  def adjust_time_off_balance(client, employee_id, adjustment_data)
      when is_integer(employee_id) do
    Client.put("/employees/#{employee_id}/time_off/balance_adjustment", client,
      json: adjustment_data
    )
  end

  @doc """
  Creates a time off request for an employee.

  The request can be submitted with a status of `"approved"`, `"denied"`, or
  `"requested"`. Approved and denied requests are recorded directly without
  triggering approval notifications.

  ## Parameters

    * `client` - Client configuration created with `BambooHR.Client.new/1`
    * `employee_id` - The ID of the employee to create the request for
    * `request_data` - Map describing the request (time off type, dates, amount, status)

  ## Examples

      iex> request_data = %{"status" => "approved", "start" => "2024-02-01", "end" => "2024-02-03"}
      iex> BambooHR.TimeOff.create_time_off_request(client, 123, request_data)
      {:ok, %{}}
  """
  @spec create_time_off_request(Client.t(), integer(), map()) :: Client.response()
  def create_time_off_request(client, employee_id, request_data) when is_integer(employee_id) do
    Client.put("/employees/#{employee_id}/time_off/request", client, json: request_data)
  end

  @doc """
  Updates the status of an existing time off request.

  Valid statuses are `"approved"`, `"denied"` (or `"declined"`), and
  `"canceled"`.

  ## Parameters

    * `client` - Client configuration created with `BambooHR.Client.new/1`
    * `request_id` - The ID of the time off request to update
    * `status_data` - Map with `"status"` (and optionally a note)

  ## Examples

      iex> BambooHR.TimeOff.change_request_status(client, 1348, %{"status" => "approved"})
      {:ok, %{}}
  """
  @spec change_request_status(Client.t(), integer(), map()) :: Client.response()
  def change_request_status(client, request_id, status_data) when is_integer(request_id) do
    Client.put("/time_off/requests/#{request_id}/status", client, json: status_data)
  end

  @doc """
  Retrieves time off requests within a date range.

  Both `"start"` and `"end"` are required in `params` (YYYY-MM-DD). The
  search is inclusive: requests whose date range overlaps the query window
  are returned. Results can be filtered by `"status"`, `"employeeId"`,
  `"type"`, or limited via `"action"` (`"view"`, `"approve"`, `"myRequests"`).

  ## Parameters

    * `client` - Client configuration created with `BambooHR.Client.new/1`
    * `params` - Map of query params, must include `"start"` and `"end"`

  ## Examples

      iex> BambooHR.TimeOff.get_time_off_requests(client, %{"start" => "2024-01-01", "end" => "2024-01-31"})
      {:ok, [%{"id" => 1348, "employeeId" => 5, "status" => %{"status" => "approved"}}]}
  """
  @spec get_time_off_requests(Client.t(), map()) :: Client.response()
  def get_time_off_requests(client, params) when is_map(params) do
    Client.get("/time_off/requests", client, params: params)
  end

  @doc """
  Retrieves a date-sorted list of employees who are out and company holidays.

  Defaults to today through 14 days out when `"start"`/`"end"` are omitted
  from `params`.

  ## Parameters

    * `client` - Client configuration created with `BambooHR.Client.new/1`
    * `params` - Optional query params: `"start"`, `"end"`, `"filter"` (set to
      `"off"` to disable the Who's Out visibility filter)

  ## Examples

      iex> BambooHR.TimeOff.get_who_is_out(client)
      {:ok, [%{"id" => 1, "type" => "timeOff", "employeeId" => 5, "name" => "Jane Smith"}]}
  """
  @spec get_who_is_out(Client.t(), map()) :: Client.response()
  def get_who_is_out(client, params \\ %{}) do
    Client.get("/time_off/whos_out", client, params: params)
  end
end
