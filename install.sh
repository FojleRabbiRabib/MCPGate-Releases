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
# openssl is required because we verify the ed25519 release signature, not
# just the SHA256. Bundling the public key in this script means a compromise
# of the releases repo cannot ship a malicious binary that passes install.
if ! command -v openssl >/dev/null 2>&1; then
  echo "Error: openssl is required for release-signature verification." >&2
  echo "Install via 'apt install openssl' / 'brew install openssl' and retry." >&2
  exit 1
fi

# ── Embedded release-signing public key ───────────────────────────────────────
# This is the ed25519 public key the maintainer signs every release with. The
# matching private key never touches CI or any online system — see the
# Releases README "Verifying a release manually" section for details. The
# same key is baked into every release binary via -ldflags so `mcpgate update`
# applies the identical check.
SIGNING_PUBKEY_PEM='-----BEGIN PUBLIC KEY-----
MCowBQYDK2VwAyEAckyuOanVl+8ciri42lcN20kZd95xwAUZN88ualFjl4Q=
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
  linux|darwin)
    ARCHIVE_EXT="tar.gz"
    ;;
  mingw*|msys*|cygwin*)
    # Git Bash / MSYS2 / Cygwin on Windows. mcpgate ships .zip for Windows.
    OS="windows"
    ARCHIVE_EXT="zip"
    ;;
  *)
    echo "Error: unsupported OS: ${OS}" >&2
    echo "Linux, macOS, and Windows (Git Bash / MSYS / Cygwin) are supported." >&2
    echo "Native Windows without a POSIX shell: download the zip from the" >&2
    echo "Releases page directly and extract mcpgate.exe onto your PATH." >&2
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
# Per-asset SHA256 lives at <archive>.sha256 (GoReleaser split: true).
# Per-asset ed25519 signature lives at <archive>.sig (uploaded by
# `make sign-release` after the maintainer signs locally).
ARCHIVE_NAME="mcpgate_${VERSION}_${OS}_${ARCH}.${ARCHIVE_EXT}"
BASE_URL="https://github.com/${RELEASES_REPO}/releases/download/${VERSION}"
DOWNLOAD_URL="${BASE_URL}/${ARCHIVE_NAME}"
CHECKSUM_URL="${BASE_URL}/${ARCHIVE_NAME}.sha256"
SIGNATURE_URL="${BASE_URL}/${ARCHIVE_NAME}.sig"

# ── Temp workspace ─────────────────────────────────────────────────────────────
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

echo "Downloading ${ARCHIVE_NAME}…"
curl -fsSL --retry 3 --retry-delay 2 -o "${TMP_DIR}/${ARCHIVE_NAME}" "${DOWNLOAD_URL}"

# ── Checksum verification ──────────────────────────────────────────────────────
echo "Verifying SHA256…"
curl -fsSL --retry 3 --retry-delay 2 -o "${TMP_DIR}/${ARCHIVE_NAME}.sha256" "${CHECKSUM_URL}" \
  || { echo "Error: failed to download ${ARCHIVE_NAME}.sha256" >&2; exit 1; }

# GoReleaser writes "<hex>  <filename>" — take the first field.
EXPECTED_HASH="$(awk '{print $1}' "${TMP_DIR}/${ARCHIVE_NAME}.sha256" | head -n1)"
if [ -z "${EXPECTED_HASH}" ]; then
  echo "Error: ${ARCHIVE_NAME}.sha256 is empty or malformed." >&2
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
  echo "Unsigned releases are refused — the maintainer signs releases" >&2
  echo "locally after CI publishes the archives, so freshly-tagged releases" >&2
  echo "may not be installable for a few minutes. Try again, or pin to a" >&2
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
# GoReleaser archives nest the binary inside a directory named after the archive.
# Tar handles both flat and one-level-deep layouts with --strip-components=1;
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
  # Hunt the binary one level deep (GoReleaser layout) then at the root.
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
echo "✓ mcpgate ${VERSION} installed → ${INSTALL_DIR}/${BIN_NAME}"
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
