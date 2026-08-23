#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# build-terminal-plugin.sh — build Terminal.ptxplugin (embedded terminal, F-381).
#
# The emulator is SwiftTerm (MIT), and it is **referenced, not copied**. The plan originally said to
# vendor it, on the grounds that plugins are built by shell scripts and cannot consume a SwiftPM
# package the way the app can. The first half is true; the conclusion is not. `project.yml` already
# declares five packages and pins them, so SwiftTerm is declared there too, at an exact revision, and
# resolved into a directory of our choosing — no target has to depend on it for that to work.
#
# That keeps ~25 000 lines of somebody else's code out of this repository, and it puts SwiftTerm inside
# machinery that already exists: `Tools/generate-third-party-notices.py` reads versions straight from
# `Package.resolved` and *fails* when a pin has no licence description. Vendored sources would sit
# outside all of it.
#
# Two traps, both found by building it rather than reasoning about it:
#
#   * The plugin's own source must not be called `terminal.swift`. SwiftTerm has `Terminal.swift`, and
#     on a case-insensitive filesystem the two intermediate object files overwrite each other — the
#     linker then reports missing symbols for types whose file was compiled perfectly well.
#   * The module must not be called `Terminal` either: SwiftTerm declares a class of that name, and a
#     module name shadowing it makes every reference to `Terminal.Terminal` unresolvable.
set -euo pipefail
cd "$(dirname "$0")/.."
ROOT="$(pwd)"
DEFAULT_DIR="$HOME/Library/Application Support/PeachCommander/plugins"
OUT_DIR="${1:-$DEFAULT_DIR}"
BUNDLE="$OUT_DIR/Terminal.ptxplugin"
SPM_DIR="$ROOT/build/spm"
SWIFTTERM="$SPM_DIR/checkouts/SwiftTerm/Sources/SwiftTerm"

# Resolve to the pinned revision. A no-op once the checkout is there, so only the first build (and a
# changed pin) needs the network — the same bargain the app already makes for Sparkle.
if [ ! -d "$SWIFTTERM" ]; then
  echo "==> Resolving SwiftTerm (pinned in project.yml) into build/spm…"
  # The pin lives in project.yml and is only readable through the generated project, which is not
  # tracked. Generating it here rather than assuming it: build-all-plugins.sh is called on its own
  # (by CI's plugins job, and by anyone following CONTRIBUTING), not only from build.sh, which used
  # to be the thing that happened to have run xcodegen first. That assumption failed silently in the
  # sense that mattered — every other plugin built, and this one died on a missing .xcodeproj.
  if [ ! -f "$ROOT/PeachCommander.xcodeproj/project.pbxproj" ]; then
    echo "==> No generated project yet; running xcodegen for the SwiftTerm pin"
    (cd "$ROOT" && xcodegen generate >/dev/null)
  fi
  xcodebuild -project "$ROOT/PeachCommander.xcodeproj" -resolvePackageDependencies \
    -clonedSourcePackagesDirPath "$SPM_DIR" >/dev/null
fi
[ -d "$SWIFTTERM" ] || { echo "error: SwiftTerm checkout missing at $SWIFTTERM" >&2; exit 1; }

# The emulator's macOS sources: everything except the iOS variants, which is exactly what SwiftTerm's
# own Package.swift excludes when building for macOS.
SWIFTTERM_SOURCES=()
while IFS= read -r f; do SWIFTTERM_SOURCES+=("$f"); done \
  < <(find "$SWIFTTERM" -name '*.swift' -not -path '*/iOS/*' | sort)
[ "${#SWIFTTERM_SOURCES[@]}" -gt 0 ] || { echo "error: no SwiftTerm sources found" >&2; exit 1; }

# Universal (arm64 + x86_64) plugin builds — see Tools/lib/pc-universal.sh.
source "$ROOT/Tools/lib/pc-universal.sh"
rm -rf "$BUNDLE"; mkdir -p "$BUNDLE/Contents/MacOS"
cp "$ROOT/Plugins/Terminal/Info.plist" "$BUNDLE/Contents/Info.plist"
pc_swiftc -emit-library -O -module-name PCTerminalPlugin -target "$TARGET" \
  -framework AppKit -framework MetalKit \
  -Xcc -I"$ROOT/Plugins/SDK" \
  -import-objc-header "$ROOT/Plugins/Terminal/TerminalBridging.h" \
  -o "$BUNDLE/Contents/MacOS/Terminal" \
  "$ROOT/Plugins/Terminal/terminalplugin.swift" \
  "$ROOT/Plugins/SDK/PluginLoc.swift" \
  "$ROOT/Plugins/SDK/PluginTheme.swift" \
  "${SWIFTTERM_SOURCES[@]}"

# Ship the plugin's localizations (see Plugins/SDK/LOCALIZATION.md).
if [ -d "$ROOT/Plugins/Terminal/Resources" ]; then
  cp -R "$ROOT/Plugins/Terminal/Resources/." "$BUNDLE/Contents/Resources/"
fi
echo "Built $BUNDLE (SwiftTerm: ${#SWIFTTERM_SOURCES[@]} sources)"
