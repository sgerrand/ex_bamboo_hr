defmodule BambooHR.TimeOff do
  @moduledoc """
  Functions for interacting with time off resources in the BambooHR API.

  Covers employee time off policies, balances, requests, and history.
  Company-wide time off metadata (types, policy list) lives in
  `BambooHR.Metadata`.

  ## Two families of request endpoints

  BambooHR has two current sets of time off request endpoints, and this
  module covers both.

  The older ones are employee-scoped and take their parameters as plain
  maps: `create_time_off_request/3`, `get_time_off_requests/2` and
  `get_who_is_out/2`.

  The newer `/time-off/requests` family (note the hyphen) treats a
  request as a resource: `list_requests/2`, `create_request/2`,
  `get_request/3`, `update_request/4`, the decisions `approve_request/3`,
  `deny_request/3` and `cancel_request/2`, and comments. `list_whos_out/4`
  belongs with them. They page with `:page` and `:page_size` and filter
  with an OData-style `:filter` string, and the request list sorts with
  `:order_by`.

  Neither family is deprecated.

  ## Request ids can change

  Editing a request that is still `REQUESTED` replaces it with a new one
  and restarts its approval workflow. **The response carries a new id**,
  and the old id returns a `410` error — reason `:gone` — from then on.
  Always keep the id from the latest response. See `update_request/4`.
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

  @doc """
  Lists time off requests, one page at a time.

  ## Parameters

    * `client` - Client configuration created with `BambooHR.Client.new/1`
    * `opts` - Optional keyword list:
      * `:filter` - OData filter, e.g. `"status eq 'REQUESTED'"`
      * `:order_by` - e.g. `"startDate asc"`; defaults to
        `"requestedAt desc"`
      * `:page`, `:page_size` (defaults to 100)
      * `:return_actions` - when `true`, each request carries a
        `"_links"` block naming the state changes you may make to it

  ## Examples

      iex> BambooHR.TimeOff.list_requests(client, filter: "employeeId eq 123")
      {:ok, %{
        "data" => [%{"id" => 1348, "employeeId" => 123, "status" => "REQUESTED"}],
        "meta" => %{"page" => 1, "pageSize" => 100, "totalItems" => 1, "totalPages" => 1}
      }}
  """
  @spec list_requests(Client.t(), keyword()) :: Client.response()
  def list_requests(client, opts \\ []) do
    Client.get("/time-off/requests", client,
      params:
        rest_params(opts,
          filter: "filter",
          order_by: "orderBy",
          page: "page",
          page_size: "pageSize",
          return_actions: "returnActions"
        )
    )
  end

  @doc """
  Creates a time off request on an employee's behalf.

  The request starts as `"REQUESTED"` and enters the approval workflow.

  Send **exactly one** of `"amount"` — the total for the whole range, in
  the category's unit — or `"dailyAmounts"`, a per-day breakdown. Both,
  or neither, is a `422` error.

  ## Parameters

    * `client` - Client configuration created with `BambooHR.Client.new/1`
    * `request_data` - Map with `"employeeId"`, `"categoryId"`,
      `"startDate"` and `"endDate"` (inclusive, `YYYY-MM-DD`), one of
      `"amount"` or `"dailyAmounts"`, and optionally `"employeeNote"` (up
      to 1024 characters)
    * `opts` - Optional keyword list: `:return_actions`

  ## Examples

      iex> request_data = %{
      ...>   "employeeId" => 123,
      ...>   "categoryId" => 4,
      ...>   "startDate" => "2024-02-01",
      ...>   "endDate" => "2024-02-02",
      ...>   "amount" => 16
      ...> }
      iex> BambooHR.TimeOff.create_request(client, request_data)
      {:ok, %{"id" => 1348, "status" => "REQUESTED", "amount" => 16}}
  """
  @spec create_request(Client.t(), map(), keyword()) :: Client.response()
  def create_request(client, request_data, opts \\ []) when is_map(request_data) do
    Client.post("/time-off/requests", client,
      json: request_data,
      params: rest_params(opts, return_actions: "returnActions")
    )
  end

  @doc """
  Retrieves a time off request.

  An id that a later edit replaced returns a `410` error — reason
  `:gone`. See `update_request/4`.

  ## Parameters

    * `client` - Client configuration created with `BambooHR.Client.new/1`
    * `request_id` - The request's ID
    * `opts` - Optional keyword list: `:return_actions`

  ## Examples

      iex> BambooHR.TimeOff.get_request(client, 1348)
      {:ok, %{"id" => 1348, "employeeId" => 123, "status" => "REQUESTED"}}
  """
  @spec get_request(Client.t(), integer(), keyword()) :: Client.response()
  def get_request(client, request_id, opts \\ []) when is_integer(request_id) do
    Client.get("/time-off/requests/#{request_id}", client,
      params: rest_params(opts, return_actions: "returnActions")
    )
  end

  @doc """
  Updates a time off request.

  Only the fields you pass are changed, and `"employeeNote" => nil`
  clears the note.

  **Editing a `"REQUESTED"` request gives it a new id.** BambooHR
  replaces the stored request and restarts its approval workflow, so the
  `"id"` in the response differs from `request_id`. That new id is the
  one to keep: the old one returns a `410` error — reason `:gone` — on
  every call from then on. `"requestedAt"` carries over. Editing an
  `"APPROVED"` request updates it in place, keeping both the id and
  `"requestedAt"`.

  Changing `"startDate"` or `"endDate"` means sending `"dailyAmounts"` in
  the same call, covering the new range — BambooHR will not spread the
  amount for you, and returns a `422` error otherwise.

  A `"DENIED"` or `"CANCELED"` request cannot be edited, nor can an
  `"APPROVED"` one that has already started unless you may edit past
  requests; each returns a `409` error.

  ## Parameters

    * `client` - Client configuration created with `BambooHR.Client.new/1`
    * `request_id` - The request's ID
    * `changes` - Map of fields to change: `"categoryId"`, `"startDate"`,
      `"endDate"`, `"employeeNote"`, `"dailyAmounts"`
    * `opts` - Optional keyword list: `:return_actions`

  ## Examples

      iex> {:ok, %{"id" => new_id}} =
      ...>   BambooHR.TimeOff.update_request(client, 1348, %{"employeeNote" => "Family trip"})
      iex> new_id
      1351
  """
  @spec update_request(Client.t(), integer(), map(), keyword()) :: Client.response()
  def update_request(client, request_id, changes, opts \\ [])
      when is_integer(request_id) and is_map(changes) do
    Client.patch("/time-off/requests/#{request_id}", client,
      json: changes,
      params: rest_params(opts, return_actions: "returnActions")
    )
  end

  @doc """
  Lists the comments on a time off request.

  ## Parameters

    * `client` - Client configuration created with `BambooHR.Client.new/1`
    * `request_id` - The request's ID

  ## Examples

      iex> BambooHR.TimeOff.list_request_comments(client, 1348)
      {:ok, %{"data" => [%{"id" => 7, "employeeId" => 5, "comment" => "Covered by Sam."}]}}
  """
  @spec list_request_comments(Client.t(), integer()) :: Client.response()
  def list_request_comments(client, request_id) when is_integer(request_id) do
    Client.get("/time-off/requests/#{request_id}/comments", client)
  end

  @doc """
  Adds a comment to a time off request.

  ## Parameters

    * `client` - Client configuration created with `BambooHR.Client.new/1`
    * `request_id` - The request's ID
    * `comment` - The comment text

  ## Examples

      iex> BambooHR.TimeOff.create_request_comment(client, 1348, "Covered by Sam.")
      {:ok, %{"id" => 7, "employeeId" => 5, "comment" => "Covered by Sam."}}
  """
  @spec create_request_comment(Client.t(), integer(), String.t()) :: Client.response()
  def create_request_comment(client, request_id, comment)
      when is_integer(request_id) and is_binary(comment) do
    Client.post("/time-off/requests/#{request_id}/comments", client,
      json: %{"comment" => comment}
    )
  end

  @doc """
  Lists approved time off overlapping a date range.

  Dates are inclusive, in the company timezone, and the range can span at
  most 366 days. Results are sorted by start date, then id.

  Time off the caller is not allowed to see is **left out without any
  error**, so an empty result does not mean nobody is out.

  ## Parameters

    * `client` - Client configuration created with `BambooHR.Client.new/1`
    * `start_date` - First day, as `YYYY-MM-DD`
    * `end_date` - Last day, as `YYYY-MM-DD`
    * `opts` - Optional keyword list:
      * `:filter` - OData filter on `employeeId`, `department`,
        `division` or `location`, using `eq`, `in` and `and`
      * `:direct_reports_only` - only the caller's direct reports; a
        caller with none gets an empty result
      * `:include_persons` - add a `"persons"` map of employee display
        data, keyed by employee id
      * `:page`, `:page_size` (defaults to 100)

  ## Examples

      iex> BambooHR.TimeOff.list_whos_out(client, "2024-02-01", "2024-02-07", include_persons: true)
      {:ok, %{
        "data" => [%{"id" => 1, "employeeId" => 123, "start" => "2024-02-01", "end" => "2024-02-02"}],
        "persons" => %{"123" => %{"displayName" => "Jane Smith"}},
        "meta" => %{"page" => 1, "pageSize" => 100, "totalItems" => 1, "totalPages" => 1}
      }}
  """
  @spec list_whos_out(Client.t(), String.t(), String.t(), keyword()) :: Client.response()
  def list_whos_out(client, start_date, end_date, opts \\ [])
      when is_binary(start_date) and is_binary(end_date) do
    params =
      [{"start", start_date}, {"end", end_date}] ++
        rest_params(opts,
          filter: "filter",
          direct_reports_only: "directReportsOnly",
          include_persons: "includePersons",
          page: "page",
          page_size: "pageSize"
        )

    Client.get("/whos-out", client, params: params)
  end

  # Maps keyword options onto the query parameter names the newer
  # endpoints use. A nil or false option is left out, which matches each
  # parameter's default.
  defp rest_params(opts, mapping) do
    for {key, param} <- mapping, value = opts[key], do: {param, value}
  end
end
