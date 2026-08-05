# Changelog

All notable changes to MCPGate are documented in this file.

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
Versioning follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [1.7.0] — 2026-08-05

### Changed

- Release pages now use curated version notes from this changelog for clear,
  user-focused summaries.
- Published archives now contain only the platform binary and proprietary
  license, with a consolidated `checksums.txt` file for verification.
- Release publication now verifies the complete archive and checksum set before
  making a release available.

### Security

- Installers and self-update continue to require a valid offline ed25519
  signature for every archive; unsigned or mismatched assets are refused.
- Release binaries are built with Go 1.25.12, incorporating the standard-library
  security fixes verified by `govulncheck`.

---

## [1.6.0] — 2026-06-23

### Added

- **Configurable destructive-confirmation policy:** the MCP elicitation prompt
  on destructive tools (`delete_file`, `laravel_artisan`) is now configurable
  per tool via `tools.confirm` (`auto` / `always` / `never`), with
  `tools.confirmOnUnavailable` (`fail-open` / `fail-closed`) for clients that
  can't elicit. A workspace config may only *tighten* a confirmation; loosening
  is global-only unless `tools.allowWorkspaceConfirmOverrides` is set.
- **First-run config seeding + hot-reloadable CORS:** `~/.mcpgate/config.json`
  is seeded on first start; `cors.origins` is settable from the global config
  and reloads live (SIGHUP / file change / dashboard "Reload Config" button).
- **`show_ignored`** option on `find_files`, `search_files`,
  `get_project_structure`, and `list_directory` to reveal `.gitignored` entries
  on demand.
- **`laravel_test`** tool, Pest/PHPUnit auto-detection from `composer.json`,
  and expanded `laravel_phpunit` flags.
- **Configurable temp-spill retention** (`temp.retentionMs`) with a startup
  purge and background janitor for `~/.mcpgate/tmp/`.

### Changed

- `list_directory` now hides noise/security dirs and `.gitignored` entries by
  default.
- `laravel_routes` filters via `route:list --json` in-process (Laravel's
  `route:list` has no `--filter`).

### Fixed

- Streamable HTTP agent sessions reconnect cleanly when a client replays a stale
  `Mcp-Session-Id` on `initialize` (e.g. the MCP Inspector "Reconnect" button) —
  the id is adopted for a new session instead of returning 404.
- Parent task progress now syncs on every subtask add / remove / status change.
- Streamable agent sessions cancel immediately on shutdown and kill.
- `search_files` no longer leaks `.gitignored` matches in its text output.
- Per-project `~/.mcpgate/tmp/` spill files are readable back via a scoped
  path-validator carve-out.

### Security

- `POST /authorize` now enforces a CSRF check before issuing an authorization
  code.
- Removed a dead path-validator bypass so default-denied paths are enforced
  unconditionally.

---

## [1.5.0] — 2026-06-06

### Security

- **OAuth token hashing at rest:** Access and refresh tokens are now stored as
  SHA-256 hashes. An attacker with read access to `mcpgate.db` can no longer
  obtain live tokens. Existing tokens are invalidated on first upgrade; clients
  must re-authenticate.

- **ECDSA / ES256 JWT support:** The external OAuth verifier now handles EC
  public keys (ES256/ES384/ES512). IdPs that default to ES256 — Auth0, Okta,
  Google, Keycloak — previously rejected every bearer token with `kid not found`.

- **patch_subtask cross-workspace isolation:** The `remove`, `status`, `update`,
  and `move` operations now verify that the target subtask belongs to the
  declared parent task before mutating. Previously a caller could combine a
  valid `task_id` with a `subtask_id` from a different workspace.

- **HTTP client timeouts for web_search / web_fetch / OAuth verifier:** A
  dedicated `http.Client` with dial, TLS, and response-header deadlines
  prevents a stalled TCP connection from pinning a goroutine indefinitely.

- **Windows deny-list fix (`os.UserHomeDir`):** `os.Getenv("HOME")` returns
  empty on Windows. The security deny-list entries (`.ssh`, `.aws`, `.mcpgate`,
  etc.) now resolve correctly via `os.UserHomeDir`. Windows-specific paths
  (`System32`, `ProgramFiles`, `AppData`) are also added to the default list.

### Fixed

- Migration 009 (`blocked_by` cascade trigger) was on disk but missing from
  the migration order — deleting a task no longer leaves ghost blockers.
- `cmd.WaitDelay` set to 5 s in subprocess spawner — a hung subprocess no
  longer blocks `cmd.Wait` indefinitely.
- Tool `commandTimeout` config is now propagated to all subprocess-based tools
  (was hardcoded 5 min).
- `mcpgate init` now writes `tools.mode` / `tools.enabled` (was writing
  non-existent fields with no effect).
- LoopbackOnly middleware returns `403` instead of `404` for misconfigured
  reverse-proxy deployments.
- Dashboard update-status cache cleared on `POST /api/reload`.
- Tool rate limiter (`tools.rateLimit` config) is now actually enforced at
  dispatch time.
