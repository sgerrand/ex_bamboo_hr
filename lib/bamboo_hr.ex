defmodule BambooHR do
  @moduledoc """
  BambooHR API client library.

  A convenient way to interact with the BambooHR API from Elixir applications.

  ## API Resources

  The library is organized into several modules, each representing a different
  API resource:

  - `BambooHR.Client` - Core client functionality and configuration
  - `BambooHR.Company` - Company information and EINs
  - `BambooHR.Employee` - Employee management
  - `BambooHR.TimeTracking` - Time entries and timesheets

  ## Getting Started

  Create a client configuration with your company subdomain and API key:

      config = BambooHR.Client.new("your_company", "your_api_key")

  Then use the resource modules to interact with the API:

      # Get company information
      {:ok, company_info} = BambooHR.Company.get_information(config)

      # Get employee directory
      {:ok, directory} = BambooHR.Employee.get_directory(config)

      # Get specific employee details
      {:ok, employee} = BambooHR.Employee.get(config, 123, ["firstName", "lastName", "jobTitle"])
  """
end
