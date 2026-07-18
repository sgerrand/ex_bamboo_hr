defmodule BambooHR.Files do
  @moduledoc """
  Functions for interacting with company and employee file resources in the
  BambooHR API.

  Covers file categories, uploads, downloads, metadata updates, and
  deletion, for both company-wide files and employee-scoped files.
  """

  alias BambooHR.Client

  @doc """
  Creates one or more company file categories.

  On success, returns `nil` (no response body).

  ## Parameters

    * `client` - Client configuration created with `BambooHR.Client.new/1`
    * `category_names` - List of category name strings; each must be
      non-empty and unique among existing company file categories

  ## Examples

      iex> BambooHR.Files.create_company_file_category(client, ["Contracts"])
      {:ok, nil}
  """
  @spec create_company_file_category(Client.t(), list(String.t())) :: Client.response()
  def create_company_file_category(client, category_names) when is_list(category_names) do
    Client.post("/files/categories", client, json: category_names)
  end

  @doc """
  Creates one or more employee file categories (not company file categories).

  On success, returns `nil` (no response body).

  ## Parameters

    * `client` - Client configuration created with `BambooHR.Client.new/1`
    * `category_names` - List of category name strings; each must be
      non-empty and unique among existing employee file categories

  ## Examples

      iex> BambooHR.Files.create_employee_file_category(client, ["Certifications"])
      {:ok, nil}
  """
  @spec create_employee_file_category(Client.t(), list(String.t())) :: Client.response()
  def create_employee_file_category(client, category_names) when is_list(category_names) do
    Client.post("/employees/files/categories", client, json: category_names)
  end

  @doc """
  Retrieves all company file categories and the files within each category
  that the requesting user is permitted to see.

  ## Parameters

    * `client` - Client configuration created with `BambooHR.Client.new/1`

  ## Examples

      iex> BambooHR.Files.list_company_files(client)
      {:ok, %{"categories" => [%{"id" => 1, "name" => "Policies", "files" => []}]}}
  """
  @spec list_company_files(Client.t()) :: Client.response()
  def list_company_files(client) do
    Client.get("/files/view", client)
  end

  @doc """
  Lists the file categories and files visible to the caller for the
  specified employee.

  This is a metadata listing (names, sizes, permissions); to download a
  file's content use `get_employee_file/3`.

  ## Parameters

    * `client` - Client configuration created with `BambooHR.Client.new/1`
    * `employee_id` - The ID of the employee whose files are being listed

  ## Examples

      iex> BambooHR.Files.list_employee_files(client, 123)
      {:ok, %{"employee" => %{"id" => 123}, "categories" => []}}
  """
  @spec list_employee_files(Client.t(), integer()) :: Client.response()
  def list_employee_files(client, employee_id) when is_integer(employee_id) do
    Client.get("/employees/#{employee_id}/files/view", client)
  end

  @doc """
  Uploads a file to a company file category.

  On success, returns `{:ok, %{"location" => url}}`, where `url` points to
  the new file resource; `{:ok, %{}}` if no `Location` header is present.

  ## Parameters

    * `client` - Client configuration created with `BambooHR.Client.new/1`
    * `file_name` - Display name for the uploaded file
    * `category_id` - ID of the file category (section) to upload into
    * `file_content` - Binary file content
    * `opts` - Optional keyword list: `:share` - whether to share the file
      with all employees (defaults to `false`)

  ## Examples

      iex> BambooHR.Files.upload_company_file(client, "handbook.pdf", 3, pdf_binary)
      {:ok, %{"location" => "https://acme.bamboohr.com/files/123"}}
  """
  @spec upload_company_file(Client.t(), String.t(), integer(), binary(), keyword()) ::
          Client.response()
  def upload_company_file(client, file_name, category_id, file_content, opts \\ [])
      when is_integer(category_id) and is_binary(file_content) do
    upload(client, "/files", file_name, category_id, file_content, opts)
  end

  @doc """
  Uploads a file to an employee's file section.

  Pass `0` as `employee_id` to use the employee associated with the API
  key. On success, returns `{:ok, %{"location" => url}}`, where `url`
  points to the new file resource; `{:ok, %{}}` if no `Location` header is
  present.

  ## Parameters

    * `client` - Client configuration created with `BambooHR.Client.new/1`
    * `employee_id` - The ID of the employee to upload the file for
    * `file_name` - Display name for the uploaded file
    * `category_id` - ID of the employee file section to upload into
    * `file_content` - Binary file content
    * `opts` - Optional keyword list: `:share` - whether to share the file
      with the employee (defaults to `false`)

  ## Examples

      iex> BambooHR.Files.upload_employee_file(client, 123, "resume.pdf", 5, pdf_binary)
      {:ok, %{"location" => "https://acme.bamboohr.com/employees/files/456"}}
  """
  @spec upload_employee_file(Client.t(), integer(), String.t(), integer(), binary(), keyword()) ::
          Client.response()
  def upload_employee_file(client, employee_id, file_name, category_id, file_content, opts \\ [])
      when is_integer(employee_id) and is_integer(category_id) and is_binary(file_content) do
    upload(client, "/employees/#{employee_id}/files", file_name, category_id, file_content, opts)
  end

  defp upload(client, path, file_name, category_id, file_content, opts) do
    share = if Keyword.get(opts, :share, false), do: "yes", else: "no"

    form = [
      fileName: file_name,
      category: category_id,
      share: share,
      file: {file_content, filename: file_name}
    ]

    case Client.post(path, client, form_multipart: form, expose_headers: true) do
      {:ok, %{headers: headers}} -> {:ok, location_header(headers)}
      {:error, reason} -> {:error, reason}
    end
  end

  defp location_header(headers) do
    case Map.get(headers, "location") do
      [location | _] -> %{"location" => location}
      _ -> %{}
    end
  end

  @doc """
  Downloads a company file by its ID.

  Returns `{:ok, %{body: binary_content, headers: headers}}`. `headers`
  includes `"content-type"` and `"content-disposition"` (which carries the
  original filename) as BambooHR set them.

  ## Parameters

    * `client` - Client configuration created with `BambooHR.Client.new/1`
    * `file_id` - The ID of the company file to download

  ## Examples

      iex> BambooHR.Files.get_company_file(client, 123)
      {:ok, %{body: <<37, 80, 68, 70>>, headers: %{"content-type" => ["application/pdf"]}}}
  """
  @spec get_company_file(Client.t(), integer()) :: Client.response()
  def get_company_file(client, file_id) when is_integer(file_id) do
    Client.get("/files/#{file_id}", client, raw_response: true, expose_headers: true)
  end

  @doc """
  Downloads an employee file by its ID.

  Pass `0` as `employee_id` to use the employee associated with the API
  key. Returns `{:ok, %{body: binary_content, headers: headers}}`.
  `headers` includes `"content-type"` and `"content-disposition"` (which
  carries the original filename) as BambooHR set them.

  ## Parameters

    * `client` - Client configuration created with `BambooHR.Client.new/1`
    * `employee_id` - The ID of the employee whose file is being retrieved
    * `file_id` - The ID of the employee file to download

  ## Examples

      iex> BambooHR.Files.get_employee_file(client, 123, 456)
      {:ok, %{body: <<37, 80, 68, 70>>, headers: %{"content-type" => ["application/pdf"]}}}
  """
  @spec get_employee_file(Client.t(), integer(), integer()) :: Client.response()
  def get_employee_file(client, employee_id, file_id)
      when is_integer(employee_id) and is_integer(file_id) do
    Client.get("/employees/#{employee_id}/files/#{file_id}", client,
      raw_response: true,
      expose_headers: true
    )
  end

  @doc """
  Updates metadata for an existing company file.

  Supports renaming the file, moving it to a different category, and
  toggling employee visibility. Only fields included in `update_data` are
  updated.

  ## Parameters

    * `client` - Client configuration created with `BambooHR.Client.new/1`
    * `file_id` - The ID of the company file to update
    * `update_data` - Map with any of `"name"`, `"categoryId"`,
      `"shareWithEmployee"`

  ## Examples

      iex> BambooHR.Files.update_company_file(client, 123, %{"name" => "handbook-v2.pdf"})
      {:ok, nil}
  """
  @spec update_company_file(Client.t(), integer(), map()) :: Client.response()
  def update_company_file(client, file_id, update_data) when is_integer(file_id) do
    Client.post("/files/#{file_id}", client, json: update_data)
  end

  @doc """
  Updates metadata for an existing employee file.

  Supports renaming the file, moving it to a different category, and
  toggling employee visibility. Only fields included in `update_data` are
  updated.

  ## Parameters

    * `client` - Client configuration created with `BambooHR.Client.new/1`
    * `employee_id` - The ID of the employee whose file is being updated
    * `file_id` - The ID of the employee file to update
    * `update_data` - Map with any of `"name"`, `"categoryId"`,
      `"shareWithEmployee"`

  ## Examples

      iex> BambooHR.Files.update_employee_file(client, 123, 456, %{"name" => "resume-2024.pdf"})
      {:ok, nil}
  """
  @spec update_employee_file(Client.t(), integer(), integer(), map()) :: Client.response()
  def update_employee_file(client, employee_id, file_id, update_data)
      when is_integer(employee_id) and is_integer(file_id) do
    Client.post("/employees/#{employee_id}/files/#{file_id}", client, json: update_data)
  end

  @doc """
  Permanently deletes a company file.

  On success, returns `nil` (no response body).

  ## Parameters

    * `client` - Client configuration created with `BambooHR.Client.new/1`
    * `file_id` - The ID of the company file to delete

  ## Examples

      iex> BambooHR.Files.delete_company_file(client, 123)
      {:ok, nil}
  """
  @spec delete_company_file(Client.t(), integer()) :: Client.response()
  def delete_company_file(client, file_id) when is_integer(file_id) do
    Client.delete("/files/#{file_id}", client)
  end

  @doc """
  Permanently deletes an employee file.

  Pass `0` as `employee_id` to use the employee associated with the API
  key. Idempotent — returns success even if the file was already deleted.

  ## Parameters

    * `client` - Client configuration created with `BambooHR.Client.new/1`
    * `employee_id` - The ID of the employee whose file is being deleted
    * `file_id` - The ID of the employee file to delete

  ## Examples

      iex> BambooHR.Files.delete_employee_file(client, 123, 456)
      {:ok, nil}
  """
  @spec delete_employee_file(Client.t(), integer(), integer()) :: Client.response()
  def delete_employee_file(client, employee_id, file_id)
      when is_integer(employee_id) and is_integer(file_id) do
    Client.delete("/employees/#{employee_id}/files/#{file_id}", client)
  end
end
