# Roadmap

The build runs in **ten strictly sequential phases**. A phase is not complete until its gate
passes in CI, and no work from a later phase begins early, however tempting. The gates exist
because building content on a foundation that cannot support it is discovered at 80%
completion, and costs three phases to undo.

Full detail, including the working rules for each phase, is in
[docs/design/14-work-order.md](docs/design/14-work-order.md).

## Status

| Phase | What it delivers | Gate | Status |
| --- | --- | --- | --- |
| **0 — Foundation** | Repo, pinned Godot, CI, static analysis, test harness, the five verification layers in skeletal form | An empty project passes all five verification layers and exports Linux + Windows from a clean checkout | ✅ Done |
| **1 — The skeleton** | `ContentRegistry`, schema validation, loader, event bus, mod loader, save system with migrations, `NetTransport`, tick scheduler, seeded RNG | Every checkbox in the architecture's definition of done, plus the modding acceptance tests | ✅ Done |
| **2 — Vertical slice** | One room, five products, one customer, one document type with three forgery vectors, one tool, one recipe, one cat. Single-player | A human can play ten minutes; the bot completes a simulated day | ✅ Done |
| **3 — Systems breadth** | All of Loop B and the encounter anatomy, the full tool tree, all of Loop C including Rush mode, all of Loop A, cats, progression and strikes | Every system integration-tested; the bot completes Acts I–II; Rush mode playable to day 10 | ✅ Done |
| **4 — Multiplayer** | Host-authoritative replication, join/drop, role division, shared verification, mod manifest reconciliation | Five headless clients run a full day and converge; join/drop at every encounter phase leaves consistent state | ✅ Done |
| **5 — Staff and late game** | Hiring as a verification encounter, the audit loop, permissions, training, turnover. Acts IV–V | Bot completes a full campaign at every player count and difficulty preset; no soft-locks across 50 seeds; pace within 15% | ✅ Done |
| **6 — Content** | The full [content manifest](docs/design/12-content-manifest.md), in bulk, against frozen schemas | Every content target met, every quality gate passed | ✅ Done |
| **7 — Modding polish** | Scaffolding CLI, hot reload, generated schemas, in-game console, event tracer, validation CLI, three example mods, full docs | A fresh checkout plus the docs alone lets someone build a working mod of each tier | ✅ Done |
| **8 — Feel** | Audio pass, visual regression baselines, retexture and kitbash pass, performance, accessibility, onboarding | 60fps at 1080p on mid-range hardware with five players and a full store; accessibility checklist complete | 🟡 Partial — see below |
| **9 — Handoff** | Telemetry-driven balance, bug triage, `HANDOFF.md`, a signed release candidate | Clean run of everything, and the handoff report written | 🟡 In progress |

Every phase gate that can be checked mechanically is checked in CI: the full test suite,
content validation against the schemas and the design's quality gates, the licence audit,
repository hygiene, documentation links, and a headless export of both platforms.

### What Phase 8 is still missing

The systems are all there and the accessibility work is done. What is not:

- **No audio.** Not a single sound file ships. Every cue the design specifies has a visual
  counterpart already, which is what the settings call "a visual cue for every sound", so
  the game is complete and playable silent — but it is silent.
- **Placeholder art.** The room is built from primitives and flat materials. Documents and
  cards are drawn as runtime vector art, which is genuinely the intended approach for
  those; the shop around them is not.
- **Performance is unmeasured on real hardware.** It is comfortably inside frame on a
  headless CI runner, which proves nothing about a laptop GPU.

### What Phase 9 is still missing

[HANDOFF.md](HANDOFF.md) is written. What it asks for is human playtesting: the bot is a
liveness probe, not a player, and the balance questions it cannot answer are listed there
in priority order.

## What is deliberately *not* on the roadmap

Stated so it is never quietly reconsidered: microtransactions, battle passes, live-service
cadence, loot boxes, NFTs, telemetry that leaves the machine without consent, and any
monetisation of mods. Real-money purchases of any kind are out — including, and especially,
in the loop that simulates gambling.

Deferred but architecturally preserved — Steam lobbies and Workshop, host migration,
dedicated servers, further jurisdictions, seasonal events, daily seeded runs, leaderboards,
console ports, photo mode — are listed with the v1 hook each one requires in
[docs/design/16-post-v1-roadmap.md](docs/design/16-post-v1-roadmap.md).
