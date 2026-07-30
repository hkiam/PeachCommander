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
    build

echo "Build complete: build/Debug/PeachCommander.app"
