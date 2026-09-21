# ADR-0004 · Code under MIT, content and assets under CC BY 4.0

- **Status:** Accepted
- **Date:** 2026-09-20
- **Affects:** [LICENSING.md](../../LICENSING.md), [CONTRIBUTING.md](../../CONTRIBUTING.md), the asset pipeline, CI

## Context

[Pillar 5](../design/01-vision.md#design-pillars) — *free as in freedom, all the way down* —
needs to become a specific pair of licences before the first outside contribution arrives.
Changing this later, once the contributor list is long, requires every contributor's consent,
so it is cheap now and expensive in a year.

Two further constraints: upstream asset sources are overwhelmingly CC0 and CC BY, and the
project wants the verification engine to be genuinely reusable by people building something
else.

## Decision

- **Code** — `core/`, `systems/`, `ui/`, `tools/`, `tests/` — under **MIT**.
- **Content definitions, schemas, design documentation and original assets** under
  **CC BY 4.0**.
- **Third-party assets** under their own licences, restricted to **CC0, CC BY and OFL**, each
  recorded in a `.license.json` sidecar beside the file.
- **No CLA.** Contributors keep their copyright and license their work under the above.

Enforced rather than intended: [`tools/licence_audit.py`](../../tools/licence_audit.py) fails
CI on a missing sidecar or a disallowed licence, and generates
[`CREDITS.md`](../../CREDITS.md) from the sidecars so attribution cannot drift.

## Consequences

### What gets better

- MIT keeps the engine code maximally reusable, including by people who want to build a
  different gatekeeping game out of the verification engine. That is a *good* outcome, not a
  leak.
- CC BY travels well between creative projects and matches what upstream sources already
  use, so incoming assets need no relicensing gymnastics.
- Attribution is machine-checked, which means the promise survives contact with a deadline.

### What gets worse

- **MIT permits a proprietary fork.** Someone can take this engine, close it, and ship. That is
  an accepted cost: the alternative (GPL) would make the code less reusable in exactly the
  cases we want to enable, and a fork that adds nothing competes badly with the original
  anyway.
- **CC BY-SA and CC BY-NC assets are unusable**, which excludes a meaningful slice of
  Freesound and a lot of otherwise good material. The audit tool enforces it, so the cost is
  paid at ingest rather than at release.
- Attribution is a permanent obligation: every shipped asset needs a correct record, forever.

### What this commits us to

- Every asset carries a sidecar. No exceptions, no "we'll swap it later".
- `CREDITS.md` is generated, never hand-edited.
- Mods are held to the same standard, and the mod manager surfaces a mod's licence summary
  to players.

## Alternatives considered

| Option | Why it lost |
| --- | --- |
| GPL-3.0 for code | Strong protection against proprietary forks, but it would block the reuse we actively want, and it complicates shipping on a store alongside proprietary platform SDKs |
| CC0 for everything | Maximal freedom, no attribution — but attribution is how a small project accumulates credit, and upstream CC BY sources would still need records anyway |
| CC BY-SA for content | Viral in a way that conflicts with MIT code and makes mixed-media assets ambiguous |
| Proprietary code, free assets | Contradicts pillar 5 outright |

**This is a decision, not a law of nature.** While the contributor list is short, the project
owner can change it with one superseding ADR.
