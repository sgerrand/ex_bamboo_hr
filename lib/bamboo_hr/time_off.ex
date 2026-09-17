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

  Uses the `v1.1` endpoint, which includes every policy type — accruing,
  manual, and unlimited.

  ## Parameters

    * `client` - Client configuration created with `BambooHR.Client.new/1`
    * `employee_id` - The ID of the employee

  ## Examples

      iex> BambooHR.TimeOff.get_employee_policies(client, 123)
      {:ok, [%{"timeOffPolicyId" => 4, "timeOffTypeId" => 1, "accrualStartDate" => "2024-02-01"}]}
  """
  @spec get_employee_policies(Client.t(), integer()) :: Client.response()
  def get_employee_policies(client, employee_id) when is_integer(employee_id) do
    Client.get("/employees/#{employee_id}/time_off/policies", client, api_version: "v1_1")
  end

  @doc """
  Assigns time off policies to an employee.

  Uses the `v1.1` endpoint. A `nil` `accrualStartDate` removes an existing
  assignment. On success, returns the current list of assigned policies,
  including manual and unlimited policy types.

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
    Client.put("/employees/#{employee_id}/time_off/policies", client,
      json: policies,
      api_version: "v1_1"
    )
  end

  @doc """
  Retrieves the time off policies currently assigned to an employee.

  Same as `get_employee_policies/2`, which now calls the `v1.1` endpoint.
  """
  @deprecated "Use get_employee_policies/2 instead"
  @spec get_employee_policies_v1_1(Client.t(), integer()) :: Client.response()
  defdelegate get_employee_policies_v1_1(client, employee_id),
    to: __MODULE__,
    as: :get_employee_policies

  @doc """
  Assigns time off policies to an employee.

  Same as `assign_employee_policies/3`, which now calls the `v1.1` endpoint.
  """
  @deprecated "Use assign_employee_policies/3 instead"
  @spec assign_employee_policies_v1_1(Client.t(), integer(), list(map())) :: Client.response()
  defdelegate assign_employee_policies_v1_1(client, employee_id, policies),
    to: __MODULE__,
    as: :assign_employee_policies

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
  Approves a time off request.

  Completes the caller's step in the approval chain, or every remaining
  step when `"bypass"` is `true`. The request stays in `REQUESTED` status
  while further approvals are outstanding. On success, returns the updated
  request.

  ## Parameters

    * `client` - Client configuration created with `BambooHR.Client.new/1`
    * `request_id` - The ID of the time off request to approve
    * `approval_data` - Optional map with `"managerNote"` (up to 1024
      characters) and `"bypass"`

  ## Examples

      iex> BambooHR.TimeOff.approve_request(client, 1348, %{"managerNote" => "Enjoy!"})
      {:ok, %{"id" => 1348, "status" => "APPROVED"}}
  """
  @spec approve_request(Client.t(), integer(), map()) :: Client.response()
  def approve_request(client, request_id, approval_data \\ %{}) when is_integer(request_id) do
    Client.post("/time-off/requests/#{request_id}/approvals", client, json: approval_data)
  end

  @doc """
  Denies a time off request.

  A denial is final: it completes the caller's step and discards the
  remaining steps in the approval chain, so the request always ends up in
  `DENIED` status. `"bypass"` changes who may deny, not what denying does —
  without it the caller must be a current approver, and denying off-step
  returns a `409` error. On success, returns the updated request.

  ## Parameters

    * `client` - Client configuration created with `BambooHR.Client.new/1`
    * `request_id` - The ID of the time off request to deny
    * `denial_data` - Optional map with `"managerNote"` (up to 1024
      characters) and `"bypass"`

  ## Examples

      iex> BambooHR.TimeOff.deny_request(client, 1348, %{"managerNote" => "Need coverage."})
      {:ok, %{"id" => 1348, "status" => "DENIED"}}
  """
  @spec deny_request(Client.t(), integer(), map()) :: Client.response()
  def deny_request(client, request_id, denial_data \\ %{}) when is_integer(request_id) do
    Client.post("/time-off/requests/#{request_id}/denials", client, json: denial_data)
  end

  @doc """
  Cancels a time off request.

  Open to the employee who requested the time off and to anyone who can
  manage it. A request can be cancelled while it is `REQUESTED`, and after
  approval only while it has not started yet. On success, returns the
  updated request.

  ## Parameters

    * `client` - Client configuration created with `BambooHR.Client.new/1`
    * `request_id` - The ID of the time off request to cancel

  ## Examples

      iex> BambooHR.TimeOff.cancel_request(client, 1348)
      {:ok, %{"id" => 1348, "status" => "CANCELED"}}
  """
  @spec cancel_request(Client.t(), integer()) :: Client.response()
  def cancel_request(client, request_id) when is_integer(request_id) do
    Client.post("/time-off/requests/#{request_id}/cancellations", client, json: %{})
  end

  @doc """
  Updates the status of an existing time off request.

  Routes to `approve_request/3`, `deny_request/3`, or `cancel_request/2`
  based on `"status"`, and passes `"note"` through as `"managerNote"`.
  Those endpoints return the updated request, where this one used to
  return an empty body. An unrecognised status returns
  `{:error, {:invalid_status, status}}`.

  ## Parameters

    * `client` - Client configuration created with `BambooHR.Client.new/1`
    * `request_id` - The ID of the time off request to update
    * `status_data` - Map with `"status"` (and optionally `"note"`)

  ## Examples

      iex> BambooHR.TimeOff.change_request_status(client, 1348, %{"status" => "approved"})
      {:ok, %{"id" => 1348, "status" => "APPROVED"}}
  """
  @deprecated "Use approve_request/3, deny_request/3, or cancel_request/2 instead"
  @spec change_request_status(Client.t(), integer(), map()) :: Client.response()
  def change_request_status(client, request_id, status_data) when is_integer(request_id) do
    case Map.get(status_data, "status") do
      "approved" ->
        approve_request(client, request_id, manager_note(status_data))

      status when status in ["denied", "declined"] ->
        deny_request(client, request_id, manager_note(status_data))

      status when status in ["canceled", "cancelled"] ->
        cancel_request(client, request_id)

      status ->
        {:error, {:invalid_status, status}}
    end
  end

  defp manager_note(status_data) do
    case Map.fetch(status_data, "note") do
      {:ok, note} -> %{"managerNote" => note}
      :error -> %{}
    end
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
