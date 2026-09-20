# Modding PoggyWoggy

[← Docs](../README.md) · [Definition type reference](definition-types.md)

> [!IMPORTANT]
> **Status.** Everything here runs today except where a section is marked **(planned)**:
> schemas, the validator, mounting a mod, load order with declared dependencies, guarded
> mod scripts on the event bus, hot reload and the in-game console. Three worked examples
> covering the three tiers live in [`examples/mods/`](../../examples/mods/), and CI
> validates them the same way it validates the base game. The one thing still unbuilt is
> **declarative patches**.

---

## The promise

**The base game is the first mod.** [`content/`](../../content/) has a manifest, definitions
and schemas identical in form to any community mod, loads through the same loader, and
holds no privileges. If the base game ever gets a privileged path, the modding system is
decorative — so it is treated as a bug ([ADR-0005](../decisions/0005-base-game-ships-as-a-mod.md)).

The test the project holds itself to: **a new product, customer, document, tool, cat, card set
or verification rule must be addable as data by someone with a text editor and zero engine
code.**

## Three tiers of modder

| Tier | Does what | Needs |
| --- | --- | --- |
| **Data modder** | New products, customers, documents, forgery vectors, recipes, cats, rules | A text editor. Nothing else. |
| **Content modder** | New models, textures, sounds, layouts, fixtures | Blender, an image editor, and the packaging CLI |
| **Script modder** | New systems, new mechanics, UI | Godot, GDScript, and the event bus |

The first tier determines whether a modding community actually forms, so it gets the most
attention.

## Your first mod in 15 minutes

You need Python 3.11+ and a text editor. No engine, no build step.

### 1. Make the folder

```bash
mkdir -p mods/my_first_mod/definitions/product
cd mods/my_first_mod
```

### 2. Write the manifest

`mods/my_first_mod/manifest.json`:

```json
{
  "id": "my_first_mod",
  "name": "My First Mod",
  "version": "0.1.0",
  "authors": ["you"],
  "game_api": ">=0.1.0 <1.0.0",
  "dependencies": {},
  "load_order": 100,
  "capabilities": ["definitions"],
  "affects_gameplay": true,
  "description": "One drink nobody asked for."
}
```

The `id` is your namespace. **Every definition you add must be prefixed with it**, which is
what stops two mods colliding.

### 3. Add a definition

`mods/my_first_mod/definitions/product/battery_tea.json`:

```json
{
  "id": "my_first_mod:battery_tea",
  "type": "product",
  "name": "loc:my_first_mod.product.battery_tea",
  "category": "hot_beverages",
  "tags": ["impulse", "urgency_high"],
  "storage": "ambient",
  "shelf_footprint": [1, 1],
  "units_per_case": 24,
  "base_cost": 0.4,
  "market_price": 2.6,
  "price_band": [1.5, 4.0],
  "shelf_life_days": 400,
  "licence": "base:general_retail",
  "suppliers": ["base:metro_wholesale"]
}
```

Note it references **base content** — `base:general_retail`, `base:metro_wholesale` — by id.
That is the whole trick: your content plugs into systems that have never heard of it.

### 4. Validate

```bash
python3 tools/validate_content.py
```

The validator picks up every folder in `mods/` with a manifest, in load order, and tells you
the file, the JSON path and the violated constraint when something is wrong. Try breaking
it on purpose — delete the `licence` line and run it again. The message should be enough to
fix it without reading any source.

### 5. What happens next

Dropping that folder in `mods/` is all that is required: the loader mounts it, the registry
indexes it, and the fridge, pricing, restock and inspection systems treat your drink like
any other. `tools/new_mod.sh` scaffolds the folder for you and `tools/validate_mod.sh`
checks it the way CI does.

## Four ways to change the game

1. **Add** — a new definition with a new id. The common case, and it must be trivially easy.
2. **Override** — a definition replacing a base one by id. Last mod in load order wins, and the
   manager shows the conflict plainly. The validator warns when this happens so it is never
   accidental.
3. **Patch** *(planned)* — a declarative edit to specific fields of an existing definition,
   expressed as JSON paths and operations. **Two mods patching different fields of the same
   product must both apply cleanly.** This is what prevents the override-conflict hell that
   kills most modded games.
4. **Extend** — a script subscribing to the event bus, contributing to query events, or
   vetoing cancellable ones. See
   [`examples/mods/house_rules`](../../examples/mods/house_rules), which adds a mechanic
   the engine has never heard of without touching a line of engine code.

