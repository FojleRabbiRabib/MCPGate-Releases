#!/usr/bin/env bash
# install.sh — quick installer for mcpgate
#
# Downloads the latest mcpgate release binary from the public releases
# repository and installs it to ~/.local/bin.
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/FojleRabbiRabib/MCPGate-Releases/main/install.sh | bash
#
# Or with a specific version:
#   VERSION=v1.2.3 bash install.sh
#
# To install to a custom directory:
#   INSTALL_DIR=/usr/local/bin bash install.sh  (requires appropriate permissions)
#
# Note for macOS users: if Gatekeeper blocks the binary run:
#   xattr -d com.apple.quarantine "${INSTALL_DIR}/mcpgate"

set -euo pipefail

RELEASES_REPO="FojleRabbiRabib/MCPGate-Releases"
INSTALL_DIR="${INSTALL_DIR:-${HOME}/.local/bin}"

# ── Dependency checks ──────────────────────────────────────────────────────────
if ! command -v curl >/dev/null 2>&1; then
  echo "Error: curl is required but was not found in PATH." >&2
  echo "Install curl (e.g. 'apt install curl' or 'brew install curl') and retry." >&2
  exit 1
fi

# ── OS / arch detection ────────────────────────────────────────────────────────
OS="$(uname -s | tr '[:upper:]' '[:lower:]')"
ARCH="$(uname -m)"
case "${ARCH}" in
  x86_64)  ARCH="amd64" ;;
  aarch64) ARCH="arm64" ;;
  arm64)   ARCH="arm64" ;;
  *)
    echo "Error: unsupported architecture: ${ARCH}" >&2
    exit 1
    ;;
esac

case "${OS}" in
  linux|darwin) ;;
  *)
    echo "Error: unsupported OS: ${OS}" >&2
    echo "On Windows use WSL or Git Bash, then re-run this script." >&2
    exit 1
    ;;
esac

# ── Version resolution ─────────────────────────────────────────────────────────
if [ -z "${VERSION:-}" ]; then
  echo "Fetching latest release version…"
  if command -v jq >/dev/null 2>&1; then
    VERSION="$(curl -fsSL "https://api.github.com/repos/${RELEASES_REPO}/releases/latest" \
      | jq -r '.tag_name')"
  else
    VERSION="$(curl -fsSL "https://api.github.com/repos/${RELEASES_REPO}/releases/latest" \
      | grep -oE '"tag_name"[[:space:]]*:[[:space:]]*"[^"]+"' \
      | grep -oE '"[^"]+"$' \
      | tr -d '"')"
  fi
fi

if [ -z "${VERSION:-}" ] || [ "${VERSION}" = "null" ]; then
  echo "Error: could not determine latest release version." >&2
  echo "Set VERSION=vX.Y.Z explicitly and retry." >&2
  exit 1
fi

echo "Installing mcpgate ${VERSION} for ${OS}/${ARCH}…"

# ── Download URLs ──────────────────────────────────────────────────────────────
# Archive name matches GoReleaser default: mcpgate_<version>_<os>_<arch>.tar.gz
# Checksum file: checksums.txt (one file listing all artefacts, GoReleaser default).
ARCHIVE_NAME="mcpgate_${VERSION}_${OS}_${ARCH}.tar.gz"
DOWNLOAD_URL="https://github.com/${RELEASES_REPO}/releases/download/${VERSION}/${ARCHIVE_NAME}"
CHECKSUMS_URL="https://github.com/${RELEASES_REPO}/releases/download/${VERSION}/checksums.txt"

# ── Temp workspace ─────────────────────────────────────────────────────────────
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

echo "Downloading ${ARCHIVE_NAME}…"
curl -fsSL --retry 3 --retry-delay 2 -o "${TMP_DIR}/${ARCHIVE_NAME}" "${DOWNLOAD_URL}"

