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

# Fall back to ~/Applications when /Applications is not writable
if [[ ! -w "$DEST_DIR" ]]; then
    DEST_DIR="$HOME/Applications"
    mkdir -p "$DEST_DIR"
fi
echo "    Destination:  $DEST_DIR"

# Create temporary directory
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

ZIP_URL="https://github.com/${REPO}/releases/latest/download/Swip.zip"
ZIP_PATH="$TMP_DIR/Swip.zip"
NEW_APP=""

echo "==> Downloading latest release from GitHub..."
if curl -fsSL --progress-bar "$ZIP_URL" -o "$ZIP_PATH"; then
    unzip -q "$ZIP_PATH" -d "$TMP_DIR/unpacked"
    NEW_APP="$TMP_DIR/unpacked/$APP_NAME"
else
    echo "Notice: Release archive not available on GitHub Releases."
    echo "Building from source with local Xcode toolchain..."
    TMP_SRC="$TMP_DIR/src"
    git clone --depth 1 "https://github.com/${REPO}.git" "$TMP_SRC"
    (cd "$TMP_SRC" && bash build.sh)
    NEW_APP="$TMP_SRC/dist/$APP_NAME"
fi

# Quit a running copy so the old version doesn't keep running after the update
if pgrep -x Swip >/dev/null 2>&1; then
    echo "==> Quitting running Swip..."
    osascript -e 'tell application id "org.woadlab.swip" to quit' >/dev/null 2>&1 || true
    for _ in 1 2 3 4 5 6 7 8 9 10; do
        pgrep -x Swip >/dev/null 2>&1 || break
        sleep 0.5
    done
    pkill -x Swip 2>/dev/null || true
fi

echo "==> Installing $APP_NAME to $DEST_DIR..."
rm -rf "${DEST_DIR:?}/$APP_NAME"
ditto "$NEW_APP" "$DEST_DIR/$APP_NAME"

# Clear gatekeeper quarantine if needed
xattr -dr com.apple.quarantine "$DEST_DIR/$APP_NAME" 2>/dev/null || true

VERSION="$(defaults read "$DEST_DIR/$APP_NAME/Contents/Info.plist" CFBundleShortVersionString 2>/dev/null || echo "?")"
echo "==> Swip $VERSION successfully installed to $DEST_DIR/$APP_NAME!"
echo "==> Launching Swip..."
open "$DEST_DIR/$APP_NAME"
