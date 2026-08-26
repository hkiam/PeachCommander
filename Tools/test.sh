#!/bin/bash
# SPDX-License-Identifier: Apache-2.0
# test.sh - Run the tests.
#
#   Tools/test.sh                    every unit-test bundle (what CI runs)
#   Tools/test.sh --changed          only the bundles your uncommitted work can affect
#   Tools/test.sh --since main       only the bundles everything since main can affect
#   Tools/test.sh --perf             the benchmarks, which are not in the normal suite
#   Tools/test.sh --list             print what would run, run nothing
#   Tools/test.sh -only-testing:PCVFSTests/DeepPathTests        …or say it yourself
#
# Anything not recognised below is handed to xcodebuild unchanged.
#
# The point of --changed is the middle of a working session: make an edit, run the bundles that
# edit can possibly break, make the next one. The full run is what you do before committing — and
# it is still the default here, so nobody gets a narrow run by forgetting a flag. Which bundles a
# change can affect is worked out by Tools/affected-tests.py from project.yml's own dependency
# graph; when it cannot narrow honestly, it says everything and this script runs everything.

set -e

cd "$(dirname "$0")/.."

SCHEME=AllTests
MODE=full
SINCE=""
LIST_ONLY=0
EXTRA=()

while [ $# -gt 0 ]; do
    case "$1" in
        --changed) MODE=changed; shift ;;
        --since)   MODE=changed; SINCE="$2"; shift 2 ;;
        --perf)    SCHEME=PerfTests; shift ;;
        --list)    LIST_ONLY=1; shift ;;
        -h|--help) sed -n '3,17p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *)         EXTRA+=("$1"); shift ;;
    esac
done

echo "=== Peach Commander Tests ==="

# project.yml is the source of truth and the .pbxproj is not tracked, so a stale one silently
# ignores build-setting changes. Regenerating on every run cost a few seconds of every run to
# guarantee that; comparing timestamps guarantees the same thing for nothing. PC_FORCE_GEN=1
# regenerates regardless, for when the generated project itself is suspect.
if [ "${PC_FORCE_GEN:-0}" = "1" ] || [ ! -f PeachCommander.xcodeproj/project.pbxproj ] \
   || [ project.yml -nt PeachCommander.xcodeproj/project.pbxproj ]; then
    echo "Generating Xcode project from project.yml..."
    xcodegen generate
fi

ONLY=()
if [ "$MODE" = "changed" ]; then
    if [ -n "$SINCE" ]; then
        AFFECTED=$(python3 Tools/affected-tests.py --scheme "$SCHEME" --since "$SINCE" --explain)
    else
        AFFECTED=$(python3 Tools/affected-tests.py --scheme "$SCHEME" --explain)
    fi
    if [ -z "$AFFECTED" ]; then
        # Not necessarily good news. Application code is the usual reason: no unit-test bundle
        # depends on PCApp, so an edit to a window controller reaches nothing here and the only
        # thing that will tell you it still compiles is Tools/build.sh.
        echo "No bundle in $SCHEME is affected — nothing to test."
        echo "(If you edited Sources/PCApp, run Tools/build.sh: no unit-test bundle covers it.)"
        exit 0
    elif [ "$AFFECTED" = "ALL" ]; then
        echo "Changes reach beyond one bundle; running the whole suite."
    else
        while IFS= read -r bundle; do ONLY+=("-only-testing:$bundle"); done <<< "$AFFECTED"
        echo "Affected bundles: $(echo "$AFFECTED" | tr '\n' ' ')"
    fi
fi

if [ "$LIST_ONLY" = "1" ]; then
    echo "Would run: -scheme $SCHEME ${ONLY[*]} ${EXTRA[*]}"
    exit 0
fi

# xcodebuild does not hand its own environment to the xctest process, so exporting PC_AI_LIVE
# here reaches nothing on its own: the schemes forward it as $(PC_AI_LIVE), which expands from a
# build setting, which is what this passes. Without it the documented `PC_AI_LIVE=1 Tools/test.sh`
# ran the whole suite with every live test silently skipped.
LIVE=()
if [ -n "${PC_AI_LIVE:-}" ]; then
    LIVE+=("PC_AI_LIVE=$PC_AI_LIVE")
    echo "Live on-device model tests: enabled (PC_AI_LIVE=$PC_AI_LIVE)"
fi

echo "Running tests..."
xcodebuild \
    -project PeachCommander.xcodeproj \
    -scheme "$SCHEME" \
    -configuration Debug \
    -derivedDataPath build \
    "${ONLY[@]}" \
    "${EXTRA[@]}" \
    "${LIVE[@]}" \
    test

echo "All tests passed."
