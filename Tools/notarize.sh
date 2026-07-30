#!/usr/bin/env bash
# notarize.sh — submit a signed DMG to Apple's notary service, staple the ticket,
# and verify Gatekeeper accepts the result.
#
# Usage: notarize.sh [path-to-dmg]        (default: build/PeachCommander.dmg)
#
# No-op unless notary credentials are present, so an unsigned build still works.
# Credentials, in order of preference:
#
#   App Store Connect API key (recommended for CI)
#     NOTARY_KEY        contents of the .p8 private key
#     NOTARY_KEY_ID     the key's Key ID
#     NOTARY_ISSUER_ID  the issuer UUID
#
#   Apple ID + app-specific password
#     NOTARY_APPLE_ID   the Apple ID e-mail
#     NOTARY_PASSWORD   an app-specific password (NOT the account password)
#     NOTARY_TEAM_ID    the Developer Team ID
#
# A notarytool *keychain profile* is deliberately not supported: a profile lives in
# a local keychain, so it cannot be handed to a fresh CI runner (the workflow used
# to document a NOTARY_KEYCHAIN_PROFILE secret, which could never have worked).
#
# Notarization requires the DMG to be signed already — Tools/codesign-app.sh signs
# the app before packaging and Tools/make-dmg.sh signs the image afterwards.
set -euo pipefail

cd "$(dirname "$0")/.."
DMG="${1:-build/PeachCommander.dmg}"

have_api_key() { [ -n "${NOTARY_KEY:-}" ] && [ -n "${NOTARY_KEY_ID:-}" ] && [ -n "${NOTARY_ISSUER_ID:-}" ]; }
have_apple_id() { [ -n "${NOTARY_APPLE_ID:-}" ] && [ -n "${NOTARY_PASSWORD:-}" ] && [ -n "${NOTARY_TEAM_ID:-}" ]; }

if ! have_api_key && ! have_apple_id; then
  echo "==> No notary credentials — skipping notarization (the DMG is NOT notarized)."
  exit 0
fi
[ -f "$DMG" ] || { echo "error: no such disk image: $DMG" >&2; exit 1; }

# Refuse to waste a submission on an unsigned image: the notary service rejects it.
if ! codesign --verify --strict "$DMG" 2>/dev/null; then
  echo "error: $DMG is not signed — set PC_CODESIGN_IDENTITY so make-dmg.sh signs it" >&2
  exit 1
fi

ARGS=()
CLEANUP=""
if have_api_key; then
  echo "==> Notarizing with an App Store Connect API key…"
  KEYFILE="$(mktemp -t notary-key).p8"
  CLEANUP="$KEYFILE"
  printf '%s' "$NOTARY_KEY" > "$KEYFILE"
  ARGS=(--key "$KEYFILE" --key-id "$NOTARY_KEY_ID" --issuer "$NOTARY_ISSUER_ID")
else
  echo "==> Notarizing with an Apple ID + app-specific password…"
  ARGS=(--apple-id "$NOTARY_APPLE_ID" --password "$NOTARY_PASSWORD" --team-id "$NOTARY_TEAM_ID")
fi
# The key file holds a private key: remove it however we exit.
trap '[ -n "$CLEANUP" ] && rm -f "$CLEANUP"' EXIT

# --wait blocks until Apple reaches a verdict; a rejection exits non-zero, which
# must fail the release rather than shipping an un-notarized image.
xcrun notarytool submit "$DMG" "${ARGS[@]}" --wait

echo "==> Stapling the ticket…"
xcrun stapler staple "$DMG"

echo "==> Verifying Gatekeeper acceptance…"
xcrun stapler validate "$DMG"
spctl --assess --type open --context context:primary-signature -vv "$DMG"

echo "==> Notarized and stapled: $DMG"
