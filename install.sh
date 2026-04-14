#!/bin/sh
# Runwork CLI installer (macOS/Linux, POSIX sh)
# Usage: curl -fsSL https://runwork.ai/install.sh | sh
#
# Environment overrides:
#   RUNWORK_VERSION              Install a specific version (default: latest from manifest)
#   RUNWORK_INSTALL_DIR          Directory to install the binary (default: $HOME/.runwork/bin)
#   RUNWORK_BIN_LINK_DIR         Symlink directory on PATH (default: $HOME/.local/bin)
#   RUNWORK_DOWNLOAD_BASE_URL    Base URL to resolve manifest and artifacts (default: https://runwork.ai)

set -e

BASE_URL="${RUNWORK_DOWNLOAD_BASE_URL:-https://runwork.ai}"
BINARY_NAME="runwork"

info() {
    printf '%s\n' "$1"
}
err() {
    printf 'Error: %s\n' "$1" >&2
}

require_cmd() {
    if ! command -v "$1" >/dev/null 2>&1; then
        err "required command '$1' is not available"
        err "$2"
        exit 1
    fi
}

require_cmd curl "Install curl and re-run this script."
require_cmd tar "Install tar and re-run this script."
require_cmd mkdir "Install coreutils (mkdir) and re-run this script."
require_cmd mv "Install coreutils (mv) and re-run this script."
require_cmd chmod "Install coreutils (chmod) and re-run this script."

if command -v sha256sum >/dev/null 2>&1; then
    sha256_cmd="sha256sum"
elif command -v shasum >/dev/null 2>&1; then
    sha256_cmd="shasum -a 256"
else
    err "neither sha256sum nor shasum is available"
    err "Install coreutils (Linux) or ensure shasum is on PATH (macOS)."
    exit 1
fi

# OS detection
UNAME_OS="$(uname -s)"
case "$UNAME_OS" in
    Darwin)  os="darwin" ;;
    Linux)   os="linux" ;;
    *)
        err "unsupported operating system: $UNAME_OS"
        err "Runwork CLI supports macOS and Linux via this installer."
        err "For Windows, run in PowerShell:"
        err "  irm ${BASE_URL}/install.ps1 | iex"
        exit 1
        ;;
esac

# Architecture detection
UNAME_ARCH="$(uname -m)"
case "$UNAME_ARCH" in
    x86_64|amd64)  arch="x64" ;;
    arm64|aarch64) arch="arm64" ;;
    *)
        err "unsupported architecture: $UNAME_ARCH"
        err "Supported: x86_64/amd64, arm64/aarch64."
        exit 1
        ;;
esac

PLATFORM="${os}-${arch}"

# Temp workspace
TMP_DIR="$(mktemp -d)"
# Cleanup on exit
trap 'rm -rf "$TMP_DIR"' EXIT

MANIFEST_PATH="${TMP_DIR}/latest.json"

info "Fetching Runwork CLI release manifest from ${BASE_URL}/cli/latest.json..."
if ! curl -fsSL "${BASE_URL}/cli/latest.json" -o "$MANIFEST_PATH"; then
    err "failed to fetch release manifest from ${BASE_URL}/cli/latest.json"
    err "Check your network and that ${BASE_URL} is reachable."
    exit 1
fi

# Parse a single scalar "key": "value" line from the per-platform block.
# The manifest is pretty-printed JSON, one field per line inside each platform object.
extract_field() {
    sed -n "/\"${PLATFORM}\"[[:space:]]*:[[:space:]]*{/,/}/p" "$MANIFEST_PATH" \
        | sed -n "s/.*\"$1\"[[:space:]]*:[[:space:]]*\"\([^\"]*\)\".*/\1/p" \
        | head -1
}

ARTIFACT_PATH="$(extract_field path)"
ARTIFACT_SHA="$(extract_field sha256)"

if [ -z "$ARTIFACT_PATH" ] || [ -z "$ARTIFACT_SHA" ]; then
    err "no artifact entry for platform '${PLATFORM}' in ${BASE_URL}/cli/latest.json"
    err "The platform may not be published yet."
    exit 1
fi

# Version resolution. Default: manifest version. Override: RUNWORK_VERSION.
MANIFEST_VERSION="$(sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$MANIFEST_PATH" | head -1)"
if [ -z "$MANIFEST_VERSION" ]; then
    err "could not parse version from release manifest"
    exit 1
fi