## Mod package format

```text
my_mod/
  manifest.json          id, name, version, authors, game version range,
                         dependencies, load-order hints, capability flags
  definitions/           JSON, one folder per definition type
  schemas/               optional: new definition types this mod introduces
  assets/                art and audio, each with a .license.json sidecar
  scenes/                .tscn
  scripts/               .gd
  locale/                translations
  patches/               declarative edits to other definitions
  README.md
```

Shipped as a directory during development and as a `.pck` or `.zip` for distribution.
`ProjectSettings.load_resource_pack()` mounts it over `res://`. Users drop it in `mods/` and
it appears in the manager.

**Assets in a mod follow the same licence rules as the base game** — CC0 or CC BY, with a
`.license.json` sidecar per file. See [LICENSING.md](../../LICENSING.md).

## The public API surface

Versioned, documented, and generated from source annotations so it cannot drift from
reality.

| Surface | Guarantee |
| --- | --- |
| Definition schemas | **Additive within a major version.** Fields are never removed or repurposed. |
| Event names and payloads | Stable within a major version. Deprecated events warn for one full minor cycle before removal. |
| `ContentRegistry` query API | Stable |
| `ModAPI` helpers — register, patch, subscribe, localise, log | Stable |
| Internal system classes | **No guarantee.** Explicitly marked. Mods touching them will break. |

## Compatibility policy

The game reports its API version. A manifest declares the range it supports via `game_api`.
**Out-of-range mods are disabled with a clear message rather than loaded and left to crash.**

[Semantic versioning](https://semver.org/spec/v2.0.0.html), applied to the public mod API:

- **Major** — a schema field is removed or repurposed, or an event payload changes shape.
  Breaks mods. Rare, announced, and accompanied by a migration note.
- **Minor** — new definition types, new fields, new events. Existing mods keep working.
- **Patch** — fixes and content that break nothing.

Every such change goes through [an ADR](../decisions/README.md) and appears in
[CHANGELOG.md](../../CHANGELOG.md).

## Load order and dependencies

Declared dependencies with semver ranges, plus `load_before` and `load_after` hints.
Topological sort **with a stable tiebreak, so the order is reproducible run to run**. Circular
dependencies fail at load with the cycle printed. The manager exposes the resolved order
and lets users pin it manually.

## Error handling

**A mod must never take the game down.** Every mod operation runs guarded: a failure
disables that mod, logs a message naming the mod, the file, the line and the violated
expectation, and the game continues without it.

The load report lists what failed and why, written for a modder to act on and for a player
to report, and the in-game console (F1) shows it alongside the resolved load order and the
overrides that won. Mod authors get a `--mod-strict` flag that turns warnings into hard
failures during development — the same idea as `tools/validate_content.py --strict`, which
works today.

## Mods in multiplayer

The host's mod set is authoritative. On join, the client compares manifests:

- gameplay-affecting mismatches **block** the join;
- cosmetic-only mismatches **warn** and continue;
- **mod definitions are never transmitted between peers.** No automatic downloading of
  arbitrary code, ever.

Details in [09 Multiplayer](../design/09-multiplayer-and-scaling.md#mods-in-multiplayer),
and the security rationale in [SECURITY.md](../../SECURITY.md).

## Developer experience *(Phase 7)*

This is where most modding systems stop short, and it is the difference between a feature
and an ecosystem.

- `tools/new_mod.sh` scaffolds a working mod from a template in one command
- **Hot reload** — change a JSON definition and see it in the running game without a restart.
  Non-negotiable for iteration speed.
- Generated JSON Schema for every definition type, so editors give autocomplete and inline
  validation *(the schemas in [`content/schemas/`](../../content/schemas/) already do this —
  point your editor at them)*
- In-game mod console — query the registry, inspect live definitions, trace events as they fire
- Event tracer — a filterable log of every bus event with payloads
- Validation CLI — checks a mod fully without launching the game; **the same code CI runs**
- Three worked example mods in the repository, one per tier, kept passing in CI

## Distribution

v1 ships local `mods/` folder loading, which is complete and sufficient. The manifest and
packaging are structured to be **Steam Workshop-compatible from day one**, so integration
is later a transport concern rather than a redesign.

## Where to ask

- [Discussions](https://github.com/phififofum/ope/discussions) for questions
- [Modding API gap](https://github.com/phififofum/ope/issues/new?template=modding_api.yml)
  when something reasonable is impossible — **that is a bug report, not a feature request**
