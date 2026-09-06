#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# publish-plugin-sdk.sh — mirror PluginSDK/ into the standalone SDK repository.
#
# Why a second repository at all: SwiftPM resolves a `.package(url:)` by cloning the repository and
# looking for `Package.swift` **at its root**. Ours is in a subdirectory, so the dependency line
# that PluginSDK/README.md and docs/content/sdk/sdk-overview.md have documented from the start has
# never resolved for anybody — a third party had to clone the whole application to build a plugin
# against headers that are six files.
#
# So Plugins/SDK/ stays canonical, PluginSDK/ stays its SwiftPM mirror inside this repository (with
# Tools/check-sdk-headers.sh failing the build if either drifts), and this script publishes that
# mirror outward on a release.
#
#   Tools/publish-plugin-sdk.sh <path-to-sdk-checkout> [tag]
#
# Copies the headers, the two Swift helpers and the porting documents into the checkout, commits if
# anything changed, and tags when a tag is given. Pushing is left to the caller: this script does
# not decide when something becomes public.
set -euo pipefail
cd "$(dirname "$0")/.."
ROOT="$(pwd)"

DEST="${1:-}"
TAG="${2:-}"
[ -n "$DEST" ] || { echo "usage: $(basename "$0") <path-to-PeachCommanderPluginSDK> [tag]" >&2; exit 2; }
[ -d "$DEST/.git" ] || { echo "error: $DEST is not a git checkout" >&2; exit 2; }

# The tag's major number is the ABI version, so `from: "1.0.0"` cannot resolve across a breaking
# change. Checked here rather than after the tag is pushed.
API="$(sed -n 's/^#define PC_API_VERSION  *\([0-9][0-9]*\).*/\1/p' Plugins/SDK/pc_common.h)"
[ -n "$API" ] || { echo "error: could not read PC_API_VERSION from Plugins/SDK/pc_common.h" >&2; exit 1; }
if [ -n "$TAG" ] && [ "${TAG%%.*}" != "$API" ]; then
    echo "error: tag $TAG has major ${TAG%%.*} but PC_API_VERSION is $API" >&2
    exit 1
fi

# Refuse to publish a mirror that has drifted from the canonical headers — the gate exists, but it
# runs in CI and this script can be run by hand.
Tools/check-sdk-headers.sh >/dev/null || { echo "error: the SDK headers have drifted; run Tools/sync-plugin-sdk.sh" >&2; exit 1; }

echo "==> Copying the ABI headers"
mkdir -p "$DEST/Sources/CPeachCommanderPlugin/include"
cp PluginSDK/Sources/CPeachCommanderPlugin/include/*.h "$DEST/Sources/CPeachCommanderPlugin/include/"
cp PluginSDK/Sources/CPeachCommanderPlugin/include/module.modulemap "$DEST/Sources/CPeachCommanderPlugin/include/"
cp PluginSDK/Sources/CPeachCommanderPlugin/shim.c "$DEST/Sources/CPeachCommanderPlugin/"

echo "==> Copying the Swift helpers"
# One adaptation, and only one: in this repository the contribution ABI is its own shim module
# (CContrib); in the package all six headers are one umbrella module. Everything else is verbatim,
# so a change here cannot quietly diverge from what the shipping plugins compile.
mkdir -p "$DEST/Sources/PeachCommanderPluginKit"
for file in PluginLoc.swift PluginTheme.swift; do
    sed -e 's/^#if canImport(CContrib)$/#if canImport(CPeachCommanderPlugin)/' \
        -e 's/^import CContrib$/import CPeachCommanderPlugin/' \
        "Plugins/SDK/$file" > "$DEST/Sources/PeachCommanderPluginKit/$file"
done

echo "==> Copying the porting documents and the licence"
cp Plugins/SDK/PORTING.md Plugins/SDK/LOCALIZATION.md LICENSE "$DEST/"

echo "==> Copying the universal-build helper"
mkdir -p "$DEST/Tools"
cp Tools/lib/pc-universal.sh "$DEST/Tools/pc-universal.sh"

cd "$DEST"
if git diff --quiet && git diff --cached --quiet; then
    echo "==> Nothing changed."
else
    git add -A
    git commit -q -m "Sync the plugin ABI from PeachCommander ($(cd "$ROOT" && git rev-parse --short HEAD))"
    echo "==> Committed."
fi

if [ -n "$TAG" ]; then
    git tag -a "$TAG" -m "Plugin SDK $TAG (PC_API_VERSION $API)"
    echo "==> Tagged $TAG. Push with: git -C $DEST push && git -C $DEST push --tags"
fi
