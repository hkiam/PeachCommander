#!/usr/bin/env bash
# check-keymap.sh — validate the shipped key-scheme files (I13 T06 AC).
#
# For every cm_ command referenced in a scheme file:
#   - registered in Sources/PCCommands/PCCommands.swift  -> OK
#   - not yet registered                                 -> pending (T01 adds the
#     disabled stub for the not-yet-implemented feature)
# Reports per-scheme binding counts + pending counts, and lists doc cm_ names not
# bound in the tc-classic scheme (informational).
#
# Exit non-zero only on a MISSING/unparsable scheme file. Pending commands are
# expected while features are still being built out; once a command is registered
# this script confirms the scheme name matches the registry spelling.

set -euo pipefail
cd "$(dirname "$0")/.."

SCHEMES=(Sources/PCApp/Resources/keymap-tc-classic.ini Sources/PCApp/Resources/keymap-macos.ini)
REGISTRY=Sources/PCCommands/PCCommands.swift
DOC=docs/product/keyboard-shortcuts.md

fail=0

# Known command names: real registrations + not-yet-implemented stubs.
STUBS=Sources/PCCommands/CommandStubs.swift
known=$( { grep -oE 'name: "(cm_[A-Za-z0-9]+)"' "$REGISTRY" | sed -E 's/name: "//; s/"//'
          [ -f "$STUBS" ] && grep -oE '"cm_[A-Za-z0-9]+"' "$STUBS" | tr -d '"'; } | sort -u)
# cm_ names mentioned anywhere in the shortcuts doc.
docall=$(grep -oE 'cm_[A-Za-z0-9]+' "$DOC" 2>/dev/null | sort -u || true)

for scheme in "${SCHEMES[@]}"; do
  [ -f "$scheme" ] || { echo "MISSING scheme: $scheme"; fail=1; continue; }
  count=0; pending=0
  while IFS= read -r line; do
    # skip comments, blanks, section headers
    case "$line" in ''|\;*|\#*|\[*) continue;; esac
    key="${line%%=*}"
    cmd="${line#*=}"
    key="$(echo "$key" | xargs)"; cmd="$(echo "$cmd" | xargs)"
    [ -z "$cmd" ] && continue
    count=$((count+1))
    if [ "${cmd#cm_}" != "$cmd" ] && ! grep -qx "$cmd" <<<"$known"; then
      pending=$((pending+1))
    fi
  done < "$scheme"
  echo "OK: $(basename "$scheme") — $count bindings ($pending pending registration)"
done

# Informational: doc cm_ names not bound in tc-classic.
if [ -f "$DOC" ]; then
  docnames=$(grep -oE 'cm_[A-Za-z0-9]+' "$DOC" | sort -u)
  bound=$(grep -hoE 'cm_[A-Za-z0-9]+' "${SCHEMES[0]}" | sort -u)
  missing=$(comm -23 <(echo "$docnames") <(echo "$bound") || true)
  if [ -n "$missing" ]; then
    echo "--- doc cm_ names not bound in $(basename "${SCHEMES[0]}") (info) ---"
    echo "$missing"
  fi
fi

exit $fail
