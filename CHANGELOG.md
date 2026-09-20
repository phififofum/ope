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

### Notes

No release has been tagged. There is no playable build yet — see [ROADMAP.md](ROADMAP.md)
for what phase the project is in.

[Unreleased]: https://github.com/phififofum/ope/commits/main
