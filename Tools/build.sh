#!/bin/bash
# SPDX-License-Identifier: Apache-2.0
# build.sh - Build PeachCommander

set -e

echo "=== Peach Commander Build ==="

cd "$(dirname "$0")/.."

# Always regenerate: project.yml is the source of truth and the .pbxproj is not
# tracked, so a stale one silently ignores build-setting changes. (This used to be
# guarded by `[ ! -f PeachCommander.xcodeproj ]`, which is a directory — the test
# was always true, so it regenerated anyway while claiming "Project not found".)
echo "Generating Xcode project from project.yml..."
xcodegen generate

# Build Debug configuration
echo "Building Debug configuration..."
xcodebuild \
    -project PeachCommander.xcodeproj \
    -scheme PeachCommander \
    -configuration Debug \
    -derivedDataPath build \
    build

APP="build/Build/Products/Debug/PeachCommander.app"

# Plugins, into the app that was just built.
#
# Without this the bundle keeps whatever `make-dmg.sh` left there last — which can be days old, and
# looks exactly like a fresh build. Anyone verifying a plugin change by running the debug app was
# then testing the *previous* version of it, silently and with no way to notice. Measured on
# 2026-08-13: the WebDAV binary inside the bundle was eight hours older than its source.
#
# Skippable, because it is the slowest part of a build and most changes are not to plugins:
#   PC_SKIP_PLUGINS=1 Tools/build.sh
if [ "${PC_SKIP_PLUGINS:-0}" = "1" ]; then
    echo "Skipping plugins (PC_SKIP_PLUGINS=1) — the bundle keeps whatever it already had."
else
    echo "Building plugins into the app bundle..."
    Tools/build-all-plugins.sh "$APP/Contents/PlugIns"
fi

echo "Build complete: $APP"
