# Changelog

All notable changes to MCPGate are documented in this file.

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
Versioning follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [1.13.0] — 2026-11-16

### Added

- **Dashboard upstream management:** a new **Upstreams** page and `/api/upstreams` admin API create, edit, enable/disable, delete, and test trusted `boost.upstreams` definitions (stdio, `streamable_http`, `sse`). Mutations are off by default and require the global-only `dashboard.allowUpstreamEdit` flag, which no workspace config or API call can change. Each change is validated as a whole, persisted atomically, and applied through the normal reload (a rejected reload restores the previous file). Deleting an upstream a named server references is rejected, at most 8 upstreams may be enabled at once, remote auth is exposed as `hasAuth` only, and every attempt, including ones refused while editing is off, is audit-logged with the operation, upstream name, and a fixed reason code.
- Global-only `tools.enabledDefaults` opt-out re-enables individual tools from MCPGate's built-in default-disabled baseline without turning off the rest of their category or altering `tools.disabledTools` precedence.
- `mcpgate doctor` gains the `tool-defaults` check (how many of the 38 default-disabled built-in tools are active-off and which names are lifted) and the `batch-policy` check (the effective batch limits).
- Name-keyed config warnings (`tools.enabledTools`, `tools.enabledDefaults`, `tools.disabledTools`, `tools.rateLimit`, `tools.confirm`) now surface unknown `enabledDefaults` entries, non-baseline entries with no effect, `enabledDefaults` / `disabledTools` conflicts where explicit disables win, entries targeting an unlifted baseline built-in, and a workspace `enabledDefaults` list that is ignored because the global flag is off.
- `limits.maxBatchDuration` (global) and a tighten-only workspace override bound the wall-clock time of a single `batch_execute` call. Zero, the default, means unlimited. Operations skipped or cut short carry a `termination_reason` (`time_budget` or `cancellation`), and `mcpgate_batch_termination_total{reason}` counts batches rejected for exceeding the operation cap or stopped early.
- Workspace configuration may introduce or lower `limits.maxBatchOperations`; it can never raise or remove an inherited cap.
- The dashboard Memory page has a server picker that loads the root a named server serves (its active worktree while in use, otherwise its workspace); entering an absolute path manually still works.
- Audit durations are shown in a human-friendly format.

### Changed

- **Breaking:** 38 rarely-used built-in tools are now disabled by default — Android/ADB (`adb_devices`, `adb_install`, `adb_logcat`, `adb_pull`, `adb_push`, `adb_screenshot`, `adb_shell`), package/build executors (`bundle_install`, `cargo_run`, `composer_install`, `go_get`, `go_mod_tidy`, `gradle_build`, `list_python_packages`, `mvn_build`, `npm_install`, `npm_outdated`, `npm_uninstall`, `pip_install`, `python_exec`), image/archive tools (`archive`, `convert_image`, `crop_image`, `image_info`, `image_optimize`, `image_thumbnail`, `resize_image`, `unarchive`), remote/history-mutating git verbs (`git_cherry_pick`, `git_fetch`, `git_pull`, `git_push`, `git_remote`, `git_revert`, `git_stash`, `git_tag`, `git_worktree`), and `web_search`. Re-enable individual typed tools in global config via `tools.enabledDefaults` rather than adding raw binaries to `permissions.additionalAllowedCommands`. Upstream (bridge/boost) tools with the same name are unaffected and no longer trigger a name-conflict error against a default-disabled built-in.
- **Breaking:** workspace `tools.disabledTools` now unions with (adds to) the global list instead of replacing it, so a repository-local config can add disables but can never erase an operator's global disable.
- **Breaking:** workspace tool selection can no longer loosen global deny lists or a global category cap. `tools.disabled` unions with the global list; `tools.enabledTools` is intersected with a non-empty global allowlist (a disjoint result invalidates the workspace config instead of widening it); a workspace may choose any `tools.mode` (`auto`, `all` or `manual`), but a global `manual` mode is a ceiling — a workspace `all` or `auto` keeps the global category list and a workspace `manual` list is intersected with it; any other mode value invalidates the workspace config and the last-known-good policy stays active. A workspace `tools.enabledDefaults` list lifts default-off built-ins only when the global config sets the new `tools.allowWorkspaceEnabledDefaults` flag (default `false`); an explicit `disabledTools` entry still wins. Global and workspace `enabledTools` are now trimmed, deduplicated, and sorted, and a non-empty `enabledTools` list containing only blank names is rejected instead of silently becoming unrestricted. A global reload that would make an active workspace's tool policy invalid is rejected as a whole, like other incompatible workspace policy. `tools.forceProjectTypes` remains a workspace override.
- Dashboard server Validate now reports an invalid workspace config as `workspace_config_invalid` with the policy message (workspace paths masked) instead of the generic `connectivity_probe_failed`.
- `limits.maxBatchOperations` now defaults to unlimited (`0`) instead of 15, and negative values are rejected at load time. Safety continues to rely on tool timeouts, output limits, admission control, and memory protections; set a positive value to enforce a fixed cap.
- `batch_execute` audit rows for early-terminated batches record `skipped` and the termination reason, and are written even after the batch's own time budget has expired.

