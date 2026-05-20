# MCPGate — Releases

This repository hosts compiled binaries and the installer for **MCPGate** — an
enterprise-grade MCP bridge and agent server written in Go.

> **Source code** lives at [`FojleRabbiRabib/MCPGate`](https://github.com/FojleRabbiRabib/MCPGate) (private).
> **Bug reports and feature requests** → open an issue there.

---

## Install

### One-liner (Linux and macOS)

```bash
curl -fsSL https://raw.githubusercontent.com/FojleRabbiRabib/MCPGate-Releases/main/install.sh | bash
```

The script automatically detects your OS and architecture, downloads the correct
binary, verifies the SHA256 checksum, installs to `~/.local/bin/mcpgate`, and
warns if that directory is not in your `PATH`.

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

curl -LO "https://github.com/FojleRabbiRabib/MCPGate-Releases/releases/download/${VERSION}/mcpgate_${VERSION}_${PLATFORM}.tar.gz"
curl -LO "https://github.com/FojleRabbiRabib/MCPGate-Releases/releases/download/${VERSION}/checksums.txt"

# Verify checksum
grep "mcpgate_${VERSION}_${PLATFORM}.tar.gz" checksums.txt | sha256sum --check

# Extract and install
tar -xzf "mcpgate_${VERSION}_${PLATFORM}.tar.gz" --strip-components=1 mcpgate
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

Each release includes a `checksums.txt` with SHA256 hashes for every archive.
The installer and `mcpgate update` both verify checksums before installation.

> **Windows** is not natively supported. Use [WSL](https://learn.microsoft.com/en-us/windows/wsl/)
> or Git Bash and run the installer from there.

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

## Self-update

```bash
# Check for and install the latest stable release
mcpgate update

# Preview what would be downloaded without installing
mcpgate update --dry-run

# Switch to the beta channel
mcpgate update --channel beta
```

The updater downloads the new binary, verifies its SHA256 checksum, and
atomically replaces the running binary. No root access is required when installed
under `~/.local/bin`.

---

## Connecting an MCP client

All endpoints require `Authorization: Bearer <key>` unless `--no-auth` is set.

**Bridge mode** — proxy a local stdio MCP process over HTTP:

```
GET /sse?command=npx&args=-y,@modelcontextprotocol/server-filesystem,/my/workspace
Authorization: Bearer mcpg_<key>
```

**Agent mode** — use mcpgate's built-in ~60 tool suite directly:

```
GET /agent?workspace=/my/workspace
Authorization: Bearer mcpg_<key>
```

Both modes support SSE (`/sse`, `/agent`) and Streamable HTTP (`/mcp`, `/mcp/agent`).

---

## Verifying a release manually

Every release ships a `checksums.txt` in standard GoReleaser format:

```
<sha256hex>  mcpgate_v1.0.0_linux_amd64.tar.gz
<sha256hex>  mcpgate_v1.0.0_linux_arm64.tar.gz
...
```

To verify your download:

```bash
# Linux
sha256sum --check --ignore-missing checksums.txt

# macOS
shasum -a 256 --check --ignore-missing checksums.txt
```

---

## Release history

See the [Releases](../../releases) page for the full changelog and per-release
download links.

---

## Maintained by

**Fojle Rabbi** — [@FojleRabbiRabib](https://github.com/FojleRabbiRabib)

For questions, bug reports, or feature requests open an issue in the
[source repository](https://github.com/FojleRabbiRabib/MCPGate).
