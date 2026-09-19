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
- Check endpoints against BambooHR's OpenAPI spec: `elixir scripts/spec_drift.exs [SPEC_URL_OR_PATH]`

## Spec drift check

- `scripts/spec_drift.exs` is a standalone script (it uses `Mix.install` for
  `req` and `yaml_elixir`), so it lives outside `lib/` and is not shipped to
  Hex. Don't run it with `mix run`.
- It reads `lib/**/*.ex`, finds every `Client.get/post/put/delete` call, and
  builds `{METHOD, "/<api_version>/path"}` keys. Interpolations and spec
  `{param}` names both become `{}`. If a call passes the path as a function
  parameter (like `Files.upload/6`), the script reads the literal from the
  callers in the same file. If it can't work out a path, it exits 2.
- It exits 1 when the client calls an endpoint that is missing from the spec
  or deprecated in it. Uncovered spec endpoints are listed for information
  only. To keep calling an endpoint the spec doesn't list, add it with a
  reason to `@allowed_unlisted`.
- Default spec source is `openapi.bamboohr.io`, which serves the same file
  that BambooHR's own SDKs record in `specs/spec-source.json`. It is newer
  than the `specs/public.yaml` copies in those SDK repos.
- `docs/openapi.yaml` is a separate, hand-written partial spec. The drift
  check does not use it.
- CI: `.github/workflows/spec-drift.yml` runs weekly, on manual dispatch, and
  on PRs that touch `lib/` or the script. It is not part of `required`, so
  upstream spec changes can't block merges. The report also goes to the job
  summary.

## Architecture

This is an Elixir client library for the BambooHR API, published as `bamboo_hr` on Hex.pm.

### Module Structure

**Dependency flow:**

```text
Company / Datasets / Employee / Files / Hiring / Metadata / Reports / Tables / TimeOff / TimeTracking  (resource modules)
         ↓
      BambooHR.Client                          (HTTP routing + auth)
         ↓
   BambooHR.HTTPClient                         (behaviour + Req impl)
         ↓
         Req                                   (HTTP library)
```

- `BambooHR.Client` — Core struct (`t()`) holding `company_domain`, `auth`, `base_url`, `http_client`, `timeout`.
  All resource functions receive a `Client.t()` as first argument.
  `auth` is `{:api_key, key}` (Basic auth, `key:x` encoded) or
  `{:bearer, token}` (OAuth 2.0). `api_key:` in `new/1` is shorthand for
  the former; giving both `:auth` and `:api_key` raises.
  The two auth methods use different hosts and URL shapes, so a
  `base_url` written for one will not work for the other: API keys go to
  `{gateway}/{company_domain}/{version}{path}`, bearer tokens to
  `https://{company_domain}.bamboohr.com/api/{version}{path}` — the only
  server in BambooHR's spec, and what its own SDKs use. Whether bearer
  tokens also work on the gateway host is unverified, hence keeping the
  hosts split rather than moving everything to the subdomain.
  `BambooHR.OAuth.refresh_token/1` is a stateless refresh helper
  (`POST {subdomain}/token.php?request=token`); token storage and refresh
  scheduling stay with the caller.
  URL scheme: `{base_url}/{company_domain}/v1{path}`, or a different version
  segment if the caller passes `api_version:` in opts (one of `"v1"`
  (default), `"v1_1"`, `"v1_2"`, `"v2"` — validated, raises `ArgumentError`
  on anything else). `Client.get/3`, `Client.post/3`, `Client.patch/3`,
  `Client.put/3`, and `Client.delete/3` lock down `:method`, `:url`, `:headers`, and
  `:receive_timeout` against caller-supplied opts so resource modules can't
  accidentally drop auth headers.
