#!/bin/bash
# bootstrap.sh - Check and install build dependencies

set -e

echo "=== Peach Commander Bootstrap ==="

# Check for Xcode
if ! xcodebuild -version &>/dev/null; then
    echo "ERROR: Xcode not found. Please install Xcode 16+ from the App Store."
    exit 1
fi

XCODE_VERSION=$(xcodebuild -version | head -n1 | sed 's/Xcode //')
echo "Xcode version: $XCODE_VERSION"

# Check for xcodegen
if ! command -v xcodegen &>/dev/null; then
    echo "xcodegen not found, installing via Homebrew..."
    if ! command -v brew &>/dev/null; then
        echo "ERROR: Homebrew not found. Please install Homebrew: https://brew.sh"
        exit 1
    fi
    brew install xcodegen
else
    echo "xcodegen already installed"
fi

# Generate Xcode project
echo "Generating Xcode project..."
cd "$(dirname "$0")/.."
xcodegen generate

echo "Bootstrap complete. Run Tools/build.sh to build."
