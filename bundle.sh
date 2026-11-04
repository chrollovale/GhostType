#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

APP_VERSION="1.3.0"
OUTPUT_DIR="${1:-$SCRIPT_DIR}"
if [[ "$OUTPUT_DIR" != /* ]]; then
    OUTPUT_DIR="$SCRIPT_DIR/$OUTPUT_DIR"
fi
mkdir -p "$OUTPUT_DIR"

echo "==> Packaging GhostType icon..."
rm -rf AppIcon.iconset
mkdir -p AppIcon.iconset
sips -z 16 16     icon_1024.png --out AppIcon.iconset/icon_16x16.png >/dev/null
sips -z 32 32     icon_1024.png --out AppIcon.iconset/icon_16x16@2x.png >/dev/null
sips -z 32 32     icon_1024.png --out AppIcon.iconset/icon_32x32.png >/dev/null
sips -z 64 64     icon_1024.png --out AppIcon.iconset/icon_32x32@2x.png >/dev/null
sips -z 128 128   icon_1024.png --out AppIcon.iconset/icon_128x128.png >/dev/null
sips -z 256 256   icon_1024.png --out AppIcon.iconset/icon_128x128@2x.png >/dev/null
sips -z 256 256   icon_1024.png --out AppIcon.iconset/icon_256x256.png >/dev/null
sips -z 512 512   icon_1024.png --out AppIcon.iconset/icon_256x256@2x.png >/dev/null
sips -z 512 512   icon_1024.png --out AppIcon.iconset/icon_512x512.png >/dev/null
sips -z 1024 1024 icon_1024.png --out AppIcon.iconset/icon_512x512@2x.png >/dev/null
iconutil -c icns AppIcon.iconset -o AppIcon.icns
rm -rf AppIcon.iconset

echo "==> Building GhostType v$APP_VERSION in release mode..."
swift build -c release --product GhostType
BIN_PATH="$(swift build -c release --show-bin-path)/GhostType"
APP_BUNDLE="$OUTPUT_DIR/GhostType.app"
RESOURCE_BUNDLE="$(swift build -c release --show-bin-path)/GhostType_GhostType.bundle"

echo "==> Creating $APP_BUNDLE..."
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS" "$APP_BUNDLE/Contents/Resources"
cp "$BIN_PATH" "$APP_BUNDLE/Contents/MacOS/GhostType"
chmod +x "$APP_BUNDLE/Contents/MacOS/GhostType"
cp AppIcon.icns "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
cp -R "$RESOURCE_BUNDLE" "$APP_BUNDLE/Contents/Resources/"

cat <<EOF > "$APP_BUNDLE/Contents/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>GhostType</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>com.chrollovale.GhostType</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>GhostType</string>
    <key>CFBundleDisplayName</key>
    <string>GhostType</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>$APP_VERSION</string>
    <key>CFBundleVersion</key>
    <string>$APP_VERSION</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
</dict>
</plist>
EOF

codesign --force --deep --sign - "$APP_BUNDLE"
echo "==> GhostType.app created successfully at:"
echo "    $APP_BUNDLE"
