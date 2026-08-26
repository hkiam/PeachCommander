#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# pc-automation-fw.sh — find the built PCAutomation.framework and clamp the slice list to it.
#
# Sourced by every plugin that links PCAutomation. Two plugins now do (AIAssistant and AILocal),
# and forty lines of framework hunting copied into both is forty lines that drift.
#
# Sets FWDIR, and narrows PC_PLUGIN_ARCHS to the slices the framework actually has.

# Locate the built PCAutomation.framework (+ sibling frameworks) to compile/link against.
FWDIR="${PC_FRAMEWORKS_DIR:-}"
if [ -z "$FWDIR" ]; then
  # The tree this repo actually builds into first (Tools/build.sh passes -derivedDataPath build).
  # Asking xcodebuild answers with the *default* DerivedData, which on a machine that has never
  # built through Xcode's UI is an empty directory — this script then aborted, and with it every
  # plugin after it in build-all-plugins.sh, so the app bundle shipped without the AI plugin, the
  # AI column and the PFX plugins. In the VM that showed up as "the AI context items are missing"
  # and "four windows fewer than the pinned count": two defect reports for a build that never ran.
  for cand in "$ROOT/build/Build/Products/Debug" \
              "$(xcodebuild -project "$ROOT/PeachCommander.xcodeproj" -scheme PeachCommander \
                 -configuration Debug -showBuildSettings 2>/dev/null \
                 | awk -F' = ' '/ BUILT_PRODUCTS_DIR /{print $2; exit}')"; do
    if [ -n "$cand" ] && [ -d "$cand/PCAutomation.framework" ]; then FWDIR="$cand"; break; fi
  done
fi
[ -d "$FWDIR/PCAutomation.framework" ] || { echo "PCAutomation.framework not found in '$FWDIR' — build the app first"; exit 1; }

# A plugin can only be as universal as the framework it links against. make-dmg.sh passes
# the Release build, which is arm64 + x86_64; a developer's Debug build is host-architecture
# only, and compiling the x86_64 slice against it fails with
#   could not find module 'PCAutomation' for target 'x86_64-apple-macos'
# So clamp the slice list to what the framework actually contains, keeping any explicit
# PC_PLUGIN_ARCHS the caller set as an upper bound.
FW_BIN="$FWDIR/PCAutomation.framework/Versions/A/PCAutomation"
[ -f "$FW_BIN" ] || FW_BIN="$FWDIR/PCAutomation.framework/PCAutomation"
if [ -f "$FW_BIN" ]; then
  FW_ARCHS="$(lipo -archs "$FW_BIN" 2>/dev/null || echo "")"
  if [ -n "$FW_ARCHS" ]; then
    CLAMPED=""
    for a in $PC_PLUGIN_ARCHS; do
      case " $FW_ARCHS " in *" $a "*) CLAMPED="${CLAMPED:+$CLAMPED }$a" ;; esac
    done
    if [ -z "$CLAMPED" ]; then
      echo "error: PCAutomation.framework has [$FW_ARCHS], none of the requested [$PC_PLUGIN_ARCHS]" >&2
      exit 1
    fi
    if [ "$CLAMPED" != "$PC_PLUGIN_ARCHS" ]; then
      echo "note: building for [$CLAMPED] — PCAutomation.framework provides only [$FW_ARCHS]"
    fi
    PC_PLUGIN_ARCHS="$CLAMPED"
  fi
fi
