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
  Lists time tracking projects.

  ## Parameters

    * `client` - Client configuration created with `BambooHR.Client.new/1`
    * `opts` - Optional keyword list: `:filter`, `:sort`, `:page`,
      `:page_size` (defaults to 100, caps at 500)

  ## Examples

      iex> BambooHR.TimeTracking.list_projects(client, filter: "billable eq true")
      {:ok, %{
        "data" => [%{"id" => 3, "name" => "Website rebuild", "billable" => true}],
        "meta" => %{"page" => 1, "pageSize" => 100, "totalItems" => 1, "totalPages" => 1}
      }}
  """
  @spec list_projects(Client.t(), keyword()) :: Client.response()
  def list_projects(client, opts \\ []) do
    Client.get("/time-tracking/projects", client, params: list_params(opts))
  end

  @doc """
  Creates a time tracking project.

  If a **deleted** project already has this name, BambooHR restores that
  project and applies the values given instead of creating a new one, so
  the response can carry an ID you have seen before.

  Tasks can be created alongside the project rather than added
  afterwards.

  ## Parameters

    * `client` - Client configuration created with `BambooHR.Client.new/1`
    * `project_data` - Map with `"name"`, and optionally `"billable"`,
      `"includeInPayroll"`, `"allEmployeesAssigned"`, `"employeeIds"`,
      `"tasks"`

  ## Examples

      iex> BambooHR.TimeTracking.create_project(client, %{"name" => "Website rebuild"})
      {:ok, %{"id" => 3, "name" => "Website rebuild"}}
  """
  @spec create_project(Client.t(), map()) :: Client.response()
  def create_project(client, project_data) when is_map(project_data) do
    Client.post("/time-tracking/projects", client, json: project_data)
  end

  @doc """
  Retrieves a time tracking project, including who is assigned to it.

  ## Parameters

    * `client` - Client configuration created with `BambooHR.Client.new/1`
    * `project_id` - The project's ID

  ## Examples

      iex> BambooHR.TimeTracking.get_project(client, 3)
      {:ok, %{"id" => 3, "name" => "Website rebuild", "employeeIds" => [123]}}
  """
  @spec get_project(Client.t(), integer()) :: Client.response()
  def get_project(client, project_id) when is_integer(project_id) do
    Client.get("/time-tracking/projects/#{project_id}", client)
  end

  @doc """
  Updates a time tracking project.

  Only the fields given are changed. Setting `"archived"` hides the
  project without deleting it.

  ## Parameters

    * `client` - Client configuration created with `BambooHR.Client.new/1`
    * `project_id` - The project's ID
    * `changes` - Map of fields to change: `"name"`, `"billable"`,
      `"includeInPayroll"`, `"allEmployeesAssigned"`, `"archived"`,
      `"employeeIds"`, `"hasTasks"`

  ## Examples

      iex> BambooHR.TimeTracking.update_project(client, 3, %{"archived" => true})
      {:ok, %{"id" => 3, "archived" => true}}
  """
  @spec update_project(Client.t(), integer(), map()) :: Client.response()
  def update_project(client, project_id, changes)
      when is_integer(project_id) and is_map(changes) do
    Client.patch("/time-tracking/projects/#{project_id}", client, json: changes)
  end

  @doc """
  Deletes a time tracking project.

  On success, returns `nil` (no response body).

  ## Parameters

    * `client` - Client configuration created with `BambooHR.Client.new/1`
    * `project_id` - The project's ID

  ## Examples

      iex> BambooHR.TimeTracking.delete_project(client, 3)
      {:ok, nil}
  """
  @spec delete_project(Client.t(), integer()) :: Client.response()
  def delete_project(client, project_id) when is_integer(project_id) do
    Client.delete("/time-tracking/projects/#{project_id}", client)
  end

  @doc """
  Lists a project's tasks.

  Only active tasks are returned unless `:statuses` says otherwise.

  ## Parameters

    * `client` - Client configuration created with `BambooHR.Client.new/1`
    * `project_id` - The project's ID
    * `opts` - Optional keyword list: `:statuses` (a list of `"active"`
      and `"deleted"`, defaulting to `["active"]`), `:filter`, `:sort`,
      `:page`, `:page_size` (defaults to 25, caps at 500)

  ## Examples

      iex> BambooHR.TimeTracking.list_project_tasks(client, 3, statuses: ["active", "deleted"])
      {:ok, %{
        "data" => [%{"id" => 7, "projectId" => 3, "name" => "Design", "billable" => true}],
        "meta" => %{"page" => 1, "pageSize" => 25, "totalItems" => 1, "totalPages" => 1}
      }}
  """
  @spec list_project_tasks(Client.t(), integer(), keyword()) :: Client.response()
  def list_project_tasks(client, project_id, opts \\ []) when is_integer(project_id) do
    statuses = for status <- List.wrap(opts[:statuses]), do: {"statuses[]", status}

    Client.get("/time-tracking/projects/#{project_id}/tasks", client,
      params: statuses ++ list_params(opts)
    )
  end

  @doc """
  Creates a task on a project.

  ## Parameters

    * `client` - Client configuration created with `BambooHR.Client.new/1`
    * `project_id` - The project's ID
    * `task_data` - Map with `"name"`, and optionally `"billable"`

  ## Examples

      iex> BambooHR.TimeTracking.create_project_task(client, 3, %{"name" => "Design"})
      {:ok, %{"id" => 7, "projectId" => 3, "name" => "Design"}}
  """
  @spec create_project_task(Client.t(), integer(), map()) :: Client.response()
  def create_project_task(client, project_id, task_data)
      when is_integer(project_id) and is_map(task_data) do
    Client.post("/time-tracking/projects/#{project_id}/tasks", client, json: task_data)
  end

  @doc """
  Retrieves a task.

  ## Parameters

    * `client` - Client configuration created with `BambooHR.Client.new/1`
    * `task_id` - The task's ID

  ## Examples

      iex> BambooHR.TimeTracking.get_task(client, 7)
      {:ok, %{"id" => 7, "projectId" => 3, "name" => "Design"}}
  """
  @spec get_task(Client.t(), integer()) :: Client.response()
  def get_task(client, task_id) when is_integer(task_id) do
    Client.get("/time-tracking/tasks/#{task_id}", client)
  end

  @doc """
  Updates a task.

  Only the fields given are changed, and at least one must be given.

  ## Parameters

    * `client` - Client configuration created with `BambooHR.Client.new/1`
    * `task_id` - The task's ID
    * `changes` - Map with `"name"` and/or `"billable"`

  ## Examples

      iex> BambooHR.TimeTracking.update_task(client, 7, %{"billable" => false})
      {:ok, %{"id" => 7, "billable" => false}}
  """
  @spec update_task(Client.t(), integer(), map()) :: Client.response()
  def update_task(client, task_id, changes) when is_integer(task_id) and is_map(changes) do
    Client.patch("/time-tracking/tasks/#{task_id}", client, json: changes)
  end

  @doc """
  Deletes a task.

  On success, returns `nil` (no response body).

  ## Parameters

    * `client` - Client configuration created with `BambooHR.Client.new/1`
    * `task_id` - The task's ID

  ## Examples

      iex> BambooHR.TimeTracking.delete_task(client, 7)
      {:ok, nil}
  """
  @spec delete_task(Client.t(), integer()) :: Client.response()
  def delete_task(client, task_id) when is_integer(task_id) do
    Client.delete("/time-tracking/tasks/#{task_id}", client)
  end

  defp list_params(opts) do
    for {key, param} <- [filter: "filter", sort: "sort", page: "page", page_size: "pageSize"],
        value = opts[key] do
      {param, value}
    end
  end
end
