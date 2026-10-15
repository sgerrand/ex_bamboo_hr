defmodule BambooHR.Scheduling do
  @moduledoc """
  Functions for employee scheduling in the BambooHR API.

  A schedule belongs to a location and holds the shifts for the employees
  on it. A shift can recur, and a planned shift stays invisible to
  employees until it is published.

  ## IDs

  Schedule IDs are UUID strings, not integers. A shift ID is usually a
  UUID too, but a recurring shift that has not been created yet has a
  composite ID (`"<recurringShiftDefinitionId>_<recurrenceId>"`), which
  `list_shifts/2`
  returns and `publish_shifts/2` and `delete_shift/3` accept. Treat a
  shift ID as an opaque string rather than validating it as a UUID.

  An ID is percent-encoded before it goes into the request path, so one
  that holds a `/`, `?` or `#` stays a single path segment and cannot
  change which endpoint is called or add query parameters.

  An empty ID, `"."` and `".."` are never sent. An empty one would turn
  `get_shift/2` into a call on the whole list, and the dots mean "this
  folder" and "the one above" in a path. The call returns
  `{:error, %BambooHR.Error{reason: :invalid_argument}}` without
  contacting BambooHR.

  ## Paging and filtering

  Listing functions page with `:page` and `:page_size`. `:filter` and
  `:sort`, where supported, are OData-style strings passed straight
  through.

  ## Empty values

  A filter given as an empty list is never sent. Leaving it out would
  drop the filter and return everything, where a list that worked out
  empty most likely means nothing should match. An empty string, or a
  list that holds one, is treated the same way: `String.split("", ",")`
  gives `[""]`, not `[]`. A string of only spaces counts as empty. The
  filters are `:ids`, `:employee_ids`, `:schedule_ids`, `:statuses` and
  `:filter`. The call returns
  `{:error, %BambooHR.Error{reason: :empty_filter}}` without contacting
  BambooHR. Pass `nil`, or leave the option out, to mean no filter.

  An empty value for any other option, such as `:sort`, `:page` or
  `:recurrence_edit_option`, is not sent either. It is not a filter, so
  the call returns `{:error, %BambooHR.Error{reason: :invalid_argument}}`
  instead. Leave the option out, or pass `nil`, to use the default.

  ## Options

  Every `opts` argument is usually a keyword list. A map with the same
  atom keys works too, and `nil` means no options. See `t:opts/0`.

  An option the function does not know is never dropped. Left out of the
  request, a misspelt filter such as `employee_id` for `employee_ids`
  would return everything. A string key, as in `%{"ids" => ids}`, is
  unknown too. The call returns
  `{:error, %BambooHR.Error{reason: :invalid_argument}}` without
  contacting BambooHR, and the error's `:message` names the option.

  The same error comes back for a value that cannot go in a query
  string. A value is text, a number, an atom, a `Date`, a
  `NaiveDateTime`, a `DateTime`, or a flat list of those. A `MapSet`, a
  map or a list inside a list is not; turn it into a list first. `nil`
  inside a list is allowed only in `:employee_ids`, where it means
  unassigned shifts. Anywhere else it is most likely a missing value,
  so it is an error too, rather than being sent as the string `"null"`.
  """

  alias BambooHR.Client

  @typedoc """
  Options for a function in this module.

  A keyword list, a map with the same atom keys, or `nil` for no options.
  """
  @type opts :: keyword() | %{optional(atom()) => term()} | nil

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
  @spec list_schedules(Client.t(), opts()) :: Client.response()
  def list_schedules(client, opts \\ []) do
    with {:ok, params} <- list_params(opts) do
      Client.get("/scheduling/schedules", client, params: params)
    end
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

      iex> schedule_data = %{"name" => "Store floor", "locationId" => 4, "startOfWeek" => "Monday"}
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
    with {:ok, id} <- segment(schedule_id) do
      Client.get("/scheduling/schedules/#{id}", client)
    end
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
    with {:ok, id} <- segment(schedule_id) do
      Client.patch("/scheduling/schedules/#{id}", client, json: changes)
    end
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
    with {:ok, id} <- segment(schedule_id) do
      Client.delete("/scheduling/schedules/#{id}", client)
    end
  end

  @doc """
  Downloads a schedule as a PDF.

  Returns `{:ok, %{body: pdf_binary, headers: headers}}` — the body is
  PDF bytes, not JSON, so it is returned undecoded alongside the response
  headers.

  Needs an OAuth client (`auth: {:bearer, token}`, with the
  `scheduling:schedules` scope). BambooHR does not accept API keys for
  this endpoint, so an API key client gets an error back.

  BambooHR renders the PDF on request, so a large schedule can outrun
  the client's default 15s `:timeout`, and a failed render comes back as
  a `500`. Each retry would render the PDF again, so by default this
  call retries only when BambooHR certainly did not start a render: a
  `429`, a refused connection, or an HTTP/2 request the server never
  took. A `500` or a timeout is not retried.
  For a large schedule, give it a client with a longer `:timeout`. To
  retry more, or not at all, pass `:retry` (see below).

  ## Parameters

    * `client` - Client configuration created with `BambooHR.Client.new/1`
    * `schedule_id` - The schedule's UUID
    * `start_ymd` - First day to include, as `YYYY-MM-DD` or a `Date`
    * `end_ymd` - Last day to include, as `YYYY-MM-DD` or a `Date`
    * `opts` - Optional keyword list: `:group_by`, `:employee_ids` (a
      list; put `nil` in it, e.g. `[123, nil]`, to include unassigned
      shifts — a bare `nil` means no filter. A comma-joined string such
      as `"10,20"` is split into one ID each, so it means what it does
      for `list_shifts/2`),
      `:include_employees_without_shifts`, `:include_holidays`,
      `:include_time_off`, and `:retry`. `:retry` defaults to
      `:unprocessed` (described above), and also takes `false`,
      `:safe_transient`, `:transient`, or a 2-arity function, as Req
      does. A function should return `true`, `false`, `nil` (the same
      as `false`) or `{:delay, milliseconds}`. With the default HTTP
      client, anything else, or a function that raises, counts as
      `false`, with a warning. Any other `:retry` value returns an
      `:invalid_argument` error. An empty `:employee_ids` list returns
      an `:empty_filter` error; see "Empty values" above

  ## Examples

      iex> BambooHR.Scheduling.get_schedule_pdf(client, "3fa8...", "2024-01-01", "2024-01-07")
      {:ok, %{body: <<37, 80, 68, 70, 45>>, headers: %{"content-type" => ["application/pdf"]}}}
  """
  @spec get_schedule_pdf(
          Client.t(),
          String.t(),
          String.t() | Date.t(),
          String.t() | Date.t(),
          opts()
        ) :: Client.response()
  def get_schedule_pdf(client, schedule_id, start_ymd, end_ymd, opts \\ [])
      when is_binary(schedule_id) and (is_binary(start_ymd) or is_struct(start_ymd, Date)) and
             (is_binary(end_ymd) or is_struct(end_ymd, Date)) do
    with {:ok, id} <- segment(schedule_id),
         {:ok, opts} <- keyword(opts),
         {:ok, optional} <- pdf_params(opts),
         {:ok, retry} <- retry_opt(opts) do
      params =
        [{"startYmd", format_ymd(start_ymd)}, {"endYmd", format_ymd(end_ymd)}] ++ optional

      Client.get(
        "/scheduling/schedules/#{id}/pdf",
        client,
        [params: params, raw_response: true, expose_headers: true] ++ retry
      )
    end
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
  @spec list_timezones(Client.t(), opts()) :: Client.response()
  def list_timezones(client, opts \\ []) do
    with {:ok, params} <- list_params(opts) do
      Client.get("/scheduling/timezones", client, params: params)
    end
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
      are joined with commas. `:start` and `:end` are ISO-8601
      date-times; a `Date` or `NaiveDateTime` is read as UTC. A `Date`
      as `:start` means the start of that day, and as `:end` the end of
      it (`23:59:59`) in UTC, so the last day is included. In another
      zone, `23:59:59` UTC falls earlier in the local day, so pass a
      zoned `DateTime` to cover the whole local day. Pass
      `nil` in the `:employee_ids` list, e.g. `[123, nil]`, to include
      unassigned (open) shifts; a bare `nil` means no filter. An empty
      list for any of these returns an `:empty_filter` error; see "Empty
      values" above.
      `:statuses` takes lowercase values: `"planned"`, `"published"`,
      `"cancelled"`, `"deleted"`. Without it, BambooHR returns only
      planned and published shifts.

  ## Examples

      iex> BambooHR.Scheduling.list_shifts(client,
      ...>   start: "2024-01-01T00:00:00Z",
      ...>   end: "2024-01-07T23:59:59Z",
      ...>   schedule_ids: ["3fa8..."]
      ...> )
      {:ok, %{"data" => [%{"id" => "9c14...", "status" => "published"}]}}
  """
  @spec list_shifts(Client.t(), opts()) :: Client.response()
  def list_shifts(client, opts \\ []) do
    with {:ok, params} <- shift_params(opts) do
      Client.get("/scheduling/shifts", client, params: params)
    end
  end

  @doc """
  Creates a shift.

  ## Parameters

    * `client` - Client configuration created with `BambooHR.Client.new/1`
    * `shift_data` - Map with `"scheduleId"`, `"status"`, `"color"`,
      `"timezone"`, `"start"` and `"end"`, and optionally `"name"`,
      `"capacity"`, `"employeeIds"` and the `"recurrence*"` fields.
      `"status"` is lowercase (`"planned"` or `"published"`) and `"color"`
      is a 6-character hex code with no `#`. `"start"` and `"end"` are
      UTC timestamps; `"timezone"` is what the shift is shown in

  ## Examples

      iex> shift_data = %{
      ...>   "scheduleId" => "3fa8...",
      ...>   "status" => "planned",
      ...>   "color" => "336699",
      ...>   "timezone" => "America/New_York",
      ...>   "start" => "2024-01-15T14:00:00Z",
      ...>   "end" => "2024-01-15T22:00:00Z"
      ...> }
      iex> BambooHR.Scheduling.create_shift(client, shift_data)
      {:ok, %{"id" => "9c14...", "status" => "planned"}}
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
      {:ok, %{"id" => "9c14...", "status" => "published"}}
  """
  @spec get_shift(Client.t(), String.t()) :: Client.response()
  def get_shift(client, shift_id) when is_binary(shift_id) do
    with {:ok, id} <- segment(shift_id) do
      Client.get("/scheduling/shifts/#{id}", client)
    end
  end

  @doc """
  Updates a shift.

  Only the fields given are changed. On a **published** shift the changes
  are not applied straight away: they are held as `"unpublishedChanges"`
  and take effect when the shift is published again.

  If the shift already repeats, `"recurrenceEditOption"` is required:
  `"instance"` (just this shift), `"future"` (this shift and the ones
  after it), or `"all"` (every repeat from now on).

  ## Parameters

    * `client` - Client configuration created with `BambooHR.Client.new/1`
    * `shift_id` - The shift's UUID
    * `changes` - Map of the fields to change: `"name"`, `"color"`,
      `"capacity"`, `"start"`, `"end"`, `"timezone"`, `"employeeIds"`,
      and the `"recurrence*"` fields. Two more are about the update
      itself. `"updatedAt"` is the value you last read for the shift: if
      someone has changed it since, BambooHR rejects the update and you
      get a `:conflict` error, so you don't overwrite their change. Leave
      it out to skip the check. `"unpublishedChanges"` only takes `nil`,
      which throws away changes waiting to be published

  ## Examples

      iex> BambooHR.Scheduling.update_shift(client, "9c14...", %{"capacity" => 3})
      {:ok, %{"id" => "9c14...", "capacity" => 3}}

      iex> BambooHR.Scheduling.update_shift(client, "9c14...", %{
      ...>   "capacity" => 3,
      ...>   "recurrenceEditOption" => "future"
      ...> })
      {:ok, %{"id" => "9c14...", "capacity" => 3}}
  """
  @spec update_shift(Client.t(), String.t(), map()) :: Client.response()
  def update_shift(client, shift_id, changes) when is_binary(shift_id) and is_map(changes) do
    with {:ok, id} <- segment(shift_id) do
      Client.patch("/scheduling/shifts/#{id}", client, json: changes)
    end
  end

  @doc """
  Deletes a shift.

  On success, returns `nil` (no response body).

  ## Parameters

    * `client` - Client configuration created with `BambooHR.Client.new/1`
    * `shift_id` - The shift's UUID, or a composite recurrence ID
    * `opts` - Optional keyword list: `:recurrence_edit_option`, which
      says how many of a recurring shift's repeats to delete:
      `"instance"` (the default, just this shift), `"future"` (this shift
      and the ones after it), or `"all"` (every repeat from now on)

  ## Examples

      iex> BambooHR.Scheduling.delete_shift(client, "9c14...")
      {:ok, nil}
  """
  @spec delete_shift(Client.t(), String.t(), opts()) :: Client.response()
  def delete_shift(client, shift_id, opts \\ []) when is_binary(shift_id) do
    with {:ok, id} <- segment(shift_id),
         {:ok, opts} <- keyword(opts),
         {:ok, params} <- build_params(opts, recurrence_edit_option: "recurrenceEditOption") do
      Client.delete("/scheduling/shifts/#{id}", client, params: params)
    end
  end

  @doc """
  Publishes planned shifts, making them visible to employees.

  Shifts that clash with something else are skipped rather than failing
  the whole call. BambooHR answers `207` when only some of them
  published and `409` when none did. Both come back as an error, so a
  caller that matches `{:ok, _}` cannot mistake a partial run for a
  clean one: `207` is `:partial_publish` and `409` is `:conflict`. Each
  error's `:body` holds the JSON with both lists, so the shifts that did
  publish and the reason for each failure are still there.

  The HTTP client hands a `207` back as a success, like any 2xx, so
  this function turns a result with anything in `"failed"` into the
  `:partial_publish` error. That works the same with a custom
  `BambooHR.HTTPClient`. The `:body` of that error is the result encoded
  as JSON again, or as `inspect/1` prints it if a custom client handed
  back something JSON cannot hold. Telemetry sees the HTTP request,
  which succeeded, so it records a `207` as `:ok`.

  ## Parameters

    * `client` - Client configuration created with `BambooHR.Client.new/1`
    * `shift_ids` - List of 1 to 100 shift IDs to publish: UUIDs, or the
      composite IDs `list_shifts/2` returns for repeats that do not
      exist yet. An empty list, or more than 100, is a `422` error

  ## Examples

      iex> BambooHR.Scheduling.publish_shifts(client, ["9c14..."])
      {:ok, %{"published" => [%{"id" => "9c14...", "status" => "published"}], "failed" => []}}

      iex> BambooHR.Scheduling.publish_shifts(client, ["9c14...", "2b77..."])
      {:error,
       %BambooHR.Error{
         reason: :partial_publish,
         status: 207,
         body: ~s({"failed":[{"shiftId":"2b77..."}],"published":[{"id":"9c14..."}]})
       }}
  """
  @spec publish_shifts(Client.t(), list(String.t())) :: Client.response()
  def publish_shifts(client, shift_ids) when is_list(shift_ids) do
    # The headers are asked for so a partial publish keeps its request ID.
    "/scheduling/shifts/publish"
    |> Client.post(client, json: %{"shiftIds" => shift_ids}, expose_headers: true)
    |> partial_publish_to_error()
  end

  # A 207 is a 2xx, so the HTTP client returns it as a success. BambooHR
  # only reports failures on a 207 or a 409, and a 409 is already an
  # error, so a success with failures in it was a 207. This is done here
  # rather than in the HTTP client, so a custom client needs no new
  # option for it. A client that ignores `:expose_headers` hands back the
  # bare body, which is checked the same way.
  defp partial_publish_to_error({:ok, %{body: body, headers: headers}}),
    do: failed_to_error(body, headers)

  defp partial_publish_to_error({:ok, body}), do: failed_to_error(body, %{})
  defp partial_publish_to_error(error), do: error

  defp failed_to_error(%{"failed" => [_ | _]} = body, headers) do
    headers = if is_map(headers), do: headers, else: %{}

    {:error, BambooHR.Error.from_partial_success(:partial_publish, 207, encode(body), headers)}
  end

  defp failed_to_error(body, _headers), do: {:ok, body}

  # A custom client can hand back a term JSON cannot hold, such as a
  # tuple. `Jason.encode!/1` would raise on it.
  defp encode(result) do
    case Jason.encode(result) do
      {:ok, json} -> json
      {:error, _reason} -> inspect(result)
    end
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
  @spec list_shift_assessments(Client.t(), opts()) :: Client.response()
  def list_shift_assessments(client, opts \\ []) do
    with {:ok, params} <- list_params(opts) do
      Client.get("/scheduling/shift-assessments", client, params: params)
    end
  end

  defp list_params(opts) do
    with {:ok, opts} <- keyword(opts) do
      build_params(opts, filter: "filter", sort: "sort", page: "page", page_size: "pageSize")
    end
  end

  defp shift_params(opts) do
    with {:ok, opts} <- keyword(opts) do
      opts
      |> end_of_day_for(:end)
      |> build_params(
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
  end

  # A `Date` as the end of the window means the whole of that day, not its
  # first second. The end of the day, rather than midnight after it, keeps
  # a full calendar month inside BambooHR's one-month limit.
  defp end_of_day_for(opts, key) do
    case List.keyfind(opts, key, 0) do
      {^key, %Date{} = date} ->
        List.keystore(opts, key, 0, {key, NaiveDateTime.new!(date, ~T[23:59:59])})

      _ ->
        opts
    end
  end

  # The PDF endpoint takes employeeIds[] as a repeated parameter rather
  # than a comma-separated list, so each ID gets its own entry.
  defp pdf_params(opts) do
    opts = split_employee_ids(opts)

    with {:ok, params} <-
           build_params(
             opts,
             [
               group_by: "groupBy",
               include_employees_without_shifts: "includeEmployeesWithoutShifts",
               include_holidays: "includeHolidays",
               include_time_off: "includeTimeOff"
             ],
             [:employee_ids, :retry]
           ) do
      employee_ids =
        for id <- List.wrap(opts[:employee_ids]), do: {"employeeIds[]", format_value(id)}

      {:ok, employee_ids ++ params}
    end
  end

  # `list_shifts/2` sends a string as it is, and BambooHR reads "10,20"
  # there as two IDs. Sent as one employeeIds[] entry it would be one ID
  # that matches nobody, so the string is split here to mean the same.
  # An empty piece stays, so `"10,"` still gets the `:empty_filter` error.
  defp split_employee_ids(opts) do
    case List.keyfind(opts, :employee_ids, 0) do
      {:employee_ids, ids} when is_binary(ids) ->
        split = ids |> String.split(",") |> Enum.map(&String.trim/1)
        List.keystore(opts, :employee_ids, 0, {:employee_ids, split})

      _not_a_string ->
        opts
    end
  end

  # Each retry renders the PDF again, so by default only a request that
  # BambooHR certainly did not process is retried. The default goes out
  # as a function, which a custom client built on Req can pass straight
  # to it. A value no client can use is turned away before the request is
  # sent; `HTTPClient.Req` guards what a function returns.
  defp retry_opt(opts) do
    case List.keyfind(opts, :retry, 0) do
      {:retry, retry} when retry in [nil, :unprocessed] ->
        {:ok, [retry: &BambooHR.HTTPClient.Req.retry_unprocessed?/2]}

      {:retry, retry} when retry in [false, :safe_transient, :transient] ->
        {:ok, [retry: retry]}

      {:retry, retry} when is_function(retry, 2) ->
        {:ok, [retry: retry]}

      {:retry, other} ->
        {:error,
         invalid_argument(
           ":retry is #{inspect(other)}, so the request was not sent. Pass false, " <>
             ":unprocessed, :safe_transient, :transient or a 2-arity function."
         )}

      nil ->
        {:ok, [retry: &BambooHR.HTTPClient.Req.retry_unprocessed?/2]}
    end
  end

  # Takes options `keyword/1` has already read, since some callers need
  # the list before this runs. `false` is a meaningful value for the PDF
  # flags, so it is kept.
  defp build_params(opts, mapping, also_known \\ []) do
    with :ok <- check_known(opts, Keyword.keys(mapping) ++ also_known),
         :ok <- check_values(opts),
         :ok <- check_not_empty(opts) do
      {:ok, for({key, param} <- mapping, (value = opts[key]) != nil, do: {param, join(value)})}
    end
  end

  # An empty value is neither sent nor dropped: BambooHR reads a present
  # but empty `ids` as a filter and ignores every other one, and leaving
  # a filter out returns everything. `[""]` and `""` both go out as
  # `ids=`, the same as `[]` would. See "Empty values" in the moduledoc.
  # Only a filter's empty value means "match nothing", so only a filter
  # gets `:empty_filter`. Any other option, such as `:sort`, is simply
  # not usable when empty.
  @filters [:ids, :employee_ids, :schedule_ids, :statuses, :filter]

  defp check_not_empty(opts) do
    {filters, others} =
      for({key, value} <- opts, key != :retry, empty?(value), do: key)
      |> Enum.split_with(&(&1 in @filters))

    cond do
      filters != [] ->
        {:error,
         %BambooHR.Error{
           reason: :empty_filter,
           message:
             "#{names(filters)} is empty, or holds an empty value, so the request " <>
               "was not sent. Pass nil to mean no filter."
         }}

      others != [] ->
        {:error,
         invalid_argument(
           "#{names(others)} is empty, so the request was not sent. Leave it out, " <>
             "or pass nil, to use the default."
         )}

      true ->
        :ok
    end
  end

  # A value has to be something a query string can hold. Anything else,
  # such as a `MapSet`, a map or a list inside a list, raises once Req
  # encodes the query, and public functions must not raise.
  defp check_values(opts) do
    case for {key, value} <- opts, key != :retry, not sendable?(value), do: key do
      [] ->
        check_nil_items(opts)

      bad ->
        {:error,
         invalid_argument(
           "#{names(bad)} must be a string, number, atom, date, date-time, or a flat " <>
             "list of those, so the request was not sent."
         )}
    end
  end

  # `nil` in `:employee_ids` asks for unassigned shifts, and goes out as
  # the string "null". Anywhere else it is most likely a missing value,
  # such as an ID read from a map that has none, and it would go out as
  # if it were one: `ids=a,null`. `ids` overrides every other filter, so
  # that would quietly change what comes back.
  defp check_nil_items(opts) do
    case for {key, [_ | _] = value} <- opts,
             key not in [:employee_ids, :retry],
             nil in value,
             do: key do
      [] ->
        :ok

      bad ->
        {:error,
         invalid_argument(
           "#{names(bad)} holds nil, so the request was not sent. Only :employee_ids " <>
             "takes nil, to mean unassigned shifts."
         )}
    end
  end

  defp sendable?(value) when is_list(value), do: scalars?(value)
  defp sendable?(value), do: scalar?(value)

  defp scalars?([head | rest]), do: scalar?(head) and scalars?(rest)
  defp scalars?([]), do: true
  defp scalars?(_improper), do: false

  defp scalar?(value) when is_binary(value) or is_atom(value) or is_number(value), do: true
  defp scalar?(%struct{}) when struct in [Date, NaiveDateTime, DateTime], do: true
  defp scalar?(_value), do: false

  defp empty?([]), do: true
  defp empty?(value) when is_list(value), do: Enum.any?(value, &blank?/1)
  defp empty?(value), do: blank?(value)

  defp blank?(value) when is_binary(value), do: String.trim(value) == ""
  defp blank?(_value), do: false

  # An option this module does not know is never dropped. Left out of the
  # request, a misspelt filter like `employee_id` for `employee_ids` would
  # return everything. A string key, as in `%{"ids" => ids}`, is unknown
  # too. Public functions must not raise, so the call returns an error.
  defp check_known(opts, known) do
    case for {key, _value} <- opts, key not in known, do: key do
      [] ->
        :ok

      unknown ->
        {:error,
         invalid_argument(
           "unknown option #{names(unknown)}, so the request was not sent. " <>
             "Option names are atoms, and this call takes #{names(known)}."
         )}
    end
  end

  defp invalid_argument(message) do
    %BambooHR.Error{reason: :invalid_argument, message: message}
  end

  defp names(keys), do: Enum.map_join(keys, ", ", &inspect/1)

  # Options are a keyword list, but `opts[key]` elsewhere in this client
  # also reads a map or `nil`, so both are read here. Anything else would
  # raise further down, so it is turned away.
  defp keyword(nil), do: {:ok, []}
  defp keyword(opts) when is_map(opts) and not is_struct(opts), do: {:ok, Map.to_list(opts)}

  defp keyword(opts) do
    if pairs?(opts) do
      {:ok, opts}
    else
      {:error,
       invalid_argument(
         "the options must be a keyword list, a map or nil, so the request was not sent."
       )}
    end
  end

  defp pairs?([{_key, _value} | rest]), do: pairs?(rest)
  defp pairs?([]), do: true
  defp pairs?(_other), do: false

  # Keeps an ID to one path segment, whatever it holds. Encoding cannot
  # help with three values, so they are turned away. An empty ID leaves
  # the path ending in `/`, which a router may serve as the list
  # endpoint: a blank ID would then delete or fetch at the wrong level.
  # `.` and `..` are unreserved, so they pass through as they are, and a
  # proxy may resolve them as path steps.
  defp segment(id) do
    if String.trim(id) == "" or id in [".", ".."] do
      {:error,
       invalid_argument("#{inspect(id)} cannot be used as an ID, so the request was not sent.")}
    else
      {:ok, URI.encode(id, &URI.char_unreserved?/1)}
    end
  end

  defp join(value) when is_list(value), do: Enum.map_join(value, ",", &format_value/1)
  defp join(value), do: format_value(value)

  # BambooHR spells the open-shift filter as the literal string "null",
  # which `nil` would otherwise render as an empty element. Only
  # `:employee_ids` gets this far with a `nil` in it; see
  # `check_nil_items/1`.
  defp format_value(nil), do: "null"

  # BambooHR wants the shift window as an ISO-8601 date-time with an
  # offset. Req renders a DateTime or NaiveDateTime with a space in place
  # of the `T`, and a Date or NaiveDateTime carries no offset at all, so
  # the zoneless forms are read as UTC.
  # Whole seconds only, as in `Breaks.format_param/1`: `utc_now/0` carries
  # microseconds, and the spec does not say BambooHR accepts them.
  defp format_value(%DateTime{} = value),
    do: value |> DateTime.truncate(:second) |> DateTime.to_iso8601()

  defp format_value(%NaiveDateTime{} = value),
    do: value |> DateTime.from_naive!("Etc/UTC") |> format_value()

  defp format_value(%Date{} = value),
    do: value |> NaiveDateTime.new!(~T[00:00:00]) |> format_value()

  defp format_value(value), do: value

  defp format_ymd(%Date{} = value), do: Date.to_iso8601(value)
  defp format_ymd(value), do: value
end
