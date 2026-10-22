#!/bin/bash
set -euo pipefail

# Swip One-Line Installer
# Usage: curl -fsSL https://raw.githubusercontent.com/Woadlab/swip/main/install.sh | bash

REPO="Woadlab/swip"
APP_NAME="Swip.app"
DEST_DIR="/Applications"

echo "==> Installing Swip for macOS..."

# Verify macOS
if [[ "$(uname -s)" != "Darwin" ]]; then
    echo "Error: Swip requires macOS 14.0 (Sonoma) or later." >&2
    exit 1
fi

# Detect architecture
ARCH="$(uname -m)"
echo "    Architecture: $ARCH"

# Create temporary directory
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

ZIP_URL="https://github.com/${REPO}/releases/latest/download/Swip.zip"
ZIP_PATH="$TMP_DIR/Swip.zip"

echo "==> Downloading latest release from GitHub..."
if ! curl -fsSL --progress-bar "$ZIP_URL" -o "$ZIP_PATH"; then
    echo "Notice: Release archive not yet published on GitHub Releases."
    echo "Building from source with local Xcode toolchain..."
    TMP_SRC="$TMP_DIR/src"
    git clone --depth 1 "https://github.com/${REPO}.git" "$TMP_SRC"
    (cd "$TMP_SRC" && bash build.sh)
    cp -R "$TMP_SRC/dist/$APP_NAME" "$DEST_DIR/$APP_NAME"
else
    echo "==> Extracting $APP_NAME to $DEST_DIR..."
    rm -rf "$DEST_DIR/$APP_NAME"
    unzip -q "$ZIP_PATH" -d "$DEST_DIR"
fi

# Clear gatekeeper quarantine if needed
xattr -dr com.apple.quarantine "$DEST_DIR/$APP_NAME" 2>/dev/null || true

echo "==> Swip successfully installed to $DEST_DIR/$APP_NAME!"
echo "==> Launching Swip..."
open "$DEST_DIR/$APP_NAME"
