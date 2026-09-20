#!/usr/bin/env bash
# Validate one mod without launching the game -- the same code CI runs.
#
#     tools/validate_mod.sh my_mod        # a mod in mods/
#     tools/validate_mod.sh path/to/mod   # anywhere else
#
# Checks: the manifest, every definition against its schema, id namespacing, every
# reference it makes into base content, the fairness gates, and asset licence sidecars.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET="${1:-}"

if [ -z "$TARGET" ]; then
  echo "usage: tools/validate_mod.sh <mod_id|path>" >&2
  exit 2
fi

MOD_PATH="$TARGET"
[ -d "$MOD_PATH" ] || MOD_PATH="$ROOT/mods/$TARGET"
[ -d "$MOD_PATH" ] || { echo "error: no mod at '$TARGET'" >&2; exit 2; }
[ -f "$MOD_PATH/manifest.json" ] || { echo "error: $MOD_PATH has no manifest.json" >&2; exit 2; }

echo "validating $MOD_PATH"
# Base content first, so the mod's references into it resolve, then the mod itself.
python3 "$ROOT/tools/validate_content.py" --strict "$ROOT/content" "$MOD_PATH"

if compgen -G "$MOD_PATH/assets/*" >/dev/null 2>&1; then
  echo "checking asset licences"
  python3 "$ROOT/tools/licence_audit.py" --check
fi

echo "ok: $MOD_PATH would load"
