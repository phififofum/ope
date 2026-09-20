# 17 · Appendix — the data model

[← Post-v1 roadmap](16-post-v1-roadmap.md) · [Index](README.md)

---

Worked examples. Their purpose is to pin down the shape of the data so implementation
starts from a concrete target, and to make
[the modding promise](../modding/README.md) legible. Field names will evolve; **the
structure should not**.

Every example below is a real file in this repository, validated in CI. Field-by-field
documentation is in
[../modding/definition-types.md](../modding/definition-types.md).

## A product

[`content/definitions/product/cold_brew_16oz.json`](../../content/definitions/product/cold_brew_16oz.json)

```json
{
  "id": "base:cold_brew_16oz",
  "type": "product",
  "name": "loc:product.cold_brew_16oz",
  "category": "cold_beverages",
  "tags": ["chilled", "impulse", "urgency_high"],
  "storage": "chilled",
  "shelf_footprint": [1, 1],
  "units_per_case": 12,
  "base_cost": 0.88,
  "market_price": 3.4,
  "price_band": [2.2, 5.5],
  "shelf_life_days": 21,
  "licence": "base:general_retail",
  "suppliers": ["base:metro_wholesale"],
  "adjacency_affinity": ["bakery", "confectionery"],
  "urgency": "high"
}
```

`urgency` is what makes the convenience premium real: nobody haggles over a 2am
phone charger, and that asymmetry is where the interesting pricing decisions live.

## A document type

[`content/definitions/document_type/state_id_northvale.json`](../../content/definitions/document_type/state_id_northvale.json)

```json
{
  "id": "base:state_id_northvale",
  "type": "document_type",
  "name": "loc:doc.state_id_northvale",
  "family": "identity",
  "jurisdiction": "northvale",
  "layout": "res://content/layouts/id_landscape_a.tres",
  "fields": [
    { "key": "dob", "source": "person.dob", "face": "front", "format": "MM/DD/YYYY" },
    { "key": "expiry", "source": "derived.expiry", "face": "front", "format": "MM/DD/YYYY" },
    { "key": "photo", "source": "person.portrait", "face": "front" },
    { "key": "barcode", "source": "encoded.all_fields", "face": "back",
      "revealed_by": "base:barcode_scanner" }
  ],
  "security_features": [
    { "id": "uv_seal", "revealed_by": "base:uv_torch" },
    { "id": "microprint_border", "revealed_by": "base:loupe" }
  ],
  "typeface": "base:font_northvale_official",
  "variants": { "under21": { "orientation": "portrait", "banner": "loc:doc.under21" } }
}
```

Note `variants.under21`. **A vertical ID presented by someone claiming to be 27 is an
external inconsistency that costs nothing to author and reads as expert knowledge to a
player who spots it.** The data model should make that kind of detail cheap.

## A forgery vector

[`content/definitions/forgery_vector/barcode_mismatch.json`](../../content/definitions/forgery_vector/barcode_mismatch.json)

```json
{
  "id": "base:barcode_mismatch",
  "type": "forgery_vector",
  "applies_to": { "document_types": ["*"], "requires_field": "barcode" },
  "class": "internal_inconsistency",
  "tier": 2,
  "difficulty": 3,
  "detectable_by": ["base:barcode_scanner"],
  "transform": {
    "op": "perturb_field",
    "target": "barcode.dob",
    "method": "shift_years",
    "range": [2, 6]
  },
  "tell": { "behaviour": "volunteers_information", "weight": 0.4 }
}
```

`applies_to` with a wildcard plus a field requirement is what makes vectors
**combinatorial**: one definition covers every document type that has a barcode, **including
ones a mod adds later**. This is the mechanism behind the 100+ vector target.

`tier` is load-bearing and CI-enforced: at least one tool in `detectable_by` must be available
at or below that tier, or the encounter is a coin flip and the build fails.

## A recipe

[`content/definitions/recipe/three_cheese_toastie.json`](../../content/definitions/recipe/three_cheese_toastie.json)

```json
{
  "id": "base:three_cheese_toastie",
  "type": "recipe",
  "name": "loc:recipe.three_cheese_toastie",
  "price": 8.5,
  "station_primary": "griddle",
  "ingredients": [
    { "product": "base:sourdough_loaf", "qty": 2, "unit": "slice" },
    { "product": "base:cheddar_block", "qty": 60, "unit": "g" },
    { "product": "base:butter_block", "qty": 12, "unit": "g" }
  ],
  "steps": [
    { "station": "slicer", "action": "slice", "target": "base:cheddar_block",
      "seconds": 8, "skill_window": true },
    { "station": "griddle", "action": "cook", "seconds": 95, "tolerance": 14 },
    { "station": "prep", "action": "assemble", "order": ["bread", "cheese", "bread"] }
  ],
  "modifiers_allowed": ["omission", "addition", "substitution", "preparation",
                        "portioning", "quantity"],
  "store_credit_eligible": false,
  "unlocked_by": "base:food_service"
}
```

`store_credit_eligible: false` is [the Loop B/C intersection](05-loop-c-kitchen.md) made
concrete — a single boolean that turns a sandwich into a verification encounter when the
customer pays with trade-in credit.

## A cat

[`content/definitions/cat/tuxedo_shorthair.json`](../../content/definitions/cat/tuxedo_shorthair.json)

```json
{
  "id": "base:tuxedo_shorthair",
  "type": "cat",
  "name_pool": "loc:catnames.common",
  "coat": "tuxedo",
  "trait_weights": {
    "vigilant": 0.85, "territorial": 0.5, "hunter": 0.7,
    "skittish": 0.3, "nocturnal": 0.6
  },
  "base_hunting": 0.72,
  "counter_sensitivity": 0.75,
  "false_positive_rate": 0.08,
  "customer_appeal": 0.45
}
```

`false_positive_rate` is the whole cat design in one number: **the cat points attention, it
never resolves anything.**

## A mod manifest

```json
{
  "id": "community.southport_documents",
  "name": "Southport Document Pack",
  "version": "1.2.0",
  "authors": ["example"],
  "game_api": ">=1.0.0 <2.0.0",
  "dependencies": { "community.jurisdiction_framework": ">=0.4.0" },
  "load_after": ["base"],
  "capabilities": ["definitions", "assets", "scripts"],
  "affects_gameplay": true,
  "description": "Adds the Southport jurisdiction: 4 document types, 11 forgery vectors."
}
```

`affects_gameplay` drives
[multiplayer reconciliation](09-multiplayer-and-scaling.md#mods-in-multiplayer) — cosmetic
mods warn on mismatch; gameplay mods block the join.

The base game's own manifest, [`content/manifest.json`](../../content/manifest.json), has
exactly this shape. That is the point.

## Reading this appendix

**Every example above is something a person with a text editor could write.** That is the
entire test of [02 Architecture](02-architecture.md) and the modding SDK.

> If at any point during the build a new content type cannot be expressed this way, the
> architecture has drifted and must be corrected before more content is authored on top
> of it.
