#!/usr/bin/env bash
set -euo pipefail

MODE="run"
case "${1:-}" in
  --debug|--logs|--telemetry|--verify)
    MODE="$1"
    shift
    ;;
esac

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="SwiftUIDemoApp"
BUNDLE_ID="jp.eure.SwiftUIDemoApp"
DERIVED_DATA="$ROOT_DIR/.build/mac-demo"
APP_BUNDLE="$DERIVED_DATA/Build/Products/Debug/$APP_NAME.app"
APP_BINARY="$APP_BUNDLE/Contents/MacOS/$APP_NAME"

pkill -x "$APP_NAME" >/dev/null 2>&1 || true

xcodebuild \
  -project "$ROOT_DIR/Development/Storybook.xcodeproj" \
  -scheme "$APP_NAME" \
  -configuration Debug \
  -destination "platform=macOS,arch=$(uname -m)" \
  -derivedDataPath "$DERIVED_DATA" \
  -quiet \
  CODE_SIGN_IDENTITY=- \
  build

if [ "$MODE" = "--debug" ]; then
  exec lldb -- "$APP_BINARY" "$@"
fi

/usr/bin/open -n "$APP_BUNDLE" --args "$@"

case "$MODE" in
  --logs)
    exec /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\""
    ;;
  --telemetry)
    exec /usr/bin/log stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\""
    ;;
  --verify)
    for attempt in {1..20}; do
      if pgrep -x "$APP_NAME" >/dev/null; then
        echo "$APP_NAME launched: $APP_BUNDLE"
        exit 0
      fi
      sleep 0.5
    done
    echo "$APP_NAME did not launch." >&2
    exit 1
    ;;
esac
