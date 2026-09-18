defmodule BambooHR.Scheduling do
  @moduledoc """
  Functions for employee scheduling in the BambooHR API.

  A schedule belongs to a location and holds the shifts for the employees
  on it. A shift can recur, and a planned shift stays invisible to
  employees until it is published.

  ## IDs

  Schedule and shift IDs are UUID strings, not integers.

  ## Paging and filtering

  Listing functions page with `:page` and `:page_size`. `:filter` and
  `:sort`, where supported, are OData-style strings passed straight
  through.
  """

  alias BambooHR.Client

  @doc """
  Lists schedules.

  ## Parameters

    * `client` - Client configuration created with `BambooHR.Client.new/1`
    * `opts` - Optional keyword list: `:filter`, `:sort`, `:page`,
      `:page_size`

  ## Examples

      iex> BambooHR.Scheduling.list_schedules(client)
      {:ok, %{"data" => [%{"id" => "3fa8...", "name" => "Store floor"}]}}
  """
  @spec list_schedules(Client.t(), keyword()) :: Client.response()
  def list_schedules(client, opts \\ []) do
    Client.get("/scheduling/schedules", client, params: list_params(opts))
  end

  @doc """
  Creates a schedule.

  BambooHR rejects a schedule that duplicates an existing one for the
  same location and configuration.

  ## Parameters

    * `client` - Client configuration created with `BambooHR.Client.new/1`
    * `schedule_data` - Map with `"name"`, `"locationId"` and
      `"startOfWeek"`, and optionally `"timezone"`, the clock-in and
      clock-out thresholds, `"managerUserIds"`, `"employeeIds"`, and the
      auto-publish lead time

  ## Examples

      iex> schedule_data = %{"name" => "Store floor", "locationId" => 4, "startOfWeek" => "MONDAY"}
      iex> BambooHR.Scheduling.create_schedule(client, schedule_data)
      {:ok, %{"id" => "3fa8...", "name" => "Store floor"}}
  """
  @spec create_schedule(Client.t(), map()) :: Client.response()
  def create_schedule(client, schedule_data) when is_map(schedule_data) do
    Client.post("/scheduling/schedules", client, json: schedule_data)
  end

  @doc """
  Retrieves a schedule.

  ## Parameters

    * `client` - Client configuration created with `BambooHR.Client.new/1`
    * `schedule_id` - The schedule's UUID

  ## Examples

      iex> BambooHR.Scheduling.get_schedule(client, "3fa8...")
      {:ok, %{"id" => "3fa8...", "name" => "Store floor"}}
  """
  @spec get_schedule(Client.t(), String.t()) :: Client.response()
  def get_schedule(client, schedule_id) when is_binary(schedule_id) do
    Client.get("/scheduling/schedules/#{schedule_id}", client)
  end

  @doc """
  Updates a schedule.

  Only the fields given are changed.

  ## Parameters

    * `client` - Client configuration created with `BambooHR.Client.new/1`
    * `schedule_id` - The schedule's UUID
    * `changes` - Map of the fields to change, same shape as
      `create_schedule/2`

  ## Examples

      iex> BambooHR.Scheduling.update_schedule(client, "3fa8...", %{"name" => "Shop floor"})
      {:ok, %{"id" => "3fa8...", "name" => "Shop floor"}}
  """
  @spec update_schedule(Client.t(), String.t(), map()) :: Client.response()
  def update_schedule(client, schedule_id, changes)
      when is_binary(schedule_id) and is_map(changes) do
    Client.patch("/scheduling/schedules/#{schedule_id}", client, json: changes)
  end

  @doc """
  Deletes a schedule.

  Any shift on it that has not been worked is deleted too. On success,
  returns `nil` (no response body).

  ## Parameters

    * `client` - Client configuration created with `BambooHR.Client.new/1`
    * `schedule_id` - The schedule's UUID

  ## Examples

      iex> BambooHR.Scheduling.delete_schedule(client, "3fa8...")
      {:ok, nil}
  """
  @spec delete_schedule(Client.t(), String.t()) :: Client.response()
  def delete_schedule(client, schedule_id) when is_binary(schedule_id) do
    Client.delete("/scheduling/schedules/#{schedule_id}", client)
  end

  @doc """
  Downloads a schedule as a PDF.

  Returns `{:ok, %{body: pdf_binary, headers: headers}}` — the body is
  PDF bytes, not JSON, so it is returned undecoded alongside the response
  headers.

  ## Parameters

    * `client` - Client configuration created with `BambooHR.Client.new/1`
    * `schedule_id` - The schedule's UUID
    * `start_ymd` - First day to include, as `YYYY-MM-DD`
    * `end_ymd` - Last day to include, as `YYYY-MM-DD`
    * `opts` - Optional keyword list: `:group_by`, `:employee_ids` (a
      list), `:include_employees_without_shifts`, `:include_holidays`,
      `:include_time_off`

  ## Examples

      iex> BambooHR.Scheduling.get_schedule_pdf(client, "3fa8...", "2024-01-01", "2024-01-07")
      {:ok, %{body: <<37, 80, 68, 70, 45>>, headers: %{"content-type" => ["application/pdf"]}}}
  """
  @spec get_schedule_pdf(Client.t(), String.t(), String.t(), String.t(), keyword()) ::
          Client.response()
  def get_schedule_pdf(client, schedule_id, start_ymd, end_ymd, opts \\ [])
      when is_binary(schedule_id) and is_binary(start_ymd) and is_binary(end_ymd) do
    params = [{"startYmd", start_ymd}, {"endYmd", end_ymd}] ++ pdf_params(opts)

    Client.get("/scheduling/schedules/#{schedule_id}/pdf", client,
      params: params,
      raw_response: true,
      expose_headers: true
    )
  end

  @doc """
  Lists the timezones a schedule can use.

  ## Parameters

    * `client` - Client configuration created with `BambooHR.Client.new/1`
    * `opts` - Optional keyword list: `:filter` (on `name`), `:sort`,
      `:page`, `:page_size`

  ## Examples

      iex> BambooHR.Scheduling.list_timezones(client)
      {:ok, %{"data" => [%{"name" => "America/New_York"}]}}
  """
  @spec list_timezones(Client.t(), keyword()) :: Client.response()
  def list_timezones(client, opts \\ []) do
    Client.get("/scheduling/timezones", client, params: list_params(opts))
  end

  @doc """
  Lists shifts.

  Either pass `:ids`, which ignores every other filter, or pass `:start`
  and `:end` together with at least one of `:employee_ids` or
  `:schedule_ids`. The window between `:start` and `:end` can be at most
  one month.

  ## Parameters

    * `client` - Client configuration created with `BambooHR.Client.new/1`
    * `opts` - Keyword list: `:ids`, `:start`, `:end`, `:employee_ids`,
      `:schedule_ids`, `:statuses`, `:page`, `:page_size`. List values
      are joined with commas.

  ## Examples

      iex> BambooHR.Scheduling.list_shifts(client,
      ...>   start: "2024-01-01",
      ...>   end: "2024-01-07",
      ...>   schedule_ids: ["3fa8..."]
      ...> )
      {:ok, %{"data" => [%{"id" => "9c14...", "status" => "PUBLISHED"}]}}
  """
  @spec list_shifts(Client.t(), keyword()) :: Client.response()
  def list_shifts(client, opts \\ []) do
    Client.get("/scheduling/shifts", client, params: shift_params(opts))
  end

  @doc """
  Creates a shift.

  ## Parameters

    * `client` - Client configuration created with `BambooHR.Client.new/1`
    * `shift_data` - Map with `"scheduleId"`, `"status"`, `"color"`,
      `"timezone"`, `"start"` and `"end"`, and optionally `"name"`,
      `"capacity"`, `"employeeIds"` and the `"recurrence*"` fields

  ## Examples

      iex> shift_data = %{
      ...>   "scheduleId" => "3fa8...",
      ...>   "status" => "PLANNED",
      ...>   "color" => "#336699",
      ...>   "timezone" => "America/New_York",
      ...>   "start" => "2024-01-15T09:00:00-05:00",
      ...>   "end" => "2024-01-15T17:00:00-05:00"
      ...> }
      iex> BambooHR.Scheduling.create_shift(client, shift_data)
      {:ok, %{"id" => "9c14...", "status" => "PLANNED"}}
  """
  @spec create_shift(Client.t(), map()) :: Client.response()
  def create_shift(client, shift_data) when is_map(shift_data) do
    Client.post("/scheduling/shifts", client, json: shift_data)
  end

  @doc """
  Retrieves a shift.

  Includes its recurrence settings, assigned employees, and status. A
  deleted shift returns a `404` error.

  ## Parameters

    * `client` - Client configuration created with `BambooHR.Client.new/1`
    * `shift_id` - The shift's UUID

  ## Examples

      iex> BambooHR.Scheduling.get_shift(client, "9c14...")
      {:ok, %{"id" => "9c14...", "status" => "PUBLISHED"}}
  """
  @spec get_shift(Client.t(), String.t()) :: Client.response()
  def get_shift(client, shift_id) when is_binary(shift_id) do
    Client.get("/scheduling/shifts/#{shift_id}", client)
  end

  @doc """
  Updates a shift.

  Only the fields given are changed. On a **published** shift the changes
  are not applied straight away: they are held as `"unpublishedChanges"`
  and take effect when the shift is published again. For a recurring
  shift, `"recurrenceEditOption"` says how many of the repeats to change.

  ## Parameters

    * `client` - Client configuration created with `BambooHR.Client.new/1`
    * `shift_id` - The shift's UUID
    * `changes` - Map of the fields to change: `"name"`, `"color"`,
      `"capacity"`, `"start"`, `"end"`, `"timezone"`, `"employeeIds"`,
      and the `"recurrence*"` fields

  ## Examples

      iex> BambooHR.Scheduling.update_shift(client, "9c14...", %{"capacity" => 3})
      {:ok, %{"id" => "9c14...", "capacity" => 3}}
  """
  @spec update_shift(Client.t(), String.t(), map()) :: Client.response()
  def update_shift(client, shift_id, changes) when is_binary(shift_id) and is_map(changes) do
    Client.patch("/scheduling/shifts/#{shift_id}", client, json: changes)
  end

  @doc """
  Deletes a shift.

  On success, returns `nil` (no response body).

  ## Parameters

    * `client` - Client configuration created with `BambooHR.Client.new/1`
    * `shift_id` - The shift's UUID, or a composite recurrence ID
    * `opts` - Optional keyword list: `:recurrence_edit_option`, which
      says how many of a recurring shift's repeats to delete

  ## Examples

      iex> BambooHR.Scheduling.delete_shift(client, "9c14...")
      {:ok, nil}
  """
  @spec delete_shift(Client.t(), String.t(), keyword()) :: Client.response()
  def delete_shift(client, shift_id, opts \\ []) when is_binary(shift_id) do
    params =
      for {:recurrence_edit_option, value} <- opts, do: {"recurrenceEditOption", value}

    Client.delete("/scheduling/shifts/#{shift_id}", client, params: params)
  end

  @doc """
  Publishes planned shifts, making them visible to employees.

  Shifts that clash with something else are skipped rather than failing
  the whole call, and come back in the response as failures — so check
  the result even on success. BambooHR answers `207` when only some
  shifts published, which this client treats as success, and `409` when
  none of them did, which is an error.

  ## Parameters

    * `client` - Client configuration created with `BambooHR.Client.new/1`
    * `shift_ids` - List of shift UUIDs to publish

  ## Examples

      iex> BambooHR.Scheduling.publish_shifts(client, ["9c14...", "2b77..."])
      {:ok, %{"published" => ["9c14..."], "failed" => [%{"id" => "2b77...", "reason" => "CONFLICT"}]}}
  """
  @spec publish_shifts(Client.t(), list(String.t())) :: Client.response()
  def publish_shifts(client, shift_ids) when is_list(shift_ids) do
    Client.post("/scheduling/shifts/publish", client, json: %{"shiftIds" => shift_ids})
  end

  @doc """
  Lists shift assessments.

  A `:filter` is required, and must narrow by at least one of
  `employeeId`, `shiftId`, or a date.

  ## Parameters

    * `client` - Client configuration created with `BambooHR.Client.new/1`
    * `opts` - Keyword list: `:filter`, `:sort`, `:page`, `:page_size`

  ## Examples

      iex> BambooHR.Scheduling.list_shift_assessments(client, filter: "employeeId eq 123")
      {:ok, %{"data" => [%{"employeeId" => 123, "date" => "2024-01-15"}]}}
  """
  @spec list_shift_assessments(Client.t(), keyword()) :: Client.response()
  def list_shift_assessments(client, opts \\ []) do
    Client.get("/scheduling/shift-assessments", client, params: list_params(opts))
  end

  defp list_params(opts) do
    build_params(opts, filter: "filter", sort: "sort", page: "page", page_size: "pageSize")
  end

  defp shift_params(opts) do
    build_params(opts,
      ids: "ids",
      start: "start",
      end: "end",
      employee_ids: "employeeIds",
      schedule_ids: "scheduleIds",
      statuses: "statuses",
      page: "page",
      page_size: "pageSize"
    )
  end

  # The PDF endpoint takes employeeIds[] as a repeated parameter rather
  # than a comma-separated list, so each ID gets its own entry.
  defp pdf_params(opts) do
    employee_ids = for id <- List.wrap(opts[:employee_ids]), do: {"employeeIds[]", id}

    employee_ids ++
      build_params(opts,
        group_by: "groupBy",
        include_employees_without_shifts: "includeEmployeesWithoutShifts",
        include_holidays: "includeHolidays",
        include_time_off: "includeTimeOff"
      )
  end

  defp build_params(opts, mapping) do
    for {key, param} <- mapping, value = opts[key], do: {param, join(value)}
  end

  defp join(value) when is_list(value), do: Enum.join(value, ",")
  defp join(value), do: value
end
