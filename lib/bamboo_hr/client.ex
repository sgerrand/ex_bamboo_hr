defmodule BambooHR.Client do
  @moduledoc """
  Client for interacting with the BambooHR API.
  """

  @type config :: %{
          company_domain: String.t(),
          api_key: String.t(),
          base_url: String.t()
        }

  @type response :: {:ok, map()} | {:error, any()}

  @spec new(String.t(), String.t(), String.t() | nil) :: config()
  def new(company_domain, api_key, base_url \\ nil) do
    %{
      company_domain: company_domain,
      api_key: api_key,
      base_url: base_url || "https://api.bamboohr.com/api/gateway.php"
    }
  end

  @spec get_company_information(config()) :: response()
  def get_company_information(config) do
    get("/company_information", config)
  end

  @spec get_company_eins(config()) :: response()
  def get_company_eins(config) do
    get("/company_eins", config)
  end

  @spec get_employee(config(), integer(), list(String.t())) :: response()
  def get_employee(config, employee_id, fields) when is_integer(employee_id) do
    get("/employees/#{employee_id}", config, params: [fields: Enum.join(fields, ",")])
  end

  @spec add_employee(config(), map()) :: response()
  def add_employee(config, employee_data) do
    post("/employees", config, json: employee_data)
  end

  @spec update_employee(config(), integer(), map()) :: response()
  def update_employee(config, employee_id, employee_data) when is_integer(employee_id) do
    post("/employees/#{employee_id}", config, json: employee_data)
  end

  @spec get_employee_directory(config()) :: response()
  def get_employee_directory(config) do
    get("/employees/directory", config)
  end

  @spec get_timesheet_entries(config(), map()) :: response()
  def get_timesheet_entries(config, params) do
    get("/time_tracking/timesheet_entries", config, params: params)
  end

  @spec store_timesheet_clock_entries(config(), list(map())) :: response()
  def store_timesheet_clock_entries(config, entries) do
    post("/time_tracking/clock_entries/store", config, json: %{items: entries})
  end

  @spec clock_in_employee(config(), integer(), map()) :: response()
  def clock_in_employee(config, employee_id, clock_data) when is_integer(employee_id) do
    post("/time_tracking/employees/#{employee_id}/clock_in", config, json: clock_data)
  end

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
