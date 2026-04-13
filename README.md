# BambooHR

[![Test Status](https://github.com/sgerrand/ex_bamboo_hr/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/sgerrand/ex_bamboo_hr/actions/workflows/ci.yml)
[![Coverage Status](https://coveralls.io/repos/github/sgerrand/ex_bamboo_hr/badge.svg?branch=main)](https://coveralls.io/github/sgerrand/ex_bamboo_hr?branch=main)
[![Hex Version](https://img.shields.io/hexpm/v/bamboo_hr.svg)](https://hex.pm/packages/bamboo_hr)
[![Hex Docs](https://img.shields.io/badge/docs-hexpm-blue.svg)](https://hexdocs.pm/bamboo_hr/)

An Elixir client for the [Bamboo HR API][bamboohr-api-docs].

## Installation

The package can be installed by adding `bamboo_hr` to your
list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:bamboo_hr, "~> 0.3"}
  ]
end
```

## Usage

To use this client, you'll need information from BambooHR:
- Your company's subdomain
- An API key

### API Structure

The library is organized into several modules, each representing different API resources:

- `BambooHR.Client` - Core client functionality and configuration
- `BambooHR.Company` - Company information and EINs
- `BambooHR.Employee` - Employee management
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
  http_client: YourCustomHTTPClient
)
```

#### Company Information

```elixir
# Get basic company information
{:ok, company_info} = BambooHR.Company.get_information(config)

# Get company EINs
{:ok, eins_data} = BambooHR.Company.get_eins(config)
```

#### Employee Management

```elixir
# Get employee directory
{:ok, directory} = BambooHR.Employee.get_directory(config)

# Get specific employee details
{:ok, employee} = BambooHR.Employee.get(config, 123, ["firstName", "lastName", "jobTitle"])

# Add a new employee
employee_data = %{"firstName" => "Jane", "lastName" => "Smith"}
{:ok, result} = BambooHR.Employee.add(config, employee_data)

# Update an employee
update_data = %{"firstName" => "Jane", "lastName" => "Smith-Jones"}
{:ok, _} = BambooHR.Employee.update(config, 124, update_data)
```

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

`./bin/setup` installs [actionlint](https://github.com/rhysd/actionlint), [check-jsonschema](https://github.com/python-jsonschema/check-jsonschema), and [Lefthook](https://github.com/evilmartians/lefthook) via Homebrew, then activates the pre-commit hooks.

### Common commands

```bash
mix test                        # Run tests
mix format                      # Format code
mix credo --strict              # Static analysis
mix docs                        # Generate documentation
mix deps.unlock --check-unused  # Check for unused dependencies
```

### Pre-commit hooks

Hooks run automatically on `git commit` (in parallel):

| Hook | Files |
|---|---|
| `mix format --check-formatted` | `*.ex`, `*.exs` |
| `actionlint` | `.github/workflows/*.yml` |
| `check-jsonschema` (workflow schema) | `.github/workflows/*.yml` |
| `check-jsonschema` (dependabot schema) | `.github/dependabot.yml` |

## License

BambooHR is [released under the MIT license](LICENSE).

[bamboohr-api-docs]: https://documentation.bamboohr.com/reference/
