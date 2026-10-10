#!/usr/bin/env bash
set -euo pipefail

# Build the native SwiftPM GUI host and stage its bundle before Launch Services
# opens it. Remaining arguments are forwarded unchanged to Storybook's parser.
MODE="${1:-run}"
case "$MODE" in
  run|--build-only|--debug|--logs|--telemetry|--verify)
    if [[ $# -gt 0 ]]; then shift; fi
    ;;
  --storybook|--storybook-name=*)
    MODE="run"
    ;;
  *)
    echo "usage: $0 [run|--build-only|--debug|--logs|--telemetry|--verify] [Storybook arguments]" >&2
    exit 2
    ;;
esac

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PACKAGE_DIR="$ROOT_DIR/Development/MacDemo"
APP_NAME="StorybookMacDemo"
BUNDLE_ID="com.eure.StorybookMacDemo"
APP_BUNDLE="$ROOT_DIR/dist/$APP_NAME.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_BINARY="$APP_CONTENTS/MacOS/$APP_NAME"

if [[ "$MODE" != "--build-only" ]]; then
  pkill -x "$APP_NAME" >/dev/null 2>&1 || true
fi

swift build --package-path "$PACKAGE_DIR" --product "$APP_NAME"
BUILD_DIR="$(swift build --package-path "$PACKAGE_DIR" --show-bin-path)"

# Stage from an empty bundle so old executables or resources cannot survive a
# rebuild. This path is owned only by this repository's demonstration host.
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_CONTENTS/MacOS"
cp "$BUILD_DIR/$APP_NAME" "$APP_BINARY"
chmod +x "$APP_BINARY"

cat >"$APP_CONTENTS/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>$APP_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleName</key>
  <string>$APP_NAME</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>1.0</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>LSMinimumSystemVersion</key>
  <string>14.0</string>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
  <key>NSHighResolutionCapable</key>
  <true/>
</dict>
</plist>
PLIST

open_app() {
  if [[ $# -gt 0 ]]; then
    /usr/bin/open -n "$APP_BUNDLE" --args "$@"
  else
    /usr/bin/open -n "$APP_BUNDLE"
  fi
}

case "$MODE" in
  --build-only)
    echo "$APP_BUNDLE"
    ;;
  run)
    open_app "$@"
    ;;
  --debug)
    open_app "$@"
    lldb -n "$APP_NAME"
    ;;
  --logs)
    open_app "$@"
    /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\""
    ;;
  --telemetry)
    open_app "$@"
    /usr/bin/log stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\""
    ;;
  --verify)
    open_app "$@"
    sleep 1
    pgrep -x "$APP_NAME" >/dev/null
    echo "Running: $APP_BUNDLE"
    ;;
esac
