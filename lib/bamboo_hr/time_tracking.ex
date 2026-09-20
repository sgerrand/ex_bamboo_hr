defmodule BambooHR.TimeTracking do
  @moduledoc """
  Functions for interacting with time tracking resources in the BambooHR API.

  ## Two families of endpoints

  BambooHR has two current sets of time tracking endpoints, and this
  module covers both.

  The older `/time_tracking/*` endpoints work in bulk and are
  employee-scoped: `get_timesheet_entries/2`, `store_clock_entries/2`,
  `clock_in/3`, and `clock_out/3`.

  The newer `/time-tracking/*` endpoints (note the hyphen) are a REST
  surface with one resource per record — clock entries, hour entries and
  timesheets — plus page-based pagination and OData-style filtering. They
  are the ones to reach for when you need to read, correct or delete a
  single entry, or to page through a large range.

  Neither family is deprecated. They address the same underlying records,
  so an entry created through one is visible through the other.

  ## Paging and filtering

  `list_clock_entries/2`, `list_hour_entries/2` and `list_timesheets/2`
  take `:filter`, `:sort`, `:page` and `:page_size`. `:filter` and
  `:sort` are OData-style strings passed straight through, e.g.
  `filter: "employeeId eq 123"`, `sort: "start desc"`. Page size defaults
  to 50 and caps at 200. Clock and hour entries also need at least 10;
  a smaller `:page_size` returns a `422` error.
  """

  alias BambooHR.Client

  @doc """
  Retrieves timesheet entries within a specified date range.

  ## Parameters

    * `client` - Client configuration created with `BambooHR.Client.new/1`
    * `params` - Map containing query parameters (start, end dates, and optional employee IDs)

  ## Examples

      iex> params = %{
      ...>   "start" => "2024-01-01",
      ...>   "end" => "2024-01-31",
      ...>   "employeeIds" => "123,124"
      ...> }
      iex> BambooHR.TimeTracking.get_timesheet_entries(client, params)
      {:ok, %{
        "entries" => [
          %{
            "id" => "1",
            "employeeId" => "123",
            "date" => "2024-01-15",
            "hours" => 8.0
          }
        ]
      }}
  """
  @spec get_timesheet_entries(Client.t(), map()) :: Client.response()
  def get_timesheet_entries(client, params) do
    Client.get("/time_tracking/timesheet_entries", client, params: params)
  end

  @doc """
  Stores timesheet clock entries for employees.

  ## Parameters

    * `client` - Client configuration created with `BambooHR.Client.new/1`
    * `entries` - List of clock entry maps containing employee ID, date, start and end times

  ## Examples

      iex> entries = [
      ...>   %{
      ...>     "employeeId" => "123",
      ...>     "date" => "2024-01-15",
      ...>     "start" => "09:00:00",
      ...>     "end" => "17:00:00"
      ...>   }
      ...> ]
      iex> BambooHR.TimeTracking.store_clock_entries(client, entries)
      {:ok, %{"message" => "Entries stored successfully"}}
  """
  @spec store_clock_entries(Client.t(), list(map())) :: Client.response()
  def store_clock_entries(client, entries) do
    Client.post("/time_tracking/clock_entries/store", client, json: %{items: entries})
  end

  @doc """
  Records a clock-in event for an employee.

  ## Parameters

    * `client` - Client configuration created with `BambooHR.Client.new/1`
    * `employee_id` - The ID of the employee to clock in
    * `clock_data` - Map containing clock-in details (date, start time, timezone, etc.)

  ## Examples

      iex> clock_data = %{
      ...>   "date" => "2024-01-15",
      ...>   "start" => "09:00",
      ...>   "timezone" => "America/New_York"
      ...> }
      iex> BambooHR.TimeTracking.clock_in(client, 123, clock_data)
      {:ok, %{"message" => "Successfully clocked in"}}
  """
  @spec clock_in(Client.t(), integer(), map()) :: Client.response()
  def clock_in(client, employee_id, clock_data) when is_integer(employee_id) do
    Client.post("/time_tracking/employees/#{employee_id}/clock_in", client, json: clock_data)
  end

  @doc """
  Records a clock-out event for an employee.

  ## Parameters

    * `client` - Client configuration created with `BambooHR.Client.new/1`
    * `employee_id` - The ID of the employee to clock out
    * `clock_data` - Map containing clock-out details (date, end time, timezone)

  ## Examples

      iex> clock_data = %{
      ...>   "date" => "2024-01-15",
      ...>   "end" => "17:00",
      ...>   "timezone" => "America/New_York"
      ...> }
      iex> BambooHR.TimeTracking.clock_out(client, 123, clock_data)
      {:ok, %{"message" => "Successfully clocked out"}}
  """
  @spec clock_out(Client.t(), integer(), map()) :: Client.response()
  def clock_out(client, employee_id, clock_data) when is_integer(employee_id) do
    Client.post("/time_tracking/employees/#{employee_id}/clock_out", client, json: clock_data)
  end

  @doc """
  Lists clock entries, one page at a time.

  ## Parameters

    * `client` - Client configuration created with `BambooHR.Client.new/1`
    * `opts` - Optional keyword list: `:filter`, `:sort`, `:page`,
      `:page_size`. Filterable fields are `timesheetId`, `employeeId`,
      `start` and `end`; sortable are `start`, `end` and `updatedAt`,
      defaulting to `start desc`.

  ## Examples

      iex> BambooHR.TimeTracking.list_clock_entries(client, filter: "employeeId eq 123")
      {:ok, %{
        "data" => [%{"id" => 1, "employeeId" => 123, "start" => "2024-01-15T09:00:00-05:00"}],
        "meta" => %{"page" => 1, "pageSize" => 50, "totalItems" => 1, "totalPages" => 1}
      }}
  """
  @spec list_clock_entries(Client.t(), keyword()) :: Client.response()
  def list_clock_entries(client, opts \\ []) do
    Client.get("/time-tracking/clock-entries", client, params: list_params(opts))
  end

  @doc """
  Creates a clock entry.

  For corrections and retroactive entries; use `create_clock_in/2` to
  clock someone in right now. The parent daily entry and timesheet are
  worked out from `"start"` and `"timezone"`, and created if needed. A
  `409` error means the resolved timesheet does not accept clock entries.

  ## Parameters

    * `client` - Client configuration created with `BambooHR.Client.new/1`
    * `entry_data` - Map with `"employeeId"`, `"start"`, `"end"` and
      `"timezone"`, and optionally `"note"`, `"projectId"`, `"taskId"`,
      `"clockInLocation"`, `"clockOutLocation"`

  ## Examples

      iex> entry_data = %{
      ...>   "employeeId" => 123,
      ...>   "start" => "2024-01-15T09:00:00-05:00",
      ...>   "end" => "2024-01-15T17:00:00-05:00",
      ...>   "timezone" => "America/New_York"
      ...> }
      iex> BambooHR.TimeTracking.create_clock_entry(client, entry_data)
      {:ok, %{"id" => 1, "employeeId" => 123}}
  """
  @spec create_clock_entry(Client.t(), map()) :: Client.response()
  def create_clock_entry(client, entry_data) when is_map(entry_data) do
    Client.post("/time-tracking/clock-entries", client, json: entry_data)
  end

  @doc """
  Retrieves a single clock entry.

  Geolocation comes back as `nil` when the employee's configuration has
  it switched off.

  ## Parameters

    * `client` - Client configuration created with `BambooHR.Client.new/1`
    * `entry_id` - The ID of the clock entry

  ## Examples

      iex> BambooHR.TimeTracking.get_clock_entry(client, 1)
      {:ok, %{"id" => 1, "employeeId" => 123, "start" => "2024-01-15T09:00:00-05:00"}}
  """
  @spec get_clock_entry(Client.t(), integer()) :: Client.response()
  def get_clock_entry(client, entry_id) when is_integer(entry_id) do
    Client.get("/time-tracking/clock-entries/#{entry_id}", client)
  end

  @doc """
  Updates a clock entry.

  Only the fields given are changed; anything left out keeps its value.

  ## Parameters

    * `client` - Client configuration created with `BambooHR.Client.new/1`
    * `entry_id` - The ID of the clock entry to update
    * `changes` - Map of the fields to change: `"start"`, `"end"`,
      `"timezone"`, `"note"`, `"projectId"`, `"taskId"`,
      `"clockInLocation"`, `"clockOutLocation"`

  ## Examples

      iex> BambooHR.TimeTracking.update_clock_entry(client, 1, %{"note" => "Corrected"})
      {:ok, %{"id" => 1, "note" => "Corrected"}}
  """
  @spec update_clock_entry(Client.t(), integer(), map()) :: Client.response()
  def update_clock_entry(client, entry_id, changes)
      when is_integer(entry_id) and is_map(changes) do
    Client.patch("/time-tracking/clock-entries/#{entry_id}", client, json: changes)
  end

  @doc """
  Deletes a clock entry.

  On success, returns `nil` (no response body).

  ## Parameters

    * `client` - Client configuration created with `BambooHR.Client.new/1`
    * `entry_id` - The ID of the clock entry to delete

  ## Examples

      iex> BambooHR.TimeTracking.delete_clock_entry(client, 1)
      {:ok, nil}
  """
  @spec delete_clock_entry(Client.t(), integer()) :: Client.response()
  def delete_clock_entry(client, entry_id) when is_integer(entry_id) do
    Client.delete("/time-tracking/clock-entries/#{entry_id}", client)
  end

  @doc """
  Clocks an employee in at the current server time.

  Creates an open clock entry, one with no `"end"`. Clocking in on behalf
  of someone else needs permission to manage that employee's time.

  ## Parameters

    * `client` - Client configuration created with `BambooHR.Client.new/1`
    * `clock_in_data` - Map with `"employeeId"` and `"timezone"`, and
      optionally `"clockInLocation"`

  ## Examples

      iex> clock_in_data = %{"employeeId" => 123, "timezone" => "America/New_York"}
      iex> BambooHR.TimeTracking.create_clock_in(client, clock_in_data)
      {:ok, %{"id" => 1, "employeeId" => 123, "end" => nil}}
  """
  @spec create_clock_in(Client.t(), map()) :: Client.response()
  def create_clock_in(client, clock_in_data) when is_map(clock_in_data) do
    Client.post("/time-tracking/clock-ins", client, json: clock_in_data)
  end

  @doc """
  Clocks an employee out, closing their open clock entry.

  ## Parameters

    * `client` - Client configuration created with `BambooHR.Client.new/1`
    * `clock_out_data` - Map with `"employeeId"`, and optionally
      `"clockOutLocation"`

  ## Examples

      iex> BambooHR.TimeTracking.create_clock_out(client, %{"employeeId" => 123})
      {:ok, %{"id" => 1, "end" => "2024-01-15T17:00:00-05:00"}}
  """
  @spec create_clock_out(Client.t(), map()) :: Client.response()
  def create_clock_out(client, clock_out_data) when is_map(clock_out_data) do
    Client.post("/time-tracking/clock-outs", client, json: clock_out_data)
  end

  @doc """
  Lists hour entries, one page at a time.

  ## Parameters

    * `client` - Client configuration created with `BambooHR.Client.new/1`
    * `opts` - Optional keyword list: `:filter`, `:sort`, `:page`,
      `:page_size`

  ## Examples

      iex> BambooHR.TimeTracking.list_hour_entries(client, page_size: 10)
      {:ok, %{
        "data" => [%{"id" => 5, "employeeId" => 123, "date" => "2024-01-15", "hours" => 8}],
        "meta" => %{"page" => 1, "pageSize" => 10, "totalItems" => 1, "totalPages" => 1}
      }}
  """
  @spec list_hour_entries(Client.t(), keyword()) :: Client.response()
  def list_hour_entries(client, opts \\ []) do
    Client.get("/time-tracking/hour-entries", client, params: list_params(opts))
  end

  @doc """
  Creates an hour entry.

  ## Parameters

    * `client` - Client configuration created with `BambooHR.Client.new/1`
    * `entry_data` - Map with `"employeeId"`, `"date"` and `"hours"`, and
      optionally `"note"`, `"projectId"`, `"taskId"`

  ## Examples

      iex> entry_data = %{"employeeId" => 123, "date" => "2024-01-15", "hours" => 8}
      iex> BambooHR.TimeTracking.create_hour_entry(client, entry_data)
      {:ok, %{"id" => 5, "employeeId" => 123, "hours" => 8}}
  """
  @spec create_hour_entry(Client.t(), map()) :: Client.response()
  def create_hour_entry(client, entry_data) when is_map(entry_data) do
    Client.post("/time-tracking/hour-entries", client, json: entry_data)
  end

  @doc """
  Retrieves a single hour entry.

  ## Parameters

    * `client` - Client configuration created with `BambooHR.Client.new/1`
    * `entry_id` - The ID of the hour entry

  ## Examples

      iex> BambooHR.TimeTracking.get_hour_entry(client, 5)
      {:ok, %{"id" => 5, "employeeId" => 123, "hours" => 8}}
  """
  @spec get_hour_entry(Client.t(), integer()) :: Client.response()
  def get_hour_entry(client, entry_id) when is_integer(entry_id) do
    Client.get("/time-tracking/hour-entries/#{entry_id}", client)
  end

  @doc """
  Updates an hour entry.

  Only the fields given are changed.

  ## Parameters

    * `client` - Client configuration created with `BambooHR.Client.new/1`
    * `entry_id` - The ID of the hour entry to update
    * `changes` - Map of the fields to change: `"date"`, `"hours"`,
      `"note"`, `"projectId"`, `"taskId"`

  ## Examples

      iex> BambooHR.TimeTracking.update_hour_entry(client, 5, %{"hours" => 7.5})
      {:ok, %{"id" => 5, "hours" => 7.5}}
  """
  @spec update_hour_entry(Client.t(), integer(), map()) :: Client.response()
  def update_hour_entry(client, entry_id, changes)
      when is_integer(entry_id) and is_map(changes) do
    Client.patch("/time-tracking/hour-entries/#{entry_id}", client, json: changes)
  end

  @doc """
  Deletes an hour entry.

  On success, returns `nil` (no response body).

  ## Parameters

    * `client` - Client configuration created with `BambooHR.Client.new/1`
    * `entry_id` - The ID of the hour entry to delete

  ## Examples

      iex> BambooHR.TimeTracking.delete_hour_entry(client, 5)
      {:ok, nil}
  """
  @spec delete_hour_entry(Client.t(), integer()) :: Client.response()
  def delete_hour_entry(client, entry_id) when is_integer(entry_id) do
    Client.delete("/time-tracking/hour-entries/#{entry_id}", client)
  end

  @doc """
  Lists timesheets, one page at a time.

  Timesheets for future periods are never returned.

  ## Parameters

    * `client` - Client configuration created with `BambooHR.Client.new/1`
    * `opts` - Optional keyword list: `:filter`, `:sort`, `:page`,
      `:page_size`. Filterable fields are `employeeId`, `status`,
      `startDate` and `endDate`; sortable are `startDate`, `endDate`,
      `approvedAt` and `updatedAt`, defaulting to `startDate desc`.

  ## Examples

      iex> BambooHR.TimeTracking.list_timesheets(client, filter: "status eq 'OPEN'")
      {:ok, %{
        "data" => [%{"id" => 9, "employeeId" => 123, "status" => "OPEN"}],
        "meta" => %{"page" => 1, "pageSize" => 50, "totalItems" => 1, "totalPages" => 1}
      }}
  """
  @spec list_timesheets(Client.t(), keyword()) :: Client.response()
  def list_timesheets(client, opts \\ []) do
    Client.get("/time-tracking/timesheets", client, params: list_params(opts))
  end

  @doc """
  Retrieves a single timesheet.

  ## Parameters

    * `client` - Client configuration created with `BambooHR.Client.new/1`
    * `timesheet_id` - The ID of the timesheet

  ## Examples

      iex> BambooHR.TimeTracking.get_timesheet(client, 9)
      {:ok, %{"id" => 9, "employeeId" => 123, "status" => "OPEN"}}
  """
  @spec get_timesheet(Client.t(), integer()) :: Client.response()
  def get_timesheet(client, timesheet_id) when is_integer(timesheet_id) do
    Client.get("/time-tracking/timesheets/#{timesheet_id}", client)
  end

  @doc """
  Retrieves a timesheet's totals.

  ## Parameters

    * `client` - Client configuration created with `BambooHR.Client.new/1`
    * `timesheet_id` - The ID of the timesheet

  ## Examples

      iex> BambooHR.TimeTracking.get_timesheet_summary(client, 9)
      {:ok, %{"regularHours" => 40, "overtimeHours" => 2}}
  """
  @spec get_timesheet_summary(Client.t(), integer()) :: Client.response()
  def get_timesheet_summary(client, timesheet_id) when is_integer(timesheet_id) do
    Client.get("/time-tracking/timesheets/#{timesheet_id}/summary", client)
  end

  @doc """
  Approves a timesheet.

  `last_changed_at` guards against approving a timesheet that changed
  after you read it: pass the `"hoursLastChangedAt"` from the timesheet you
  looked at, and BambooHR returns a `409` error if it has moved on since.
  Don't use `"updatedAt"` — it can lag behind changes to the hours.

  ## Parameters

    * `client` - Client configuration created with `BambooHR.Client.new/1`
    * `timesheet_id` - The ID of the timesheet to approve
    * `last_changed_at` - The `"hoursLastChangedAt"` value from that timesheet

  ## Examples

      iex> BambooHR.TimeTracking.approve_timesheet(client, 9, "2024-01-15T17:00:00Z")
      {:ok, %{"id" => 9, "status" => "APPROVED"}}
  """
  @spec approve_timesheet(Client.t(), integer(), String.t()) :: Client.response()
  def approve_timesheet(client, timesheet_id, last_changed_at)
      when is_integer(timesheet_id) and is_binary(last_changed_at) do
    Client.post("/time-tracking/timesheet-approvals", client,
      json: %{"timesheetId" => timesheet_id, "lastChangedAt" => last_changed_at}
    )
  end

  @doc """
  Lists time tracking configurations.

  Returns both the auto-managed `GLOBAL` configuration and any `GROUP`
  ones. Deleted configurations are never returned.

  ## Parameters

    * `client` - Client configuration created with `BambooHR.Client.new/1`
    * `opts` - Optional keyword list: `:filter`, `:order_by`, `:select`
      (a sparse fieldset), `:page`, `:page_size` (defaults to 20)

  ## Examples

      iex> BambooHR.TimeTracking.list_configurations(client, filter: "type eq 'GROUP'")
      {:ok, %{
        "data" => [%{"id" => 2, "name" => "Warehouse", "timesheetType" => "CLOCK"}],
        "meta" => %{"page" => 1, "pageSize" => 20, "totalItems" => 1, "totalPages" => 1}
      }}
  """
  @spec list_configurations(Client.t(), keyword()) :: Client.response()
  def list_configurations(client, opts \\ []) do
    Client.get("/time-tracking/configurations", client, params: configuration_params(opts))
  end

  @doc """
  Creates a group time tracking configuration, with its approval workflow.

  The type is always `GROUP`: the `GLOBAL` configuration is managed by
  BambooHR and cannot be created here.

  ## Parameters

    * `client` - Client configuration created with `BambooHR.Client.new/1`
    * `configuration_data` - Map with `"name"`, `"timesheetType"`,
      `"workWeekStartsOn"`, `"approverType"`, `"approvalCutoff"` and
      `"approvalCutoffDays"`, plus the optional clock-in, mobile,
      geolocation and overtime settings
    * `opts` - Optional keyword list: `:idempotency_key`, which lets a
      retry of the same request be recognised rather than creating a
      second configuration

  ## Examples

      iex> configuration_data = %{
      ...>   "name" => "Warehouse",
      ...>   "timesheetType" => "CLOCK",
      ...>   "workWeekStartsOn" => "MONDAY",
      ...>   "approverType" => "MANAGER",
      ...>   "approvalCutoff" => "DAY_OF_WEEK",
      ...>   "approvalCutoffDays" => 2
      ...> }
      iex> BambooHR.TimeTracking.create_configuration(client, configuration_data)
      {:ok, %{"id" => 2, "name" => "Warehouse"}}
  """
  @spec create_configuration(Client.t(), map(), keyword()) :: Client.response()
  def create_configuration(client, configuration_data, opts \\ [])
      when is_map(configuration_data) do
    Client.post(
      "/time-tracking/configurations",
      client,
      [json: configuration_data] ++ idempotency(opts)
    )
  end

  @doc """
  Retrieves a time tracking configuration.

  A deleted configuration returns a `404` error.

  ## Parameters

    * `client` - Client configuration created with `BambooHR.Client.new/1`
    * `configuration_id` - The configuration's ID

  ## Examples

      iex> BambooHR.TimeTracking.get_configuration(client, 2)
      {:ok, %{"id" => 2, "name" => "Warehouse", "type" => "GROUP"}}
  """
  @spec get_configuration(Client.t(), integer()) :: Client.response()
  def get_configuration(client, configuration_id) when is_integer(configuration_id) do
    Client.get("/time-tracking/configurations/#{configuration_id}", client)
  end

  @doc """
  Updates a time tracking configuration.

  Uses JSON Merge Patch (RFC 7396): fields you pass are applied, fields
  you leave out keep their values, and an explicit `nil` clears a
  nullable field. Both `GLOBAL` and `GROUP` configurations can be
  updated.

  ## Parameters

    * `client` - Client configuration created with `BambooHR.Client.new/1`
    * `configuration_id` - The configuration's ID
    * `changes` - Map of the fields to change, same shape as
      `create_configuration/3`

  ## Examples

      iex> BambooHR.TimeTracking.update_configuration(client, 2, %{"mobileEnabled" => false})
      {:ok, %{"id" => 2, "mobileEnabled" => false}}
  """
  @spec update_configuration(Client.t(), integer(), map()) :: Client.response()
  def update_configuration(client, configuration_id, changes)
      when is_integer(configuration_id) and is_map(changes) do
    merge_patch("/time-tracking/configurations/#{configuration_id}", client, changes)
  end

  @doc """
  Deletes a group time tracking configuration.

  Only works when no employees are enrolled: move or un-enrol them first,
  otherwise BambooHR returns a `422` error. On success, returns `nil` (no
  response body).

  ## Parameters

    * `client` - Client configuration created with `BambooHR.Client.new/1`
    * `configuration_id` - The configuration's ID

  ## Examples

      iex> BambooHR.TimeTracking.delete_configuration(client, 2)
      {:ok, nil}
  """
  @spec delete_configuration(Client.t(), integer()) :: Client.response()
  def delete_configuration(client, configuration_id) when is_integer(configuration_id) do
    Client.delete("/time-tracking/configurations/#{configuration_id}", client)
  end

  @doc """
  Lists employee time tracking enrolments.

  Both enabled and disabled enrolments are returned; narrow with a
  `:filter` on `enabled`.

  ## Parameters

    * `client` - Client configuration created with `BambooHR.Client.new/1`
    * `opts` - Optional keyword list: `:filter`, `:order_by`, `:select`,
      `:page`, `:page_size` (defaults to 20)

  ## Examples

      iex> BambooHR.TimeTracking.list_enrolled_employees(client, filter: "enabled eq true")
      {:ok, %{
        "data" => [%{"employeeId" => 123, "enabled" => true, "configurationId" => 2}],
        "meta" => %{"page" => 1, "pageSize" => 20, "totalItems" => 1, "totalPages" => 1}
      }}
  """
  @spec list_enrolled_employees(Client.t(), keyword()) :: Client.response()
  def list_enrolled_employees(client, opts \\ []) do
    Client.get("/time-tracking/employees", client, params: configuration_params(opts))
  end

  @doc """
  Retrieves an employee's time tracking enrolment.

  ## Parameters

    * `client` - Client configuration created with `BambooHR.Client.new/1`
    * `employee_id` - The employee's ID

  ## Examples

      iex> BambooHR.TimeTracking.get_employee_enrollment(client, 123)
      {:ok, %{"employeeId" => 123, "enabled" => true, "configurationId" => 2}}
  """
  @spec get_employee_enrollment(Client.t(), integer()) :: Client.response()
  def get_employee_enrollment(client, employee_id) when is_integer(employee_id) do
    Client.get("/time-tracking/employees/#{employee_id}", client)
  end

  @doc """
  Enables, disables or reassigns an employee's time tracking enrolment.

  Uses JSON Merge Patch (RFC 7396), so only the fields you pass are
  applied. An employee with no enrolment record yet gets one.

  ## Parameters

    * `client` - Client configuration created with `BambooHR.Client.new/1`
    * `employee_id` - The employee's ID
    * `changes` - Map with `"enabled"`, `"configurationId"` and/or
      `"enabledOn"`

  ## Examples

      iex> BambooHR.TimeTracking.update_employee_enrollment(client, 123, %{"enabled" => true})
      {:ok, %{"employeeId" => 123, "enabled" => true}}
  """
  @spec update_employee_enrollment(Client.t(), integer(), map()) :: Client.response()
  def update_employee_enrollment(client, employee_id, changes)
      when is_integer(employee_id) and is_map(changes) do
    merge_patch("/time-tracking/employees/#{employee_id}", client, changes)
  end

  @doc """
  Enables, disables or reassigns many enrolments at once.

  Takes 1 to 1000 records, each needing an `"employeeId"` and otherwise
  shaped like `update_employee_enrollment/3`. BambooHR answers `202` —
  the batch is accepted, not necessarily finished, so read the response
  for per-record results.

  By default a record that fails leaves the rest applied. Pass
  `atomic: true` to have the whole batch rejected instead.

  ## Parameters

    * `client` - Client configuration created with `BambooHR.Client.new/1`
    * `records` - List of maps, each with at least `"employeeId"`
    * `opts` - Optional keyword list: `:atomic`, `:idempotency_key`

  ## Examples

      iex> records = [%{"employeeId" => 123, "enabled" => true, "configurationId" => 2}]
      iex> BambooHR.TimeTracking.bulk_upsert_employee_enrollments(client, records)
      {:ok, %{"results" => [%{"employeeId" => 123, "status" => "UPDATED"}]}}
  """
  @spec bulk_upsert_employee_enrollments(Client.t(), list(map()), keyword()) :: Client.response()
  def bulk_upsert_employee_enrollments(client, records, opts \\ []) when is_list(records) do
    params = for {:atomic, value} <- opts, do: {"atomic", value}

    Client.post(
      "/time-tracking/employees/bulk-upsert",
      client,
      [json: records, params: params] ++ idempotency(opts)
    )
  end

  # These endpoints take JSON Merge Patch, and the employee enrolment one
  # rejects anything else with a 415, so the body is encoded here rather
  # than through Req's :json option, which would set application/json.
  defp merge_patch(path, client, changes) do
    Client.patch(path, client,
      body: Jason.encode!(changes),
      content_type: "application/merge-patch+json"
    )
  end

  defp idempotency(opts) do
    for {:idempotency_key, key} <- opts, do: {:idempotency_key, key}
  end

  defp configuration_params(opts) do
    for {key, param} <- [
          filter: "filter",
          order_by: "orderBy",
          select: "select",
          page: "page",
          page_size: "pageSize"
        ],
        value = opts[key] do
      {param, value}
    end
  end

  defp list_params(opts) do
    for {key, param} <- [filter: "filter", sort: "sort", page: "page", page_size: "pageSize"],
        value = opts[key] do
      {param, value}
    end
  end
end