- Unsaved subtask draft no longer fires a `DELETE` API request on discard.
- Enter key in subtask input no longer submits the parent task form.

### Added

- **Native Windows Service:** `mcpgate service install/uninstall/start/stop/
  restart/status` now integrates with the Windows SCM directly — Automatic
  start type, restart-on-failure. No NSSM or WinSW required.
- **Windows subprocess graceful shutdown:** Bridge/boost subprocesses receive
  `CTRL_BREAK_EVENT` with a 3 s window before hard kill.
- **FreeBSD support:** `freebsd/amd64` added to release build matrix.
- **Consolidated `checksums.txt`:** Single `sha256sum`-format file replaces
  per-archive `.sha256` files.
- **Brave Search and Tavily web_search providers:** Configure via
  `MCPGATE_BRAVE_API_KEY` / `MCPGATE_TAVILY_API_KEY` env vars, config file,
  or `--brave-api-key` / `--tavily-api-key` CLI flags. Falls back to
  DuckDuckGo when no key is set.
- **20 new MCP tools:** `list_allowed_commands`, `session_info`, `check_format`,
  `sort_imports`, `crop_image`, `image_optimize`, `image_thumbnail`, `adb_pull`,
  `adb_push`, `adb_screenshot`, `laravel_env_check`, `laravel_routes`,
  `laravel_tinker_eval`, `npm_outdated`, `npm_uninstall`, `go_mod_tidy`,
  `dependency_audit`, `list_scripts`, `bulk_update_tasks`, `export_tasks`.
- **7 new git tools:** `git_branch`, `git_checkout`, `git_merge`, `git_pull`,
  `git_push`, `git_remote`, `git_stash`.
- **6 new filesystem tools:** `file_stat`, `list_directory`,
  `read_multiple_files`, `file_diff`, `archive`, `unarchive`.
  `edit_file` gains `replace_all` mode; `search_files` gains `regex` flag.
- **`.env.example`:** Documents all `MCPGATE_*` environment variables.
- **Windows PowerShell installer** (`install.ps1`) added to this repository.

---

## [1.4.0] — 2026-06-04

### Added

- **Inter-task dependency graph:** Tasks now support `blocked_by` and `blocks`
  relationships. The dashboard exposes a blocked-by picker with a done-block
  guard — a task with open blockers cannot be marked done until all blocking
  tasks are resolved.

- **First-class subtask table:** Subtasks are migrated from a JSON column to a
  dedicated table with inline create, update, reorder, and delete operations
  via `patch_subtask`. Each subtask carries its own status, position, and
  timestamps.

### Fixed

- **Workspace isolation in MCP task tools:** All task tools now enforce strict
  workspace scoping — a session cannot read or mutate tasks belonging to a
  different workspace even when the task ID is guessed.

- **Subtask draft commit ordering (UI):** Subtask drafts created in the
  dashboard are now staged locally and committed to the API in order, preventing
  race conditions that previously caused out-of-order subtask positions.

- **GoReleaser tag-push deduplication:** The release workflow no longer fails
  when the tag already exists on the MCPGate-Releases mirror, making re-runs
  of a release job safe.

- **Go toolchain pinned to 1.25.11:** The module and all CI workflows pin the
  Go toolchain version explicitly to prevent surprise build differences across
  environments.

### Changed

- **Docs synced:** README, REVIEW, and migration baseline updated to reflect
  the subtask table schema, dependency graph, and current feature set.

---

## [1.3.0] — 2026-05-30

### Added

- **React + Vite SPA dashboard:** The static HTML dashboard is replaced by a
  full React + TypeScript + shadcn/ui application served at `/manage`. Provides
  kanban task board, session table, filterable audit log, settings panel, and
  live SSE-driven updates with dark/light theme.

- **Tailwind HTML templates for OAuth pages:** The OAuth consent and error
  pages are now rendered from Tailwind-styled Go templates, matching the
  dashboard visual language. `ExternalBaseURL` config field controls the
  public-facing base URL used in OAuth redirects and asset paths.

- **Hot-reload propagation:** Live config reload (`SIGHUP` / `POST /api/reload`)
  now propagates to the transport handler, agent tool dispatcher, security
  validators, and read-before-write tracker without restarting the process.

- **Read-before-write guard:** The agent enforces a configurable
  `requireReadBeforeWrite` policy — any tool that writes a file must have
  first read that file in the same session, preventing blind overwrites.

- **Per-tool enable/disable and command timeout:** Individual tools can be
  switched on or off via `tools.enabled` / `tools.disabled` config keys.
  `tools.commandTimeout` sets the maximum wall-clock time for subprocess-based
  tools (format, lint, test, npm, go).

- **Workspace overlay config:** Per-workspace `~/.mcpgate/<workspace>/.mcpgate.json`
  overrides merge on top of the global config, allowing per-project tool
  selection and policy without touching the global config.

