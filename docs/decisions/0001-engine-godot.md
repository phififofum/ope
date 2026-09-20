# ADR-0001 · Build on Godot 4.7, not Unity

- **Status:** Accepted
- **Date:** 2026-09-20
- **Affects:** everything. [02 Architecture](../design/02-architecture.md), CI, the modding SDK.

## Context

Three hard constraints govern this project: **FOSS assets and tooling throughout, deep
runtime modding, and long stretches of unsupervised implementation.** The instinct was
Unity — the larger ecosystem, the more mature console path — and that instinct is
reasonable. All three constraints point the other way.

## Decision

Build on **Godot 4.7.2 stable**, GDScript, Forward+ renderer, Jolt physics,
`ENetMultiplayerPeer` behind a `NetTransport` interface. The version is pinned in
[`.godot-version`](../../.godot-version) and CI uses the matching binary. Dev snapshots are
never tracked.

## Consequences

### What gets better

| Requirement | Godot 4.7 | Unity 6 LTS |
| --- | --- | --- |
| **Runtime mod loading** | `ProjectSettings.load_resource_pack()` mounts a `.pck`/`.zip` over `res://` at runtime — scenes, scripts, art, audio, and overrides of base files. An engine feature, zero dependencies. | No equivalent. Addressables + AssetBundles plus an out-of-band loader (BepInEx, MelonLoader). C# mod assemblies cannot hot-reload. |
| **Authorable project files** | `.tscn`, `.tres`, `project.godot` are plain, diffable, hand-writable text | `.unity` and `.prefab` are YAML keyed by 128-bit GUIDs and fileIDs. Anyone working without the editor open produces broken prefabs they cannot diagnose. |
| **Headless verification** | `godot --headless` runs the full engine — scene tree, physics, multiplayer peers. Fast enough for per-commit integration tests. | `-batchmode` + Unity Test Framework works, but is heavy and slow to iterate. |
| **5-player co-op** | `MultiplayerSpawner`, `MultiplayerSynchronizer`, `@rpc`, `ENetMultiplayerPeer` — sized for exactly this | Netcode for GameObjects is capable but heavier than this game needs |
| **Licence posture** | MIT engine, no account, no seat, no runtime-fee history. Modders can build from source. | Proprietary; fine in practice, but in tension with [pillar 5](../design/01-vision.md#design-pillars) |
| **Scale fit** | One small interior. Vulkan with Jolt is far more than enough. | Maturity advantage matters in open worlds, not here |

**The modding row is the decisive one.** In Godot it is an engine primitive rather than a
community workaround. The authorability row is second: text scenes are the difference
between a project that can be self-corrected and one that silently becomes unopenable.

### What gets worse

Stated plainly so the trade is on the record: a much smaller asset
ecosystem (irrelevant — [we are FOSS-only](0004-licensing-mit-and-cc-by.md)), a less mature
console certification path (out of v1 scope), weaker profiling tools, a shallower well of
tutorials, and **weaker global illumination and lightmapping** — mitigated by baking
`LightmapGI` for a small static interior, which is the right technique for this game anyway.

### What this commits us to

- Full static typing in GDScript. Every variable, parameter and return annotated;
  `class_name` on every script.
- Text formats only — never a binary `.tscn` or `.res`.
- The headless pipeline is built in Phase 0, before the game.
- GDExtension (godot-rust) stays reserved for a measured hot path. Expect to need none.

## Alternatives considered

| Option | Why it lost |
| --- | --- |
| Unity 6 LTS | Runtime mod loading requires third-party loaders; opaque project files; proprietary licence in tension with pillar 5 |
| Unreal 5 | Overwhelming for one small interior; C++/Blueprint modding story is worse again; heavy CI |
| Bevy / custom | Would spend the entire budget building what Godot ships |
