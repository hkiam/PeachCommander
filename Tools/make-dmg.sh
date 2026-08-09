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
APPNAME="$(basename "$APP")"
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

echo "==> Verifying the bundle ships everything, universally…"
# Fails the release rather than shipping a host-only slice or a plugin that never got
# built. Both happened before; RELEASE.md documented the check as something to run by
# hand, which is why it never got run.
Tools/verify-shipping.sh "$APP"

echo "==> Staging…"
rm -rf "$STAGING" "$DMG"
mkdir -p "$STAGING"
cp -R "$APP" "$STAGING/"
ln -s /Applications "$STAGING/Applications"

# The window background (F-311). In a folder with a leading dot so it does not appear as a third icon
# beside the app and the symlink. A TIFF holding both the 600×400 and the 1200×800 rendering, so the
# picture is sharp on a Retina display and on an older one — a single PNG would be soft on one of them.
BACKGROUND="Design/dmg/background.tiff"
if [ -f "$BACKGROUND" ]; then
  mkdir -p "$STAGING/.background"
  cp "$BACKGROUND" "$STAGING/.background/background.tiff"
else
  # Not fatal, but not silent either: a release that quietly ships without the background would look
  # like the arrangement had failed, which is a different problem with a different fix.
  echo "    warning: $BACKGROUND is missing — the image will have no background picture" >&2
fi

echo "==> Creating disk image…"
# Read-write first, so the window can be arranged inside it, then compressed. Creating UDZO directly
# produces a working image whose window opens at whatever size the Finder last used — the app and the
# Applications symlink can land on top of each other, and the drag the whole layout exists to suggest
# is not visible at all.
RW="build/PeachCommander-rw.dmg"
rm -f "$RW"
hdiutil create \
  -volname "$VOLNAME" \
  -srcfolder "$STAGING" \
  -ov -format UDRW \
  "$RW" >/dev/null

# Arranging the window means talking to the Finder, and the Finder is not always there — a headless
# CI runner has no session to ask. So this is allowed to fail: a plain DMG is a working DMG, and a
# release must not fall over because the icons ended up in the default position.
echo "==> Arranging the window…"
# Only ask the Finder for a background when there is one to set: the line is interpolated into the
# script rather than guarded inside it, because an AppleScript that refers to a missing file fails as
# a whole and would take the icon positions down with it.
if [ -f "$STAGING/.background/background.tiff" ] || [ -f "$BACKGROUND" ]; then
  BACKGROUND_LINE='set background picture of theViewOptions to file ".background:background.tiff"'
else
  BACKGROUND_LINE=""
fi
MOUNT="$(hdiutil attach -readwrite -noverify -noautoopen "$RW" | grep -o '/Volumes/.*' | head -1 || true)"
if [ -n "$MOUNT" ]; then
  if osascript <<APPLESCRIPT >/dev/null 2>&1
    tell application "Finder"
      tell disk "$VOLNAME"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {200, 150, 800, 550}
        set theViewOptions to the icon view options of container window
        set arrangement of theViewOptions to not arranged
        set icon size of theViewOptions to 128
        $BACKGROUND_LINE
        set position of item "$APPNAME" of container window to {150, 200}
        set position of item "Applications" of container window to {450, 200}
        close
        open
        update without registering applications
        delay 1
      end tell
    end tell
APPLESCRIPT
  then
    echo "    window arranged"
  else
    echo "    note: the Finder could not arrange the window (headless session?) — packaging anyway"
  fi
  sync
  hdiutil detach "$MOUNT" >/dev/null || hdiutil detach "$MOUNT" -force >/dev/null || true
else
  echo "    note: could not mount the image to arrange it — packaging anyway"
fi

echo "==> Compressing…"
rm -f "$DMG"
hdiutil convert "$RW" -format UDZO -o "$DMG" >/dev/null
rm -f "$RW"
rm -rf "$STAGING"

# Did the arrangement actually survive into the finished image? Asked of the image rather than assumed
# from the AppleScript's exit status: the background is recorded in the volume's .DS_Store, and that
# file is only written when the Finder closes the window. Finder itself will not answer
# `background picture` on a read-only mount — it raises an AppleEvent error — so the .DS_Store is read
# directly, which is the record that matters anyway.
#
# A warning, not a failure: a disk image without its background still installs perfectly well, and a
# release must not fall over for the sake of a picture.
if [ -f "$BACKGROUND" ]; then
  CHECK_MOUNT="$(hdiutil attach -readonly -noverify -noautoopen "$DMG" | grep -o '/Volumes/.*' | head -1 || true)"
  if [ -n "$CHECK_MOUNT" ]; then
    if strings -a "$CHECK_MOUNT/.DS_Store" 2>/dev/null | grep -q "background.tiff"; then
      echo "    background recorded in the image"
    else
      echo "    warning: the image has no background picture — the Finder step did not take" >&2
    fi
    hdiutil detach "$CHECK_MOUNT" >/dev/null 2>&1 || hdiutil detach "$CHECK_MOUNT" -force >/dev/null 2>&1
  fi
fi

# The image itself is signed too, so Gatekeeper can evaluate the download before
# anything is copied out of it, and so notarytool has something to attach a ticket
# to. Again a no-op when no identity is configured.
if [ -n "${PC_CODESIGN_IDENTITY:-}" ]; then
  echo "==> Signing the disk image…"
  codesign --force --timestamp --sign "$PC_CODESIGN_IDENTITY" "$DMG"
fi

echo "==> Done: $DMG ($(du -h "$DMG" | cut -f1))"