### Fixed

- Session lifecycle: idle expiry uses a monotonic timer, bridge sessions fall back to their last activity, standalone GET streams count as activity, a reservation honors the stricter of the live and caller limits, and negative `limits.maxSessions` is rejected at load.
- Configuration reload is atomic: a replacement is validated before any live state changes, boost tools route through the live dispatcher, and the agent reload no longer risks a recursive lock deadlock.
- Streamable HTTP: oversize request bodies get `413` instead of being truncated, sessionless non-initialize requests are rejected before any session or subprocess is reserved, buffered responses and subprocess stderr are bounded, and upstream list errors fail closed.
- Background command execution: deadlines, retention, and status reporting are reliable, live `get_result` polls render their status text, and a caller's own still-running call is named in `queue_timeout` rejections.
- Tools: `move_file` requires `overwrite=true` before replacing an existing destination, `delete_memory` asks for the same confirmation as the other deletion tools, `find_files` no longer leaks an extra entry with `has_more=false`, `search_files` guards its argument vector and excludes archive temp files, and batch results disambiguate nested operations and report confirmation-capacity errors.
- Memory: recovery is serialized across processes, uncreated instruction paths resolve, the recovery quarantine is pruned by count and age, orphaned temp files are cleaned, and Claude front matter is preserved.
- Dashboard: SSE reconnect resumes after a terminal close, task dialogs keep their form across subtask edits, polling treats URL changes as loading transitions, and several progress-input and button-spinner edge cases are fixed.

### Security

- Argument blocklist now catches clustered and attached GNU short options, and systemd unit paths are escaped.
- Path validation folds case when matching denied sub-directories and prefixes.
- `X-Forwarded-For` is walked right to left behind trusted proxies, and public dashboard mode fails closed on invalid peer configuration.
- OAuth tokens are no longer persisted in plaintext, the backup directory is protected, refresh-token family revocation is enforced, and JWKS failures are negatively cached.
- The admin socket is bound without a process-wide umask, discovery files are validated, and login attempts are rate-limited.
- Release-asset downloads validate the URL host and scheme, and upstream redirects are pinned to the previous hop.
- Go is bumped to 1.26.11 with patched dependencies.

---

## [1.12.0] — 2026-09-09

### Added

