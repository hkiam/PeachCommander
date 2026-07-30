#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
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

echo "==> Regenerating the Xcode project…"
# A release must never be packaged from a project file that has drifted from
# project.yml — the build settings live there, and a stale .pbxproj silently
# ignores them (that is how the first universal build still linked the
# host-architecture keg).
xcodegen generate

echo "==> Preparing universal libssh2 + openssl…"
# The app target is configured for arm64 + x86_64 (project.yml), but PCNet links
# libssh2 and a Homebrew keg only holds the host architecture — so the x86_64 slice
# cannot link against it. This stages 2-slice copies under build/universal-deps and
# PC_SSH2_PREFIX below points the build at them instead of the keg.
Tools/make-universal-deps.sh
SSH2_PREFIX="$PWD/build/universal-deps"

echo "==> Building ${CONFIG} (universal: arm64 + x86_64)..."
# No ARCHS/ONLY_ACTIVE_ARCH override here on purpose: overriding them is what used
# to reduce the shipped DMG to a single slice while the docs advertised universal.
xcodebuild -project PeachCommander.xcodeproj \
  -scheme PeachCommander \
  -configuration "$CONFIG" \
  -derivedDataPath "$DERIVED" \
  -destination "platform=macOS" \
  PC_SSH2_PREFIX="$SSH2_PREFIX" \
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
# Homebrew on the target machine (F-214). Takes the universal copies the build
# just linked against — the Homebrew kegs would put a single-architecture dylib
# into a universal app and break SFTP on the other architecture.
PC_SSH2_PREFIX="$SSH2_PREFIX" Tools/bundle-libssh2.sh "$APP"

# Sign here, not after the image exists: whatever is copied into the DMG below is
# what users run, so the app has to be signed first. No-op without
# PC_CODESIGN_IDENTITY, which keeps the unsigned build path unchanged.
Tools/codesign-app.sh "$APP"

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

# The image itself is signed too, so Gatekeeper can evaluate the download before
# anything is copied out of it, and so notarytool has something to attach a ticket
# to. Again a no-op when no identity is configured.
if [ -n "${PC_CODESIGN_IDENTITY:-}" ]; then
  echo "==> Signing the disk image…"
  codesign --force --timestamp --sign "$PC_CODESIGN_IDENTITY" "$DMG"
fi

echo "==> Done: $DMG ($(du -h "$DMG" | cut -f1))"
