#!/bin/zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SDK_DIR="/Library/Developer/CommandLineTools/SDKs"
SDK_PATH="$SDK_DIR/MacOSX.sdk"

if [[ -d "$SDK_DIR/MacOSX15.4.sdk" ]]; then
  SDK_PATH="$SDK_DIR/MacOSX15.4.sdk"
elif [[ -d "$SDK_DIR/MacOSX15.sdk" ]]; then
  SDK_PATH="$SDK_DIR/MacOSX15.sdk"
fi

export CLANG_MODULE_CACHE_PATH="$ROOT_DIR/.build/clang-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$ROOT_DIR/.build/swiftpm-module-cache"
export SDKROOT="$SDK_PATH"

APP_NAME="XeeLite"
APP_DIR="$ROOT_DIR/dist/$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
ICONSET_DIR="$ROOT_DIR/.build/$APP_NAME.iconset"
ICON_PATH="$RESOURCES_DIR/$APP_NAME.icns"
PROJECT_ICON_SOURCE="$ROOT_DIR/Resources/icon.png"

cd "$ROOT_DIR"
swift build -c release

rm -rf "$APP_DIR"
rm -rf "$ICONSET_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR" "$ICONSET_DIR"

cp "$ROOT_DIR/.build/release/$APP_NAME" "$MACOS_DIR/$APP_NAME"
chmod +x "$MACOS_DIR/$APP_NAME"

if [[ -f "$PROJECT_ICON_SOURCE" ]]; then
  sizes=(16 32 128 256 512)

  for size in "${sizes[@]}"; do
    sips -z "$size" "$size" "$PROJECT_ICON_SOURCE" --out "$ICONSET_DIR/icon_${size}x${size}.png" >/dev/null
    retina_size=$((size * 2))
    sips -z "$retina_size" "$retina_size" "$PROJECT_ICON_SOURCE" --out "$ICONSET_DIR/icon_${size}x${size}@2x.png" >/dev/null
  done

  iconutil -c icns "$ICONSET_DIR" -o "$ICON_PATH"
fi

cat > "$CONTENTS_DIR/Info.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>XeeLite</string>
    <key>CFBundleIconFile</key>
    <string>XeeLite.icns</string>
    <key>CFBundleIdentifier</key>
    <string>com.codex.xeelite</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>XeeLite</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
EOF

echo "Created $APP_DIR"
