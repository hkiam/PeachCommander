#!/bin/bash
# build.sh - Build PeachCommander

set -e

echo "=== Peach Commander Build ==="

cd "$(dirname "$0")/.."

# Ensure project is generated
if [ ! -f "PeachCommander.xcodeproj" ]; then
    echo "Project not found, generating..."
    xcodegen generate
fi

# Build Debug configuration
echo "Building Debug configuration..."
xcodebuild \
    -project PeachCommander.xcodeproj \
    -scheme PeachCommander \
    -configuration Debug \
    build

echo "Build complete: build/Debug/PeachCommander.app"
