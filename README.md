# MCPGate — Releases

[![Latest Release](https://img.shields.io/github/v/release/FojleRabbiRabib/MCPGate-Releases?label=latest)](../../releases)
[![Downloads](https://img.shields.io/github/downloads/FojleRabbiRabib/MCPGate-Releases/total?label=downloads)](../../releases)
[![Downloads (latest)](https://img.shields.io/github/downloads/FojleRabbiRabib/MCPGate-Releases/latest/total?label=downloads%20%28latest%29)](../../releases)
[![License](https://img.shields.io/badge/license-proprietary-red)](LICENSE)
[![Stars](https://img.shields.io/github/stars/FojleRabbiRabib/MCPGate-Releases?style=flat)](../../stargazers)

This repository hosts compiled binaries and the installer for **MCPGate** — an
enterprise-grade MCP bridge and agent server written in Go.

> **Source code** is in a private repository.
> **All public interactions — bug reports, feature requests, install issues,
> usage questions — happen in [this repo's Issues tab](../../issues).**
> Please do not email the maintainer directly for non-security matters; opening
> an issue keeps the conversation visible to other users and the changelog.
> Security-sensitive findings are the one exception — see *Reporting a Security Issue* below.

---

## Install

### One-liner (Linux and macOS)

```bash
curl -fsSL https://raw.githubusercontent.com/FojleRabbiRabib/MCPGate-Releases/main/install.sh | bash
```

The script automatically detects your OS and architecture, downloads the correct
binary, verifies the **SHA256 checksum AND the offline ed25519 signature**
against the maintainer's public key embedded in the script, installs to
`~/.local/bin/mcpgate`, and warns if that directory is not in your `PATH`.

> The signing public key is reproduced inside `install.sh` and matches the
> key baked into every release binary. The private half never touches CI or
> any online system — a compromise of this releases repository cannot mint
> binaries the installer or the `mcpgate update` command will trust.

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
curl -LO "${BASE}/${ARCHIVE}.sha256"
curl -LO "${BASE}/${ARCHIVE}.sig"

# Verify checksum
sha256sum --check ${ARCHIVE}.sha256

# Verify ed25519 signature (see "Verifying a release manually" for signing.pub)
openssl pkeyutl -verify -pubin -inkey signing.pub -rawin -in ${ARCHIVE} -sigfile ${ARCHIVE}.sig

# Extract and install
tar -xzf "${ARCHIVE}" --strip-components=1 mcpgate
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
| Windows | x86_64 (amd64) | `mcpgate_<version>_windows_amd64.zip` |
| Windows | arm64 | `mcpgate_<version>_windows_arm64.zip` |

Each release ships:

- `<archive>` — the binary tarball / zip itself.
- `<archive>.sha256` — per-asset SHA256 checksum (GoReleaser `split: true`).
- `<archive>.sig` — ed25519 signature over the archive bytes, produced
  offline by the maintainer with `openssl pkeyutl -sign -inkey signing.key`.
- `<archive>.sbom.spdx.json` — SPDX-JSON Software Bill of Materials.

Both `install.sh` and `mcpgate update` verify the SHA256 **and** the ed25519
signature before touching the running binary. A release missing its `.sig`
files is treated as untrusted and refused — the maintainer signs releases
locally after CI publishes the archives, so freshly-tagged releases may
appear on this page for a few minutes before becoming installable.

> **Windows native:** the installer auto-detects Git Bash / MSYS / Cygwin
> environments and fetches the `.zip` archive. Native installs without a
> POSIX shell aren't supported by `install.sh`; download the zip from the
> Releases page directly, extract `mcpgate.exe`, and place it on `PATH`.
> systemd-style service install (`mcpgate service install`) is Linux-only;
> Windows operators can wrap the binary with NSSM or WinSW.

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

# Install as a user systemd service (Linux, no root required)
mcpgate service install
mcpgate service enable
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

---

## Web dashboard

MCPGate ships a React + TypeScript management dashboard embedded in the binary.
Access it at **`/manage`** after starting the server.

```
http://127.0.0.1:8080/manage
```

Login with your master API key. The dashboard provides:

- **Overview** — server KPIs (active sessions / cap, health checks, root-user warning)
- **Sessions** — live session table with kill action and confirm dialog
- **Audits** — filterable tool invocation log with search, date range, severity, and clear-all
- **Tasks** — kanban board with bulk-select, create/edit dialog, inline subtask checklist (drag-to-reorder, per-subtask status), inter-task dependency graph (blocked-by picker, done-block guard), priority and progress
- **Settings** — key rotation, update-available banner, connection status

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

Endpoints are unified: `/sse` (legacy SSE 2024-11-05) and `/mcp` (Streamable
HTTP 2025-11-25) both accept a `?mode=` query parameter (default `agent`).

**Agent mode** (built-in tool suite, no subprocess):

```
GET  /sse?workspace=/my/workspace
POST /mcp?workspace=/my/workspace
Authorization: Bearer <key>
```

**Bridge mode** (proxy a local stdio MCP process):

```
GET  /sse?mode=bridge&command=npx&args=-y%20@modelcontextprotocol/server-filesystem%20.&workspace=/my/workspace
POST /mcp?mode=bridge&command=php&args=artisan%20boost:mcp&workspace=/my/project
Authorization: Bearer <key>
```

**Boost mode** (stdio MCP process + built-in agent tools merged):

```
POST /mcp?mode=boost&command=php&args=artisan%20boost:mcp&workspace=/my/project
Authorization: Bearer <key>
```

> **`args`** is whitespace-separated (URL-encode spaces as `%20`).
> **`workspace`** is the project root and **doubles as the subprocess working
> directory** in bridge/boost modes — there is no separate `cwd` parameter.
> Bridge/boost subprocess communication uses newline-delimited JSON per the
> MCP stdio transport spec, so every spec-compliant MCP server works out of
> the box (`@modelcontextprotocol/server-*`, Laravel Boost, Python `mcp`-SDK
> servers, custom Go/Rust servers).

---

## Verifying a release manually

Two checks: SHA256 (catches bit-rot and casual tampering) and ed25519
signature (the actual trust anchor).

### 1. Checksum

Per-asset `.sha256` files ship alongside each archive (GoReleaser
`split: true`):

```bash
VERSION=v1.0.0
PLATFORM=linux_amd64
ARCHIVE=mcpgate_${VERSION}_${PLATFORM}.tar.gz

curl -LO "https://github.com/FojleRabbiRabib/MCPGate-Releases/releases/download/${VERSION}/${ARCHIVE}"
curl -LO "https://github.com/FojleRabbiRabib/MCPGate-Releases/releases/download/${VERSION}/${ARCHIVE}.sha256"
sha256sum --check ${ARCHIVE}.sha256        # Linux
shasum -a 256 --check ${ARCHIVE}.sha256    # macOS
```

### 2. Ed25519 signature

Save the maintainer's public key to a file (also reproduced in `install.sh`):

```bash
cat > signing.pub <<'EOF'
-----BEGIN PUBLIC KEY-----
MCowBQYDK2VwAyEAckyuOanVl+8ciri42lcN20kZd95xwAUZN88ualFjl4Q=
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

## Release history

See the [Releases](../../releases) page for the full changelog and per-release
download links.

---

## Reporting a Security Issue

Security-sensitive findings **must not** be filed as public issues. Email the
maintainer directly via the address on the GitHub profile linked below, and
expect acknowledgement within 48 hours. See the project's internal SECURITY
policy for severity-based response targets.

---

## Maintained by

**Fojle Rabbi** — [@FojleRabbiRabib](https://github.com/FojleRabbiRabib)

- **Bug reports, feature requests, install / usage questions** → [open an issue here](../../issues)
- **Security findings** → see *Reporting a Security Issue* above
- **General contact** → GitHub profile

The source repository is private; please do not attempt to open issues or
pull requests there.

---

## License

MCPGate is **proprietary software**. © 2026 Fojle Rabbi. All rights reserved.
See [LICENSE](LICENSE) for full terms.
