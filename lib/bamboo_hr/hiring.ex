defmodule BambooHR.Hiring do
  @moduledoc """
  Functions for interacting with the Applicant Tracking System (ATS) in the
  BambooHR API.

  The owner of the API key used for these endpoints must have access to ATS
  settings.
  """

  alias BambooHR.Client

  @doc """
  Retrieves a paginated list of job applications.

  ## Parameters

    * `client` - Client configuration created with `BambooHR.Client.new/1`
    * `params` - Optional query params: `"page"`, `"jobId"`,
      `"applicationStatusId"`, `"applicationStatus"`, `"jobStatusGroups"`,
      `"searchString"`, `"sortBy"`, `"sortOrder"`, `"newSince"`

  ## Examples

      iex> BambooHR.Hiring.get_applications(client)
      {:ok, %{"applications" => [], "paginationComplete" => true, "nextPageUrl" => nil}}
  """
  @spec get_applications(Client.t(), map()) :: Client.response()
  def get_applications(client, params \\ %{}) do
    Client.get("/applicant_tracking/applications", client, params: params)
  end

  @doc """
  Retrieves the full details of a single application, including applicant
  info, job details, questions and answers, and status history.

  ## Parameters

    * `client` - Client configuration created with `BambooHR.Client.new/1`
    * `application_id` - The ID of the application to retrieve

  ## Examples

      iex> BambooHR.Hiring.get_application(client, 42)
      {:ok, %{"id" => 42, "applicant" => %{"firstName" => "Jane"}}}
  """
  @spec get_application(Client.t(), integer()) :: Client.response()
  def get_application(client, application_id) when is_integer(application_id) do
    Client.get("/applicant_tracking/applications/#{application_id}", client)
  end

  @doc """
  Retrieves the applicant statuses configured for the company, including
  both system-defined and custom statuses.

  ## Parameters

    * `client` - Client configuration created with `BambooHR.Client.new/1`

  ## Examples

      iex> BambooHR.Hiring.get_applicant_statuses(client)
      {:ok, [%{"id" => "1", "name" => "New", "enabled" => true}]}
  """
  @spec get_applicant_statuses(Client.t()) :: Client.response()
  def get_applicant_statuses(client) do
    Client.get("/applicant_tracking/statuses", client)
  end

  @doc """
  Retrieves all company locations available for use when creating a job
  opening.

  Use the returned location IDs as the `jobLocation` field passed to
  `create_job_opening/7`.

  ## Parameters

    * `client` - Client configuration created with `BambooHR.Client.new/1`

  ## Examples

      iex> BambooHR.Hiring.get_company_locations(client)
      {:ok, [%{"id" => 1, "name" => "HQ"}]}
  """
  @spec get_company_locations(Client.t()) :: Client.response()
  def get_company_locations(client) do
    Client.get("/applicant_tracking/locations", client)
  end

  @doc """
  Retrieves the list of employees who can be assigned as a hiring lead
  when creating a new job opening.

  Use the returned `employeeId` values as the `hiring_lead` argument to
  `create_job_opening/7`.

  ## Parameters

    * `client` - Client configuration created with `BambooHR.Client.new/1`

  ## Examples

      iex> BambooHR.Hiring.get_hiring_leads(client)
      {:ok, [%{"employeeId" => 123, "preferredFullName" => "Jane Smith"}]}
  """
  @spec get_hiring_leads(Client.t()) :: Client.response()
  def get_hiring_leads(client) do
    Client.get("/applicant_tracking/hiring_leads", client)
  end

  @doc """
  Retrieves a list of job opening summaries.

  By default returns all non-deleted job openings.

  ## Parameters

    * `client` - Client configuration created with `BambooHR.Client.new/1`
    * `params` - Optional query params: `"statusGroups"`, `"status_ids"`,
      `"sortBy"`, `"sortOrder"`

  ## Examples

      iex> BambooHR.Hiring.get_job_summaries(client)
      {:ok, [%{"id" => 7, "title" => %{"label" => "Engineer"}, "status" => %{"label" => "Open"}}]}
  """
  @spec get_job_summaries(Client.t(), map()) :: Client.response()
  def get_job_summaries(client, params \\ %{}) do
    Client.get("/applicant_tracking/jobs", client, params: params)
  end

  @doc """
  Creates a new candidate application for a job opening.

  Only fields required by the target job opening's standard questions
  need to be provided beyond `first_name`, `last_name`, and `job_id`.

  ## Parameters

    * `client` - Client configuration created with `BambooHR.Client.new/1`
    * `first_name` - The candidate's first name
    * `last_name` - The candidate's last name
    * `job_id` - The ID of the job opening for the candidate application
    * `opts` - Optional keyword list of additional fields, e.g. `:email`,
      `:phoneNumber`, `:source`, `:address`, `:city`, `:state`, `:zip`,
      `:country`, `:linkedinUrl`, `:dateAvailable`, `:desiredSalary`,
      `:referredBy`, `:websiteUrl`, `:highestEducation`, `:collegeName`,
      `:references`, and the binary file fields `:resume` / `:coverLetter`
      (each as `{binary_content, filename: "..."}`)

  ## Examples

      iex> BambooHR.Hiring.create_candidate(client, "Jane", "Doe", 7, email: "jane@example.com")
      {:ok, %{"result" => "success", "candidateId" => 99}}
  """
  @spec create_candidate(Client.t(), String.t(), String.t(), integer(), keyword()) ::
          Client.response()
  def create_candidate(client, first_name, last_name, job_id, opts \\ [])
      when is_binary(first_name) and is_binary(last_name) and is_integer(job_id) do
    form = [firstName: first_name, lastName: last_name, jobId: job_id] ++ opts
    Client.post("/applicant_tracking/application", client, form_multipart: form)
  end

  @doc """
  Creates a new job opening.

  Use `get_company_locations/1` and `get_hiring_leads/1` to obtain valid
  IDs for the `jobLocation` and `hiring_lead` fields.

  ## Parameters

    * `client` - Client configuration created with `BambooHR.Client.new/1`
    * `posting_title` - The posting title of the job opening
    * `job_status` - One of `"Draft"`, `"Open"`, `"On Hold"`, `"Filled"`,
      `"Canceled"`
    * `hiring_lead` - Employee ID of the hiring lead (from
      `get_hiring_leads/1`)
    * `employment_type` - e.g. `"Full-Time"`, `"Part-Time"`, `"Contractor"`
    * `job_description` - The long-form text description of the job opening
    * `opts` - Optional keyword list of additional fields, e.g.
      `:department`, `:minimumExperience`, `:compensation`, `:jobLocation`
      (from `get_company_locations/1`), `:internalJobCode`,
      `:locationType`, and the `applicationQuestion*` fields (each
      `"true"`, `"false"`, or `"Required"`)

  ## Examples

      iex> BambooHR.Hiring.create_job_opening(client, "Engineer", "Open", 123, "Full-Time", "Build things")
      {:ok, %{"result" => "success", "jobOpeningId" => "42"}}
  """
  @spec create_job_opening(
          Client.t(),
          String.t(),
          String.t(),
          integer(),
          String.t(),
          String.t(),
          keyword()
        ) :: Client.response()
  def create_job_opening(
        client,
        posting_title,
        job_status,
        hiring_lead,
        employment_type,
        job_description,
        opts \\ []
      )
      when is_binary(posting_title) and is_binary(job_status) and is_integer(hiring_lead) and
             is_binary(employment_type) and is_binary(job_description) do
    form =
      [
        postingTitle: posting_title,
        jobStatus: job_status,
        hiringLead: hiring_lead,
        employmentType: employment_type,
        jobDescription: job_description
      ] ++ opts

    Client.post("/applicant_tracking/job_opening", client, form_multipart: form)
  end

  @doc """
  Adds a comment to an application.

  ## Parameters

    * `client` - Client configuration created with `BambooHR.Client.new/1`
    * `application_id` - The ID of the application to add a comment to
    * `comment_data` - Map with `"comment"` (required) and `"type"`
      (optional, defaults to `"comment"`)

  ## Examples

      iex> BambooHR.Hiring.create_application_comment(client, 42, %{"comment" => "Great fit"})
      {:ok, %{"type" => "comment", "id" => 55}}
  """
  @spec create_application_comment(Client.t(), integer(), map()) :: Client.response()
  def create_application_comment(client, application_id, comment_data)
      when is_integer(application_id) do
    Client.post("/applicant_tracking/applications/#{application_id}/comments", client,
      json: comment_data
    )
  end

  @doc """
  Updates the status of an application.

  Use `get_applicant_statuses/1` to obtain valid status IDs.

  ## Parameters

    * `client` - Client configuration created with `BambooHR.Client.new/1`
    * `application_id` - The ID of the application to update
    * `status_id` - The ID of the status to assign to the application

  ## Examples

      iex> BambooHR.Hiring.update_applicant_status(client, 42, 2)
      {:ok, nil}
  """
  @spec update_applicant_status(Client.t(), integer(), integer()) :: Client.response()
  def update_applicant_status(client, application_id, status_id)
      when is_integer(application_id) and is_integer(status_id) do
    Client.post("/applicant_tracking/applications/#{application_id}/status", client,
      json: %{"status" => status_id}
    )
  end
end
