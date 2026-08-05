#!/usr/bin/env bash
# install.sh — quick installer for MCPGate
#
# Downloads the latest MCPGate release binary from the public releases
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
# Skip the root-user confirmation prompt:
#   bash install.sh -y
#   bash install.sh --yes
#
# Note for macOS users: if Gatekeeper blocks the binary run:
#   xattr -d com.apple.quarantine "${INSTALL_DIR}/mcpgate"

set -euo pipefail

RELEASES_REPO="FojleRabbiRabib/MCPGate-Releases"
INSTALL_DIR="${INSTALL_DIR:-${HOME}/.local/bin}"
SKIP_CONFIRM=0

# ── Flag parsing ───────────────────────────────────────────────────────────────
for arg in "$@"; do
  case "${arg}" in
    -y|--yes) SKIP_CONFIRM=1 ;;
    *) echo "Unknown option: ${arg}" >&2; echo "Usage: bash install.sh [-y|--yes]" >&2; exit 1 ;;
  esac
done

# ── Dependency checks ──────────────────────────────────────────────────────────
if ! command -v curl >/dev/null 2>&1; then
  echo "Error: curl is required but was not found in PATH." >&2
  echo "Install curl (e.g. 'apt install curl' or 'brew install curl') and retry." >&2
  exit 1
fi
# openssl is required because we verify the ed25519 release signature, not
# just the SHA256. Bundling the public key in this script means a compromise
# of the releases repo cannot ship a malicious binary that passes install.
if ! command -v openssl >/dev/null 2>&1; then
  echo "Error: openssl is required for release-signature verification." >&2
  echo "Install via 'apt install openssl' / 'brew install openssl' and retry." >&2
  exit 1
fi

# ── Embedded release-signing public key ───────────────────────────────────────
# This is the ed25519 public key used to verify release signatures. The
# corresponding private key is kept offline. The same public key is embedded in
# every release binary so `mcpgate update` applies the identical check.
SIGNING_PUBKEY_PEM='-----BEGIN PUBLIC KEY-----
MCowBQYDK2VwAyEATLE/mKPX5XUUhOh6XN6T0XOvn2zKGyte4YyMFEa9bHk=
-----END PUBLIC KEY-----'

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
  linux|darwin|freebsd)
    ARCHIVE_EXT="tar.gz"
    ;;
  mingw*|msys*|cygwin*)
    # Git Bash / MSYS2 / Cygwin on Windows. mcpgate ships .zip for Windows.
    OS="windows"
    ARCHIVE_EXT="zip"
    ;;
  *)
    echo "Error: unsupported OS: ${OS}" >&2
    echo "Linux, macOS, FreeBSD, and Windows (Git Bash / MSYS / Cygwin) are supported." >&2
    echo "Native Windows without a POSIX shell: download the zip from the" >&2
    echo "Releases page directly and extract mcpgate.exe onto your PATH." >&2
    exit 1
    ;;
esac

# ── Root user guard ────────────────────────────────────────────────────────────
if [ "$(id -u)" -eq 0 ] && [ "${SKIP_CONFIRM}" -eq 0 ]; then
  echo ""
  echo "WARNING: Running installer as root."
  echo "   This will install MCPGate with elevated privileges."
  echo "   The default install location (~/.local/bin) does not require root."
  echo ""
  printf "Continue anyway? [y/N] "
  read -r confirm
  if [ "${confirm}" != "y" ] && [ "${confirm}" != "Y" ]; then
    echo "Aborting."
    exit 1
  fi
fi

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

echo "Installing MCPGate ${VERSION} for ${OS}/${ARCH}…"

# ── Download URLs ──────────────────────────────────────────────────────────────
# Release assets use mcpgate_<version>_<os>_<arch>.<ext> names.
# checksums.txt contains all SHA256 digests; each archive has a matching .sig.
ARCHIVE_NAME="mcpgate_${VERSION}_${OS}_${ARCH}.${ARCHIVE_EXT}"
BASE_URL="https://github.com/${RELEASES_REPO}/releases/download/${VERSION}"
DOWNLOAD_URL="${BASE_URL}/${ARCHIVE_NAME}"
CHECKSUM_URL="${BASE_URL}/checksums.txt"
SIGNATURE_URL="${BASE_URL}/${ARCHIVE_NAME}.sig"

