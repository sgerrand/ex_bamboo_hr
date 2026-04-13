# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build/Test/Lint Commands
- Setup environment: `mix setup`
- Run all tests: `mix test`
- Run single test: `mix test path/to/test_file.exs:line_number`
- Run specific test file: `mix test path/to/test_file.exs`
- Format code: `mix format`
- Check formatting (CI): `mix format --check-formatted`
- Static analysis: `mix credo`
- Generate docs: `mix docs`
- Check unused deps: `mix deps.unlock --check-unused`

## Architecture

This is an Elixir client library for the BambooHR API, published as `bamboo_hr` on Hex.pm.

### Module Structure

**Dependency flow:**
```
Company / Employee / TimeTracking  (resource modules)
         ↓
      BambooHR.Client              (HTTP routing + auth)
         ↓
   BambooHR.HTTPClient             (behaviour + Req impl)
         ↓
         Req                       (HTTP library)
```

- `BambooHR.Client` — Core struct (`t()`) holding `company_domain`, `api_key`, `base_url`, `http_client`. All resource functions receive a `Client.t()` as first argument. Auth uses Basic auth with `api_key:x` encoding. URL scheme: `{base_url}/{company_domain}/v1{path}`.
- `BambooHR.HTTPClient` — Behaviour with a single `request/1` callback. `BambooHR.HTTPClient.Req` is the default implementation; tests inject a mock via Mox.
- `BambooHR.Company`, `BambooHR.Employee`, `BambooHR.TimeTracking` — Resource modules that delegate to `Client.get/3` or `Client.post/3`. All public functions return `{:ok, data} | {:error, reason}`.

### Testing Patterns
- Bypass library mocks the HTTP layer at the TCP level (not Mox) for integration-style tests.
- Each test module sets up a Bypass instance and builds a `Client.t()` pointing at the local Bypass port.
- Tests run `async: true`.

## Code Style Guidelines
- All public functions must have `@spec` type specs and `@doc` documentation.
- Handle errors with pattern matching; never raise from public API functions.
- No Ecto in this project — remove the `has_many`/`belongs_to` guideline if it appears elsewhere.

## CI
- Test matrix: Elixir 1.17/1.18 × OTP 25/26/27. Linting and coverage run only on Elixir 1.18 + OTP 27.
- Compilation, tests, and docs all use `--warnings-as-errors`.

## Development Setup
- Install dev tooling and activate hooks: `./bin/setup && mix setup`
- `./bin/setup` installs actionlint, check-jsonschema, and lefthook via Homebrew, then runs `lefthook install`
- Pre-commit hooks run in parallel: `mix format --check-formatted`, `actionlint`, `check-jsonschema` (workflow schema + dependabot schema)

## Git Flow
- Branch naming: `feature-description-ticket-id`
- PRs should include tests and documentation updates

At the end of every change, update CLAUDE.md with anything useful that would have been helpful at the start.
