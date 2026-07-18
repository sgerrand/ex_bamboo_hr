defmodule BambooHR.Datasets do
  @moduledoc """
  Functions for querying the BambooHR Datasets API.

  Datasets are the current, non-deprecated replacement for ad-hoc custom
  reporting — see `BambooHR.Reports` for the older, still-supported saved
  Custom Reports endpoints. Datasets endpoints live under different API
  version segments than the rest of this client (`v1_2` for catalog/field
  discovery, `v2` for querying data); every function here passes the
  appropriate `api_version:` to `BambooHR.Client` for you.
  """

  alias BambooHR.Client

  @doc """
  Retrieves the catalog of datasets available for querying.

  Each entry's `"name"` is the machine-readable identifier used as
  `dataset_name` in `get_dataset_fields/3`, `get_field_options/4`, and
  `get_dataset_data/4`.

  ## Parameters

    * `client` - Client configuration created with `BambooHR.Client.new/1`

  ## Examples

      iex> BambooHR.Datasets.list_datasets(client)
      {:ok, %{"datasets" => [%{"name" => "employee", "label" => "Employee"}]}}
  """
  @spec list_datasets(Client.t()) :: Client.response()
  def list_datasets(client) do
    Client.get("/datasets", client, api_version: "v1_2")
  end

  @doc """
  Retrieves a paginated list of field descriptors for a dataset.

  Use the returned field `"name"` values in the `fields` argument to
  `get_field_options/4` and `get_dataset_data/4`.

  ## Parameters

    * `client` - Client configuration created with `BambooHR.Client.new/1`
    * `dataset_name` - Machine-readable dataset identifier (see `list_datasets/1`)
    * `params` - Optional query params: `"page"` (default 1) and
      `"page_size"` (default 500, max 1000)

  ## Examples

      iex> BambooHR.Datasets.get_dataset_fields(client, "employee")
      {:ok, %{"name" => "employee", "fields" => [%{"name" => "status", "label" => "Status"}]}}
  """
  @spec get_dataset_fields(Client.t(), String.t(), map()) :: Client.response()
  def get_dataset_fields(client, dataset_name, params \\ %{}) when is_binary(dataset_name) do
    Client.get("/datasets/#{dataset_name}/fields", client, params: params, api_version: "v1_2")
  end

  @doc """
  Retrieves the allowed values for one or more fields in a dataset, for use
  as filter values when querying data via `get_dataset_data/4`.

  ## Parameters

    * `client` - Client configuration created with `BambooHR.Client.new/1`
    * `dataset_name` - Machine-readable dataset identifier (see `list_datasets/1`)
    * `fields` - List of field names to get options for
    * `opts` - Optional keyword list: `:filters` - a map narrowing which
      options are returned (e.g. only options that exist for active
      employees); `:dependent_fields` - a map of field name to the other
      fields/values its options depend on

  ## Examples

      iex> BambooHR.Datasets.get_field_options(client, "employee", ["status"])
      {:ok, %{"status" => [%{"id" => "Active", "value" => "Active"}]}}
  """
  @spec get_field_options(Client.t(), String.t(), list(String.t()), keyword()) ::
          Client.response()
  def get_field_options(client, dataset_name, fields, opts \\ [])
      when is_binary(dataset_name) and is_list(fields) do
    body =
      %{"fields" => fields}
      |> maybe_put("filters", Keyword.get(opts, :filters))
      |> maybe_put("dependentFields", Keyword.get(opts, :dependent_fields))

    Client.post("/datasets/#{dataset_name}/field-options", client,
      json: body,
      api_version: "v1_2"
    )
  end

  @doc """
  Queries a dataset and returns matching records.

  Each row in the `"data"` array wraps its values under a `"fields"`
  object. Use `get_dataset_fields/3` to discover available field names and
  `get_field_options/4` to discover valid filter values.

  ## Parameters

    * `client` - Client configuration created with `BambooHR.Client.new/1`
    * `dataset_name` - Machine-readable dataset identifier (see `list_datasets/1`)
    * `fields` - List of field names to return
    * `opts` - Optional keyword list: `:filter` - an OData-style filter
      expression string (operators: `eq`, `ne`, `lt`, `le`, `gt`, `ge`,
      `and`, `or`, `in`); `:order_by` - comma-separated sort rules, each a
      field name followed by `asc` or `desc` (sorted fields must also
      appear in `fields`); `:page` - page number, defaults to 1;
      `:page_size` - records per page, defaults to 100, max 1000

  ## Examples

      iex> BambooHR.Datasets.get_dataset_data(client, "employee", ["firstName", "lastName", "status"],
      ...>   filter: "status eq 'Active'"
      ...> )
      {:ok, %{"data" => [%{"fields" => %{"firstName" => "Jane", "status" => "Active"}}], "meta" => %{"page" => 1}}}
  """
  @spec get_dataset_data(Client.t(), String.t(), list(String.t()), keyword()) ::
          Client.response()
  def get_dataset_data(client, dataset_name, fields, opts \\ [])
      when is_binary(dataset_name) and is_list(fields) do
    body =
      %{"fields" => fields}
      |> maybe_put("filter", Keyword.get(opts, :filter))
      |> maybe_put("orderBy", Keyword.get(opts, :order_by))
      |> maybe_put("page", Keyword.get(opts, :page))
      |> maybe_put("pageSize", Keyword.get(opts, :page_size))

    Client.post("/datasets/#{dataset_name}/data", client, json: body, api_version: "v2")
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
