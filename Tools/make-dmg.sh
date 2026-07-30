#!/usr/bin/env bash
# make-dmg.sh - Build a distributable DMG of Peach Commander.
#
# Builds the app in the given configuration (default: Release), stages it next
# to an /Applications symlink, and packages a compressed (UDZO) disk image at
# build/PeachCommander.dmg.
#
# NOTE: the produced app is NOT code-signed or notarized (the project builds
# with CODE_SIGNING_ALLOWED=NO). For real distribution the app must be signed
# with a Developer ID certificate and notarized before this DMG is created —
# see docs/iterations/I20 and RELEASE.md. This script covers the packaging
# step so the rest can be layered on once signing credentials are available.
set -euo pipefail

cd "$(dirname "$0")/.."

CONFIG="${1:-Release}"
DERIVED="build/dmg-derived"
STAGING="build/dmg-staging"
DMG="build/PeachCommander.dmg"
VOLNAME="Peach Commander"

echo "==> Regenerating third-party notices…"
# Refresh Resources/ThirdPartyNotices.json + Licenses/ so the shipped app always
# carries current open-source attributions (versions from Package.resolved).
python3 Tools/generate-third-party-notices.py

echo "==> Building ${CONFIG}..."
xcodebuild -project PeachCommander.xcodeproj \
  -scheme PeachCommander \
  -configuration "$CONFIG" \
  -derivedDataPath "$DERIVED" \
  -destination "platform=macOS,arch=$(uname -m)" \
  ARCHS="$(uname -m)" ONLY_ACTIVE_ARCH=YES \
  CODE_SIGNING_ALLOWED=NO \
  build >/dev/null

APP="$DERIVED/Build/Products/$CONFIG/PeachCommander.app"
if [ ! -d "$APP" ]; then
  echo "error: built app not found at $APP" >&2
  exit 1
fi

echo "==> Bundling plugins into the app…"
# Ship every plugin inside Contents/PlugIns so a DMG install has them all present
# and (enabled by default) active. They are signed as part of the --deep pass in
# the release flow (see RELEASE.md) since they live inside the app bundle.
# The AI plugin links PCAutomation.framework — point it at THIS build's framework
# (the one shipped in the app), not the default Debug DerivedData, so it binds to
# the exact copy it runs against.
PC_FRAMEWORKS_DIR="$PWD/$DERIVED/Build/Products/$CONFIG" \
  Tools/build-all-plugins.sh "$APP/Contents/PlugIns"

echo "==> Embedding libssh2 (SFTP) into Frameworks…"
# Bundle libssh2 + openssl@3 with @rpath install names so SFTP works without
# Homebrew on the target machine (F-214).
Tools/bundle-libssh2.sh "$APP"

echo "==> Staging…"
rm -rf "$STAGING" "$DMG"
mkdir -p "$STAGING"
cp -R "$APP" "$STAGING/"
ln -s /Applications "$STAGING/Applications"

echo "==> Creating disk image…"
hdiutil create \
  -volname "$VOLNAME" \
  -srcfolder "$STAGING" \
  -ov -format UDZO \
  "$DMG" >/dev/null

rm -rf "$STAGING"
echo "==> Done: $DMG ($(du -h "$DMG" | cut -f1))"
