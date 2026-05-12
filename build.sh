#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

if ! command -v xcodegen >/dev/null 2>&1; then
  echo "❌ xcodegen not found. Install with: brew install xcodegen"
  exit 1
fi

echo "→ Generating ClaudeUsage.xcodeproj"
xcodegen generate --quiet

CONFIG="${1:-Debug}"
DERIVED="$(pwd)/build"
mkdir -p "$DERIVED"

echo "→ Building (-configuration $CONFIG, team 3ML6V62AF5, auto-provisioning)"
xcodebuild \
  -project ClaudeUsage.xcodeproj \
  -scheme ClaudeUsage \
  -configuration "$CONFIG" \
  -destination 'platform=macOS' \
  -derivedDataPath "$DERIVED" \
  -allowProvisioningUpdates \
  -allowProvisioningDeviceRegistration \
  -quiet build

APP="$DERIVED/Build/Products/$CONFIG/AI Usage.app"
if [ ! -d "$APP" ]; then
  echo "❌ Build did not produce $APP"
  exit 1
fi

echo "✅ Built: $APP"
echo
echo "Next:"
echo "  1) cp -R \"$APP\" /Applications/"
echo "  2) open \"/Applications/AI Usage.app\""
echo "  3) Right-click your desktop → Edit Widgets → search 'AI Usage' → drop it on the desktop."