- `BambooHR.HTTPClient` — Behaviour with a single `request/1` callback.
  The opts keyword list passed to implementations is documented in the
  behaviour's `@moduledoc`, including `:expose_headers` (surface response
  headers alongside the body — needed when a header, not the body, carries
  the useful data, e.g. a `Location` header) and `:raw_response` (skip
  JSON-decoding — needed for binary responses like file downloads).
  `BambooHR.HTTPClient.Req` is the default implementation; tests use
  Bypass (a real local HTTP server) rather than mocking the behaviour.
- `BambooHR.Company`, `BambooHR.Datasets`, `BambooHR.Employee`,
  `BambooHR.Files`, `BambooHR.Hiring`, `BambooHR.Metadata`,
  `BambooHR.Reports`, `BambooHR.Tables`, `BambooHR.TimeOff`,
  `BambooHR.TimeTracking` — Resource modules that delegate to
  `Client.get/3`, `Client.post/3`, `Client.patch/3`, `Client.put/3`, or
  `Client.delete/3`.
  All public functions return `{:ok, data} | {:error, reason}`. `data` is
  the decoded JSON body — usually a map, occasionally `nil` (empty 2xx
  body) or a list/scalar.
  `BambooHR.Metadata` covers the `/meta/fields`, `/meta/tables`,
  `/meta/lists`, `/meta/time_off/types`, and `/meta/time_off/policies`
  endpoints used for field/type discovery.
  `BambooHR.TimeOff` covers employee-scoped time off endpoints (policies,
  balances, requests, history) — company-wide time off metadata (types,
  policy list) lives in `Metadata` instead, to keep the `/meta/` prefix
  grouped in one module. `get_employee_policies/2` and
  `assign_employee_policies/3` call the `v1.1` endpoints, which include
  manual and unlimited (non-accruing) policy types. The `..._v1_1` names
  are `@deprecated` delegates kept for callers of older versions.
  Time off request decisions use the `/time-off/requests/{id}` process
  endpoints — `approve_request/3`, `deny_request/3`, `cancel_request/2`.
  They return the updated request. `change_request_status/3` is a
  `@deprecated` wrapper that routes on `"status"` and maps `"note"` to
  `"managerNote"`.
  `BambooHR.Employee` covers single-employee reads and writes, the
  directory, the cursor-paginated `GET /employees` list, and
  `get_changed/3` (`GET /employees/changed`) for sync jobs — feed its
  `"latest"` back as the next `since`. Row-level change tracking for
  tabular fields lives in `Tables.get_changed_table_data/3` instead,
  keeping each module to its own resource. `list/2`
  returns one page; `stream/2` follows `meta.page.nextCursor` and emits
  `{:ok, employee}` per record, or a single `{:error, reason}` before
  halting, since public functions must not raise. BambooHR takes filters
  and pagination as bracketed query params (`filter[city]`, `page[limit]`),
  which Req does not build from nested maps, so `Employee` flattens them
  itself; list values are joined with commas.
  `BambooHR.Reports` covers only the current, non-deprecated Custom
  Reports endpoints (`/custom-reports`, `/custom-reports/{id}`). The
  older `/reports/custom` and `/reports/{id}` endpoints are deprecated,
  and their true replacement is the Datasets API, in `BambooHR.Datasets`.
  `BambooHR.Datasets` covers the current, non-deprecated Datasets
  endpoints only (`v1.2` catalog/field discovery, `v2` data querying) —
  the deprecated `v1`/`v1.1` Datasets variants are skipped, same reasoning
  as elsewhere in this client.
  `BambooHR.Files` covers both company and employee files — categories,
  upload (`:form_multipart`), metadata update, download (`:raw_response` +
  `:expose_headers`), and delete. File upload responses carry the created
  file's identity only in the `Location` header, same as `Employee.add/2`.
  `BambooHR.Tables` covers row-level CRUD on employee tabular fields (job
  info, compensation, custom tabular fields, etc.) — `table` is the raw
  table name string (e.g. `"jobInfo"`), discoverable via
  `Metadata.get_tabular_fields/1`. `create_table_row/4` and
  `update_table_row/5` call the `v1.1` endpoints; the spec marks the `v1`
  forms deprecated and describes `v1.1` as compatible with them.
  `BambooHR.Webhooks` covers webhook CRUD plus delivery logs and the
  `monitor_fields` / `post-fields` discovery endpoints. Webhooks belong to
  the credentials that created them — another user's webhook returns 403.
  `update/3` is a full replacement, so omitted fields revert to defaults.
  `create/2` is the only response carrying `privateKey` (used to verify
  deliveries); it cannot be fetched again.
  `verify_signature/4` checks an incoming delivery: HMAC-SHA256 of the raw
  body concatenated with the timestamp (body first, no separator),
  lowercase hex, compared with `:crypto.hash_equals/2`. Headers are
  `X-BambooHR-Signature` and `X-BambooHR-Timestamp`. That scheme is not in
  the OpenAPI spec — it comes from the PHP sample at
  <https://documentation.bamboohr.com/docs/webhooks>, and the test fixture
  is generated with Python's `hmac` so it does not just mirror our own
  implementation. Some third-party guides describe a Stripe-style
  `timestamp.body` string; that does not match BambooHR.
  `BambooHR.TimeTracking` covers two current families. The older
  `/time_tracking/*` endpoints are bulk and employee-scoped
  (`get_timesheet_entries/2`, `store_clock_entries/2`, `clock_in/3`,
  `clock_out/3`); the newer `/time-tracking/*` ones (hyphen) are REST
  per-record, with page-based paging and OData `filter`/`sort` strings
  passed straight through. Neither is deprecated and both address the
  same records, so an entry created via one is visible via the other.
  `create_clock_in/2` and `create_clock_out/2` are named apart from the
  older `clock_in/3` and `clock_out/3` on purpose — same idea, different
  request shape. `approve_timesheet/3` takes the timesheet's
  `hoursLastChangedAt` (sent as `lastChangedAt`) for optimistic
  concurrency; a stale value returns 409. Not `updatedAt` — that can lag
  behind changes to the hours.
  Remaining uncovered time tracking areas: projects/tasks,
  configurations, employees, imports, kiosks, time clocks, and shift
  differentials.
  `BambooHR.Breaks` covers meal and rest breaks — break policies, the
  breaks on them, employee assignment, per-employee views, and
  compliance assessments. Kept out of `TimeTracking` despite the shared
  `/time-tracking/` prefix: it is its own resource tree, its IDs are
  UUID strings rather than integers, and it pages with `:offset` /
  `:limit` instead of `:page` / `:page_size`. `update_policy/3` patches;
  `sync_policy/3` replaces the policy and everything attached to it.
  `assign_employees/3` adds, `set_employees/3` replaces.
  The `:effective` option on `list_employee_break_availabilities/3` must
  be `YYYY-MM-DDTHH:MM:SS` with no zone. `list_params/1` turns a `Date`,
  `NaiveDateTime` or `DateTime` into that form, since Req would put a
  space in place of the `T`. A `DateTime` keeps its local clock time and
  loses its zone, because the spec does not say which zone BambooHR uses.
  Bypass does not check the spec's patterns, so a test can pass with a
  value the real API rejects.
  `BambooHR.Scheduling` covers schedules, shifts, shift assessments, and
  the schedule PDF export (`:raw_response` + `:expose_headers`, like
  `Files` downloads). IDs are UUID strings. The PDF endpoint is the only
  one that takes OAuth alone, not API keys. `publish_shifts/2` can
  half-succeed: BambooHR answers 207 when only some shifts published,
  which this client treats as success, so callers must read `"failed"`
  in the body rather than trusting `{:ok, _}`. The PDF endpoint wants
  repeated `employeeIds[]` params, not a comma-joined list — Plug parses
  the `[]` suffix back into a list, which is what the test asserts.
  Enum values are lowercase (`planned`, `published`; `instance`,
  `future`, `all` for `recurrenceEditOption`), `color` is 6 hex digits
  with no `#`, and a publish failure is keyed `shiftId`, not `id`.
  Bypass accepts any value, so check doc examples against the spec.
  `BambooHR.Hiring` covers the Applicant Tracking System (ATS): job
  applications, statuses, locations, hiring leads, job openings, and
  candidates. `create_candidate/5` and `create_job_opening/7` use
  `:form_multipart` like `Files` uploads, but return a JSON body directly
  (`candidateId`/`jobOpeningId`) rather than a `Location` header.