# ── Temp workspace ─────────────────────────────────────────────────────────────
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

echo "Downloading ${ARCHIVE_NAME}…"
curl -fsSL --retry 3 --retry-delay 2 -o "${TMP_DIR}/${ARCHIVE_NAME}" "${DOWNLOAD_URL}"

# ── Checksum verification ──────────────────────────────────────────────────────
echo "Verifying SHA256…"
curl -fsSL --retry 3 --retry-delay 2 -o "${TMP_DIR}/checksums.txt" "${CHECKSUM_URL}" \
  || { echo "Error: failed to download checksums.txt" >&2; exit 1; }

# checksums.txt is in sha256sum format: "<hex>  <filename>" (one line per archive).
# Strip a leading '*' that some tools emit before the filename, then find our archive.
EXPECTED_HASH="$(grep -E "(^| )\\*?${ARCHIVE_NAME}( |\$)" "${TMP_DIR}/checksums.txt" \
  | awk '{print $1}' | head -n1)"
if [ -z "${EXPECTED_HASH}" ]; then
  echo "Error: checksums.txt has no entry for ${ARCHIVE_NAME}." >&2
  echo "Contents of checksums.txt:" >&2
  cat "${TMP_DIR}/checksums.txt" >&2
  exit 1
fi

if command -v sha256sum >/dev/null 2>&1; then
  ACTUAL_HASH="$(sha256sum "${TMP_DIR}/${ARCHIVE_NAME}" | awk '{print $1}')"
elif command -v shasum >/dev/null 2>&1; then
  ACTUAL_HASH="$(shasum -a 256 "${TMP_DIR}/${ARCHIVE_NAME}" | awk '{print $1}')"
else
  # openssl is mandatory above so this branch is always reachable.
  ACTUAL_HASH="$(openssl dgst -sha256 "${TMP_DIR}/${ARCHIVE_NAME}" | awk '{print $NF}')"
fi

if [ "${ACTUAL_HASH}" != "${EXPECTED_HASH}" ]; then
  echo "Error: SHA256 mismatch!" >&2
  echo "  expected: ${EXPECTED_HASH}" >&2
  echo "  actual:   ${ACTUAL_HASH}" >&2
  exit 1
fi
echo "✓ SHA256 OK"

# ── Ed25519 signature verification ─────────────────────────────────────────────
# The .sha256 alone is insufficient: it lives in the same GitHub release and
# would be replaced atomically with the archive in a release-repo compromise.
# The .sig is produced offline; verifying it here binds the binary to the
# maintainer rather than to whoever could push to the releases repo today.
echo "Verifying ed25519 signature…"
if ! curl -fsSL --retry 3 --retry-delay 2 -o "${TMP_DIR}/${ARCHIVE_NAME}.sig" "${SIGNATURE_URL}"; then
  echo "Error: release ${VERSION} is missing ${ARCHIVE_NAME}.sig." >&2
  echo "Unsigned releases are refused. A newly published release may not" >&2
  echo "have its offline signature yet. Try again later, or pin to a" >&2
  echo "previous VERSION." >&2
  exit 1
fi

printf '%s\n' "${SIGNING_PUBKEY_PEM}" > "${TMP_DIR}/signing.pub"
if ! openssl pkeyutl -verify -pubin -inkey "${TMP_DIR}/signing.pub" \
    -rawin -in "${TMP_DIR}/${ARCHIVE_NAME}" \
    -sigfile "${TMP_DIR}/${ARCHIVE_NAME}.sig" >/dev/null 2>&1; then
  echo "Error: ed25519 signature did NOT verify against the maintainer's key." >&2
  echo "This is a hard refusal — the downloaded archive is not trusted." >&2
  exit 1
