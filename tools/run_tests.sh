#!/usr/bin/env bash
# Runs the whole test suite the way CI does.
#
#   tools/run_tests.sh                 # everything, including the slow simulation suites
#   tools/run_tests.sh tests/unit      # one directory
#
# CI runs the same suites sharded across runners -- see the matrix in ci.yml. Locally
# they run in sequence, which takes about twenty minutes; tests/simulation is most of
# that, because every suite in it plays whole simulated days.
#
# GODOT may be set to a specific binary; otherwise `godot` from PATH is used.
set -euo pipefail

GODOT="${GODOT:-godot}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

targets=("$@")
if [ ${#targets[@]} -eq 0 ]; then
  targets=(tests/unit tests/integration tests/simulation)
fi

args=()
for target in "${targets[@]}"; do
  args+=(-a "$target")
done

# --ignoreHeadlessMode: gdUnit4 warns that input-driven tests cannot work headless.
# None of ours are; the simulation is driven through the tick scheduler, not input.
exec "$GODOT" --headless --path . \
  -s addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode "${args[@]}"
