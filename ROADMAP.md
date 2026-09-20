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
| **0 — Foundation** | Repo, pinned Godot, CI, static analysis, test harness, the five verification layers in skeletal form | An empty project passes all five verification layers and exports Linux + Windows from a clean checkout | 🟡 **In progress** |
| **1 — The skeleton** | `ContentRegistry`, schema validation, loader, event bus, mod loader, save system with migrations, `NetTransport`, tick scheduler, seeded RNG | Every checkbox in the architecture's definition of done, plus the modding acceptance tests | ⚪ Not started |
| **2 — Vertical slice** | One room, five products, one customer, one document type with three forgery vectors, one tool, one recipe, one cat. Single-player | A human can play ten minutes; the bot completes a simulated day | ⚪ Not started |
| **3 — Systems breadth** | All of Loop B and the encounter anatomy, the full tool tree, all of Loop C including Rush mode, all of Loop A, cats, progression and strikes | Every system integration-tested; the bot completes Acts I–II; Rush mode playable to day 10 | ⚪ Not started |
| **4 — Multiplayer** | Host-authoritative replication, join/drop, role division, shared verification, mod manifest reconciliation | Five headless clients run a full day and converge; join/drop at every encounter phase leaves consistent state | ⚪ Not started |
| **5 — Staff and late game** | Hiring as a verification encounter, the audit loop, permissions, training, turnover. Acts IV–V | Bot completes a full campaign at every player count and difficulty preset; no soft-locks across 50 seeds; pace within 15% | ⚪ Not started |
| **6 — Content** | The full [content manifest](docs/design/12-content-manifest.md), in bulk, against frozen schemas | Every content target met, every quality gate passed | ⚪ Not started |
| **7 — Modding polish** | Scaffolding CLI, hot reload, generated schemas, in-game console, event tracer, validation CLI, three example mods, full docs | A fresh checkout plus the docs alone lets someone build a working mod of each tier | ⚪ Not started |
| **8 — Feel** | Audio pass, visual regression baselines, retexture and kitbash pass, performance, accessibility, onboarding | 60fps at 1080p on mid-range hardware with five players and a full store; accessibility checklist complete | ⚪ Not started |
| **9 — Handoff** | Telemetry-driven balance, bug triage, `HANDOFF.md`, a signed release candidate | Clean run of everything, and the handoff report written | ⚪ Not started |

## Phase 0 in detail — what is actually done

- [x] Repository, licensing, contribution and governance scaffolding
- [x] Content data model: schemas, worked definitions, namespaced ids
- [x] Content validator (`tools/validate_content.py`) running in CI
- [x] Licence audit (`tools/licence_audit.py`) running in CI, generating `CREDITS.md`
- [x] Repository hygiene and documentation-link checks running in CI
- [x] Lint and format automation — ruff, gdlint, gdformat, yamllint, markdownlint,
      codespell — pinned in `.pre-commit-config.yaml` and run in CI
- [x] The full design specification, [17 documents](docs/design/README.md)
- [x] `project.godot` pinned to 4.7.2, importing cleanly headless
- [x] A boot scene that loads every definition through the real engine and exits
      non-zero if any is missing (`godot --headless --path . -- --smoke-test`)
- [x] Export presets for Linux and Windows, built and smoke-tested in CI from a clean
      checkout
- [x] SteamPipe depot scripts and a tagged-release workflow that uploads to a playtest
      branch ([guide](docs/release/steam.md))
- [ ] gdUnit4 vendored in `addons/`, one passing example test
- [ ] Scene-reference checker (broken node paths, missing resources)
- [ ] Headless integration harness with one asserting test beyond the boot scene
- [ ] Visual regression harness with one approved baseline

Four items left before the gate closes. The next merge that matters is gdUnit4 and the
first real integration test; after that, Phase 1 is the skeleton.

## What is deliberately *not* on the roadmap

Stated so it is never quietly reconsidered: microtransactions, battle passes, live-service
cadence, loot boxes, NFTs, telemetry that leaves the machine without consent, and any
monetisation of mods. Real-money purchases of any kind are out — including, and especially,
in the loop that simulates gambling.

Deferred but architecturally preserved — Steam lobbies and Workshop, host migration,
dedicated servers, further jurisdictions, seasonal events, daily seeded runs, leaderboards,
console ports, photo mode — are listed with the v1 hook each one requires in
[docs/design/16-post-v1-roadmap.md](docs/design/16-post-v1-roadmap.md).
