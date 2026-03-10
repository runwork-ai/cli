#!/bin/sh
# Runwork CLI installer
# Usage: curl -fsSL https://runwork.ai/install.sh | sh

set -e

REPO="runwork-ai/cli"
BINARY_NAME="runwork"

# Detect OS
OS="$(uname -s)"
case "$OS" in
  Darwin) os="darwin" ;;
  Linux)  os="linux" ;;
  *)
    echo "Error: Unsupported operating system: $OS"
    echo "Runwork CLI supports macOS and Linux. For Windows, download from GitHub Releases."
    exit 1
    ;;
esac

# Detect architecture
ARCH="$(uname -m)"
case "$ARCH" in
  x86_64|amd64)  arch="x64" ;;
  arm64|aarch64)  arch="arm64" ;;
  *)
    echo "Error: Unsupported architecture: $ARCH"
    exit 1
    ;;
esac

TARGET="${BINARY_NAME}-${os}-${arch}"
ARCHIVE="${TARGET}.tar.gz"

# Get latest version
echo "Fetching latest Runwork CLI version..."
VERSION=$(curl -fsSL "https://api.github.com/repos/${REPO}/releases/latest" | grep '"tag_name"' | sed -E 's/.*"([^"]+)".*/\1/')

if [ -z "$VERSION" ]; then
  echo "Error: Could not determine latest version."
  exit 1
fi

echo "Installing Runwork CLI ${VERSION} (${os}/${arch})..."

DOWNLOAD_URL="https://github.com/${REPO}/releases/download/${VERSION}/${ARCHIVE}"

# Create temp directory
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

# Download
curl -fsSL "$DOWNLOAD_URL" -o "${TMP_DIR}/${ARCHIVE}"

# Extract
tar -xzf "${TMP_DIR}/${ARCHIVE}" -C "$TMP_DIR"

# Determine install directory
INSTALL_DIR="/usr/local/bin"
if [ ! -w "$INSTALL_DIR" ]; then
  INSTALL_DIR="${HOME}/.local/bin"
  mkdir -p "$INSTALL_DIR"
fi

# Install
mv "${TMP_DIR}/${TARGET}" "${INSTALL_DIR}/${BINARY_NAME}"
chmod +x "${INSTALL_DIR}/${BINARY_NAME}"

# Verify
if command -v "$BINARY_NAME" > /dev/null 2>&1; then
  echo ""
  echo "Runwork CLI ${VERSION} installed to ${INSTALL_DIR}/${BINARY_NAME}"
  echo ""
  echo "Get started:"
  echo "  runwork login"
  echo "  runwork init"
else
  echo ""
  echo "Runwork CLI ${VERSION} installed to ${INSTALL_DIR}/${BINARY_NAME}"
  echo ""
  if [ "$INSTALL_DIR" = "${HOME}/.local/bin" ]; then
    echo "Add ~/.local/bin to your PATH:"
    echo "  export PATH=\"\$HOME/.local/bin:\$PATH\""
    echo ""
  fi
  echo "Then run:"
  echo "  runwork login"
  echo "  runwork init"
fi
