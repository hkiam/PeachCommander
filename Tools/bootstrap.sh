#!/bin/bash
# SPDX-License-Identifier: Apache-2.0
# bootstrap.sh - Check and install build dependencies

set -e

echo "=== Peach Commander Bootstrap ==="

# Check for Xcode
if ! xcodebuild -version &>/dev/null; then
    echo "ERROR: Xcode not found. Please install Xcode 26+ from the App Store."
    exit 1
fi

XCODE_VERSION=$(xcodebuild -version | head -n1 | sed 's/Xcode //')
echo "Xcode version: $XCODE_VERSION"

# Enforce the major version rather than only reporting it: on Xcode 16 the
# bootstrap used to succeed and the build then failed much later with confusing
# errors (Swift 6.0 rejects the existentials in PCVFS, and the macOS 26 SDK APIs
# behind @available(macOS 26) are missing).
XCODE_MAJOR="${XCODE_VERSION%%.*}"
if [ "${XCODE_MAJOR:-0}" -lt 26 ] 2>/dev/null; then
    echo "ERROR: Xcode 26 or newer is required (found $XCODE_VERSION)."
    echo "       The sources use Swift 6.3 syntax and the macOS 26 SDK."
    exit 1
fi

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

# libssh2 — SFTP (F-214). Not optional for building: CSSH2 resolves <libssh2.h>
# from the keg and no header is vendored, so without it the build fails much later
# with confusing errors. ci.yml installs it explicitly for the same reason.
if ! brew --prefix libssh2 >/dev/null 2>&1 || [ ! -d "$(brew --prefix libssh2)/include" ]; then
    echo "libssh2 not found, installing via Homebrew..."
    brew install libssh2
else
    echo "libssh2 already installed"
fi

# Generate Xcode project
echo "Generating Xcode project..."
cd "$(dirname "$0")/.."
xcodegen generate

echo "Bootstrap complete. Run Tools/build.sh to build."
