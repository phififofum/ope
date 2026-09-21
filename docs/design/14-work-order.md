# 14 · The autonomous work order

[← Testing](13-testing-and-verification.md) · [Index](README.md) · [Next: Risks and non-goals →](15-risks-and-non-goals.md)

> **Load-bearing. Read this first.** Phases are strictly sequential. A phase is not complete
> until its gate passes in CI, and no work from a later phase may begin early, however
> tempting.

---

The gates exist because work done unsupervised will otherwise build content on a
foundation that cannot support it — and discover the problem at 80% completion.

Live status: [ROADMAP.md](../../ROADMAP.md).

## Phase 0 — Foundation

Repository, pinned Godot, CI pipeline, static analysis, test harness, the
[five verification layers](13-testing-and-verification.md) in skeletal form, and the
release path. **Build the pipeline before the game**, because every later phase depends on
being able to prove itself.

**Gate:** an empty project passes all five verification layers and exports Linux and Windows
builds from a clean checkout, with the artifacts uploadable to a Steam branch.

## Phase 1 — The skeleton

All of [02 Architecture](02-architecture.md). `ContentRegistry`, schema validation, loader,
event bus, mod loader with load order and dependency resolution, save system with
migrations, the `NetTransport` interface, tick scheduler, seeded RNG streams. **No gameplay
whatsoever.**

**Gate:** every checkbox in
[the skeleton's definition of done](02-architecture.md#definition-of-done-for-the-skeleton),
plus the modding acceptance tests.

> This is the most important gate in the project. It is worth spending disproportionate time
> here, and it is the one most likely to be cut under pressure.

## Phase 2 — Vertical slice

The narrowest possible complete experience: one room, one shelf type, five products, one
supplier, one customer archetype, one document type with three forgery vectors, one tool,
one recipe, one board game with a component list, one cat, single-player only. **Every loop
present in miniature**, including the kitchen — a slice without Loop C would test the wrong
thing. Gamepad and keyboard both first-class from here.

**Gate:** a human can play ten minutes and the bot player can complete a simulated day.
This is the first moment the game is worth looking at, and **the first build worth putting on
a Steam playtest branch**.

## Phase 3 — Systems breadth

All of [Loop B](04-loop-b-counter.md)'s families and the encounter anatomy, the full tool
tree, all of [Loop C](05-loop-c-kitchen.md) including Rush mode, all of
[Loop A](03-loop-a-floor.md), all of [Loop D](06-loop-d-case.md),
[cats](07-cats.md), [progression and strikes](08-progression-and-staff.md).

**Build in that order** — B and C first, because they are primary and need the most iteration
time. Systems complete, content still thin: a handful of definitions per type, enough to
exercise every code path.

**Gate:** every system has integration test coverage; the bot completes Acts I and II; Rush
mode is playable end to end and a human can reach at least day 10 in it.

## Phase 4 — Multiplayer

All of [09](09-multiplayer-and-scaling.md). Host-authoritative replication, join and drop, role
division, shared verification, mod manifest reconciliation.

**Gate:** five headless clients run a full day and converge; join and drop at every phase of an
encounter leaves consistent state.

## Phase 5 — Staff and late game

All of [the staff section](08-progression-and-staff.md#staff-and-the-late-game). Hiring as a
verification encounter, the audit loop, permissions, training, turnover. Acts IV and V
including the grey-market thread.

**Gate:** bot completes a full campaign at every player count from 1 to 5 and on every
difficulty preset; no soft-locks across 50 seeds; progression pace within 15% across counts.

## Phase 6 — Content

All of [12 Content manifest](12-content-manifest.md), in bulk, against **frozen schemas**.
This is the volume phase and it should be fast precisely because phases 1–5 made it data
entry with a validator.

**Gate:** every content target met, every quality gate passed.

## Phase 7 — Modding polish

The [SDK developer experience](../modding/README.md): scaffolding CLI, hot reload,
generated schemas, in-game console, event tracer, validation CLI, three working example
mods, and the full documentation set.

**Gate:** a fresh checkout plus the docs alone lets someone build a working mod of each
tier; the examples pass CI.

## Phase 8 — Feel

Audio pass, visual regression baselines, the retexture and kitbash pass, performance
profiling, [accessibility](10-onboarding-and-interface.md#accessibility), tutorial and
onboarding, settings.

**Gate:** 60fps at 1080p on mid-range hardware with five players and a full shop; visual
regression baselines approved; accessibility checklist complete.

## Phase 9 — Handoff

Telemetry-driven balance passes, bug triage, `HANDOFF.md`, and a built, signed release
candidate on a Steam branch.

**Gate:** clean run of everything, and the handoff report written.

## Working rules for the whole run

- **Commit small and often, every commit green.**
- **Write the test first** for anything in `core/`.
- **When the specification is ambiguous**, consult the [pillars](01-vision.md#design-pillars)
  in order. Record the decision as an [ADR](../decisions/README.md). **Do not stall.**
- **When the specification is wrong** — and it will be somewhere — deviate, and write down
  what and why. A spec is a starting position, not a cage.
- **Never break a gate to make progress.** A phase that looks done but failed its gate is a
  phase that will cost three phases later.
- **Keep the roadmap current** so an interrupted run can resume without re-deriving context.
