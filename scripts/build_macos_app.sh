#!/bin/bash
# Build Trinity.app for macOS
# Requires: zig 0.15.x, macOS 11+
# Usage: ./scripts/build_macos_app.sh [output_dir]
#
# Creates:
#   Trinity.app    — macOS application bundle (9.3 MB)
#   Trinity-v2.1.0.dmg — distributable disk image (3.1 MB)

set -e

VERSION="2.1.0"
BUILD_NUMBER="56"
OUTPUT_DIR="${1:-$HOME/Desktop}"
APP_DIR="$OUTPUT_DIR/Trinity.app"
CONTENTS="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$SCRIPT_DIR/.."

echo "Building Trinity.app v$VERSION..."

# Step 1: Build binaries
echo "  [1/4] Building Zig binaries..."
cd "$PROJECT_DIR"
zig build

# Step 2: Create bundle structure
echo "  [2/4] Creating app bundle..."
rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES"

# Copy binaries
cp zig-out/bin/fluent "$RESOURCES/fluent"
cp zig-out/bin/tri "$RESOURCES/tri"
cp zig-out/bin/vibee "$RESOURCES/vibee"
cp zig-out/bin/firebird "$RESOURCES/firebird"
chmod +x "$RESOURCES"/*

# Create launcher
cat > "$MACOS_DIR/Trinity" << 'LAUNCHER'
#!/bin/bash
DIR="$(cd "$(dirname "$0")" && pwd)"
RESOURCES="$DIR/../Resources"
BINARY="$RESOURCES/fluent"

osascript <<APPLESCRIPT
tell application "Terminal"
    activate
    set bannerCmd to "clear; printf '\\n'; printf '  ═══════════════════════════════════════════════════════════\\n'; printf '  ║  TRINITY AI v2.1.0 — Local Autonomous Multi-Modal Agent ║\\n'; printf '  ║  56 IMMORTAL Cycles  |  phi^2 + 1/phi^2 = 3            ║\\n'; printf '  ║  Chat + Code + Vision + Voice + Tools + Self-Reflection  ║\\n'; printf '  ═══════════════════════════════════════════════════════════\\n'; printf '\\n'; printf '  Binaries: fluent | tri | vibee | firebird\\n'; printf '  Run:  tri --help  for full command list\\n'; printf '\\n'"
    do script bannerCmd & "; export PATH=\"$RESOURCES:\$PATH\"; \"$BINARY\"" in front window
end tell
APPLESCRIPT
LAUNCHER
chmod +x "$MACOS_DIR/Trinity"

# Create Info.plist
cat > "$CONTENTS/Info.plist" << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>Trinity</string>
    <key>CFBundleIdentifier</key>
    <string>com.trinity.igla</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>Trinity</string>
    <key>CFBundleDisplayName</key>
    <string>Trinity AI</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string>
    <key>CFBundleVersion</key>
    <string>$BUILD_NUMBER</string>
    <key>LSMinimumSystemVersion</key>
    <string>11.0</string>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.developer-tools</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSHumanReadableCopyright</key>
    <string>Trinity v$VERSION — Unified Autonomous System. $BUILD_NUMBER IMMORTAL Cycles.</string>
</dict>
</plist>
PLIST

# Step 3: Create DMG
echo "  [3/4] Creating DMG..."
DMG_PATH="$OUTPUT_DIR/Trinity-v$VERSION.dmg"
rm -f "$DMG_PATH"
hdiutil create -volname "Trinity AI v$VERSION" -srcfolder "$APP_DIR" -ov -format UDZO "$DMG_PATH" 2>/dev/null

# Step 4: Verify
echo "  [4/4] Verifying..."
plutil -lint "$CONTENTS/Info.plist" > /dev/null
APP_SIZE=$(du -sh "$APP_DIR" | cut -f1)
DMG_SIZE=$(du -sh "$DMG_PATH" | cut -f1)

echo ""
echo "  Trinity.app created: $APP_DIR ($APP_SIZE)"
echo "  DMG created: $DMG_PATH ($DMG_SIZE)"
echo ""
echo "  Embedded binaries:"
ls -lh "$RESOURCES/" | awk 'NR>1 {printf "    %-12s %s\n", $NF, $5}'
echo ""
echo "  Done. Double-click Trinity.app or mount the DMG."
