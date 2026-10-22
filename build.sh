#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")"
app="$PWD/dist/Swip.app"
module_cache="$PWD/.build/module-cache"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources" "$PWD/.build" "$module_cache"

MIN_MACOS="14.0"
arch="$(uname -m)"
binary="$PWD/.build/Swip-$arch"

echo "==> Compiling Swip for $arch (macOS $MIN_MACOS+)..."
find Sources -name '*.swift' -print0 | xargs -0 xcrun swiftc \
  -swift-version 5 -O -parse-as-library \
  -target "$arch-apple-macosx$MIN_MACOS" \
  -module-cache-path "$module_cache" \
  -o "$binary"

cp "$binary" "$app/Contents/MacOS/Swip"
chmod +x "$app/Contents/MacOS/Swip"

echo "==> Generating Info.plist..."
cat > "$app/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>Swip</string>
    <key>CFBundleIdentifier</key>
    <string>org.woadlab.swip</string>
    <key>CFBundleName</key>
    <string>Swip</string>
    <key>CFBundleDisplayName</key>
    <string>Swip</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.2</string>
    <key>CFBundleVersion</key>
    <string>3</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
PLIST

echo "==> Generating AppIcon..."
xcrun swiftc Sources/UI/BrandArtwork.swift scripts/make-icon.swift -o .build/make-icon
.build/make-icon "$PWD/.build/AppIcon.iconset"
iconutil -c icns "$PWD/.build/AppIcon.iconset" -o "$app/Contents/Resources/AppIcon.icns"

echo "==> Code signing Swip.app..."
codesign --force --sign - "$app"
codesign --verify --deep --strict "$app"

echo "==> Packaging Swip.dmg and Swip.zip..."
dmg_staging="$PWD/.build/dmg"
rm -rf "$dmg_staging"
mkdir -p "$dmg_staging"
cp -R "$app" "$dmg_staging/"
ln -s /Applications "$dmg_staging/Applications"
rm -f "$PWD/dist/Swip.dmg" "$PWD/dist/Swip.zip"
hdiutil create -volname "Swip" -srcfolder "$dmg_staging" -ov -format UDZO "$PWD/dist/Swip.dmg" >/dev/null
(cd "$PWD/dist" && zip -q -r -y Swip.zip Swip.app)

echo "==> Successfully built and packaged Swip.app, Swip.dmg, and Swip.zip in dist/"
