#!/usr/bin/env bash
# The nightly probe: run the bot across every player count and difficulty preset, on
# several seeds, and report anything that soft-locked, went insolvent or stalled.
#
#     tools/nightly_bot.sh              # 10 days, 3 seeds, every count and preset
#     tools/nightly_bot.sh 30 10        # 30 days, 10 seeds -- the weekly campaign run
#
# It is not a test of skill. It answers: can a campaign be completed, does anything
# soft-lock, does the economy reach a dead end, is any objective unreachable.
#
# Output: reports/bot/<timestamp>.json, plus a summary on stdout.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

DAYS="${1:-10}"
SEEDS="${2:-3}"
GODOT="${GODOT:-}"
if [ -z "$GODOT" ]; then
  GODOT_VERSION="$(tr -d '[:space:]' < .godot-version)"
  if [ -x ".tooling/godot-$GODOT_VERSION/godot" ]; then
    GODOT=".tooling/godot-$GODOT_VERSION/godot"
  else
    GODOT="godot"
  fi
fi

STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
OUT="reports/bot/${STAMP}.json"

echo "bot sweep: ${DAYS} days x ${SEEDS} seeds, every player count and preset"
set +e
"$GODOT" --headless --path . -- --bot --days "$DAYS" --seeds "$SEEDS" --out "$OUT" >/dev/null 2>&1
STATUS=$?
set -e

[ -f "$OUT" ] || { echo "error: the sweep produced no report" >&2; exit 2; }
python3 tools/telemetry_summary.py "$OUT"
exit $STATUS
