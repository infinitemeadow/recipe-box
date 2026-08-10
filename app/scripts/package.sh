#!/bin/bash
# Builds Recipe Box into a double-clickable RecipeBox.app bundle.
# Usage: ./scripts/package.sh   (run from the app/ directory)
set -euo pipefail

APP_NAME="RecipeBox"
BUNDLE_ID="com.recipebox.app"
VERSION="0.1.0"
MIN_OS="14.0"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "› Building release binary…"
swift build -c release

BIN="$(swift build -c release --show-bin-path)/$APP_NAME"
DIST="$ROOT/dist"
APP="$DIST/$APP_NAME.app"

echo "› Assembling $APP_NAME.app…"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/$APP_NAME"

# App icon — generate on first run, then embed.
if [ ! -f "$ROOT/Resources/AppIcon.icns" ]; then
    echo "› Generating app icon…"
    "$ROOT/scripts/make-icon.sh"
fi
cp "$ROOT/Resources/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>            <string>$APP_NAME</string>
    <key>CFBundleDisplayName</key>     <string>Recipe Box</string>
    <key>CFBundleExecutable</key>      <string>$APP_NAME</string>
    <key>CFBundleIconFile</key>        <string>AppIcon</string>
    <key>CFBundleIdentifier</key>      <string>$BUNDLE_ID</string>
    <key>CFBundlePackageType</key>     <string>APPL</string>
    <key>CFBundleShortVersionString</key> <string>$VERSION</string>
    <key>CFBundleVersion</key>         <string>$VERSION</string>
    <key>CFBundleInfoDictionaryVersion</key> <string>6.0</string>
    <key>LSMinimumSystemVersion</key>  <string>$MIN_OS</string>
    <key>NSPrincipalClass</key>        <string>NSApplication</string>
    <key>NSHighResolutionCapable</key> <true/>
    <key>LSApplicationCategoryType</key> <string>public.app-category.lifestyle</string>
</dict>
</plist>
PLIST

echo "› Ad-hoc code-signing…"
codesign --force --sign - "$APP" >/dev/null 2>&1 || echo "  (codesign skipped)"

echo "✓ Built: $APP"
echo "  Open with: open \"$APP\"   — or drag it into /Applications"
