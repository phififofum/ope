# AGENTS.md

Instructions for any agent — or any human in a hurry — working in this repository.
Everything here is the short form of [CONTRIBUTING.md](CONTRIBUTING.md); where they
disagree, CONTRIBUTING.md wins.

## Before you change anything

1. Read [docs/design/14-work-order.md](docs/design/14-work-order.md). **Phases are
   sequential and gated.** Work from a later phase does not get merged early.
2. Read the spec section for what you are touching —
   [docs/design/README.md](docs/design/README.md) is the index.
3. Check [ROADMAP.md](ROADMAP.md) for what is actually built versus specified.

## Run these before you claim anything works

```bash
python3 tools/check_repo_hygiene.py
python3 tools/validate_content.py --strict
python3 tools/licence_audit.py --check
python3 tools/check_doc_links.py
pre-commit run --all-files

godot --headless --path . --import
godot --headless --path . -- --smoke-test
```

**"It compiles" is not done. "It has a test that exercises it through the real scene tree"
is done.**

## The rules that get a change reverted

1. No binary `.tscn` or `.res`. Text formats only — every diff must be reviewable.
2. No hardcoded game values in scripts. If a designer or modder might tune it, it lives in
   JSON.
3. No privileged path for base content. It loads through the same loader, schemas and
   registry as any mod.
4. No test disabled, skipped or weakened to make the pipeline green. Fix it or revert.
5. No asset without a `.license.json` sidecar naming a CC0 or CC BY licence.
6. No player-visible string as a literal. `loc:` keys only.
7. No forgery vector the player cannot catch with a tool available at its tier. CI enforces
   this; it is a fairness rule, not a balance one.
8. No tool that returns a verdict. Tools reveal; players judge.

## When the spec is ambiguous

Apply the [design pillars](README.md#design-pillars) **in order**, decide, and record it as
an [ADR](docs/decisions/README.md). **Do not stall, and do not deviate silently.**

## When the spec is wrong

Deviate, and write the ADR. It is a starting position, not a cage.

## Conventions

- GDScript: full static typing, `class_name` on every script, formatted with `gdformat`.
- Python: ruff, line length 100.
- Commits: [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/).
- Ids: namespaced and snake_case — `base:` for shipped content.
