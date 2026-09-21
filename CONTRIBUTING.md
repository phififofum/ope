# Contributing to PoggyWoggy

Thanks for being here. This document is the whole contract: what to work on, how to work on
it, and what will get a pull request sent back.

Everyone participating agrees to the [Code of Conduct](CODE_OF_CONDUCT.md).

Working with an agent, or want the rules in one screen? [AGENTS.md](AGENTS.md).

---

## Contents

- [Where the project is right now](#where-the-project-is-right-now)
- [Ways to contribute](#ways-to-contribute)
- [Before you write code](#before-you-write-code)
- [Development setup](#development-setup)
- [The five rules](#the-five-rules)
- [Workflow](#workflow)
- [Commit messages](#commit-messages)
- [Pull requests](#pull-requests)
- [Adding content](#adding-content)
- [Adding assets](#adding-assets)
- [Writing docs](#writing-docs)
- [Recording a decision](#recording-a-decision)
- [Labels](#labels)
- [Licensing your contribution](#licensing-your-contribution)

---

## Where the project is right now

**Phase 0 — Foundation.** No game code is committed yet. The specification is written, the
content data model is real and validated in CI, and the scaffolding is in place.

That shapes what is useful. Ranked, today:

1. **Design review.** Read a spec document, find the place where it contradicts itself or
   cannot be built, and open a [design proposal](https://github.com/phififofum/ope/issues/new?template=design_proposal.yml).
   Finding a hole now costs an hour; finding it in Phase 6 costs a month.
2. **Content definitions.** Products, recipes, document types, forgery vectors, cats. These are
   JSON, they validate locally in under a second, and they need no engine.
3. **Tooling.** `tools/` is Python and stands alone. The validator's error messages are a
   feature — improving them is real work.
4. **Docs.** Anything in `docs/` that is unclear to you is unclear, full stop.

Engine work begins when Phase 0's gate passes. Watch [ROADMAP.md](ROADMAP.md).

## Ways to contribute

| You want to | Start with |
| --- | --- |
| Report a defect in tools, content or docs | [Bug report](https://github.com/phififofum/ope/issues/new?template=bug_report.yml) |
| Argue with a design decision | [Design proposal](https://github.com/phififofum/ope/issues/new?template=design_proposal.yml) |
| Add a product, recipe, document type, forgery vector or cat | [Content definition](https://github.com/phififofum/ope/issues/new?template=content_definition.yml) |
| Report a gap in the modding API or SDK | [Modding API](https://github.com/phififofum/ope/issues/new?template=modding_api.yml) |
| Fix or improve documentation | [Docs](https://github.com/phififofum/ope/issues/new?template=documentation.yml) |
| Pick up a piece of the work order | [Build task](https://github.com/phififofum/ope/issues/new?template=build_task.yml) |
| Help get a build in front of testers | [docs/release/steam.md](docs/release/steam.md) |
| Ask a question | [Discussions](https://github.com/phififofum/ope/discussions) — see [SUPPORT.md](SUPPORT.md) |
| Report a vulnerability | **Not an issue.** See [SECURITY.md](SECURITY.md) |

## Before you write code

Three things, in this order:

1. **Open an issue first** for anything larger than a typo. A PR that arrives without a
   discussed issue may be asking for work nobody wants yet — that is a bad afternoon for you
   and an awkward review for us.
2. **Read the relevant spec section.** Every system has one, and the spec is opinionated on
   purpose. If your change contradicts it, that is fine — but say so explicitly, and
   [record the decision](#recording-a-decision).
3. **Check the phase.** Work from a later phase does not get merged early, however tempting.
   The gates exist because building content on a foundation that cannot support it is the
   single most expensive mistake available to this project.

## Development setup

**To build and play, you need nothing but the repository:** `./build.sh run` fetches the
pinned engine into `.tooling/` and produces a self-contained executable. To work on the
code you want Python 3.11+ for the tooling, and the same pinned engine on your PATH is
convenient but not required — `.tooling/godot-4.7.2/godot` works for every command below.
Do not develop against a different engine version, and do not track dev snapshots.

```bash
git clone https://github.com/phififofum/ope.git poggywoggy
cd poggywoggy

python3 -m pip install --user jsonschema pre-commit
pre-commit install          # formats and lints on every commit, exactly as CI does

python3 tools/validate_content.py       # every definition against its schema
python3 tools/licence_audit.py --check  # every asset has a valid sidecar
python3 tools/check_repo_hygiene.py     # text formats, LF, parseable JSON
python3 tools/check_doc_links.py        # every relative link resolves
```

Building and running:

```bash
./build.sh                                 # build for this machine
./build.sh all                             # Linux and Windows
./build.sh run                             # build and play

GODOT=.tooling/godot-4.7.2/godot tools/run_tests.sh          # the full suite
GODOT=.tooling/godot-4.7.2/godot python3 tools/visual_regression.py
```

These are exactly what CI runs. If they pass locally, that part of CI will pass.

### Formatting is automated, so do not argue with it

`pre-commit install` wires up every formatter and linter the project uses — **ruff** for
Python, **gdformat** and **gdlint** for GDScript, **yamllint**, **markdownlint**,
**codespell**, and the whitespace hooks. All are open source and pinned to a release in
[`.pre-commit-config.yaml`](.pre-commit-config.yaml).

```bash
pre-commit run --all-files   # everything, without committing
pre-commit autoupdate        # bump the pinned hooks, in its own PR
```

If you cannot install pre-commit locally, a maintainer can run the
[Format workflow](.github/workflows/format.yml) manually and push the fixes.

## The five rules

These come straight from the specification and a pull request that breaks one will be sent
back regardless of how good the rest of it is.

1. **Never commit a binary `.tscn` or `.res`.** Text formats only, so every diff is reviewable.
2. **Never store a hardcoded game value in a script.** If a designer or a modder might want to
   change it, it lives in JSON. ([pillar 3](README.md#design-pillars))
3. **Never give base content a privileged path.** The base game loads through the same
   loader, schemas and registry as any mod. A shortcut here kills the modding system as a
   real capability.
4. **Never disable or skip a failing test to make the pipeline green.** Fix it or revert.
5. **Never ship an asset without a `.license.json` sidecar.** CI enforces it; this rule is here
   so you do not waste a round trip finding out.

## Workflow

```text
fork → branch → change → validate locally → PR → review → squash-merge
```

- Branch from `main`. Name it `<type>/<short-description>` — `feat/component-check`,
  `fix/validator-path-reporting`, `docs/modding-quickstart`.
- Keep pull requests small and single-purpose. A 40-line PR gets reviewed today; a
  2,000-line PR gets reviewed eventually.
- Commit small and often, and keep every commit green.
- Rebase on `main` rather than merging it back in, so history stays readable.

## Commit messages

[Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/). The type prefix is
what drives the changelog.

```text
<type>(<scope>): <summary in the imperative, no trailing period>

<body: why, not what — the diff already says what>

<footer: Closes #123 / BREAKING CHANGE: …>
```

Types: `feat`, `fix`, `docs`, `content`, `test`, `refactor`, `perf`, `build`, `ci`, `chore`.
Scopes are the directory or system touched: `registry`, `counter`, `kitchen`, `modding`,
`tools`, `content`, `docs`.

```text
content(product): add six chilled beverages with adjacency affinities
fix(tools): report the JSON path, not just the file, on schema failure
docs(modding): add the 15-minute first mod walkthrough
```

Anything that changes a definition schema, an event name or an event payload is a
**breaking change to the public mod API** and must say so in the footer. See the
[compatibility policy](docs/modding/README.md#compatibility-policy).

## Pull requests

The [template](.github/PULL_REQUEST_TEMPLATE.md) fills itself in as a checklist. Beyond that:

- **Link the issue.** `Closes #123`.
- **Say what you verified, and how.** "Validator passes" is a fact. "Should be fine" is not.
- **Describe the deviation.** If the change departs from the spec, name the section and say
  why. Unexplained deviations are the main reason a PR stalls.
- **Screenshots or recordings** for anything visual, once there is something to see.
- **Draft PRs are welcome** for early feedback — mark them draft rather than apologising in
  the description.

A maintainer reviews within a week. If it has been longer, a nudge in the thread is welcome
and not rude.

## Adding content

Content is JSON validated against a schema. The full walkthrough is in
[docs/modding/README.md](docs/modding/README.md); the short version:

1. Find the definition type in [docs/modding/definition-types.md](docs/modding/definition-types.md).
2. Copy the nearest existing file in `content/definitions/<type>/` and edit it.
3. Every id is namespaced: base content uses `base:`, mods use `<modid>:`.
4. Every player-visible string is a `loc:` key, never a literal. No exceptions — localisation
   is not retrofittable.
5. Run `python3 tools/validate_content.py`.

Content quality gates (the validator checks the mechanical ones; review checks the rest):

- Schema-valid with zero warnings.
- Every product reachable through some licence; every licence unlocks something.
- Every document type has at least three distinct forgery vectors, spanning all three
  [kinds of wrong](docs/design/04-loop-b-counter.md#the-three-kinds-of-wrong).
- Every forgery vector detectable by at least one tool available at the tier it appears.
  **A forgery the player cannot possibly catch is a bug, not difficulty.**
- Every recipe completable with ingredients purchasable at that stage.
- No product strictly dominated by another at the same tier.

## Adding assets

Sources must be **CC0 or CC BY**. Not CC BY-NC, not CC BY-SA, not "found it on a site that
seemed fine". Preferred sources are listed in
[docs/design/11-art-audio-licensing.md](docs/design/11-art-audio-licensing.md).

Every asset file gets a sidecar next to it:

```json
{
  "file": "content/assets/props/display_case.glb",
  "source": "https://kenney.nl/assets/...",
  "author": "Kenney",
  "license": "CC0-1.0",
  "retrieved": "2026-09-20",
  "modifications": "retextured, UVs adjusted"
}
```

Then run `python3 tools/licence_audit.py --write` to regenerate [`CREDITS.md`](CREDITS.md)
and commit both. Never hand-edit `CREDITS.md`.

> **The Freesound trap.** Freesound licences per *sound*, not per site. Roughly half the
> catalogue is CC0 and the rest is CC BY or CC BY-NC. Check the individual sound. The audit
> tool refuses anything that is not CC0 or CC BY, which is the backstop, not the process.

## Writing docs

- Write in the same register as the spec: direct, opinionated, no hedging, no marketing.
- Say what is **specified** versus what is **built**. Present tense in `docs/design/` describes
  the design, not the software. If you describe unbuilt behaviour anywhere else, label it.
- One idea per heading, and headings that answer a question the reader actually has.
- Link sideways. A reader who lands mid-document should be one click from context.
- Every code sample must be one that runs. A snippet that has not been executed is a bug
  report waiting to be filed.

## Recording a decision

When you resolve an ambiguity the spec does not cover, or deviate from it, write an
[ADR](docs/decisions/README.md). It is short — context, decision, consequences — and it is
how the project avoids re-litigating the same argument in six months.

Copy [`docs/decisions/0000-template.md`](docs/decisions/0000-template.md), number it
sequentially, and link it from the section it affects.

## Labels

Labels are defined in [`.github/labels.yml`](.github/labels.yml) so they are reviewable like
anything else. The ones worth knowing:

| Label | Means |
| --- | --- |
| `good first issue` | Self-contained, well-specified, no hidden context |
| `help wanted` | Maintainers are not working on this and would like someone to |
| `loop:a` `loop:b` `loop:c` `loop:d` | Which gameplay loop it touches |
| `area:*` | `registry`, `modding`, `netcode`, `content`, `tools`, `docs`, `a11y` |
| `phase:0`–`phase:9` | Which [work-order phase](docs/design/14-work-order.md) it belongs to |
| `spec-deviation` | Departs from the design brief; needs an ADR |
| `blocked-by-gate` | Correct work, wrong phase — parked until the gate passes |

## Licensing your contribution

By contributing you agree that your work is licensed under the project's licences:

- **Code** under [MIT](LICENSES/MIT.txt).
- **Content, docs and original assets** under [CC BY 4.0](LICENSES/CC-BY-4.0.txt).

There is no CLA. Keep your copyright. If you would like to be named, add yourself to
[`tools/credits_sources.json`](tools/credits_sources.json) and run
`python3 tools/licence_audit.py --write` in the same PR — [`CREDITS.md`](CREDITS.md) is
generated and never hand-edited.