- **Background command execution:** `execute_command` accepts `background=true` to start an already-validated command detached from the requesting connection and return an opaque handle immediately — a completion path for commands that outlast a proxy response window or clients without progress-token support. `get_result` resolves background handles for live lifecycle status (queued or running, with elapsed time and bytes captured so far), pages the retained output through the same handle once terminal, and stops a runaway execution with `cancel=true`; timeouts, memory budgets, allow-lists, and output limits stay enforced server-side for the full lifecycle, and graceful shutdown drains live entries instead of orphaning children.
- **Progress heartbeats for long tool calls:** tools that can outlast a proxy's response window (command execution, git fetch/pull/push, package managers, image tools, `web_fetch`, test coverage, and more) emit `notifications/progress` heartbeats every 2–5 seconds when the client supplies a progress token, and `batch_execute` reports exactly-once per-child completion counts plus a batch-wide heartbeat on a single monotonic progress scale.
- **Comprehensive `mcpgate doctor` diagnostics:** the five hardcoded checks are replaced by a 20-check, severity-graded registry across binary, security, database, config, and runtime — including SQLite integrity and migration-state comparison, unknown config keys (whose typos the loader silently ignores), stale tool-name entries, workspace-root availability, CLI-vs-server version skew, crash-log panic scanning, and free-space probing — with a stable `--json` report, `--strict` failure exits, `--only` subset selection, and per-check fix hints.
- **Optional per-server active worktree:** a named server can prefer a git worktree root over its workspace; the root resolves per connection, so a worktree removed mid-flight strands no live session while new connections fall back to the workspace automatically, surfaced as a Fallback badge beside the Invalid badge on the servers page.
- **Degraded server publication:** a removed workspace root or an unresolvable remote secret now marks one named server invalid (with a sanitized reason) instead of failing startup, reload, or dashboard mutations for every healthy server; publication re-checks the environment, so a restored root heals automatically.
- **Stale tool-config warnings:** `tools.enabledTools`, `tools.disabledTools`, `tools.rateLimit`, and `tools.confirm` entries matching no built-in tool now produce a deterministic warning at startup and reload — a renamed tool previously disarmed its per-tool policy silently — and the dashboard Settings page renders reload warnings as a persistent alert.
- **Expanded git tool family (20 tools):** new `git_apply` (patch to index or worktree with per-path write validation), `git_fetch` (with remote host-allowlist enforcement), `git_tag` (list/create/delete), `git_revert` and `git_cherry_pick` (with abort/skip operations and structured conflict reporting), `git_worktree` (list/add/remove/prune), and `git_blame` (line-porcelain annotation with keyset paging).
- **Git workflow enhancements:** `git_diff` gains `staged=true` to review the pending commit, `git_checkout` gains `mode=unstage`, `git_merge` gains `op=abort`, a fast-forward policy, and structured conflict lists, `git_commit` gains `amend=true` (refused while behind upstream), `git_status` reports ahead/behind counts, and `git_branch` create accepts a `start_point`.

### Fixed

- Long tool calls no longer fail behind Cloudflare with a 524 gateway timeout after roughly 100 seconds of origin silence on the Streamable HTTP path: progress events now stream to the wire incrementally while a tool runs instead of buffering until the handler returns.
- Task tools now resolve three reference shapes — full UUID, plain sequence number, and `#seq` — across every id-taking field, dependency edges are validated against cycles before writes, and `list_tasks` rows carry a UUID prefix so discovery and follow-up calls round-trip; a one-time migration removes dangling dependency references left by older versions.
- `git_merge` conflict reporting no longer misrepresents a refused merge start (leftover unmerged paths from another operation) or a failed abort as a fresh conflict of the requested branch.

---

## [1.11.0] — 2026-08-31

### Added

- **Active-execution live view:** real-time monitoring of in-flight built-in tool executions and proxied upstream forwards via `GET /executions`, live SSE broadcasts over `/api/events`, and an Active Executions strip on the dashboard audit page with visible overflow badges and pause-on-background tabs.
- **Progressive, token-efficient tool output:** bounded default output pages with typed continuation cursors across `list_tasks` (25 tasks), `search_files` (50 matches), `find_files` (continuation cursor), `list_directory` (200 entries), `git_log` (25 commits), `get_project_structure` (500 entries), `read_files` (`detail=manifest`), `git_diff` (`detail=manifest` plus per-file paging), and `git_show` (`detail=summary`).
- **Retained-result handles & `get_result` tool:** oversized batch outputs, command captures, and task exports are retained behind scope-bound expiring handles and retrieved in exact byte windows without lossy LLM summarization.
- **Targeted memory editing (`edit_memory`):** byte-precise splice engine for updating Claude-compatible project memories with optimistic concurrency, occurrence selection, and YAML frontmatter preservation.
- **Configurable dedicated-tool subcommand policy (`tools.denySubcommands`):** deny specific subcommands of dedicated command tools (starting with `laravel_artisan`) without disabling the parent tool; workspace overlays merge as a union.
- **Read-only additional directory paths (`permissions.additionalReadOnlyPaths`):** grant read-only access to dependency trees (e.g. Go module cache) while blocking all write and mutating operations.
- **Configurable git remote-URL host allowlist (`tools.allowGitRemoteHosts`):** confine git remote targets to trusted hostnames or IPv6 literals; workspace overlays merge as an intersection.
- **Keyset audit log pagination & server-side statistics:** bidirectional cursor pagination (`first`/`prev`/`next`/`last`), configurable page sizes (25/50/100/250), URL synchronization, and server-side KPI metrics via `GET /audit/stats`.
- **Exactly-once upstream tool-call auditing:** proxied bridge and boost tool invocations write terminal audit rows with normalized outcomes (`success`, `error`, `denied`, `rate_limited`, `cancelled`).

