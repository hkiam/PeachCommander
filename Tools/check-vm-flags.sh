#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# check-vm-flags.sh — every `tart run` must pass --no-graphics alongside --vnc-experimental.
#
# With the VNC flag on its own, tart *opens* the vnc:// URL, which launches Screen Sharing — and that
# window is never closed. One dead window per run accumulates inside a single Screen Sharing process;
# 136 of them had piled up before anyone noticed, because each one is invisible until you look at the
# app's window list. `--no-graphics` suppresses the window and leaves the VNC server (and therefore
# every screenshot the harness takes) exactly as it was.
#
# A one-line rule in three files is precisely the kind that comes back when a fourth is added.
set -euo pipefail
cd "$(dirname "$0")/.."

problems=0
while IFS= read -r line; do
  file="${line%%:*}"
  if ! grep -q -- "--no-graphics" <<<"$line"; then
    echo "  ⚠️  $file: 'tart run' with --vnc-experimental but without --no-graphics"
    echo "      $line"
    problems=$((problems + 1))
  fi
done < <(grep -rn "tart\(\"\, \"\| \)run" Tools/ --include="*.py" --include="*.sh" | grep -- "--vnc-experimental")

echo "tart-run call sites checked, problems=$problems"
exit $(( problems > 0 ? 1 : 0 ))