fi
echo "✓ Signature OK"

# ── Extract binary ─────────────────────────────────────────────────────────────
# Archives may place the binary at the root or one directory deep.
# Tar handles both layouts with --strip-components=1;
# zip we unpack and then locate the binary.
echo "Extracting binary…"
BIN_NAME="mcpgate"
if [ "${OS}" = "windows" ]; then
  BIN_NAME="mcpgate.exe"
fi

if [ "${ARCHIVE_EXT}" = "zip" ]; then
  command -v unzip >/dev/null 2>&1 || { \
    echo "Error: 'unzip' not found — install it and retry." >&2; exit 1; \
  }
  unzip -qq "${TMP_DIR}/${ARCHIVE_NAME}" -d "${TMP_DIR}/unpack"
  # Locate the binary at the archive root or one directory deep.
  FOUND="$(find "${TMP_DIR}/unpack" -maxdepth 2 -type f -name "${BIN_NAME}" -print -quit)"
  if [ -z "${FOUND}" ]; then
    echo "Error: ${BIN_NAME} not found inside ${ARCHIVE_NAME}." >&2
    find "${TMP_DIR}/unpack" -maxdepth 2 -type f >&2
    exit 1
  fi
  mv "${FOUND}" "${TMP_DIR}/${BIN_NAME}"
else
  tar -xzf "${TMP_DIR}/${ARCHIVE_NAME}" -C "${TMP_DIR}" --strip-components=1 \
    --wildcards "*/${BIN_NAME}" 2>/dev/null \
    || tar -xzf "${TMP_DIR}/${ARCHIVE_NAME}" -C "${TMP_DIR}" "${BIN_NAME}"
fi

if [ ! -f "${TMP_DIR}/${BIN_NAME}" ]; then
  echo "Error: ${BIN_NAME} binary not found in archive after extraction." >&2
  exit 1
fi

# ── Install ────────────────────────────────────────────────────────────────────
mkdir -p "${INSTALL_DIR}"
chmod +x "${TMP_DIR}/${BIN_NAME}" 2>/dev/null || true
mv "${TMP_DIR}/${BIN_NAME}" "${INSTALL_DIR}/${BIN_NAME}"

echo ""
echo "✓ MCPGate ${VERSION} installed → ${INSTALL_DIR}/${BIN_NAME}"
echo ""

# ── PATH check ─────────────────────────────────────────────────────────────────
# Two-step check: grep for the install dir in $PATH, then confirm with
# `command -v` to avoid false-positives on Git Bash where the same directory
# may appear in PATH as either MSYS2-style (/c/Users/…) or Windows-style
# (C:\Users\…) depending on how PATH was set.
PATH_OK=0
if echo ":${PATH}:" | grep -q ":${INSTALL_DIR}:"; then
  PATH_OK=1
fi
if [ "${PATH_OK}" -eq 0 ] && command -v mcpgate >/dev/null 2>&1; then
  PATH_OK=1
fi

if [ "${PATH_OK}" -eq 0 ]; then
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
  echo "ℹ  macOS users: if Gatekeeper blocks the mcpgate binary, remove the quarantine flag:"
  echo ""
  echo "     xattr -d com.apple.quarantine \"${INSTALL_DIR}/mcpgate\""
  echo ""
fi

# ── Next steps ─────────────────────────────────────────────────────────────────
echo "Next steps:"
if [ "${OS}" = "windows" ]; then
  echo "  Register mcpgate as a Windows Service (requires an Administrator prompt):"
  echo "    mcpgate service install   # auto-start on boot, restart on failure"
  echo "    mcpgate service start     # start it now"
else
  echo "  1. mcpgate service install"
  if [ "${OS}" = "freebsd" ]; then
    echo "  2. mcpgate service enable"
    echo "  3. mcpgate service start"
    echo ""
    echo "  (Or start manually: mcpgate serve)"
  else
    echo "  2. mcpgate service enable"
    echo "  3. mcpgate service start"
  fi
fi
echo ""
echo "Run 'mcpgate --help' to get started."