if [ -n "$RUNWORK_VERSION" ] && [ "$RUNWORK_VERSION" != "$MANIFEST_VERSION" ]; then
    VERSION="$RUNWORK_VERSION"
    ARTIFACT_FILE="$(basename "$ARTIFACT_PATH")"
    ARTIFACT_PATH="/cli/releases/${VERSION}/${ARTIFACT_FILE}"

    CHECKSUMS_PATH="${TMP_DIR}/checksums.txt"
    info "Fetching checksums for pinned version ${VERSION}..."
    if ! curl -fsSL "${BASE_URL}/cli/checksums/${VERSION}.txt" -o "$CHECKSUMS_PATH"; then
        err "failed to fetch ${BASE_URL}/cli/checksums/${VERSION}.txt"
        err "Version ${VERSION} may not exist."
        exit 1
    fi
    ARTIFACT_SHA="$(awk -v f="$ARTIFACT_FILE" '$2 == f {print $1}' "$CHECKSUMS_PATH" | head -1)"
    if [ -z "$ARTIFACT_SHA" ]; then
        err "no checksum for ${ARTIFACT_FILE} in ${BASE_URL}/cli/checksums/${VERSION}.txt"
        exit 1
    fi
else
    VERSION="$MANIFEST_VERSION"
fi

DOWNLOAD_URL="${BASE_URL}${ARTIFACT_PATH}"

info "Installing Runwork CLI ${VERSION} (${PLATFORM})..."
info "  Downloading ${DOWNLOAD_URL}"

ARCHIVE_NAME="$(basename "$ARTIFACT_PATH")"
ARCHIVE_PATH="${TMP_DIR}/${ARCHIVE_NAME}"

if ! curl -fsSL "$DOWNLOAD_URL" -o "$ARCHIVE_PATH"; then
    err "failed to download ${DOWNLOAD_URL}"
    exit 1
fi

info "  Verifying sha256..."
ACTUAL_SHA="$($sha256_cmd "$ARCHIVE_PATH" | awk '{print $1}')"
if [ "$ACTUAL_SHA" != "$ARTIFACT_SHA" ]; then
    err "sha256 mismatch for ${ARCHIVE_NAME}"
    err "  expected: $ARTIFACT_SHA"
    err "  actual:   $ACTUAL_SHA"
    err "The download may be corrupted or tampered with. Re-run or file an issue."
    exit 1
fi

info "  Extracting..."
tar -xzf "$ARCHIVE_PATH" -C "$TMP_DIR"

# The tarball contains a single binary named after the platform (e.g. runwork-darwin-arm64).
BINARY_SRC=""
for candidate in "${TMP_DIR}/runwork-${PLATFORM}" "${TMP_DIR}/${BINARY_NAME}"; do
    if [ -f "$candidate" ]; then
        BINARY_SRC="$candidate"
        break
    fi
done
if [ -z "$BINARY_SRC" ]; then
    err "could not locate the runwork binary inside ${ARCHIVE_NAME}"
    exit 1
fi

INSTALL_DIR="${RUNWORK_INSTALL_DIR:-$HOME/.runwork/bin}"
mkdir -p "$INSTALL_DIR"
if [ ! -w "$INSTALL_DIR" ]; then
    err "install directory is not writable: ${INSTALL_DIR}"
    err "Set RUNWORK_INSTALL_DIR to a directory you can write to."
    exit 1
fi

BINARY_DST="${INSTALL_DIR}/${BINARY_NAME}"
info "  Installing to ${BINARY_DST}"
mv -f "$BINARY_SRC" "$BINARY_DST"
chmod +x "$BINARY_DST"

# Symlink into a writable user bin directory on PATH.
BIN_LINK_DIR="${RUNWORK_BIN_LINK_DIR:-$HOME/.local/bin}"
mkdir -p "$BIN_LINK_DIR" 2>/dev/null || true

link_created=0
if [ -d "$BIN_LINK_DIR" ] && [ -w "$BIN_LINK_DIR" ] && [ "$BIN_LINK_DIR" != "$INSTALL_DIR" ]; then
    BIN_LINK="${BIN_LINK_DIR}/${BINARY_NAME}"
    rm -f "$BIN_LINK"
    if ln -s "$BINARY_DST" "$BIN_LINK" 2>/dev/null; then
        link_created=1
    fi
fi

info ""
info "Runwork CLI ${VERSION} installed to ${BINARY_DST}"

path_has() {
    case ":${PATH}:" in
        *":$1:"*) return 0 ;;
        *) return 1 ;;
    esac
}

if [ "$link_created" = "1" ] && path_has "$BIN_LINK_DIR"; then
    info ""
    info "Get started:"
    info "  runwork login"
    info "  runwork init"
elif [ "$link_created" = "1" ]; then
    info ""
    info "Symlinked at ${BIN_LINK}. Add its directory to PATH:"
    info ""
    info "  export PATH=\"${BIN_LINK_DIR}:\$PATH\""
    info ""
    info "Then run:"
    info "  runwork login"
    info "  runwork init"
elif path_has "$INSTALL_DIR"; then
    info ""
    info "Get started:"
    info "  runwork login"
    info "  runwork init"
else
    info ""
    info "Could not create a symlink in a writable bin directory on PATH."
    info "Add the install directory to PATH:"
    info ""
    info "  export PATH=\"${INSTALL_DIR}:\$PATH\""
    info ""
    info "Then run:"
    info "  runwork login"
    info "  runwork init"
fi
