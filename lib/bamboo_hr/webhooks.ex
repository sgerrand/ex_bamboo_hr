defmodule BambooHR.Webhooks do
  @moduledoc """
  Functions for managing webhooks in the BambooHR API.

  A webhook fires when the events it subscribes to happen, or when one of
  the fields it monitors changes. Webhooks belong to the credentials that
  created them: reading or changing another user's webhook returns a `403`
  error.

  Use `list_monitor_fields/1` for the fields a webhook can watch, and
  `get_post_fields/1` for the fields it can include in its payload.
  """

  alias BambooHR.Client

  @doc """
  Lists the webhooks owned by the current credentials.

  Each entry is a summary — ID, name, URL, and creation and last-fired
  datetimes. Use `get/2` for a webhook's full configuration.

  ## Parameters

    * `client` - Client configuration created with `BambooHR.Client.new/1`

  ## Examples

      iex> BambooHR.Webhooks.list(client)
      {:ok, %{
        "webhooks" => [
          %{
            "id" => "1",
            "name" => "Payroll sync",
            "url" => "https://example.com/hooks/bamboo",
            "created" => "2024-01-15 09:30:00",
            "lastSent" => "2024-02-01 11:05:12"
          }
        ]
      }}
  """
  @spec list(Client.t()) :: Client.response()
  def list(client) do
    Client.get("/webhooks", client)
  end

  @doc """
  Retrieves a webhook's full configuration.

  Includes the monitored fields, post fields, and events. Returns a `403`
  error if the webhook belongs to another user, and `404` if it does not
  exist.

  ## Parameters

    * `client` - Client configuration created with `BambooHR.Client.new/1`
    * `webhook_id` - The ID of the webhook to retrieve

  ## Examples

      iex> BambooHR.Webhooks.get(client, 1)
      {:ok, %{
        "id" => "1",
        "name" => "Payroll sync",
        "url" => "https://example.com/hooks/bamboo",
        "format" => "json",
        "monitorFields" => ["firstName", "lastName"],
        "events" => ["employee_with_fields.updated"]
      }}
  """
  @spec get(Client.t(), integer()) :: Client.response()
  def get(client, webhook_id) when is_integer(webhook_id) do
    Client.get("/webhooks/#{webhook_id}", client)
  end

  @doc """
  Creates a webhook.

  `webhook_data` needs `"name"`, `"url"` (which must start with
  `https://`), and `"format"` (`"json"` or `"form-encoded"`).

  `"events"` defaults to `["employee_with_fields.updated",
  "employee_with_fields.deleted", "employee_with_fields.created"]`.
  `employee_with_fields` events cannot be mixed with `employee` events.
  `"monitorFields"` is required when the events include
  `"employee.updated"` or `"employee_with_fields.updated"`, which the
  default set does.

  The response carries a `"privateKey"`, used to verify that a delivery
  came from BambooHR. **It is returned only here and cannot be fetched
  again**, so store it when you create the webhook.

  ## Parameters

    * `client` - Client configuration created with `BambooHR.Client.new/1`
    * `webhook_data` - Map describing the webhook

  ## Examples

      iex> webhook_data = %{
      ...>   "name" => "Payroll sync",
      ...>   "url" => "https://example.com/hooks/bamboo",
      ...>   "format" => "json",
      ...>   "monitorFields" => ["firstName", "lastName"]
      ...> }
      iex> BambooHR.Webhooks.create(client, webhook_data)
      {:ok, %{"id" => "4", "name" => "Payroll sync", "privateKey" => "abc123"}}
  """
  @spec create(Client.t(), map()) :: Client.response()
  def create(client, webhook_data) when is_map(webhook_data) do
    Client.post("/webhooks", client, json: webhook_data)
  end

  @doc """
  Replaces a webhook's configuration.

  This is a full replacement: every field in `webhook_data` overwrites the
  stored value, and anything left out reverts to its default. Send the
  complete configuration, not just the parts you want changed. The private
  key is not regenerated.

  ## Parameters

    * `client` - Client configuration created with `BambooHR.Client.new/1`
    * `webhook_id` - The ID of the webhook to replace
    * `webhook_data` - Map describing the webhook, same shape as `create/2`

  ## Examples

      iex> webhook_data = %{
      ...>   "name" => "Payroll sync",
      ...>   "url" => "https://example.com/hooks/v2",
      ...>   "format" => "json",
      ...>   "monitorFields" => ["firstName", "lastName"]
      ...> }
      iex> BambooHR.Webhooks.update(client, 1, webhook_data)
      {:ok, %{"id" => "1", "url" => "https://example.com/hooks/v2"}}
  """
  @spec update(Client.t(), integer(), map()) :: Client.response()
  def update(client, webhook_id, webhook_data)
      when is_integer(webhook_id) and is_map(webhook_data) do
    Client.put("/webhooks/#{webhook_id}", client, json: webhook_data)
  end

  @doc """
  Deletes a webhook.

  Only the credentials that created a webhook can delete it; anything else
  returns a `403` error.

  ## Parameters

    * `client` - Client configuration created with `BambooHR.Client.new/1`
    * `webhook_id` - The ID of the webhook to delete

  ## Examples

      iex> BambooHR.Webhooks.delete(client, 1)
      {:ok, nil}
  """
  @spec delete(Client.t(), integer()) :: Client.response()
  def delete(client, webhook_id) when is_integer(webhook_id) do
    Client.delete("/webhooks/#{webhook_id}", client)
  end

  @doc """
  Lists recent delivery attempts for a webhook.

  Covers the last 14 days, up to 200 entries, and is empty when nothing
  has been delivered in that window. `"lastAttempted"` and `"lastSuccess"`
  are usually UTC datetimes (`YYYY-MM-DD HH:MM:SS`), but can instead hold
  a status string such as `"Webhook Not Found"`.

  ## Parameters

    * `client` - Client configuration created with `BambooHR.Client.new/1`
    * `webhook_id` - The ID of the webhook to list deliveries for

  ## Examples

      iex> BambooHR.Webhooks.list_logs(client, 1)
      {:ok, [
        %{
          "webhookId" => "1",
          "url" => "https://example.com/hooks/bamboo",
          "lastAttempted" => "2024-02-01 11:05:12",
          "lastSuccess" => "2024-02-01 11:05:12"
        }
      ]}
  """
  @spec list_logs(Client.t(), integer()) :: Client.response()
  def list_logs(client, webhook_id) when is_integer(webhook_id) do
    Client.get("/webhooks/#{webhook_id}/log", client)
  end

  @doc """
  Lists the employee fields a webhook can monitor.

  Monitored fields only apply to webhooks using update events
  (`"employee.updated"` or `"employee_with_fields.updated"`). Use the
  field IDs or aliases from this response in `"monitorFields"`.

  ## Parameters

    * `client` - Client configuration created with `BambooHR.Client.new/1`

  ## Examples

      iex> BambooHR.Webhooks.list_monitor_fields(client)
      {:ok, %{"fields" => [%{"id" => "firstName", "name" => "First Name"}]}}
  """
  @spec list_monitor_fields(Client.t()) :: Client.response()
  def list_monitor_fields(client) do
    Client.get("/webhooks/monitor_fields", client)
  end

  @doc """
  Retrieves the employee fields a webhook can include in its payload.

  Also lists the related table and page records those fields refer to. Use
  the field IDs or aliases from this response as the keys of
  `"postFields"`.

  ## Parameters

    * `client` - Client configuration created with `BambooHR.Client.new/1`

  ## Examples

      iex> BambooHR.Webhooks.get_post_fields(client)
      {:ok, %{"fields" => [%{"id" => "firstName", "name" => "First Name"}]}}
  """
  @spec get_post_fields(Client.t()) :: Client.response()
  def get_post_fields(client) do
    Client.get("/webhooks/post-fields", client)
  end
end