# ── Checksum verification ──────────────────────────────────────────────────────
echo "Verifying checksum…"
curl -fsSL --retry 3 --retry-delay 2 -o "${TMP_DIR}/checksums.txt" "${CHECKSUMS_URL}"

# Extract the expected hash for our specific archive from the checksums file.
EXPECTED_HASH="$(grep "${ARCHIVE_NAME}" "${TMP_DIR}/checksums.txt" | awk '{print $1}')"

if [ -z "${EXPECTED_HASH}" ]; then
  echo "Error: ${ARCHIVE_NAME} not found in checksums.txt." >&2
  cat "${TMP_DIR}/checksums.txt" >&2
  exit 1
fi

if command -v sha256sum >/dev/null 2>&1; then
  ACTUAL_HASH="$(sha256sum "${TMP_DIR}/${ARCHIVE_NAME}" | awk '{print $1}')"
elif command -v shasum >/dev/null 2>&1; then
  ACTUAL_HASH="$(shasum -a 256 "${TMP_DIR}/${ARCHIVE_NAME}" | awk '{print $1}')"
else
  echo "Warning: sha256sum / shasum not found — skipping checksum verification." >&2
  ACTUAL_HASH="${EXPECTED_HASH}"
fi

if [ "${ACTUAL_HASH}" != "${EXPECTED_HASH}" ]; then
  echo "Error: SHA256 mismatch!" >&2
  echo "  expected: ${EXPECTED_HASH}" >&2
  echo "  actual:   ${ACTUAL_HASH}" >&2
  exit 1
fi
echo "✓ Checksum OK"

# ── Extract binary ─────────────────────────────────────────────────────────────
# GoReleaser tarballs nest the binary inside a directory named after the archive.
# --strip-components=1 handles both flat and one-level-deep layouts safely.
echo "Extracting binary…"
tar -xzf "${TMP_DIR}/${ARCHIVE_NAME}" -C "${TMP_DIR}" --strip-components=1 \
  --wildcards '*/mcpgate' 2>/dev/null \
  || tar -xzf "${TMP_DIR}/${ARCHIVE_NAME}" -C "${TMP_DIR}" mcpgate

if [ ! -f "${TMP_DIR}/mcpgate" ]; then
  echo "Error: mcpgate binary not found in archive after extraction." >&2
  echo "Archive contents:" >&2
  tar -tzf "${TMP_DIR}/${ARCHIVE_NAME}" >&2
  exit 1
fi

# ── Install ────────────────────────────────────────────────────────────────────
mkdir -p "${INSTALL_DIR}"
chmod +x "${TMP_DIR}/mcpgate"
mv "${TMP_DIR}/mcpgate" "${INSTALL_DIR}/mcpgate"

echo ""
echo "✓ mcpgate ${VERSION} installed → ${INSTALL_DIR}/mcpgate"
echo ""

# ── PATH check ─────────────────────────────────────────────────────────────────
if ! echo ":${PATH}:" | grep -q ":${INSTALL_DIR}:"; then
  echo "⚠  ${INSTALL_DIR} is not in your PATH."
  echo "   Add the following line to your shell profile (~/.bashrc, ~/.zshrc, etc.):"
  echo ""
  echo "     export PATH=\"\${HOME}/.local/bin:\${PATH}\""
  echo ""
  echo "   Then reload your shell:  source ~/.bashrc  (or open a new terminal)"
  echo ""
fi

# ── macOS Gatekeeper notice ────────────────────────────────────────────────────
if [ "${OS}" = "darwin" ]; then
  echo "ℹ  macOS users: if Gatekeeper blocks mcpgate, remove the quarantine flag:"
  echo ""
  echo "     xattr -d com.apple.quarantine \"${INSTALL_DIR}/mcpgate\""
  echo ""
fi

# ── Next steps ─────────────────────────────────────────────────────────────────
echo "Next steps:"
echo "  1. mcpgate service install"
echo "  2. mcpgate service enable"
echo "  3. mcpgate service start"
echo ""
echo "Run 'mcpgate --help' to get started."
