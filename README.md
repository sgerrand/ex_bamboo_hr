# BambooHR

[![Test Status](https://github.com/sgerrand/ex_bamboo_hr/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/sgerrand/ex_bamboo_hr/actions/workflows/ci.yml)
[![Coverage Status](https://coveralls.io/repos/github/sgerrand/ex_bamboo_hr/badge.svg?branch=main)](https://coveralls.io/github/sgerrand/ex_bamboo_hr?branch=main)
[![Hex Version](https://img.shields.io/hexpm/v/bamboo_hr.svg)](https://hex.pm/packages/bamboo_hr)
[![Hex Docs](https://img.shields.io/badge/docs-hexpm-blue.svg)](https://hexdocs.pm/bamboo_hr/)

An Elixir client for the [Bamboo HR API][bamboohr-api-docs].

## Installation

The package can be installed by adding `bamboo_hr` to your
list of dependencies in `mix.exs`:

<!-- x-release-please-start-version -->

```elixir
def deps do
  [
    {:bamboo_hr, "~> 0.4.0"}
  ]
end
```

<!-- x-release-please-end -->

## Usage

To use this client, you'll need information from BambooHR:

- Your company's subdomain
- An API key

### API Structure

The library is organized into several modules, each representing different API resources:

- `BambooHR.Client` - Core client functionality and configuration
- `BambooHR.Company` - Company information and EINs
- `BambooHR.Employee` - Employee management
- `BambooHR.Metadata` - Field, tabular, and list field metadata
- `BambooHR.TimeTracking` - Time entries and timesheets

### Examples

#### Getting Started

First, create a client configuration:

```elixir
config = BambooHR.Client.new(company_domain: "your_company", api_key: "your_api_key")
```

You can also specify optional parameters:

```elixir
config = BambooHR.Client.new(
  company_domain: "your_company",
  api_key: "your_api_key",
  base_url: "https://custom-api.example.com",
  http_client: YourCustomHTTPClient,
  timeout: 30_000
)
```

| Option | Default | Description |
| --- | --- | --- |
| `:auth` | from `:api_key` | `{:api_key, key}` or `{:bearer, token}` |
| `:base_url` | depends on `:auth` | Override the API base URL |
| `:http_client` | `BambooHR.HTTPClient.Req` | Custom HTTP client module |
| `:timeout` | `15_000` | HTTP receive timeout in milliseconds |

#### OAuth

Pass an OAuth 2.0 access token instead of an API key:

```elixir
config = BambooHR.Client.new(company_domain: "your_company", auth: {:bearer, access_token})
```

The two methods use different hosts, which the client picks for you:

| Auth | URL |
| --- | --- |
| `{:api_key, key}` | `https://api.bamboohr.com/api/gateway.php/{company}/v1/...` |
| `{:bearer, token}` | `https://{company}.bamboohr.com/api/v1/...` |

Access tokens expire. `BambooHR.OAuth.refresh_token/1` exchanges a refresh
token for a new pair; storing them and deciding when to refresh is up to
you:

```elixir
{:ok, %{"access_token" => access_token} = tokens} =
  BambooHR.OAuth.refresh_token(
    company_domain: "your_company",
    client_id: client_id,
    client_secret: client_secret,
    refresh_token: refresh_token
  )
```

#### Company Information

```elixir
# Get basic company information
{:ok, company_info} = BambooHR.Company.get_information(config)
```

#### Employee Management

```elixir
# Get employee directory
{:ok, directory} = BambooHR.Employee.get_directory(config)

# List employees, one page at a time
{:ok, page} = BambooHR.Employee.list(config, filter: %{"city" => "Austin"}, limit: 50)

# List employee IDs changed since a timestamp, for syncing
{:ok, %{"latest" => latest, "employees" => changed}} =
  BambooHR.Employee.get_changed(config, "2024-01-01T00:00:00Z")

# Stream every employee, following the cursor from page to page
config
|> BambooHR.Employee.stream(fields: ["workEmail"])
|> Enum.each(fn
  {:ok, employee} -> IO.inspect(employee)
  {:error, reason} -> IO.inspect(reason)
end)

# Get specific employee details
{:ok, employee} = BambooHR.Employee.get(config, 123, ["firstName", "lastName", "jobTitle"])

# Add a new employee
employee_data = %{"firstName" => "Jane", "lastName" => "Smith"}
{:ok, result} = BambooHR.Employee.add(config, employee_data)

# Update an employee
update_data = %{"firstName" => "Jane", "lastName" => "Smith-Jones"}
{:ok, _} = BambooHR.Employee.update(config, 124, update_data)
```

#### Field Metadata

```elixir
# List all employee fields (id, name, type)
{:ok, %{"fields" => fields}} = BambooHR.Metadata.get_fields(config)

# List tabular fields (employment history, compensation, etc.)
{:ok, %{"tabularFields" => tabular}} = BambooHR.Metadata.get_tabular_fields(config)

# List list fields and their option values (departments, divisions, etc.)
{:ok, %{"items" => lists}} = BambooHR.Metadata.get_lists(config)
```

#### Webhooks

```elixir
# List the fields a webhook can monitor
{:ok, %{"fields" => fields}} = BambooHR.Webhooks.list_monitor_fields(config)

# Create a webhook. The private key is returned only here — store it.
webhook_data = %{
  "name" => "Payroll sync",
  "url" => "https://example.com/hooks/bamboo",
  "format" => "json",
  "monitorFields" => ["firstName", "lastName"]
}
{:ok, %{"id" => id, "privateKey" => key}} = BambooHR.Webhooks.create(config, webhook_data)

# Check recent delivery attempts
{:ok, logs} = BambooHR.Webhooks.list_logs(config, String.to_integer(id))

# Verify an incoming delivery. Pass the raw body, before any JSON parsing.
BambooHR.Webhooks.verify_signature(
  raw_body,
  signature_header,
  timestamp_header,
  key
)
```

#### Errors

Every function returns `{:ok, result}` or `{:error, %BambooHR.Error{}}`.
Match on the error's `:reason` rather than on a status code:

```elixir
case BambooHR.Employee.get(config, 123, ["firstName"]) do
  {:ok, employee} -> employee
  {:error, %BambooHR.Error{reason: :not_found}} -> nil
  {:error, %BambooHR.Error{reason: :rate_limited}} -> retry_later()
  {:error, error} -> Logger.error(Exception.message(error))
end
```

The same struct covers requests that never reached BambooHR
(`:transport_error`) and replies that were not valid JSON
(`:decode_error`). It also carries BambooHR's own `:message` and the
`:request_id` when the response includes them.

#### Time Tracking

```elixir
# Get timesheet entries
params = %{
  "start" => "2024-01-01",
  "end" => "2024-01-31",
  "employeeIds" => "123,124"
}
{:ok, timesheet_data} = BambooHR.TimeTracking.get_timesheet_entries(config, params)

# Clock in an employee
clock_data = %{
  "date" => "2024-01-15",
  "start" => "09:00",
  "timezone" => "America/New_York"
}
{:ok, _} = BambooHR.TimeTracking.clock_in(config, 123, clock_data)

# List clock entries with OData-style filtering and paging
{:ok, page} =
  BambooHR.TimeTracking.list_clock_entries(config,
    filter: "employeeId eq 123",
    sort: "start desc",
    page_size: 50
  )

# Correct a single entry
{:ok, entry} = BambooHR.TimeTracking.update_clock_entry(config, 1, %{"note" => "Corrected"})

# Approve a timesheet, guarding against a concurrent change
{:ok, timesheet} = BambooHR.TimeTracking.approve_timesheet(config, 9, last_changed_at)

# Clock out an employee
clock_out_data = %{
  "date" => "2024-01-15",
  "end" => "17:00",
  "timezone" => "America/New_York"
}
{:ok, _} = BambooHR.TimeTracking.clock_out(config, 123, clock_out_data)
```

## Development

### Requirements

- Elixir 1.17+ / Erlang/OTP 25+ (see `.tool-versions` for exact versions used locally)
- [Homebrew](https://brew.sh) (macOS/Linux) for dev tooling

### Setup

Install dependencies and git hooks:

```bash
./bin/setup
mix setup
```

`./bin/setup` installs
[actionlint](https://github.com/rhysd/actionlint),
[check-jsonschema](https://github.com/python-jsonschema/check-jsonschema),
and [mado](https://github.com/akiomik/mado)
via Homebrew.
`mix setup` then fetches Elixir dependencies and activates the pre-commit
hooks via [`git_hoox`](https://hex.pm/packages/git_hoox).

### Common commands

```bash
mix test                        # Run tests
mix format                      # Format code
mix credo --strict              # Static analysis
mix dialyzer                    # Type analysis (PLT cached under priv/plts/)
mix docs                        # Generate documentation
mix deps.unlock --check-unused  # Check for unused dependencies
```

### Pre-commit hooks

Hooks run automatically on `git commit` (configured in `.git_hoox.exs`):

| Hook | Files |
| --- | --- |
| `mix format --check-formatted` | `*.ex`, `*.exs` |
| `actionlint` | `.github/workflows/*.yml` |
| `check-jsonschema` (workflow schema) | `.github/workflows/*.yml` |
| `check-jsonschema` (dependabot schema) | `.github/dependabot.yml` |
| `check-jsonschema` (release-please config) | `release-please-config.json` |
| `check-jsonschema` (release-please manifest) | `.release-please-manifest.json` |
| `mado check` | `*.md` |

Inspect the resolved config with `mix git_hoox.list` or validate it with
`mix git_hoox.doctor`.

## License

BambooHR is [released under the BSD 2-Clause license](LICENSE).

[bamboohr-api-docs]: https://documentation.bamboohr.com/reference/
