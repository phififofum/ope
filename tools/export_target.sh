#!/usr/bin/env bash
# Exports one preset, and decides whether it worked by looking at the file on disk.
#
#   GODOT=/path/to/godot tools/export_target.sh "Linux" build/linux/poggywoggy.x86_64
#
# The engine sometimes aborts *after* writing a perfectly good pack -- the log ends with
# "DONE savepack" and the process still dies with a signal. Trusting the exit code there
# throws away a finished build and fails the run, so the size of the output file is what
# counts. One retry covers a genuinely interrupted export.
#
# This lives in its own script because build.sh and both workflows need to agree about
# it; when they disagree, the one that trusts the exit code is the one that breaks, and
# it breaks on the day somebody tries to cut a release.
set -euo pipefail

GODOT="${GODOT:-godot}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

preset="${1:?usage: export_target.sh <preset> <output>}"
output="${2:?usage: export_target.sh <preset> <output>}"

mkdir -p "$(dirname "$output")"
"$GODOT" --headless --path "$ROOT" --export-release "$preset" "$output" >/dev/null 2>&1 || true
if [ ! -s "$output" ]; then
  echo "retrying the $preset export" >&2
  "$GODOT" --headless --path "$ROOT" --export-release "$preset" "$output" >/dev/null 2>&1 || true
fi
if [ ! -s "$output" ]; then
  echo "error: the $preset export produced nothing at $output" >&2
  exit 1
fi
chmod +x "$output" 2>/dev/null || true
echo "$output ($(du -h "$output" | cut -f1))"
