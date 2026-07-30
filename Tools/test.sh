#!/bin/bash
# test.sh - Run all tests

set -e

echo "=== Peach Commander Tests ==="

cd "$(dirname "$0")/.."

# Ensure project is generated
if [ ! -f "PeachCommander.xcodeproj" ]; then
    echo "Project not found, generating..."
    xcodegen generate
fi

# Run tests for all test targets
echo "Running tests..."

xcodebuild \
    -project PeachCommander.xcodeproj \
    -scheme PeachCommander \
    -configuration Debug \
    test

echo "All tests passed."
