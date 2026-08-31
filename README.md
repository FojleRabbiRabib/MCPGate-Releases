# MCPGate — Releases

[![Latest Release](https://img.shields.io/github/v/release/FojleRabbiRabib/MCPGate-Releases?label=latest)](../../releases)
[![Downloads](https://img.shields.io/github/downloads/FojleRabbiRabib/MCPGate-Releases/total?label=downloads)](../../releases)
[![Downloads (latest)](https://img.shields.io/github/downloads/FojleRabbiRabib/MCPGate-Releases/latest/total?label=downloads%20%28latest%29)](../../releases)
[![License](https://img.shields.io/badge/license-proprietary-red)](LICENSE)
[![Stars](https://img.shields.io/github/stars/FojleRabbiRabib/MCPGate-Releases?style=flat)](../../stargazers)

This repository provides official compiled binaries, installers, the
proprietary license, and user documentation for **MCPGate** — an enterprise-grade
MCP bridge and agent server written in Go. Each release page uses the matching
version section from [`CHANGELOG.md`](CHANGELOG.md).

### v1.11.0 highlights

- **Active-execution live view:** real-time tracking of in-flight built-in and proxied upstream tool executions via `GET /executions`, SSE broadcast over `/api/events`, and an Active Executions dashboard strip.
- **Progressive bounded tool outputs & `get_result`:** token-efficient default pages and continuation cursors across task, search, find, directory, diff, and git log surfaces; oversized outputs are retained behind expiring handles and retrieved via `get_result`.
- **Targeted memory editing (`edit_memory`):** byte-precise splice tool for updating Claude-compatible project memories with optimistic concurrency and YAML frontmatter preservation.
- **Granular security & permission controls:** read-only additional directory paths (`additionalReadOnlyPaths`), dedicated subcommand deny policy (`denySubcommands`), and git remote host allowlisting (`allowGitRemoteHosts`).
- **Keyset audit log pagination & outcome statistics:** bidirectional cursor pagination (`first`/`prev`/`next`/`last`), configurable page sizes (25/50/100/250), URL synchronization, and server-side KPI outcome statistics (`GET /audit/stats`).
- **Tool rename (`read_files`):** `read_multiple_files` renamed to `read_files` across all surfaces.


> ## Open-source at 1,000 stars
>
> When this repository reaches **1,000 GitHub stars**, the private MCPGate
> source repository will be made public and **MCPGate will be open-sourced for
> everyone**.

> **All public interactions — bug reports, feature requests, install issues,
> usage questions — happen in [this repo's Issues tab](../../issues).**
> Please do not email the maintainer directly for non-security matters; opening
> an issue keeps the conversation visible to other users and the changelog.
> Security-sensitive findings are the one exception — see *Reporting a Security Issue* below.

---

## Install

### One-liner (Linux / macOS / FreeBSD)

```bash
curl -fsSL https://raw.githubusercontent.com/FojleRabbiRabib/MCPGate-Releases/main/install.sh | bash
```

The script automatically detects your OS and architecture, downloads the correct
binary, verifies the **SHA256 checksum AND the offline ed25519 signature**
against the maintainer's public key embedded in the script, installs to
`~/.local/bin/mcpgate`, and warns if that directory is not in your `PATH`.

### One-liner (Windows — PowerShell)

```powershell
iex (irm https://raw.githubusercontent.com/FojleRabbiRabib/MCPGate-Releases/main/install.ps1)
```

The script detects your architecture, verifies SHA256 and ed25519 signature
(requires `openssl.exe` — ships with Git for Windows), installs
`mcpgate.exe` to `%LOCALAPPDATA%\Programs\MCPGate\`, and offers to add that
directory to your user `PATH`.

> The signing public key is reproduced inside `install.sh` and matches the
> key baked into every release binary. The corresponding private key is kept
> offline, so published archives must carry a valid maintainer signature before
> the installer or `mcpgate update` will trust them.

### Specific version

```bash
VERSION=v1.2.3 bash <(curl -fsSL https://raw.githubusercontent.com/FojleRabbiRabib/MCPGate-Releases/main/install.sh)
```

### Custom install directory

```bash
INSTALL_DIR=/usr/local/bin bash <(curl -fsSL https://raw.githubusercontent.com/FojleRabbiRabib/MCPGate-Releases/main/install.sh)
```

### Manual download

Download the archive for your platform from the [Releases](../../releases) page,
verify the checksum, and extract the binary:

```bash
VERSION=v1.0.0
PLATFORM=linux_amd64
ARCHIVE=mcpgate_${VERSION}_${PLATFORM}.tar.gz
BASE=https://github.com/FojleRabbiRabib/MCPGate-Releases/releases/download/${VERSION}

curl -LO "${BASE}/${ARCHIVE}"
curl -LO "${BASE}/checksums.txt"
curl -LO "${BASE}/${ARCHIVE}.sig"

# Verify checksum (checksums.txt is sha256sum format — one line per platform)
grep "${ARCHIVE}" checksums.txt | sha256sum --check

# Verify ed25519 signature (see "Verifying a release manually" for signing.pub)
openssl pkeyutl -verify -pubin -inkey signing.pub -rawin -in ${ARCHIVE} -sigfile ${ARCHIVE}.sig

# Extract and install
tar -xzf "${ARCHIVE}" mcpgate
chmod +x mcpgate
mv mcpgate ~/.local/bin/mcpgate
```

---

## Supported platforms

| OS | Architecture | Archive |
|---|---|---|
| Linux | x86_64 (amd64) | `mcpgate_<version>_linux_amd64.tar.gz` |
| Linux | arm64 | `mcpgate_<version>_linux_arm64.tar.gz` |
| macOS | x86_64 (Intel) | `mcpgate_<version>_darwin_amd64.tar.gz` |
| macOS | Apple Silicon | `mcpgate_<version>_darwin_arm64.tar.gz` |
| FreeBSD | x86_64 (amd64) | `mcpgate_<version>_freebsd_amd64.tar.gz` |
| Windows | x86_64 (amd64) | `mcpgate_<version>_windows_amd64.zip` |
| Windows | arm64 | `mcpgate_<version>_windows_arm64.zip` |

Each release ships:

- `<archive>` — the platform binary plus the public proprietary `LICENSE`.
- `checksums.txt` — SHA256 digests for all platform archives in `sha256sum` format.
- `<archive>.sig` — ed25519 signature over the archive bytes, produced
  offline by the maintainer with `openssl pkeyutl -sign -inkey signing.key`.

Both `install.sh` / `install.ps1` and `mcpgate update` verify the SHA256 **and** the ed25519
signature before touching the running binary. A release missing its `.sig`
files is treated as untrusted and refused. Unsigned release candidates remain
drafts and are not exposed as the latest release. Publication happens only after
every archive signature has been attached and cryptographically verified.

> **Windows native:** use `install.ps1` (PowerShell one-liner above) for a
> fully verified install. `install.sh` also works under Git Bash / MSYS /
> Cygwin. After install, `mcpgate service install` integrates with the
> Windows Service Control Manager (SCM) natively — no NSSM or WinSW needed.

---

## macOS note

macOS Gatekeeper may block the binary on first run because it is not signed with
an Apple Developer certificate. To remove the quarantine flag:

```bash
xattr -d com.apple.quarantine ~/.local/bin/mcpgate
```

---

## First run

```bash
# Start the server
# Your API key is printed once to stderr on first start — save it.
mcpgate serve

# Retrieve the key at any time
mcpgate key show

# Linux/macOS — install as a systemd user service (no root required)
mcpgate service install
mcpgate service enable
mcpgate service start

# Windows — install as a Windows Service (requires elevated/Administrator prompt)
mcpgate service install
mcpgate service start
```

On first start mcpgate creates `~/.mcpgate/` with:

| Path | Purpose |
|---|---|
| `~/.mcpgate/key` | Master API key (chmod 600) |
| `~/.mcpgate/config.json` | Global configuration |
| `~/.mcpgate/mcpgate.db` | SQLite database (tasks + audit log) |
| `~/.mcpgate/logs/mcpgate.log` | Structured log output |
| `~/.mcpgate/admin.sock` | Unix socket for the admin API |
| `~/.mcpgate/tmp/` | Oversized tool-output spill files (created on demand, auto-pruned) |

---

## Web dashboard

MCPGate ships a React + TypeScript management dashboard embedded in the binary.
Access it at **`/manage`** after starting the server.

```
http://127.0.0.1:8080/manage
```

Login with your master API key. The dashboard provides:

- **Overview** — server KPIs, health checks, session/admission state, and root-user warning
- **Named Servers** — manage, edit, validate, enable/disable, and gracefully drain named MCP servers
- **Sessions** — live session table with kill action and confirmation dialog
- **Audits** — real-time Active Executions live strip, server-side KPI statistics cards, and filterable invocation history with keyset pagination (page size selector, URL sync) and clear-all
- **Tasks** — kanban board with bulk-select, create/edit dialog, inline subtasks, dependency graph, priority, and progress
- **Memory** — workspace-scoped Claude-compatible memory catalog, search, validation diagnostics, body-on-selection editing, and revision-safe create/update/edit/move/delete flows
- **Settings** — key rotation, global reload, active workspace generation/validation diagnostics, rejected-reload remediation, update status, and connection state

The dashboard receives live updates via SSE from `/api/events` and supports dark/light theme.

By default the dashboard is loopback-only. To expose it behind a reverse proxy:

```bash
mcpgate serve --dashboard-public --dashboard-allow 10.0.0.0/8
```

---

## Self-update

```bash
# Check for and install the latest stable release
mcpgate update

# Preview what would be downloaded without installing
mcpgate update --dry-run

# Switch to the beta channel
mcpgate update --channel beta
```

The updater downloads the new binary, verifies its SHA256 checksum, verifies
the ed25519 `.sig` against the public key baked into the running binary, and
only then atomically replaces itself. A release without a `.sig` (or with a
signature that doesn't match) is refused — no installation, no rollback
required. No root access is required when installed under `~/.local/bin`.

---

## Connecting an MCP client

All endpoints require `Authorization: Bearer <key>` unless `--no-auth` is set.

Named MCP servers are addressed via `/mcp/{routeKey}`. Each route key resolves
server-side to one mode, one workspace, and a set of trusted upstreams — client
query parameters cannot override server topology. The bare `/mcp` endpoint
returns 404 `route_key_required`.

**Agent mode** (built-in tool suite, no subprocess):

```
POST /mcp/my-project
Authorization: Bearer <key>
```

Use `--stateless` when a client requires sessionless Streamable HTTP. Pending
confirmation continuations and stateless tool-rate buckets are process-local,
so multi-replica deployments need consistent routing when one logical flow or
aggregate quota must stay on one process.

**Bridge mode** — configured upstream MCP surface only:

```
POST /mcp/browser
Authorization: Bearer <key>
```

**Boost mode** — configured upstreams plus MCPGate built-in tools:

```
POST /mcp/my-project
Authorization: Bearer <key>
```

Define named servers in `~/.mcpgate/config.json` (`servers` array) or manage them
via the dashboard at `/manage/servers`.

> **Cross-server isolation:** A `Mcp-Session-Id` minted via `/mcp/server-a` cannot
> attach via `/mcp/server-b`. Each session is bound to its route key.
>
> **Legacy SSE:** Legacy `/sse` and `/messages` endpoints still accept `?mode=` +
> `?workspace=` for backward compatibility with older clients.
>
> **Confirmation** is an interaction safeguard, not an authorization boundary.
> MCPGate uses standard form elicitation only when the negotiated client
> advertises it; authentication, per-session ACLs, path/command restrictions,
> argument validation, and tool policy remain authoritative.

---

## Verifying a release manually

Two checks: SHA256 (catches bit-rot and casual tampering) and ed25519
signature (the actual trust anchor).

### 1. Checksum

All platform digests are in a single `checksums.txt` in `sha256sum` format:

```bash
VERSION=v1.0.0
PLATFORM=linux_amd64
ARCHIVE=mcpgate_${VERSION}_${PLATFORM}.tar.gz

curl -LO "https://github.com/FojleRabbiRabib/MCPGate-Releases/releases/download/${VERSION}/${ARCHIVE}"
curl -LO "https://github.com/FojleRabbiRabib/MCPGate-Releases/releases/download/${VERSION}/checksums.txt"
grep "${ARCHIVE}" checksums.txt | sha256sum --check        # Linux
grep "${ARCHIVE}" checksums.txt | shasum -a 256 --check    # macOS
```

### 2. Ed25519 signature

Save the maintainer's public key to a file (also reproduced in `install.sh`):

```bash
cat > signing.pub <<'EOF'
-----BEGIN PUBLIC KEY-----
MCowBQYDK2VwAyEATLE/mKPX5XUUhOh6XN6T0XOvn2zKGyte4YyMFEa9bHk=
-----END PUBLIC KEY-----
EOF
```

Then download the `.sig` and verify:

```bash
curl -LO "https://github.com/FojleRabbiRabib/MCPGate-Releases/releases/download/${VERSION}/${ARCHIVE}.sig"
openssl pkeyutl -verify -pubin -inkey signing.pub -rawin -in ${ARCHIVE} -sigfile ${ARCHIVE}.sig
# → "Signature Verified Successfully"
```

A successful verification means the archive came from the maintainer's
offline private key — not from anyone who happened to be able to write to
this GitHub release.

---

## Configuration

**Global config:** `~/.mcpgate/config.json`  
**Workspace override:** `.mcpgate/config.json` inside the workspace root.

Config cascade: **built-in defaults → global config → workspace config**.
Workspace overlays may extend explicit command/path permissions and tighten
supported limits, but cannot weaken inherited security policy.

Stateful sessions retain their validated workspace overlay while they are live.
MCPGate watches only those active workspace config targets: a valid edit advances
that workspace generation and updates matching reloadable Agent/Boost sessions;
an invalid edit keeps the previous last-known-good overlay. Global reloads first
rebase every retained active workspace against the proposed replacement and
reject the entire reload if any active overlay becomes incompatible. Sessions
that finish setup during a concurrent reload catch up before becoming visible.

Public `/health` exposes only aggregate active/reference/invalid workspace-config
counts. Authenticated dashboard/admin diagnostics expose per-workspace generation,
validation details, and the latest rejected global reload with remediation.

Run `mcpgate init` inside a workspace to create a starter config,
`mcpgate config validate` before publication, and `mcpgate config show` to inspect
the merged effective policy.

The annotated examples in this repository track the supported public schema,
including configured boost upstreams, admission controls, subprocess timeout and
memory policies, Claude-compatible memory limits, tool activation/rate limits,
and confirmation:

- [`config.global.example.json`](config.global.example.json) — copy to `~/.mcpgate/config.json`
- [`config.example.json`](config.example.json) — copy to `<workspace>/.mcpgate/config.json`

### Environment variables

| Variable | Description |
|---|---|
| `MCPGATE_API_KEY` | Override the key file — useful for automated deployments and containers |
| `MCPGATE_BIND` | Override `--bind` (e.g. `0.0.0.0:8080`) |
| `MCPGATE_CORS_ORIGIN` | Override `--cors-origin` |
| `MCPGATE_NO_AUTH` | `1`/`true`/`yes` — disable Bearer auth (dev only) |
| `MCPGATE_UNSAFE_PUBLIC_NOAUTH` | `1`/`true`/`yes` — explicit opt-in required to combine `MCPGATE_NO_AUTH` with a non-loopback bind |
| `MCPGATE_STATELESS` | `1`/`true`/`yes` — stateless Streamable HTTP mode |
| `MCPGATE_TRUSTED_PROXIES` | Comma-separated CIDRs whose `X-Forwarded-*` we honour |
| `MCPGATE_DASHBOARD_PUBLIC` | `1`/`true`/`yes` — widen the dashboard peer gate |
| `MCPGATE_DASHBOARD_ALLOW` | Comma-separated CIDRs admitted to `/manage*` |
| `MCPGATE_ALLOW_ROOT` | `1`/`true`/`yes` — bypass the interactive root-user confirmation prompt |
| `MCPGATE_UPDATE_CHANNEL` | `stable` or `beta` |
| `MCPGATE_SEARCH_PROVIDER` | `auto`, `brave`, `tavily`, or `ddg` — web_search backend (default: `auto`) |
| `MCPGATE_BRAVE_API_KEY` | Brave Search API key — enables Brave as web_search provider |
| `MCPGATE_TAVILY_API_KEY` | Tavily Search API key — enables Tavily as web_search provider |

---

## Release history

See [CHANGELOG.md](CHANGELOG.md) for the full version history with detailed
release notes. The [Releases](../../releases) page has per-release download
links and attached assets.

---

## Reporting a Security Issue

Security-sensitive findings **must not** be filed as public issues. Email the
maintainer directly via the address on the GitHub profile linked below, and
expect acknowledgement within 48 hours. See [SECURITY.md](SECURITY.md) for
severity-based response targets.

---

## Maintained by

**Fojle Rabbi** — [@FojleRabbiRabib](https://github.com/FojleRabbiRabib)

- **Bug reports, feature requests, install / usage questions** → [open an issue here](../../issues)
- **Security findings** → see *Reporting a Security Issue* above
- **General contact** → GitHub profile

---

## License

MCPGate is **proprietary software**. © 2026 Fojle Rabbi. All rights reserved.
See [LICENSE](LICENSE) for full terms.
