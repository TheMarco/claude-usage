#!/usr/bin/env bash
#
# Builds a Release-signed .dmg ready to give to a friend.
#
#   ./release.sh                   → signed .dmg (Gatekeeper warns once on first open)
#   ./release.sh --notarize        → signed + notarized + stapled .dmg (no warning)
#
# First-time notarization setup (once per machine):
#   1) Generate an app-specific password at appleid.apple.com
#      → Sign In & Security → App-Specific Passwords → +
#   2) xcrun notarytool store-credentials ai-usage \
#        --apple-id you@example.com --team-id 3ML6V62AF5 --password <APP_SPECIFIC_PW>

set -euo pipefail
cd "$(dirname "$0")"

NAME="AI Usage"
VERSION="${VERSION:-1.0}"
DMG="AI-Usage-${VERSION}.dmg"
SIGNING_ID="Developer ID Application: Marco van Hylckama Vlieg (3ML6V62AF5)"
NOTARY_PROFILE="${NOTARY_PROFILE:-ai-usage}"

NOTARIZE=0
for arg in "$@"; do
  case "$arg" in
    --notarize) NOTARIZE=1 ;;
    *) echo "Unknown flag: $arg"; exit 2 ;;
  esac
done

command -v xcodegen >/dev/null 2>&1 || {
  echo "❌ xcodegen required: brew install xcodegen"; exit 1; }

security find-identity -v -p codesigning | grep -q "$SIGNING_ID" || {
  echo "❌ Signing identity not in keychain: $SIGNING_ID"
  echo "   Available identities:"
  security find-identity -v -p codesigning
  exit 1; }

echo "→ Generating Xcode project"
xcodegen generate --quiet

echo "→ Cleaning"
rm -rf ./build "$DMG"

echo "→ Building Release with Developer ID + Hardened Runtime"
xcodebuild \
  -project ClaudeUsage.xcodeproj \
  -scheme ClaudeUsage \
  -configuration Release \
  -derivedDataPath ./build \
  CODE_SIGN_STYLE=Manual \
  CODE_SIGN_IDENTITY="$SIGNING_ID" \
  CODE_SIGN_ENTITLEMENTS="" \
  PROVISIONING_PROFILE_SPECIFIER="" \
  ENABLE_HARDENED_RUNTIME=YES \
  OTHER_CODE_SIGN_FLAGS="--timestamp --options=runtime" \
  MARKETING_VERSION="$VERSION" \
  -quiet build

APP="./build/Build/Products/Release/${NAME}.app"
[ -d "$APP" ] || { echo "❌ Build failed; no $APP"; exit 1; }

echo "→ Re-signing widget + app with Developer ID + entitlements"
codesign --force --options runtime --timestamp \
  --sign "$SIGNING_ID" \
  --entitlements Sources/Widget/Widget.entitlements \
  "$APP/Contents/PlugIns/ClaudeUsageWidget.appex"

codesign --force --options runtime --timestamp \
  --sign "$SIGNING_ID" \
  --entitlements Sources/App/App.entitlements \
  "$APP"

echo "→ Verifying signature"
codesign --verify --deep --strict --verbose=2 "$APP" 2>&1 | tail -5
spctl --assess --type execute --verbose "$APP" 2>&1 | tail -3 || true

echo "→ Packaging DMG"
TMP="$(mktemp -d)"
cp -R "$APP" "$TMP/"
ln -s /Applications "$TMP/Applications"
hdiutil create -volname "AI Usage" -srcfolder "$TMP" -ov -format UDZO "$DMG" >/dev/null
rm -rf "$TMP"

if [ "$NOTARIZE" = "1" ]; then
  echo "→ Notarizing via Apple (keychain profile: $NOTARY_PROFILE) — this takes ~1–3 min"
  xcrun notarytool submit "$DMG" \
    --keychain-profile "$NOTARY_PROFILE" \
    --wait

  echo "→ Stapling notarization ticket"
  xcrun stapler staple "$DMG"
  xcrun stapler validate "$DMG"
  echo
  echo "✅ Notarized and ready: $(pwd)/$DMG"
  echo "   Friend: double-click .dmg → drag 'AI Usage' to Applications → done."
else
  echo
  echo "✅ Signed (not notarized): $(pwd)/$DMG"
  echo "   Friend will see a one-time Gatekeeper warning. To open:"
  echo "     1. Drag 'AI Usage' from the .dmg to /Applications"
  echo "     2. Right-click 'AI Usage' in Applications → Open → Open"
  echo
  echo "   Re-run with --notarize to get a warning-free build."
fi
