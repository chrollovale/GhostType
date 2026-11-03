#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Generate icon if missing
if [ ! -f "AppIcon.icns" ]; then
    echo "==> Generating AppIcon.icns..."
    swift generate_icon.swift icon_1024.png
    mkdir -p AppIcon.iconset
    sips -z 16 16     icon_1024.png --out AppIcon.iconset/icon_16x16.png
    sips -z 32 32     icon_1024.png --out AppIcon.iconset/icon_16x16@2x.png
    sips -z 32 32     icon_1024.png --out AppIcon.iconset/icon_32x32.png
    sips -z 64 64     icon_1024.png --out AppIcon.iconset/icon_32x32@2x.png
    sips -z 128 128   icon_1024.png --out AppIcon.iconset/icon_128x128.png
    sips -z 256 256   icon_1024.png --out AppIcon.iconset/icon_128x128@2x.png
    sips -z 256 256   icon_1024.png --out AppIcon.iconset/icon_256x256.png
    sips -z 512 512   icon_1024.png --out AppIcon.iconset/icon_256x256@2x.png
    sips -z 512 512   icon_1024.png --out AppIcon.iconset/icon_512x512.png
    sips -z 1024 1024 icon_1024.png --out AppIcon.iconset/icon_512x512@2x.png
    iconutil -c icns AppIcon.iconset -o AppIcon.icns
    rm -rf AppIcon.iconset
fi

echo "==> Building KeyInjector in release mode..."
swift build -c release

BIN_PATH="$(swift build -c release --show-bin-path)/KeyInjector"
APP_BUNDLE="KeyInjector.app"

echo "==> Creating $APP_BUNDLE..."
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

cp "$BIN_PATH" "$APP_BUNDLE/Contents/MacOS/KeyInjector"
chmod +x "$APP_BUNDLE/Contents/MacOS/KeyInjector"

if [ -f "AppIcon.icns" ]; then
    cp "AppIcon.icns" "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
fi

cat << 'EOF' > "$APP_BUNDLE/Contents/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>KeyInjector</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>com.antigravity.KeyInjector</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>KeyInjector</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
</dict>
</plist>
EOF

echo "==> KeyInjector.app created successfully at:"
echo "    $SCRIPT_DIR/$APP_BUNDLE"
