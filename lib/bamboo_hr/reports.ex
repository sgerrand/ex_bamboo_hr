defmodule BambooHR.Reports do
  @moduledoc """
  Functions for interacting with saved custom reports in the BambooHR API.

  Covers the current, non-deprecated "Custom Reports" endpoints only. The
  older `/reports/custom` and `/reports/{id}` endpoints are deprecated in
  favour of these. The newer Datasets API, which replaces ad-hoc reporting
  entirely, lives in `BambooHR.Datasets` instead.
  """

  alias BambooHR.Client

  @doc """
  Retrieves a paginated list of saved custom reports available in the account.

  Each entry contains an `"id"` and a `"name"`; pass the `"id"` to
  `get_report/3` to execute the report and retrieve its data.

  ## Parameters

    * `client` - Client configuration created with `BambooHR.Client.new/1`
    * `params` - Optional query params: `"page"` (default 1) and
      `"page_size"` (default 500, max 1000)

  ## Examples

      iex> BambooHR.Reports.list_reports(client)
      {:ok, %{"reports" => [%{"id" => 42, "name" => "Headcount by Department"}]}}
  """
  @spec list_reports(Client.t(), map()) :: Client.response()
  def list_reports(client, params \\ %{}) do
    Client.get("/custom-reports", client, params: params)
  end

  @doc """
  Executes a saved custom report and returns its data.

  The `"data"` array contains one flat map per employee record, keyed by
  the fields selected when the report was created.

  ## Parameters

    * `client` - Client configuration created with `BambooHR.Client.new/1`
    * `report_id` - The numeric ID of the saved custom report to execute
    * `params` - Optional query params: `"page"` (default 1) and
      `"page_size"` (default 500, max 1000)

  ## Examples

      iex> BambooHR.Reports.get_report(client, 42)
      {:ok, %{"data" => [%{"firstName" => "John", "status" => "Active"}], "aggregations" => []}}
  """
  @spec get_report(Client.t(), integer(), map()) :: Client.response()
  def get_report(client, report_id, params \\ %{}) when is_integer(report_id) do
    Client.get("/custom-reports/#{report_id}", client, params: params)
  end
end
