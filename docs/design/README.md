# The specification

Seventeen documents. They are opinionated on purpose: this is written to be *executed*,
not deliberated, so it decides things a specification would normally defer.

> [!IMPORTANT]
> **It is a starting position, not a cage.** It is wrong somewhere. When you find the place,
> deviate — and write down what and why in an [ADR](../decisions/README.md). Deviating
> silently is the only version of this that causes damage.

## Read in this order

**If you have ten minutes:** [01 Vision](01-vision.md), then the loop that interests you.

**If you are about to write code:** [14 The work order](14-work-order.md) first, then
[02 Architecture](02-architecture.md), then [13 Testing](13-testing-and-verification.md).
In that order, and do not skip the third.

**If you are about to write content:** [17 The data model](17-data-model.md) and
[../modding/definition-types.md](../modding/definition-types.md).

## Index

| # | Document | What it settles |
| --- | --- | --- |
| 01 | [Vision and pillars](01-vision.md) | The thesis, the four loops and their weighting, the five pillars, the design centre |
| 02 | [Architecture](02-architecture.md) | **Load-bearing.** Engine, the content registry, the event bus, determinism, saves, repo layout |
| 03 | [Loop A — the floor](03-loop-a-floor.md) | Library and cafe inventory, zone design, maintenance, ordering, expansion, the day's rhythm |
| 04 | [Loop B — the counter](04-loop-b-counter.md) | The verification engine, the scenario families, verdicts, the anatomy of an encounter, the director, reading people |
| 05 | [Loop C — the kitchen](05-loop-c-kitchen.md) | Stations, the modification grammar, progressive automation, Rush mode |
| 06 | [Loop D — the case](06-loop-d-case.md) | Sealed product, singles, authentication, grading, the adversaries, the responsible-design line |
| 07 | [Cats](07-cats.md) | Pest control, counter assistance, reputation, adoption, mischief, scope discipline |
| 08 | [Progression and staff](08-progression-and-staff.md) | Three currencies, licences, strikes, the campaign acts, hiring, the audit loop |
| 09 | [Multiplayer and scaling](09-multiplayer-and-scaling.md) | Topology, what replicates, roles at each count, how scaling actually works, difficulty |
| 10 | [Onboarding and interface](10-onboarding-and-interface.md) | The first hour, the diegetic-first rule, the inspection interface, controls, accessibility |
| 11 | [Art, audio and licensing](11-art-audio-licensing.md) | The art split, procedural documents, asset sourcing, automated licence compliance, the soundscape |
| 12 | [Content manifest](12-content-manifest.md) | v1.0 targets by category, and the quality gates each batch must pass |
| 13 | [Testing and verification](13-testing-and-verification.md) | **Load-bearing.** Five verification layers, the bot player, telemetry, what must never be done |
| 14 | [The work order](14-work-order.md) | **Load-bearing.** Ten sequential phases, their gates, the working rules |
| 15 | [Risks and non-goals](15-risks-and-non-goals.md) | What could sink this, what is deliberately out, the open questions |
| 16 | [Post-v1 roadmap](16-post-v1-roadmap.md) | What not to build now, and the v1 hook each deferred feature needs |
| 17 | [The data model](17-data-model.md) | Worked definition examples — the fastest way to understand what 02 is asking for |

## Where this came from

The specification is the descendant of a single build brief written for autonomous
implementation. Two decisions restructured it and are recorded as ADRs rather than being
quietly absorbed:

- the setting moved from a bodega to a late-night board game cafe
  ([ADR-0002](../decisions/0002-setting-board-game-cafe.md));
- the project was renamed to PoggyWoggy
  ([ADR-0003](../decisions/0003-project-name-poggywoggy.md)).

Where these documents still carry an older label, this specification wins and the older
label is not content.
