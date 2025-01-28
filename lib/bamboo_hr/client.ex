defmodule BambooHR.Client do
  @moduledoc """
  Client for interacting with the BambooHR API.

  ## Configuration

  To use this client, you'll need information from BambooHR:
  - Your company's subdomain
  - An API key

  ## Usage

      config = BambooHR.Client.new("your_company", "your_api_key")
      {:ok, company_info} = BambooHR.Client.get_company_information(config)
  """

  @type config :: %{
          company_domain: String.t(),
          api_key: String.t(),
          base_url: String.t()
        }

  @type response :: {:ok, map()} | {:error, any()}

  @doc """
  Creates a new client configuration.

  ## Parameters

    * `company_domain` - Your company's subdomain
    * `api_key` - Your API key
    * `base_url` - Optional custom base URL for the API (defaults to BambooHR's standard API URL)

  ## Examples

      iex> config = BambooHR.Client.new("acme", "api_key_123")
      %{
        company_domain: "acme",
        api_key: "api_key_123",
        base_url: "https://api.bamboohr.com/api/gateway.php"
      }

      # With custom base URL
      iex> config = BambooHR.Client.new("acme", "api_key_123", "https://custom-api.example.com")
      %{
        company_domain: "acme",
        api_key: "api_key_123",
        base_url: "https://custom-api.example.com"
      }
  """
  @spec new(String.t(), String.t(), String.t() | nil) :: config()
  def new(company_domain, api_key, base_url \\ nil) do
    %{
      company_domain: company_domain,
      api_key: api_key,
      base_url: base_url || "https://api.bamboohr.com/api/gateway.php"
    }
  end

  @doc """
  Retrieves company information.

  Returns basic company details including name, address, and employee count.

  ## Examples

      iex> BambooHR.Client.get_company_information(config)
      {:ok, %{
        "name" => "Acme Corp",
        "employeeCount" => 100,
        "city" => "San Francisco"
      }}
  """
  @spec get_company_information(config()) :: response()
  def get_company_information(config) do
    get("/company_information", config)
  end

  @doc """
  Retrieves company EINs (Employer Identification Numbers).

  Returns a list of EINs associated with the company.

  ## Examples

      iex> BambooHR.Client.get_company_eins(config)
      {:ok, %{
        "eins" => [
          %{"ein" => "12-3456789", "name" => "Acme Corp"},
          %{"ein" => "98-7654321", "name" => "Acme Subsidiary"}
        ]
      }}
  """
  @spec get_company_eins(config()) :: response()
  def get_company_eins(config) do
    get("/company_eins", config)
  end

  @doc """
  Retrieves information about a specific employee.

  ## Parameters

    * `config` - Client configuration
    * `employee_id` - The ID of the employee to retrieve
    * `fields` - List of field names to retrieve (e.g., ["firstName", "lastName", "jobTitle"])

  ## Examples

      iex> BambooHR.Client.get_employee(config, 123, ["firstName", "lastName", "jobTitle"])
      {:ok, %{
        "firstName" => "John",
        "lastName" => "Doe",
        "jobTitle" => "Software Engineer"
      }}
  """
  @spec get_employee(config(), integer(), list(String.t())) :: response()
  def get_employee(config, employee_id, fields) when is_integer(employee_id) do
    get("/employees/#{employee_id}", config, params: [fields: Enum.join(fields, ",")])
  end

  @doc """
  Adds a new employee.

  ## Parameters

    * `config` - Client configuration
    * `employee_data` - Map containing the employee information (firstName and lastName are required)

  ## Examples

      iex> employee_data = %{"firstName" => "Jane", "lastName" => "Smith"}
      iex> BambooHR.Client.add_employee(config, employee_data)
      {:ok, %{"id" => 124}}
  """
  @spec add_employee(config(), map()) :: response()
  def add_employee(config, employee_data) do
    post("/employees", config, json: employee_data)
  end

  @doc """
  Updates information for an existing employee.

  ## Parameters

    * `config` - Client configuration
    * `employee_id` - The ID of the employee to update
    * `employee_data` - Map containing the updated employee information

  ## Examples

      iex> update_data = %{"firstName" => "Jane", "lastName" => "Smith-Jones"}
      iex> BambooHR.Client.update_employee(config, 124, update_data)
      {:ok, %{}}
  """
  @spec update_employee(config(), integer(), map()) :: response()
  def update_employee(config, employee_id, employee_data) when is_integer(employee_id) do
    post("/employees/#{employee_id}", config, json: employee_data)
  end

  @doc """
  Retrieves the company's employee directory.

  Returns a list of all employees with basic information like name and contact details.

  ## Examples

      iex> BambooHR.Client.get_employee_directory(config)
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
  @spec get_employee_directory(config()) :: response()
  def get_employee_directory(config) do
    get("/employees/directory", config)
  end

  @doc """
  Retrieves timesheet entries within a specified date range.

  ## Parameters

    * `config` - Client configuration
    * `params` - Map containing query parameters (start, end dates, and optional employee IDs)

  ## Examples

      iex> params = %{
      ...>   "start" => "2024-01-01",
      ...>   "end" => "2024-01-31",
      ...>   "employeeIds" => "123,124"
      ...> }
      iex> BambooHR.Client.get_timesheet_entries(config, params)
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
  @spec get_timesheet_entries(config(), map()) :: response()
  def get_timesheet_entries(config, params) do
    get("/time_tracking/timesheet_entries", config, params: params)
  end

  @doc """
  Stores timesheet clock entries for employees.

  ## Parameters

    * `config` - Client configuration
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
      iex> BambooHR.Client.store_timesheet_clock_entries(config, entries)
      {:ok, %{"message" => "Entries stored successfully"}}
  """
  @spec store_timesheet_clock_entries(config(), list(map())) :: response()
  def store_timesheet_clock_entries(config, entries) do
    post("/time_tracking/clock_entries/store", config, json: %{items: entries})
  end

  @doc """
  Records a clock-in event for an employee.

  ## Parameters

    * `config` - Client configuration
    * `employee_id` - The ID of the employee to clock in
    * `clock_data` - Map containing clock-in details (date, start time, timezone, etc.)

  ## Examples

      iex> clock_data = %{
      ...>   "date" => "2024-01-15",
      ...>   "start" => "09:00",
      ...>   "timezone" => "America/New_York"
      ...> }
      iex> BambooHR.Client.clock_in_employee(config, 123, clock_data)
      {:ok, %{"message" => "Successfully clocked in"}}
  """
  @spec clock_in_employee(config(), integer(), map()) :: response()
  def clock_in_employee(config, employee_id, clock_data) when is_integer(employee_id) do
    post("/time_tracking/employees/#{employee_id}/clock_in", config, json: clock_data)
  end

  @doc """
  Records a clock-out event for an employee.

  ## Parameters

    * `config` - Client configuration
    * `employee_id` - The ID of the employee to clock out
    * `clock_data` - Map containing clock-out details (date, end time, timezone)

  ## Examples

      iex> clock_data = %{
      ...>   "date" => "2024-01-15",
      ...>   "end" => "17:00",
      ...>   "timezone" => "America/New_York"
      ...> }
      iex> BambooHR.Client.clock_out_employee(config, 123, clock_data)
      {:ok, %{"message" => "Successfully clocked out"}}
  """
  @spec clock_out_employee(config(), integer(), map()) :: response()
  def clock_out_employee(config, employee_id, clock_data) when is_integer(employee_id) do
    post("/time_tracking/employees/#{employee_id}/clock_out", config, json: clock_data)
  end

  defp get(path, config, opts \\ []) do
    request(:get, path, config, opts)
  end

  defp post(path, config, opts) do
    request(:post, path, config, opts)
  end

  defp request(method, path, config, opts) do
    url = build_url(config, path)
    headers = build_headers(config.api_key)

    req_opts = Keyword.merge([headers: headers], opts)

    case Req.new(url: url)
         |> Req.merge(req_opts)
         |> Req.request(method: method) do
      {:ok, %{status: status, body: body}} when status in 200..299 ->
        {:ok, body}

      {:ok, %{status: status, body: body}} ->
        {:error, %{status: status, body: body}}

      {:error, error} ->
        {:error, error}
    end
  end

  defp build_url(config, path) do
    "#{config.base_url}/#{config.company_domain}/v1#{path}"
  end

  defp build_headers(api_key) do
    [
      {"Authorization", "Basic " <> Base.encode64("#{api_key}:x")},
      {"Accept", "application/json"}
    ]
  end
end
