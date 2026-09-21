# Changelog

All notable changes to this project are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this
project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html) **applied to the
public mod API** — definition schemas, event names and event payloads. See
[GOVERNANCE.md](GOVERNANCE.md#releases).

## [Unreleased]

### Added

- Project renamed to **PoggyWoggy**; setting fixed as a late-night board game cafe
  ([ADR-0002](docs/decisions/0002-setting-board-game-cafe.md),
  [ADR-0003](docs/decisions/0003-project-name-poggywoggy.md)).
- The full design specification as sixteen numbered documents in [`docs/design/`](docs/design/).
- Content data model: JSON Schemas and worked definitions for `product`, `document_type`,
  `forgery_vector`, `recipe` and `cat`, loaded as the base game's own mod in
  [`content/`](content/).
- `tools/validate_content.py` — validates every definition against its schema and reports the
  file, the JSON path and the violated constraint.
- `tools/licence_audit.py` — asserts every asset carries a valid `.license.json` sidecar and
  generates [`CREDITS.md`](CREDITS.md).
- Continuous integration running both tools plus repository hygiene checks.
- Modding guide and definition-type reference in [`docs/modding/`](docs/modding/).
- Architecture decision records in [`docs/decisions/`](docs/decisions/).
- Open-source scaffolding: contribution guide, code of conduct, security policy, support
  guide, governance, licensing policy, issue forms, pull request template, labels, CODEOWNERS.
- Godot 4.7.2 project with a Phase 0 boot scene that loads every definition through the real
  engine and exits non-zero if any is missing (`godot --headless --path . -- --smoke-test`).
- Export presets for Linux and Windows, smoke-tested as exported binaries in CI.
- Steam release path: SteamPipe app and depot scripts in [`steam/`](steam/), a tagged-release
  workflow that uploads to a playtest branch, and
  [docs/release/steam.md](docs/release/steam.md)
  ([ADR-0006](docs/decisions/0006-steam-as-the-test-distribution-channel.md)).
- Lint and format automation, pinned in [`.pre-commit-config.yaml`](.pre-commit-config.yaml)
  and run in CI: ruff, gdlint, gdformat, yamllint, markdownlint, codespell and the whitespace
  hooks. A manual Format workflow applies them and pushes the result.
- `tools/check_repo_hygiene.py` and `tools/check_doc_links.py`, both CI gates.

- The simulation itself: a 20 Hz tick scheduler, named RNG streams, and a `Shop` that runs
  all four loops against one clock, so a human at 60fps, five networked peers and the bot
  player all execute the same day.
- Loop B, the counter: `VerificationEngine`, the rule engine, the forgery generator, five
  verdicts, and the fairness contract that a forgery is only ever sent when the player's
  own toolkit can catch it — or when declining resolves it without penalty.
- Loop A, the floor: stock with lots, expiry, deliveries that can arrive wrong, faced
  shelves, walk-up retail sales, shrink and lost sales.
- Loop C, the kitchen: tickets, stations, accuracy, and Rush mode.
- Loop D, the case: **sealed product that can be sold or opened.** Every pack, blister,
  bundle and box on the rack is ordinary stock a customer might buy, so opening one is
  priced at the sale it costs you. Singles go into the case to sell or onto the wall to
  show, where they draw footfall instead of cash. The lifetime return on everything you
  have opened is reported at closing time, and the validator enforces that it can never
  be a winning strategy ([Loop D](docs/design/06-loop-d-case.md)).
- Cats, staff and the audit loop, the director that paces a shift, the economy, strikes
  and licences.
- Host-authoritative multiplayer with artifact truth redacted before it reaches a peer,
  over a loopback transport that makes the wire assertable in tests.
- A first-person shop to play it in: a built room, interactables that each do one thing,
  runtime-rendered documents whose fields appear only under the right tool, and a HUD
  with a visual counterpart for every sound.
- The content manifest in bulk: ~1,000 definitions generated against the frozen schemas by
  `tools/generate_content.py`, with the quality gates enforced in CI.
- The modding SDK: `tools/new_mod.sh`, `tools/validate_mod.sh`, three worked example mods
  covering the three tiers, an in-game console with an event tracer, and content hot reload.
- Telemetry: a bot player with six policies, a sweep across presets, player counts and
  seeds, and `tools/telemetry_summary.py` to read the result.
- One-command builds: `./build.sh` fetches its own pinned Godot and export templates and
  produces a single self-contained executable, with nothing to install first.

### Public mod API

Additive, so mods written against the schemas keep working:

- `product.sealed` — `card_set`, `form`, `packs`. Required on any product whose category is
  `sealed_product`, which is what lets a mod's set be sold and opened like the base game's.
- `sealed_open_attempted` — a new cancellable event, fired before a sealed unit is opened,
  carrying the product, the set, the pack count and the shelf price.

### Notes

`v0.1.0-playtest.1` is the first tagged build, published as a pre-release so that
playtesters can download and run it. It is a snapshot for testing, **not** a release of
the public mod API — schemas and event names may still move without a major version
until `v1.0.0`. See [ROADMAP.md](ROADMAP.md) for what is and is not finished, and
[HANDOFF.md](HANDOFF.md) for what most needs a human to look at.

[Unreleased]: https://github.com/phififofum/ope/commits/main