### Testing Patterns

- Bypass library mocks the HTTP layer at the TCP level for integration-style tests.
- Resource-module tests `use BambooHR.BypassCase` (in `test/support/bypass_case.ex`)
  which provides `bypass` and `config` (a `Client.t()` pointing at the local
  Bypass port) in the test context.
- Tests run `async: true`.
- Telemetry handlers are global, so a test's handler also sees events
  from other async tests. Attach with `&__MODULE__.forward_telemetry/4`
  and `{self(), ref}` in `client_test.exs`: it forwards only events fired
  from the test's own process. An anonymous handler also logs a
  "local function" warning.

## Code Style Guidelines

- All public functions must have `@spec` type specs and `@doc` documentation.
- `BambooHR.Client` has `doctest BambooHR.Client` enabled in
  `client_test.exs`; the doctests in `Client.new/1` are real and will run in
  CI — keep struct field order in sync with `defstruct` or they'll fail.
- Handle errors with pattern matching; never raise from public API functions.
- Every failure is `{:error, %BambooHR.Error{}}` — see `lib/bamboo_hr/error.ex`.
  `BambooHR.HTTPClient.Req` builds it with `from_response/3` (non-2xx),
  `from_exception/1` (transport), or `from_decode_error/3` (bad JSON in a
  2xx). Callers match on `:reason`, not the status code. The struct is a
  `defexception`, so `Exception.message/1` works and callers may raise it,
  but the client never does. It also picks up BambooHR's diagnostic
  headers: `x-bamboohr-error-message` / `X-BambooHR-Message` into
  `:message`, and `X-Request-ID` into `:request_id`. Telemetry stop
  metadata carries `:status` (nil for transport failures) and the reason
  atom.
