#!/usr/bin/env bash
# check-version.sh — verify a release tag matches the version the app reports.
#
# Usage: check-version.sh [tag]
#   tag   e.g. v0.2.0 or 0.2.0. Defaults to $GITHUB_REF_NAME, so the release
#         workflow can call it with no arguments.
#
# Without a tag it just prints the version from project.yml and exits 0, which
# makes it a handy "what version is this?" for local use.
#
# Why: project.yml is the single source of CFBundleShortVersionString, and nothing
# derives the git tag from it. Tagging v0.2.0 while project.yml still says 0.1.0
# used to ship an app that called itself the old version — silently, since every
# other check passes. Wired into release.yml ahead of the build so a mismatch fails
# in seconds instead of after packaging.
set -euo pipefail

cd "$(dirname "$0")/.."

# Read the two keys straight out of project.yml. Deliberately no PyYAML: this gate
# runs before any dependency is installed, and the runner's system python3 has no
# yaml module — importing it made the check fail while *reporting* an empty version,
# i.e. blaming the tag for a missing module.
version_key() {  # version_key <key>
  sed -n "s/^[[:space:]]*$1:[[:space:]]*\"\{0,1\}\([^\"]*\)\"\{0,1\}[[:space:]]*$/\1/p" project.yml
}

SHORT="$(version_key CFBundleShortVersionString)"
BUILD="$(version_key CFBundleVersion)"

# Never fall through with an empty value — that produced a misleading mismatch.
if [ -z "$SHORT" ]; then
  echo "error: could not read CFBundleShortVersionString from project.yml" >&2
  exit 1
fi
if [ "$(printf '%s\n' "$SHORT" | wc -l | tr -d ' ')" != "1" ]; then
  echo "error: CFBundleShortVersionString is ambiguous in project.yml:" >&2
  printf '  %s\n' $SHORT >&2
  exit 1
fi
[ -n "$BUILD" ] || BUILD="?"

TAG="${1:-${GITHUB_REF_NAME:-}}"

# Not a version tag (a branch name, a manual dispatch, or no argument): report only.
case "$TAG" in
  v[0-9]*|[0-9]*) ;;
  *)
    echo "project.yml: version $SHORT (build $BUILD)"
    [ -n "$TAG" ] && echo "note: '$TAG' is not a version tag — nothing to compare."
    exit 0 ;;
esac

WANT="${TAG#v}"
if [ "$WANT" != "$SHORT" ]; then
  echo "::error::Tag $TAG does not match project.yml (CFBundleShortVersionString = $SHORT)."
  echo "Bump CFBundleShortVersionString to $WANT in project.yml and commit before tagging," >&2
  echo "or retag to v$SHORT. Otherwise the release ships an app reporting the wrong version." >&2
  exit 1
fi

echo "✓ tag $TAG matches project.yml version $SHORT (build $BUILD)"
