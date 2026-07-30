#!/usr/bin/env bash
# extract-strings.sh - Refresh the app's String Catalog from source.
#
# Builds PCApp (which emits per-file .stringsdata via SWIFT_EMIT_LOC_STRINGS) and
# merges the extracted `String(localized:)` keys into Sources/PCApp/Localizable.xcstrings
# with xcstringstool. Run this after adding/changing user-facing strings; then add
# translations (Tools/apply-translations.py) and rebuild.
set -euo pipefail
cd "$(dirname "$0")/.."

XCS="$(xcrun --find xcstringstool)"
CATALOG="Sources/PCApp/Localizable.xcstrings"
DERIVED="build/loc-derived"

echo "==> Building PCApp to extract localizable strings…"
xcodebuild -project PeachCommander.xcodeproj -scheme PeachCommander -configuration Debug \
  -derivedDataPath "$DERIVED" CODE_SIGNING_ALLOWED=NO build >/dev/null

echo "==> Merging extracted strings into ${CATALOG}..."
# All .stringsdata emitted for the PCApp module.
DATA=$(find "$DERIVED/Build" -path '*PCApp.build*' -name '*.stringsdata')
[ -n "$DATA" ] || { echo "error: no .stringsdata found" >&2; exit 1; }
# shellcheck disable=SC2086
"$XCS" sync "$CATALOG" --stringsdata $DATA

python3 - "$CATALOG" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
print(f"==> {len(d['strings'])} keys in the catalog.")
PY