### Changed

- **Breaking:** the `read_multiple_files` tool is renamed to `read_files`. Operators must update `?tools=` allowlists and config entries referencing the old name. Input and output schemas remain unchanged.
- List, search, diff, log, and directory tools now default to bounded pages to optimize token consumption and model response speed.
- Dashboard Audits page replaces "Load more" with keyset pagination and server-side statistics cards.

### Fixed

- Tool schemas normalize reflection-inferred nullable type unions into strict-client-compatible `anyOf` branches with single-string types.
- `batch_execute` operations input schema is declared as a nullable free-form object (`{"anyOf":[{"type":"null"},{"type":"object"}],"additionalProperties":true}`).
- `POST /authorize` key-entry submissions are exempt from the dashboard CSRF check to prevent 403 errors during localhost OAuth flows while keeping CSRF enforced for session-backed logins; OAuth round-trip parameters are preserved on key correction.
- Write-side path validation is strictly applied to `execute_command` CWD, image destinations, `adb_pull`/`adb_screenshot` targets, and mutating git operations.

### Security

- Git tool arguments are validated against option injection (`--output=`, `--receive-pack=`, `--upload-pack=`) and invalid ref formats across all git tools before subprocess execution.
- Git remote URLs enforce safe transport protocols (`https`, `http`, `git`, `ssh`, scp-like `host:path`), blocking local `file://` references and remote helpers.

---

## [1.10.0] — 2026-08-24

### Added

- **Named MCP servers with clean per-server endpoints:** connect directly to `/mcp/{routeKey}` where mode, workspace, and upstreams resolve server-side. Bare `/mcp` returns a deterministic 404.
- **Cross-server session isolation:** MCP sessions are pinned to their route key; sessions cannot attach across different server endpoints.
- **Remote Streamable HTTP and SSE upstream transports:** connect to remote MCP upstreams alongside local stdio upstreams, with endpoint-level timeout, secret-reference authentication, and egress protection.
- **Dashboard Named Servers management:** full web UI (`/manage/servers`) and admin API for viewing, adding, editing, validating, toggling, and gracefully draining named servers.
- **Pluggable crash logging and panic protection:** structured crash reporting with thread-safe file, buffer, and silent logging sinks, automatic LogDir scoping, and credential sanitization.

### Changed

- Client topology override query parameters (`?workspace=`, `?mode=`, `?command=`, `?args=`, `?cwd=`, `?env=`, `?tools=`) on `/mcp/{routeKey}` are rejected with `400 Bad Request`.
- Go toolchain baseline updated to **1.25.14** for official release binaries.
- `web_fetch` adds DOM-aware primary content extraction, discussion preservation, Markdown formatting, charset decoding, and conditional caching.
- Web dashboard enforces strict type checking and improved select dropdown behavior in modal dialogs.

### Fixed

- Browser OAuth authorization form submissions now complete seamlessly with third-party providers via meta refresh navigation, preventing multi-hop redirect CSP blocking.
- Server edit dialog in the web dashboard safely handles servers with empty upstream lists without runtime errors.
- Stateful agent connections safely reuse correlated sessions across fresh client initializations without accumulating duplicate active sessions.
- Request cancellation and duplicate JSON-RPC request-ID cleanup release lifecycle resources deterministically.

### Security

- OAuth `/authorize` form redirect CSP dynamically admits registered client callback origins without wildcarding.
- Recovered panic logs redact bearer tokens, authorization headers, and credential assignments.
- `web_fetch` enforces public-only HTTP(S) destinations, blocking access to private, loopback, link-local, multicast, and special-use IP ranges.

---

## [1.9.0] — 2026-08-20

### Added

- **Configured multi-upstream bridge and boost:** run multiple named stdio MCP servers from trusted global configuration and expose one merged MCP surface to clients.
- **Upstream health and resilience controls:** configure required/optional upstreams, startup/request timeouts, health checks, environment inheritance, and conflict handling.
- **Host-wide subprocess memory ceiling:** `limits.executionMemory.maxHost` can cap finite subprocess reservations across the MCPGate process.

### Changed

