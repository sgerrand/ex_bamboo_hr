defmodule BambooHR.Employee do
  @moduledoc """
  Functions for interacting with employee resources in the BambooHR API.
  """

  alias BambooHR.Client

  @doc """
  Retrieves information about a specific employee.

  ## Parameters

    * `client` - Client configuration created with `BambooHR.Client.new/1`
    * `employee_id` - The ID of the employee to retrieve
    * `fields` - List of field names to retrieve (e.g., ["firstName", "lastName", "jobTitle"])

  ## Examples

      iex> BambooHR.Employee.get(client, 123, ["firstName", "lastName", "jobTitle"])
      {:ok, %{
        "firstName" => "John",
        "lastName" => "Doe",
        "jobTitle" => "Software Engineer"
      }}
  """
  @spec get(Client.t(), integer(), nonempty_list(String.t())) :: Client.response()
  def get(client, employee_id, fields)
      when is_integer(employee_id) and is_list(fields) and fields != [] do
    Client.get("/employees/#{employee_id}", client, params: [fields: Enum.join(fields, ",")])
  end

  @doc """
  Adds a new employee.

  BambooHR returns no response body for this endpoint — the created
  employee is identified only by the `Location` header, which points to
  the employee's page in the BambooHR web app (and includes the new
  employee's ID). This function surfaces that header as `"location"`; if
  the upstream response has no `Location` header, the result is `{:ok,
  %{}}`.

  ## Parameters

    * `client` - Client configuration created with `BambooHR.Client.new/1`
    * `employee_data` - Map containing the employee information (firstName and lastName are required)

  ## Examples

      iex> employee_data = %{"firstName" => "Jane", "lastName" => "Smith"}
      iex> BambooHR.Employee.add(client, employee_data)
      {:ok, %{"location" => "https://acme.bamboohr.com/employees/employee.php?id=124"}}
  """
  @spec add(Client.t(), map()) :: Client.response()
  def add(client, employee_data) do
    case Client.post("/employees", client, json: employee_data, expose_headers: true) do
      {:ok, %{headers: headers}} -> {:ok, BambooHR.ResponseHeaders.location(headers)}
      {:ok, _unexpected} -> {:ok, %{}}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Updates information for an existing employee.

  ## Parameters

    * `client` - Client configuration created with `BambooHR.Client.new/1`
    * `employee_id` - The ID of the employee to update
    * `employee_data` - Map containing the updated employee information

  ## Examples

      iex> update_data = %{"firstName" => "Jane", "lastName" => "Smith-Jones"}
      iex> BambooHR.Employee.update(client, 124, update_data)
      {:ok, %{}}
  """
  @spec update(Client.t(), integer(), map()) :: Client.response()
  def update(client, employee_id, employee_data) when is_integer(employee_id) do
    Client.post("/employees/#{employee_id}", client, json: employee_data)
  end

  @doc """
  Retrieves the company's employee directory.

  Returns a list of all employees with basic information like name and contact details.

  ## Parameters

    * `client` - Client configuration created with `BambooHR.Client.new/1`

  ## Examples

      iex> BambooHR.Employee.get_directory(client)
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
  @spec get_directory(Client.t()) :: Client.response()
  def get_directory(client) do
    Client.get("/employees/directory", client)
  end

  @doc """
  Lists the IDs of employees that changed since a timestamp.

  Meant for syncing: instead of fetching every employee, fetch the ones
  that changed. A change to any field on the employee record counts, as
  does a change to their employment status, job info, or compensation
  tables.

  Returns `%{"latest" => timestamp, "employees" => %{id => change}}`,
  where each change carries `"id"`, `"action"` (`"Inserted"`, `"Updated"`,
  or `"Deleted"`), and `"lastChanged"`. Feed `"latest"` back as `since` on
  the next sync.

  ## Parameters

    * `client` - Client configuration created with `BambooHR.Client.new/1`
    * `since` - ISO 8601 timestamp; only later changes are returned
    * `opts` - Optional keyword list:
      * `:type` - Limit to one change type: `"inserted"`, `"updated"`,
        `"deleted"`, or `"all"`. Defaults to every type.

  ## Examples

      iex> BambooHR.Employee.get_changed(client, "2024-01-01T00:00:00Z")
      {:ok, %{
        "latest" => "2024-01-15T09:30:00+00:00",
        "employees" => %{
          "123" => %{
            "id" => "123",
            "action" => "Updated",
            "lastChanged" => "2024-01-15T09:30:00+00:00"
          }
        }
      }}
  """
  @spec get_changed(Client.t(), String.t(), keyword()) :: Client.response()
  def get_changed(client, since, opts \\ []) when is_binary(since) do
    params = [since: since] ++ for {:type, type} <- opts, do: {:type, type}

    Client.get("/employees/changed", client, params: params)
  end

  @doc """
  Lists employees, one page at a time.

  Returns `%{"data" => [...], "meta" => %{"total" => n, "page" => %{...}},
  "_links" => %{...}}`. `meta.total` counts every employee matching the
  filter, not just this page. `meta.page.nextCursor` is the cursor for the
  next page, or `nil` on the last one — pass it back as `:after`. Use
  `stream/2` to walk every page.

  Values the caller has no permission to read come back as `nil`, with
  their names listed in the record's `_restrictedFields`. An employee the
  caller cannot read at all still appears, so neither an empty result nor
  an all-`nil` record means the employee does not exist. Filtering or
  sorting on a field the caller cannot read drops those employees from the
  results entirely.

  ## Parameters

    * `client` - Client configuration created with `BambooHR.Client.new/1`
    * `opts` - Optional keyword list:
      * `:filter` - Map of field name to value, combined with AND. A list
        value matches any of its entries, which is how `"ids"` is passed.
        Filtering on an unsupported field returns a `422` error.
      * `:sort` - Field name, or list of them. Prefix with `-` for
        descending order. Sortable: `"employeeId"`, `"firstName"`,
        `"lastName"`, `"preferredName"`, `"jobTitleName"`, `"status"`.
      * `:fields` - List of extra field names to include beyond the
        default set. Unknown names are ignored by BambooHR.
      * `:limit` - Page size, 1 to 2500 (BambooHR defaults to 250)
      * `:after` - Cursor for the next page, from `meta.page.nextCursor`
      * `:before` - Cursor for the previous page, from `meta.page.prevCursor`

  ## Examples

      iex> BambooHR.Employee.list(client, filter: %{"city" => "Austin"}, limit: 2)
      {:ok, %{
        "data" => [%{"employeeId" => "123", "firstName" => "John"}],
        "meta" => %{"total" => 1, "page" => %{"nextCursor" => nil}},
        "_links" => %{"self" => %{"href" => "..."}}
      }}
  """
  @spec list(Client.t(), keyword()) :: Client.response()
  def list(client, opts \\ []) do
    Client.get("/employees", client, params: build_list_params(opts))
  end

  @doc """
  Streams every employee, following the cursor from page to page.

  Each element is `{:ok, employee}`. If a request fails, the stream emits a
  single `{:error, reason}` and stops, so a caller that ignores errors sees
  a short list rather than an exception.

  Requests are made as the stream is consumed. `:after` and `:before` are
  ignored — the stream starts at the first page and pages forward.

  ## Parameters

    * `client` - Client configuration created with `BambooHR.Client.new/1`
    * `opts` - Same as `list/2`, except `:after` and `:before`

  ## Examples

      iex> client |> BambooHR.Employee.stream(fields: ["workEmail"]) |> Enum.take(1)
      [{:ok, %{"employeeId" => "123", "workEmail" => "john@example.com"}}]
  """
  @spec stream(Client.t(), keyword()) :: Enumerable.t()
  def stream(client, opts \\ []) do
    opts = Keyword.drop(opts, [:after, :before])

    Stream.resource(
      fn -> :first_page end,
      fn
        :halt -> {:halt, :halt}
        cursor -> next_page(client, opts, cursor)
      end,
      fn _state -> :ok end
    )
  end

  defp next_page(client, opts, cursor) do
    opts = if cursor == :first_page, do: opts, else: Keyword.put(opts, :after, cursor)

    case list(client, opts) do
      {:ok, %{"data" => data} = page} ->
        {Enum.map(data, &{:ok, &1}), next_cursor(page)}

      {:ok, _unexpected} ->
        {:halt, :halt}

      {:error, reason} ->
        {[{:error, reason}], :halt}
    end
  end

  defp next_cursor(page) do
    case get_in(page, ["meta", "page", "nextCursor"]) do
      cursor when is_binary(cursor) and cursor != "" -> cursor
      _ -> :halt
    end
  end

  # BambooHR takes filters and pagination as bracketed query parameters —
  # filter[city]=Austin, page[limit]=250 — which Req does not build from
  # nested maps, so they are flattened here.
  defp build_list_params(opts) do
    filters =
      opts
      |> Keyword.get(:filter, %{})
      |> Enum.map(fn {field, value} -> {"filter[#{field}]", join(value)} end)

    page =
      for key <- [:limit, :after, :before], value = opts[key] do
        {"page[#{key}]", value}
      end

    optional =
      for key <- [:sort, :fields], value = opts[key] do
        {to_string(key), join(value)}
      end

    filters ++ page ++ optional
  end

  defp join(value) when is_list(value), do: Enum.join(value, ",")
  defp join(value), do: value
end
