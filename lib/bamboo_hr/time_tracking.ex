defmodule BambooHR.TimeTracking do
  @moduledoc """
  Functions for interacting with time tracking resources in the BambooHR API.
  """

  alias BambooHR.Client

  @doc """
  Retrieves timesheet entries within a specified date range.

  ## Parameters

    * `client` - Client configuration created with `BambooHR.Client.new/3`
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

    * `client` - Client configuration created with `BambooHR.Client.new/3`
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

    * `client` - Client configuration created with `BambooHR.Client.new/3`
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

    * `client` - Client configuration created with `BambooHR.Client.new/3`
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
end
