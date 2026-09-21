<div align="center">

# PoggyWoggy

**A first-person co-op sim for 1–5 players about running a late-night board game cafe —
where the hard part is knowing what to check.**

[![Status: design](https://img.shields.io/badge/status-design%20%E2%80%94%20phase%200-orange)](docs/design/14-work-order.md)
[![Engine: Godot 4.7](https://img.shields.io/badge/engine-Godot%204.7.2-478cbf)](docs/design/02-architecture.md)
[![Code: MIT](https://img.shields.io/badge/code-MIT-green)](LICENSE)
[![Content: CC BY 4.0](https://img.shields.io/badge/content-CC%20BY%204.0-green)](LICENSING.md)
[![PRs welcome](https://img.shields.io/badge/PRs-welcome-brightgreen)](CONTRIBUTING.md)

[What it is](#what-it-is) ·
[The four loops](#the-four-loops) ·
[Quick start](#quick-start) ·
[Docs](#documentation-map) ·
[Contributing](CONTRIBUTING.md) ·
[Roadmap](ROADMAP.md)

</div>

---

> [!IMPORTANT]
> **This is an early build, not a finished game.** All four loops run, a shift can be
> played first-person, and a bot plays whole campaigns headlessly — but the art is
> placeholder geometry, there is no audio, and the content is broad rather than deep.
> [ROADMAP.md](ROADMAP.md) is the honest status, phase by phase.

## Play it

**[Download the latest build →](https://github.com/phififofum/ope/releases/latest)**

No install, no launcher, no account. One file that already contains everything it needs.

| | |
| --- | --- |
| **Windows** | Download the `-windows.zip`, unzip it, run `poggywoggy.exe`. Windows will say it does not recognise the publisher, because the build is not signed: **More info → Run anyway**. |
| **Linux** | Download the `-linux.zip`, unzip it, then `chmod +x poggywoggy.x86_64 && ./poggywoggy.x86_64`. |
| **macOS** | Not built yet. |

### Controls

| | |
| --- | --- |
| Move | `W` `A` `S` `D`, `Shift` to run |
| Use what you are looking at | `E` |
| Pick a document up, put it down | `E`, `Q` |
| Turn it over, look closer | hold **right mouse**, scroll wheel, `F` to flip |
| Reach for the tool in your other hand | **left mouse** |
| Approve, decline, partial | `1`, `2`, `3` |
| The binder of rules | `B` |
| Developer console | `F1` |

Cutting a new build for testers is one button — **Actions → Release → Run workflow** — and
takes about ten minutes: [how it works](docs/release/playtest.md).

### Or build it yourself

Needs nothing installed — it fetches its own pinned engine and export templates into
`.tooling/`, and touches nothing outside the repository:

```bash
git clone https://github.com/phififofum/ope.git
cd ope
./build.sh run          # build and play  (build.ps1 on Windows)
./build.sh all          # both platforms, into build/
```

## What it is

You run a board game cafe. The kind with a wall of four hundred games to borrow, a kitchen,
a card counter, and a cat asleep on the display case. You cook, you run tournaments, you
shelve boxes, and you stand behind the glass deciding whether the card someone just slid
across it is real — and whether the person sliding it is.

**The thesis: scrutiny is a budget, and you never have enough of it.** Every session presents
more things worth checking than there is time to check. Card authenticity, condition grades,
IDs at the bar, payment fraud, trade-in collections of uncertain origin — all of it arrives while
a kitchen ticket burns and a tournament needs adjudicating. The skill is not in checking
everything. It is in knowing what to check.

The signature encounter, and the reason the setting works: **to buy a card, you must check the
card and card the person, in the same transaction** — while the grill is going and table six wants
a rules ruling. Both meanings of *card checking*, in one moment, with real money on it.

And the decision that runs underneath all of it: every sealed pack, bundle and booster box
on the rack is stock a customer could walk in and buy. **You can sell it, or you can open
it.** What you pull goes in the case to sell or on the wall to show, and the game tells you
at closing time exactly what opening things has returned you against what selling them
would have. It is never the winning play — the content validator enforces that — and some
nights you will do it anyway.

| | |
| --- | --- |
| **Players** | 1–5 online co-op, host-authoritative. Tuned for **three**. |
| **Engine** | Godot 4.7.2, GDScript, Forward+ ([why](docs/decisions/0001-engine-godot.md)) |
| **Platforms** | Linux and Windows desktop for v1. macOS best-effort. |
| **Lineage** | Quarantine Zone (scrutiny) · PlateUp (kitchen) · TCG Simulator (the gamble) · Supermarket Together (the floor) |
| **Licence** | Code MIT · content and assets CC BY 4.0 · every asset carries a machine-readable licence record |

## The four loops

Four loops, and they are deliberately **not** equal. Two are why you play, one is the gamble
that funds and threatens the others, and one is the space they all happen in.

| Loop | Weight | Cadence | Player fantasy | Spec |
| --- | --- | --- | --- | --- |
| **B — The Counter** | Primary | Punctuated, high-attention | Catch the thing that's wrong before it costs you | [04](docs/design/04-loop-b-counter.md) |
| **C — The Kitchen** | Co-primary | Bursty, escalating, dexterous | Hold a system together as it speeds up | [05](docs/design/05-loop-c-kitchen.md) |
| **D — The Case** | Recurring hook | Slow burn, spiky | Hope, and the bookkeeping that follows it | [06](docs/design/06-loop-d-case.md) |
| **A — The Floor** | Substrate | Continuous, ambient | Build a space people want to spend six hours in | [03](docs/design/03-loop-a-floor.md) |

A is the floor you stand on. B interrupts you. C is the timer you are always already behind on.
D is the reason somebody walks in with a binder. **The signature session texture is being
mid-sandwich when someone puts a questionable ID on the counter, and having to decide
which one can wait.** That collision is the game.

This weighting has teeth: when something must be cut, it is cut from A. When there is a polish
pass to spend, it is spent on B and C.

## Design pillars

When an ambiguity comes up that the spec does not cover, it resolves in favour of these, **in order**:

1. **Scrutiny is the verb.** The signature moment is *noticing*. Not clicking fast, not memorising.
2. **Never idle, never overwhelmed.** A player with nothing to do is a bug. So is a player who cannot triage. Automation converts one kind of work into another, never into no work.
3. **The skeleton outranks the content.** Everything is data from the first commit. If content can only be added in code, the system is wrong and gets rebuilt.
4. **Co-op is the default reading.** Single-player is co-op with four empty chairs.
5. **Free as in freedom, all the way down.** Engine, tooling, art, audio, fonts — every asset carries a machine-readable licence record.

Pillar 3 has a concrete test, and it is the one that governs this repository:
**the base game ships as a mod.** `content/` has a manifest, definitions and schemas identical
in form to any community mod, loads through the same loader, and holds no privileges.

## Quick start

**Nothing to install first.** Clone it and run one command:

```bash
git clone https://github.com/phififofum/ope.git poggywoggy
cd poggywoggy

./build.sh run      # Linux/macOS — fetches the engine, builds, and plays it
.\build.ps1 run     # Windows — the same
```

The script downloads the pinned engine and its export templates into `.tooling/` inside
the repository — no system packages, no sudo, nothing outside this directory — then
produces **one self-contained executable**:

```text
build/linux/poggywoggy.x86_64      74 MB, everything inside it
build/windows/poggywoggy.exe      108 MB, everything inside it
```

`./build.sh` builds for this machine, `./build.sh all` builds both, `./build.sh run`
builds and plays. To hand the build to a tester over Steam instead, see
[docs/release/steam.md](docs/release/steam.md).

### Working on it

```bash
python3 -m pip install --user jsonschema pre-commit
pre-commit install                         # the same lint and format checks CI runs

python3 tools/validate_content.py          # every definition against its schema
tools/run_tests.sh                         # the full suite, headless
```

Add a product in `content/definitions/product/`, re-run the validator, and you have done the
thing the whole architecture exists to make easy — see
[the 15-minute first mod](docs/modding/README.md#your-first-mod-in-15-minutes).

## Documentation map

Start wherever matches what you came for.

| I want to… | Go to |
| --- | --- |
| Understand the game in ten minutes | [docs/design/01-vision.md](docs/design/01-vision.md) |
| See what is built and what is next | [ROADMAP.md](ROADMAP.md) · [docs/design/14-work-order.md](docs/design/14-work-order.md) |
| Understand the architecture before writing code | [docs/design/02-architecture.md](docs/design/02-architecture.md) |
| Add content or write a mod | [docs/modding/README.md](docs/modding/README.md) · [definition types](docs/modding/definition-types.md) |
| Know why something was decided the way it was | [docs/decisions/](docs/decisions/) |
| Look up a term | [docs/glossary.md](docs/glossary.md) |
| Build and ship a test build to Steam | [docs/release/steam.md](docs/release/steam.md) |
| Contribute code, art, audio or docs | [CONTRIBUTING.md](CONTRIBUTING.md) |
| Report something that is wrong | [open an issue](https://github.com/phififofum/ope/issues/new/choose) |
| Report something that is *sensitive* | [SECURITY.md](SECURITY.md) |
| Get help | [SUPPORT.md](SUPPORT.md) |

The full design specification lives in [`docs/design/`](docs/design/) as sixteen numbered
documents. [`docs/design/README.md`](docs/design/README.md) is the index and tells you
which three are load-bearing.

## Repository layout

```text
build.sh            one command, no prerequisites: fetch the engine, build, run
project.godot       pinned to Godot 4.7.2 (.godot-version)
export_presets.cfg  Linux and Windows, each a single self-contained executable
core/               engine-facing code. no game content.
  registry/  events/  modding/  net/  save/  sim/  util/
systems/            the game: counter, kitchen, floor, case, cats, staff, director, world
ui/                 screens, HUD, and the runtime document renderer
content/            THE BASE GAME, AS A MOD — manifest, schemas, JSON definitions
  schemas/          one JSON Schema per definition type
  definitions/      one folder per definition type
  assets/           art + audio, each with a .license.json sidecar
docs/
  design/           the specification, 17 numbered documents
  modding/          modding SDK guide and definition reference
  decisions/        architecture decision records (ADRs)
  release/          how a build reaches a tester
steam/              SteamPipe app and depot scripts
tools/              validator, licence audit, and the CLIs CI runs
mods/               local mods are dropped here (gitignored)
.github/            issue forms, PR template, CI, release, CODEOWNERS
```

`addons/` holds the vendored test framework, so the suite runs with only the pinned
engine and this repository. The layout follows
[the architecture doc](docs/design/02-architecture.md#repository-layout).

## Contributing

Contributions are welcome, and the most useful ones right now are **design review** and
**content definitions** — the parts that do not need the engine to exist yet.

- Read [CONTRIBUTING.md](CONTRIBUTING.md) first: it covers the workflow, the commit
  convention, and the five non-negotiable rules that come straight from the spec.
- Every issue starts from [a form](https://github.com/phififofum/ope/issues/new/choose) —
  bug, design proposal, content, modding API, docs, or a build-order task.
- Everyone participating agrees to the [Code of Conduct](CODE_OF_CONDUCT.md).
- Good first contributions are labelled [`good first issue`](https://github.com/phififofum/ope/labels/good%20first%20issue).

## Licensing

| What | Licence |
| --- | --- |
| Code (`core/`, `systems/`, `ui/`, `tools/`, `tests/`) | [MIT](LICENSES/MIT.txt) |
| Content, design docs, and original assets | [CC BY 4.0](LICENSES/CC-BY-4.0.txt) |
| Third-party assets | Their own — CC0 or CC BY only, recorded per file |

Every asset ships with a `.license.json` sidecar naming its source, author, licence and
modifications. CI fails the build if a sidecar is missing or names a licence we cannot ship.
[`CREDITS.md`](CREDITS.md) is generated from those sidecars, so credits can never drift from
reality. Full detail in [LICENSING.md](LICENSING.md).

## Why "PoggyWoggy"?

It is the name on the sign, and the previous owner is not around to explain it. The project
was called *BODEGA*, then *TABLE STAKES*, while the setting was still being argued about
(see [ADR-0002](docs/decisions/0002-setting-board-game-cafe.md) and
[ADR-0003](docs/decisions/0003-project-name-poggywoggy.md)). A cafe full of people who
say "poggy woggy" unironically at 2am is a truer description of the room than either.

---

<div align="center">
<sub>Built in the open. No microtransactions, no live service, no loot boxes, ever —
<a href="docs/design/15-risks-and-non-goals.md#explicit-non-goals-for-v10">that is in the spec</a>.</sub>
</div>
