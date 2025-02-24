# BambooHR

[![Hex Version](https://img.shields.io/hexpm/v/bamboo_hr.svg)](https://hex.pm/packages/bamboo_hr) [![Hex Docs](https://img.shields.io/badge/docs-hexpm-blue.svg)](https://hexdocs.pm/bamboo_hr/)

An Elixir client for the [Bamboo HR API][bamboohr-api-docs].

## Installation

The package can be installed by adding `bamboo_hr` to your
list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:bamboo_hr, "~> 0.1.0"}
  ]
end
```

## Usage

To use this client, you'll need information from BambooHR:
- Your company's subdomain
- An API key

### Example

The following code sample illustrates how to use
`BambooHR.Client.get_company_information/1` to fetch information about your
company stored in BambooHR via their API.

```elixir
config = BambooHR.Client.new("your_company", "your_api_key")
{:ok,
 %{
   "name" => "Acme Corp",
   "employeeCount" => 100,
   "city" => "San Francisco"
 }} = BambooHR.Client.get_company_information(config)
```

## License

BambooHR is [released under the MIT license](LICENSE).

[bamboohr-api-docs]: https://documentation.bamboohr.com/reference/