- **Root-user confirmation guard:** Starting `mcpgate` as root now requires an
  explicit `--allow-root` flag or interactive confirmation, with the warning
  surfaced in the dashboard overview panel.

- **Admin API envelope responses and audit-clear endpoint:** All admin API
  responses are now wrapped in a consistent JSON envelope. A new
  `DELETE /api/audit` endpoint clears the audit log.

- **Expanded test coverage:** New tests for logger, metrics, rate-limiter,
  service layer, and graceful shutdown. Health check now verifies privilege
  level with injectable `UIDFn` / `MemFn` helpers.

### Fixed

- **Session LastActivity for stream-agent sessions:** `LastActivity` is now
  updated on every tool invocation in stream-agent (Streamable HTTP) sessions,
  not only on SSE ping ticks.

- **CI lint exclusions for `web/node_modules`:** golangci-lint v2 config
  updated to exclude the frontend dependency tree from Go analysis, fixing
  false-positive lint failures in CI.

---

## [1.2.0] — 2026-05-25

### Added

- **OAuth client name capture:** The `client_name` parameter in the OAuth
  authorization request is now stored and displayed in the dashboard audit
  detail modal, giving operators visibility into which MCP client initiated
  a session.

- **Audit detail modal:** The dashboard audit log row now expands to a modal
  with full request context, tool arguments, and result metadata.

- **Session workspace and Last Active columns:** The sessions table now shows
  the workspace path and a human-readable last-active timestamp for every
  active session type (SSE, Streamable HTTP, stream-agent).

- **Poll-driven update-available banner:** The dashboard polls for a new
  release in the background and surfaces a dismissible banner with a
  release-notes link when one is available.

### Fixed

- **`mcpgate update --restart` restarts the systemd service:** Previously the
  flag was parsed but the restart step was silently skipped; the service is
  now restarted via `systemctl --user restart mcpgate` after a successful
  update.

### Changed

- **MCPGate rebrand:** All remaining product-noun references (`mcpbridge`,
  `mcpgate-agent`, internal package comments) are normalised to `MCPGate`.

---

## [1.1.1] — 2026-05-25

### Fixed

- **Updater accepts PKIX-wrapped public key:** The self-update signature
  verifier now accepts both raw and PKIX-wrapped ed25519 public keys,
  resolving a failure when the signing key was re-generated in PKIX format.

- **Archive names preserve the leading `v`:** GoReleaser archive name template
  corrected so that `mcpgate_v1.1.1_linux_amd64.tar.gz` matches the URL
  pattern expected by `install.sh` and `mcpgate update`.

- **Changelog entries strip commit hash:** The GoReleaser changelog template
  no longer includes the short commit hash prefix in release notes, keeping
  entries clean and human-readable.

---

## [1.1.0] — 2026-05-25

### Added

- **Workspace-aware filesystem sandboxing:** The filesystem and git tools now
  enforce a strict workspace boundary. Paths outside the declared workspace
  root are rejected at the tool dispatcher level, preventing traversal to
  arbitrary host paths.

- **Dynamic version injection:** `EffectiveConfig.Version` is now populated
  from the `ldflags`-injected build version at link time, so
  `mcpgate version`, the admin API, and the dashboard all report the correct
  release tag rather than `dev`.

- **GoReleaser git changelog engine:** Releases now use GoReleaser's built-in
  git-log changelog renderer, producing per-release notes derived from
  conventional commits automatically on tag push.

- **Release mirrored to source repo:** The CI release workflow pushes the
  matching tag to the private source repository after GoReleaser publishes
  assets to MCPGate-Releases, keeping both repos in sync.

### Fixed

- **Tool input schema alignment:** Several tools had mismatches between their
  declared JSON Schema and the actual handler behaviour (wrong field names,
  missing optionals, incorrect types). All schemas are now validated against
  their handlers.

- **Dashboard `style-src 'self'` CSP:** Inline `style` attributes removed from
  dashboard HTML; all styles moved to external classes to satisfy the strict
  `style-src 'self'` Content Security Policy header.

- **Operator config polish:** Rate-limit defaults, website URL field, and
  GoReleaser asset naming cleaned up based on first-release operator feedback.

---

## [1.0.0] — 2026-05-24

### Added

- MCP bridge mode: proxy any stdio MCP server over HTTP SSE and Streamable HTTP.
- Agent mode: rich built-in tool suite (filesystem, git, project, testing,
  formatting, web search, tasks, images, Android, Laravel, ML, and more).
- Dashboard: web UI for session management, audit log, task tracking, and
  key rotation.
- OAuth 2.0 server with PKCE; external IdP support via JWKS / token
  introspection.
- Prometheus metrics, OpenTelemetry-compatible structured logging.
- Graceful shutdown, config hot-reload (SIGHUP), background update checks.
- Admin Unix-socket API for CLI management (`mcpgate admin`).
- `mcpgate init`, `mcpgate key`, `mcpgate backup`, `mcpgate update`,
  `mcpgate doctor` subcommands.
