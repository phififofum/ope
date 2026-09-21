<!--
Thank you for this. A few notes before you delete this comment:

  · Keep the PR small and single-purpose. A 40-line PR gets reviewed today.
  · Draft PRs are welcome — mark it draft rather than apologising in the description.
  · Every box below is a real check, not ceremony. If one does not apply, strike it
    through and say why in one line. An honest "not done, here's why" reviews faster
    than a tick that turns out to be optimistic.
-->

## What this changes

<!-- One paragraph. What a reader needs to know before looking at the diff. -->

Closes #

## Why

<!-- The diff says what. This section says why — the problem, not the patch. -->

## Type of change

- [ ] `feat` — new capability
- [ ] `fix` — something was wrong
- [ ] `content` — definitions, schemas or data
- [ ] `docs` — documentation only
- [ ] `test` / `ci` / `build` / `chore` — plumbing
- [ ] `refactor` / `perf` — behaviour unchanged

## Spec alignment

<!--
Name the spec document and heading this implements, or the one it departs from.
Unexplained deviation from the spec is the main reason a PR stalls.
-->

- Spec reference:
- [ ] This follows the spec as written
- [ ] This **deviates** from the spec — recorded in an ADR under `docs/decisions/`, linked here:
- Work-order phase: <!-- 0–9; work from a later phase is not merged early -->

## How this was verified

<!--
Facts, not intentions. "Validator passes on 62 definitions" is a fact.
"Should be fine" is not. Paste the command and the result.
-->

```bash
python3 tools/validate_content.py
python3 tools/licence_audit.py --check
```

## The five rules

- [ ] No binary `.tscn` or `.res` — text formats only, every diff reviewable
- [ ] No hardcoded game values in scripts — anything a designer or modder might tune lives in JSON
- [ ] No privileged path for base content — it loads through the same loader, schemas and registry as any mod
- [ ] No test disabled, skipped or weakened to make the pipeline green
- [ ] Every new asset has a `.license.json` sidecar with an allowed licence, and `CREDITS.md` was regenerated

## Checklist

- [ ] Commits follow [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/)
- [ ] Every player-visible string is a `loc:` key, not a literal
- [ ] Docs updated if behaviour or data shape changed
- [ ] `CHANGELOG.md` updated under `[Unreleased]` (skip for docs-only and internal chores)
- [ ] No new colour-only signal — every colour-carried cue has a shape, pattern or text equivalent

## Public mod API

<!-- Definition schemas, event names, event payloads. Leave the second box ticked if untouched. -->

- [ ] This changes the public mod API — the change and its version impact are described above
- [ ] This does not touch the public mod API

## Screenshots / recordings

<!-- Anything visual, once there is something to see. Before and after, ideally. -->

## Notes for the reviewer

<!-- Where to start, what you are unsure about, what you would like a second opinion on. -->
