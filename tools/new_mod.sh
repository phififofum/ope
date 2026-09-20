#!/usr/bin/env bash
# Scaffold a working mod in one command.
#
#     tools/new_mod.sh my_mod             # a data mod, ready to validate
#     tools/new_mod.sh my_mod --scripts   # ...with an event-bus script as well
#
# The result is a mod that already validates and already changes the game: a product on
# the shelf. Delete what you do not want; the point is to start from something that
# works rather than from an empty folder.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MOD_ID="${1:-}"
WITH_SCRIPTS="${2:-}"

if [ -z "$MOD_ID" ]; then
  echo "usage: tools/new_mod.sh <mod_id> [--scripts]" >&2
  exit 2
fi
if ! printf '%s' "$MOD_ID" | grep -Eq '^[a-z0-9_.]+$'; then
  echo "error: a mod id is lower-case letters, digits, dots or underscores" >&2
  exit 2
fi

TARGET="$ROOT/mods/$MOD_ID"
if [ -e "$TARGET" ]; then
  echo "error: $TARGET already exists" >&2
  exit 1
fi

mkdir -p "$TARGET/definitions/product" "$TARGET/assets" "$TARGET/locale"

cat > "$TARGET/manifest.json" <<JSON
{
  "id": "$MOD_ID",
  "name": "$MOD_ID",
  "version": "0.1.0",
  "authors": ["you"],
  "game_api": ">=0.1.0 <1.0.0",
  "dependencies": {},
  "load_order": 100,
  "capabilities": ["definitions"],
  "affects_gameplay": true,
  "description": "A mod that adds one drink nobody asked for."
}
JSON

cat > "$TARGET/definitions/product/house_special.json" <<JSON
{
  "id": "$MOD_ID:house_special",
  "type": "product",
  "name": "loc:$MOD_ID.product.house_special",
  "category": "cold_beverages",
  "tags": ["chilled", "impulse"],
  "storage": "chilled",
  "shelf_footprint": [1, 1],
  "units_per_case": 12,
  "base_cost": 0.75,
  "market_price": 3.2,
  "price_band": [2.0, 5.0],
  "shelf_life_days": 30,
  "licence": "base:general_retail",
  "suppliers": ["base:metro_wholesale"]
}
JSON

cat > "$TARGET/locale/en.json" <<JSON
{
  "loc:$MOD_ID.product.house_special": "House Special"
}
JSON

cat > "$TARGET/README.md" <<MD
# $MOD_ID

A PoggyWoggy mod.

## What it does

Adds one product. It references base content by id (\`base:general_retail\`,
\`base:metro_wholesale\`), which is the whole trick: your content plugs into systems that
have never heard of it.

## Working on it

\`\`\`bash
tools/validate_mod.sh $MOD_ID   # the same checks CI runs
\`\`\`

Ids are namespaced to \`$MOD_ID:\`. To *override* base content instead, use the base id --
the loader treats that as an override and records which mod won.
MD

if [ "$WITH_SCRIPTS" = "--scripts" ]; then
  mkdir -p "$TARGET/scripts"
  python3 - "$TARGET" "$MOD_ID" <<'PY'
import sys, pathlib, json
target, mod_id = pathlib.Path(sys.argv[1]), sys.argv[2]
(target / "scripts" / "main.gd").write_text(f'''extends RefCounted

## {mod_id}: an event-bus mod.
##
## The bus a mod gets is the bus base systems get -- same event names, same veto power.
## That is the test that the modding API is real rather than decorative.

var api: ModApi


func _enter_mod(p_api: ModApi) -> void:
	api = p_api
	api.on_attempt(EventCatalog.SALE_ATTEMPTED, _on_sale_attempted)
	api.on(EventCatalog.PRICE_REQUESTED, _on_price_requested)


## Return a non-empty reason to refuse the sale; the player is shown the reason.
func _on_sale_attempted(payload: Dictionary) -> String:
	if bool(payload.get("age_restricted", false)) and not bool(payload.get("id_verified", false)):
		return "house rule: no ID, no sale"
	return ""


## Query events aggregate deterministically. This one multiplies, so 1.05 is a 5% markup.
func _on_price_requested(_payload: Dictionary) -> float:
	return 1.05
''')
manifest = json.loads((target / "manifest.json").read_text())
manifest["capabilities"] = ["definitions", "scripts"]
(target / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
PY
fi

echo "created mods/$MOD_ID"
echo "next: tools/validate_mod.sh $MOD_ID"
