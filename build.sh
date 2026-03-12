#!/bin/bash
set -e
APP_NAME="VolPerApp"
BUILD_DIR="$(pwd)/build"
CONTENTS_DIR="$BUILD_DIR/$APP_NAME.app/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
ICONSET_DIR="$(pwd)/iconset"

echo "Building $APP_NAME..."
rm -rf "$BUILD_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

if [ ! -d "$ICONSET_DIR" ]; then ./generate_icon.sh; fi

TMPSET=$(mktemp -d)
cp -r "$ICONSET_DIR" "$TMPSET/AppIcon.iconset"
iconutil -c icns -o "$RESOURCES_DIR/AppIcon.icns" "$TMPSET/AppIcon.iconset"
rm -rf "$TMPSET"

swiftc main.swift -parse-as-library -o "$MACOS_DIR/$APP_NAME" -suppress-warnings \
    -framework CoreAudio -framework AudioToolbox
chmod +x "$MACOS_DIR/$APP_NAME"

cat > "$CONTENTS_DIR/Info.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>VolPerApp</string>
    <key>CFBundleIdentifier</key>
    <string>com.bogdantudorache.VolPerApp</string>
    <key>CFBundleName</key>
    <string>VolPerApp</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>LSUIElement</key>
    <true/>
</dict>
</plist>
EOF

echo "Build complete!"
if pgrep -x "$APP_NAME" > /dev/null; then pkill -x "$APP_NAME"; sleep 0.5; fi
rm -rf "/Applications/$APP_NAME.app"
cp -r "$BUILD_DIR/$APP_NAME.app" "/Applications/"
echo "Launching $APP_NAME..."
open "/Applications/$APP_NAME.app"
