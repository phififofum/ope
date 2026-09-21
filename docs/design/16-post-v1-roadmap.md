# 16 · Post-v1 roadmap

[← Risks and non-goals](15-risks-and-non-goals.md) · [Index](README.md) · [Next: The data model →](17-data-model.md)

---

This document exists mainly to say **what not to build**, while making sure the architecture
does not preclude it. Each item names the v1 hook that must exist so the feature is later a
matter of work rather than a rewrite.

| Deferred feature | v1 hook that must exist |
| --- | --- |
| Steam lobbies, NAT punch-through, Workshop | `NetTransport` interface ([02](02-architecture.md)); Workshop-compatible mod manifest ([SDK](../modding/README.md)) |
| Host migration | Save system that can serialise full session state mid-shift |
| Dedicated servers | Host authority already cleanly separated from local player |
| **Additional shop archetypes** — a nightclub door, a pharmacy counter, a border kiosk | Everything is a `fixture` and `licence` composition; no hardcoded shop type |
| Seasonal and holiday events | The `event` definition type and director profiles |
| More cities and jurisdictions | `document_type` jurisdiction is already data |
| More card sets, rotations and formats | `card_set` is already data, including pull rates and legality windows |
| Challenge and daily seeded runs | Deterministic seeded RNG from day one |
| Leaderboards | Deterministic runs plus the telemetry log |
| Console ports | Gamepad first-class from Phase 2; no desktop-only assumptions in save paths |
| Further localisation | Every string in `loc_string` definitions from the first commit |
| Photo mode and shop sharing | Save format includes full layout; camera already decoupled |
| A second location | Progression state is already per-shop rather than global |

## Explicitly not on the roadmap

Stated so it is never quietly reconsidered: **microtransactions, battle passes, live-service
cadence, loot boxes, NFT anything, telemetry that leaves the machine without consent, and
any monetisation of mods.**

Given that [Loop D](06-loop-d-case.md) simulates a gamble, the first of those is not a
business-model preference — it is a line.

## What the community should be able to build without us

A useful test of whether the [modding system](../modding/README.md) actually succeeded. If
it is real, the community should be able to ship all of these **without a single engine
change**:

- A different country's document set, with its own formats and forgery vectors
- A total conversion to a different kind of gatekeeping business — a nightclub door, a
  pharmacy counter, a border kiosk
- New card games with their own sets, rarities and authentication tells
- New cuisines with their own stations and recipe grammars
- Harder director profiles and custom difficulty presets
- Cosmetic packs, shop themes, seasonal decor
- New cat breeds, traits and behaviours
- Quality-of-life UI mods
- Translation packs

**If any of these would require touching engine code, the modding system has a gap — and it
is treated as a bug rather than a limitation.**