- No Ecto in this project — remove the `has_many`/`belongs_to` guideline if it appears elsewhere.
- BambooHR's public docs (`documentation.bamboohr.com`) are JS-rendered and
  mostly 404 or return empty content through WebFetch/WebSearch. To verify
  exact endpoint paths, methods, and request/response shapes, fetch
  `specs/public.yaml` (an OpenAPI spec) from the
  `BambooHR/bhr-api-python` GitHub repo instead — it's the authoritative,
  machine-readable source and is kept current with the real API.

## CI

- Test matrix: Elixir 1.17/1.18/1.19 × OTP 25/26/27/28.
  Unsupported combinations excluded: 1.17+28, 1.18+28, 1.19+25.
  Linting runs on a separate `include:` entry pinned to the newest
  default toolchain (currently Elixir 1.20 + OTP 29) rather than a member
  of the matrix arrays above — bumping the default doesn't require
  touching the compatibility matrix or its exclude list.
- `coverage`, `dialyzer`, and `docs` are separate jobs pinned to
  `.tool-versions` (currently Elixir 1.20.2-otp-29 / OTP 29.0.3).
  `dialyzer` and `docs` are in the `required` job's `needs:` list;
  `coverage` is not.
- `required` is the one job branch protection checks. It needs `test`,
  `docs`, `dialyzer`, and `lint-markdown`. It runs with `if: always()` and
  exits 1 if any of those failed, was cancelled, or was skipped. Both
  parts matter: without `if: always()` a failed dependency would leave
  `required` skipped, and branch protection treats a skipped check as not
  failed. The job reads `needs.*.result` and nothing else, so it runs with
  `permissions: {}`.
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