- Bridge now exposes configured upstreams only; boost exposes the same upstreams plus MCPGate's built-in agent tools.
- Bridge/boost process topology now comes from global configuration. Client `command` and `args` query parameters are no longer accepted.
- Tool admission better preserves responsiveness when builds, tests, installs, and other heavy work run concurrently.

### Fixed

- Compatible fresh Streamable bridge/boost connections from the same logical client session can reuse the existing stateful runtime instead of starting duplicate persistent upstream processes.
- Standalone Streamable server-message delivery no longer loses a queued message when receivers overlap, disconnect, or are superseded.
- Canceled requests release queued work more promptly instead of remaining blocked behind unrelated operations.

### Security

- Workspace configuration can only tighten configured upstream policy and cannot introduce new executable topology.
- Upstream environment inheritance is explicitly allow-listed, and upstream diagnostics are sanitized before entering application logs.
- Logical-session correlation is not an authorization mechanism; raw correlation and MCP session identifiers are excluded from ordinary lifecycle telemetry.

---


## [1.8.0] — 2026-08-15

### Added

- **Resource-aware admission control:** bounded fair queues coordinate expensive session setup and tool work across agent, bridge, boost, stateless, and batch paths with cancellation, overload guidance, and low-cardinality resource-pressure telemetry.
- **Typed subprocess memory policies:** operators can configure process-tree, session, workspace-aggregate, category, and tool memory ceilings with platform-aware enforcement and fail-closed `hard-required` behavior.
- **Claude-compatible project memory ownership:** `.mcpgate/memory/` is now MCPGate's dedicated project-memory store, with revision-safe MCP/admin/dashboard workflows, optional sharing with Claude Code through a symlink, and no generic filesystem write bypass.
- **Boost-aware batch execution:** `batch_execute` can invoke the merged boost tool surface, including upstream-owned tools, while preserving ordered results, structured errors, cancellation, limits, and bounded aggregate output.
- **Active workspace configuration hot reload:** stateful sessions retain and watch validated workspace overlays while active; valid edits publish to matching reloadable sessions, invalid edits keep the last-known-good policy, and authenticated diagnostics expose generation/remediation details.

### Changed

- Confirmation now uses SDK-standard MCP form elicitation based on negotiated capability. The proprietary fallback and `tools.confirmOnUnavailable` setting are removed; authentication, ACLs, path/command restrictions, and tool validation remain authoritative.
- Explicit command additions now apply consistently to agent execution and bridge/boost spawning while preserving separate least-privilege built-in command bases and executable-identity safeguards.
- Stateful agent/bridge/boost discovery and downgrade behavior now follows the SDK capability model with explicit machine-readable negotiation guidance.
- Release publication is offline-gated: CI prepares verified drafts, while `make sign-release` verifies assets/checksums, creates and verifies every ed25519 signature, and publishes only after exact signed parity is confirmed.
- Release and CI builds now use **Go 1.25.13**.

### Fixed

- Boost upstream startup, transport, timeout, process-exit, and malformed-protocol failures no longer take down MCPGate-owned tools; upstream-owned calls fail with stable degraded-state errors until a new healthy session is opened.
- Task/subtask migration and restore handling preserves released migration integrity and safely normalizes server-owned UUID identities across upgrades.
- Dashboard health diagnostics correctly handle the health endpoint media type.
- Reloadable Agent and Boost sessions can no longer remain on a stale policy generation when initialization overlaps a global or workspace reload.
- Rejected global reloads return a non-success operator response with actionable authenticated diagnostics instead of reporting a false successful reload.

### Security

- Agent command defaults are reduced to bounded read-oriented utilities; runtimes, package managers, compilers, shells, Git, and other higher-consequence commands require explicit opt-in.
- Confirmation authorizations are random, expiring, single-use, and bound to the exact invocation, authenticated scope, and policy generation; replay, mutation, wrong-scope reuse, expiry, and stale-policy retries fail closed.
- Runtime security identity is namespaced by authoritative auth/trust domain and canonical workspace identity, preventing alias or raw-ID collisions across sessions, throttling, confirmation, and stateless quotas.
- Resource-aware admission, process-tree memory enforcement, bounded subprocess I/O, and fail-safe workspace publication reduce denial-of-service and mixed-policy exposure.
- Go **1.25.13** resolves the reachable standard-library vulnerabilities detected by `govulncheck` against Go 1.25.12.

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
