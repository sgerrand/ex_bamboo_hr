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
- Type analysis: `mix dialyzer` (PLT stored under `priv/plts/`)
- Generate docs: `mix docs`
- Check unused deps: `mix deps.unlock --check-unused`

## Architecture

This is an Elixir client library for the BambooHR API, published as `bamboo_hr` on Hex.pm.

### Module Structure

**Dependency flow:**

```text
Company / Employee / Metadata / TimeTracking  (resource modules)
         ↓
      BambooHR.Client                          (HTTP routing + auth)
         ↓
   BambooHR.HTTPClient                         (behaviour + Req impl)
         ↓
         Req                                   (HTTP library)
```

- `BambooHR.Client` — Core struct (`t()`) holding `company_domain`, `api_key`, `base_url`, `http_client`, `timeout`.
  All resource functions receive a `Client.t()` as first argument.
  Auth uses Basic auth with `api_key:x` encoding.
  URL scheme: `{base_url}/{company_domain}/v1{path}`.
  `Client.get/3` and `Client.post/3` lock down `:method`, `:url`, `:headers`,
  and `:receive_timeout` against caller-supplied opts so resource modules
  can't accidentally drop auth headers.
- `BambooHR.HTTPClient` — Behaviour with a single `request/1` callback.
  The opts keyword list passed to implementations is documented in the
  behaviour's `@moduledoc`. `BambooHR.HTTPClient.Req` is the default
  implementation; tests use Bypass (a real local HTTP server) rather than
  mocking the behaviour.
- `BambooHR.Company`, `BambooHR.Employee`, `BambooHR.Metadata`,
  `BambooHR.TimeTracking` — Resource modules that delegate to `Client.get/3`
  or `Client.post/3`. All public functions return
  `{:ok, data} | {:error, reason}`. `data` is the decoded JSON body —
  usually a map, occasionally `nil` (empty 2xx body) or a list/scalar.
  `BambooHR.Metadata` covers the `/meta/fields`, `/meta/tables`, and
  `/meta/lists` endpoints used for field discovery.

### Testing Patterns

- Bypass library mocks the HTTP layer at the TCP level for integration-style tests.
- Resource-module tests `use BambooHR.BypassCase` (in `test/support/bypass_case.ex`)
  which provides `bypass` and `config` (a `Client.t()` pointing at the local
  Bypass port) in the test context.
- Tests run `async: true`.

## Code Style Guidelines

- All public functions must have `@spec` type specs and `@doc` documentation.
- `BambooHR.Client` has `doctest BambooHR.Client` enabled in
  `client_test.exs`; the doctests in `Client.new/1` are real and will run in
  CI — keep struct field order in sync with `defstruct` or they'll fail.
- Handle errors with pattern matching; never raise from public API functions.
- No Ecto in this project — remove the `has_many`/`belongs_to` guideline if it appears elsewhere.

## CI

- Test matrix: Elixir 1.17/1.18/1.19 × OTP 25/26/27/28.
  Unsupported combinations excluded: 1.17+28, 1.18+28, 1.19+25.
  Linting runs only on Elixir 1.19 + OTP 28.
- `coverage`, `dialyzer`, and `docs` are separate jobs pinned to
  `.tool-versions` (currently Elixir 1.19 / OTP 28). `dialyzer` is in the
  `required` job's `needs:` list so a Dialyzer error fails the required
  check.
- Compilation, tests, and docs all use `--warnings-as-errors`.
- Dialyzer PLTs are cached at `priv/plts/` and keyed by OS / OTP / Elixir /
  `mix.lock` hash in CI.
- `actionlint` runs shellcheck on `run:` blocks.
  Use `# shellcheck disable=SC1010` for `mix do` steps (false positive — `do` is a Mix keyword, not a shell keyword).

## Development Setup

- Install dev tooling and activate hooks: `./bin/setup && mix setup`
- `./bin/setup` installs actionlint and check-jsonschema via Homebrew, plus
  `mado` from the `akiomik/mado` tap.
- `mix setup` runs `deps.get` then `git_hoox.install` to activate the
  pre-commit hooks managed by the [`git_hoox`](https://hex.pm/packages/git_hoox) Hex package.
- Pre-commit hook config lives in `.git_hoox.exs` at the repo root. Hooks run
  in parallel (`parallel: true`) and use `git_hoox`'s native `files:` glob plus
  `{staged_files}` substitution — a near one-to-one port of the previous
  Lefthook config.
- Inspect resolved config with `mix git_hoox.list`; validate it with
  `mix git_hoox.doctor`.
- Markdown lint uses [`mado`](https://github.com/akiomik/mado) — Rust, CommonMark/GFM,
  drop-in for most `markdownlint` rules.
  CI uses the `akiomik/mado@<sha> # v0.3.0` action; default invocation is `mado check .`.
  `mado.toml` at repo root excludes `CHANGELOG.md`.

## Git Flow

- Branch naming: `feature-description-ticket-id`
- PRs should include tests and documentation updates

At the end of every change, update CLAUDE.md with anything useful that would have been helpful at the start.
