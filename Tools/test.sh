#!/bin/bash
# test.sh - Run all tests

set -e

echo "=== Peach Commander Tests ==="

cd "$(dirname "$0")/.."

# Always regenerate: project.yml is the source of truth and the .pbxproj is not
# tracked, so a stale one silently ignores build-setting changes. (This used to be
# guarded by `[ ! -f PeachCommander.xcodeproj ]`, which is a directory — the test
# was always true, so it regenerated anyway while claiming "Project not found".)
echo "Generating Xcode project from project.yml..."
xcodegen generate

# Run tests for all test targets
echo "Running tests..."

xcodebuild \
    -project PeachCommander.xcodeproj \
    -scheme PeachCommander \
    -configuration Debug \
    test

echo "All tests passed."
