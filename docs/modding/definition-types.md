# Definition type reference

[← Modding guide](README.md) · [Docs](../README.md)

Every definition is a JSON object with an `id`, a `type`, and a schema-validated body. Ids are
namespaced: `base:` for shipped content, your mod's `id` for yours.

The authoritative source is [`content/schemas/`](../../content/schemas/) — this page is the
readable version of those files. If the two disagree, **the schema is right** and this page is
a bug.

Validate anything you write with:

```bash
python3 tools/validate_content.py          # everything, in load order
python3 tools/validate_content.py --strict # warnings fail too
```

## Types shipped today

| Type | Governs | Schema |
| --- | --- | --- |
| [`product`](#product) | Anything with a SKU | [product.schema.json](../../content/schemas/product.schema.json) |
| [`supplier`](#supplier) | Where stock comes from, and how honest it is | [supplier.schema.json](../../content/schemas/supplier.schema.json) |
| [`licence`](#licence) | What you may sell, and the scrutiny it drags in | [licence.schema.json](../../content/schemas/licence.schema.json) |
| [`tool`](#tool) | Instruments of inspection | [tool.schema.json](../../content/schemas/tool.schema.json) |
| [`document_type`](#document_type) | Any inspectable artifact, cards included | [document_type.schema.json](../../content/schemas/document_type.schema.json) |
| [`forgery_vector`](#forgery_vector) | One way an artifact can be wrong | [forgery_vector.schema.json](../../content/schemas/forgery_vector.schema.json) |
| [`recipe`](#recipe) | Kitchen items | [recipe.schema.json](../../content/schemas/recipe.schema.json) |
| [`cat`](#cat) | Residents | [cat.schema.json](../../content/schemas/cat.schema.json) |

Planned for later phases, specified in
[02 Architecture](../design/02-architecture.md#definition-types-in-v1): `customer_archetype`,
`rule`, `fixture`, `staff_role`, `event`, `upgrade`, `board_game`, `card_set`, `loc_string`.

## Rules that apply to every type

- **`id` is namespaced and snake_case**: `^[a-z0-9_]+:[a-z0-9_]+$`. Base content uses `base:`.
- **`type` must match the folder** the file lives in.
- **Player-visible strings are `loc:` keys**, never literals: `^loc:[a-z0-9_.]+$`. Localisation
  is not retrofittable.
- **Unknown fields are rejected.** A typo in a field name is an error, not a silent no-op.
- **Resource paths start with `res://`.**
- Referenced ids must exist. The validator resolves them across base content and every
  loaded mod.

---

## `product`

Cafe stock, kitchen ingredients, retail goods, sealed product, singles.

| Field | Type | Required | Notes |
| --- | --- | --- | --- |
| `name` | `loc:` key | ✅ | |
| `category` | enum | ✅ | `hot_beverages`, `cold_beverages`, `bakery`, `chilled`, `frozen`, `ambient`, `confectionery`, `alcohol`, `nicotine`, `household`, `accessories`, `board_games`, `sealed_product`, `singles` |
| `tags` | string[] | | Free-form, snake_case. Systems query by tag — `chilled`, `impulse`, `theft_exposed`, `age_restricted`. **This is how your content plugs into systems that have never heard of it.** |
| `storage` | enum | ✅ | `ambient`, `chilled`, `frozen`. Drives degradation outside its class. |
| `shelf_footprint` | [int, int] | | Tiles occupied |
| `units_per_case` | int | | Delivery granularity |
| `base_cost` | number | ✅ | What you pay |
| `market_price` | number | ✅ | Drifts daily within a band. `0` means not sold directly (an ingredient). |
| `price_band` | [number, number] | ✅ | Bounds of the market drift |
| `shelf_life_days` | int | ✅ | `0` means non-perishable |
| `licence` | id | ✅ | Must exist. **Every product must be reachable through some licence.** |
| `suppliers` | id[] | ✅ | At least one, and each must exist |
| `model` | `res://` path | | |
| `adjacency_affinity` | string[] | | Categories that lift each other's basket attachment |
| `urgency` | enum | | `low`, `medium`, `high` — raises tolerable markup |

## `supplier`

| Field | Type | Required | Notes |
| --- | --- | --- | --- |
| `name` | `loc:` key | ✅ | |
| `catalogue` | string[] | ✅ | Categories carried |
| `lead_time_days` | [int, int] | ✅ | Min and max |
| `minimum_order` | number | | |
| `price_tier` | enum | ✅ | `premium`, `standard`, `discount`, `grey` |
| `reliability` | 0–1 | ✅ | Chance the delivery arrives as scheduled |
| `legitimacy` | object | ✅ | `counterfeit_rate`, `manifest_accuracy`, `credentials_verifiable` |

**`legitimacy` is the interesting field.** The cheap supplier is cheap for a reason, and that
reason shows up at the back door as a verification encounter.

## `licence`

| Field | Type | Required | Notes |
| --- | --- | --- | --- |
| `name` | `loc:` key | ✅ | |
| `unlocks_categories` | string[] | ✅ | **A licence that unlocks nothing is a validator warning** |
| `cost` | number | ✅ | |
| `renewal_days` | int | ✅ | |
| `standing_required` | int | | Gate on the standing currency |
| `verification_burden` | string[] | | Human-readable list of the obligations it creates |
| `strike_consequences` | object | ✅ | `first`, `second`, `third` |

## `tool`

| Field | Type | Required | Notes |
| --- | --- | --- | --- |
| `name` | `loc:` key | ✅ | |
| `tier` | 0–4 | ✅ | Availability tier. Cross-checked against every forgery vector. |
| `reveals` | string[] | ✅ | Field keys and security-feature ids this tool makes visible |
| `inspection_seconds` | number | ✅ | **Every tool costs time.** That price is the tension. |
| `unlocked_by` | string | ✅ | Licence id, milestone or `start` |
| `failure_modes` | string[] | | Where it misleads. Good tools have them. |
| `destructive` | bool | | Consumes the artifact |
| `returns_verdict` | `false` | | **Must be false if present.** A tool reveals; it never judges. CI enforces this. |

## `document_type`

Any inspectable artifact. A trading card is a document type with different fields — that is
deliberate, and it is why authentication reuses the whole verification engine.

| Field | Type | Required | Notes |
| --- | --- | --- | --- |
| `name` | `loc:` key | ✅ | |
| `family` | enum | ✅ | `identity`, `payment`, `entitlement`, `commercial`, `credential`, `collectible` |
| `jurisdiction` | string | | For identity documents |
| `layout` | `res://` path | | The vector layout it renders through |
| `fields` | object[] | ✅ | `key`, `source`, `face` (`front`/`back`/`edge`), optional `format` and `revealed_by` |
| `security_features` | object[] | | `id` plus the `revealed_by` tool |
| `typeface` | string | | **Typeface is a forgery vector**, so it is data |
| `variants` | object | | e.g. an under-21 portrait layout |

A field with `revealed_by` cannot be read at all without that tool. A field without it is
visible to the naked eye.

## `forgery_vector`

| Field | Type | Required | Notes |
| --- | --- | --- | --- |
| `applies_to` | object | ✅ | `document_types` (ids, or `"*"`), plus optional `requires_field` / `requires_feature` |
| `class` | enum | ✅ | `internal_inconsistency`, `external_inconsistency`, `physical_defect` |
| `tier` | 0–4 | ✅ | The campaign tier at which it starts appearing |
| `difficulty` | 1–5 | ✅ | How subtle it is within its tier |
| `detectable_by` | id[] | ✅ | **At least one must be a tool whose `tier` ≤ this vector's `tier`** |
| `transform` | object | ✅ | The perturbation: `op`, `target`, `method`, and op-specific parameters |
| `tell` | object | | `behaviour` and `weight` — the ambient signal, correlated with guilt, never determinative |

Two gates that CI enforces, both from the fairness rule:

- **Every forgery must be catchable.** A vector at tier 2 whose only detecting tool unlocks at
  tier 3 fails the build.
- **Every document type needs at least three applicable vectors, spanning all three
  classes**, so no single habit of looking catches everything.

Wildcard targeting is what makes vectors combinatorial — `{"document_types": ["*"],
"requires_field": "barcode"}` covers every document with a barcode, including ones added
by a mod loaded after yours.

## `recipe`

| Field | Type | Required | Notes |
| --- | --- | --- | --- |
| `name` | `loc:` key | ✅ | |
| `price` | number | ✅ | |
| `station_primary` | string | | |
| `ingredients` | object[] | ✅ | `product` (must exist), `qty`, optional `unit` and `optional` |
| `steps` | object[] | ✅ | `station`, `action`, optional `target`, `seconds`, `tolerance`, `skill_window`, `order` |
| `modifiers_allowed` | enum[] | | `omission`, `addition`, `substitution`, `preparation`, `portioning`, `quantity` |
| `store_credit_eligible` | bool | | `false` on hot prepared food — which is what turns a sandwich into a verification encounter |
| `unlocked_by` | id | | Licence |

## `cat`

| Field | Type | Required | Notes |
| --- | --- | --- | --- |
| `name_pool` | `loc:` key | ✅ | |
| `model` | `res://` path | | |
| `coat` | string | ✅ | |
| `trait_weights` | object | ✅ | Keys from `vigilant`, `lazy`, `skittish`, `social`, `territorial`, `hunter`, `thief`, `vocal`, `nocturnal`, `escape_artist`; values 0–1 |
| `base_hunting` | 0–1 | ✅ | Pest suppression |
| `counter_sensitivity` | 0–1 | ✅ | How readily it reacts at the counter |
| `false_positive_rate` | 0–1 | ✅ | **The cat points attention; it never resolves anything** |
| `customer_appeal` | 0–1 | ✅ | Footfall and patience effect |
| `vocalisations` | `res://` path | | Per-cat audio, so players recognise which one is complaining |

---

## Adding a type that does not exist yet

Write the schema, add a folder, and the loader picks it up — **no switch statement to edit**,
because the registry is generic over type. If you find yourself needing engine changes to add
a type, that is
[a bug worth reporting](https://github.com/phififofum/ope/issues/new?template=modding_api.yml).
