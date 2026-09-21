# ADR-0005 · The base game ships as a mod and holds no privileges

- **Status:** Accepted
- **Date:** 2026-09-20
- **Affects:** [02 Architecture](../design/02-architecture.md), the modding SDK, every content system

## Context

Every game that advertises deep modding and delivers a shallow version fails the same way:
the base content gets a fast path. It is loaded from a different place, validated differently,
or allowed to reference internals that mods cannot. Nobody decides this — **it accretes under
deadline pressure**, one shortcut at a time, and by the time anyone notices, the modding
system is a marketing claim.

[Pillar 3](../design/01-vision.md#design-pillars) says the skeleton outranks the content. That
needs a test that fails loudly.

## Decision

**The base game is the first mod.** [`content/`](../../content/) has a manifest, definitions
and schemas identical in form to any community mod, loads through the same loader, and is
subject to the same validation, the same namespacing rules and the same error handling.

Concretely:

- `content/manifest.json` has the same shape any mod's manifest has.
- Base ids are namespaced `base:` exactly as a mod's are namespaced by its own id. The
  validator rejects an unnamespaced id in base content.
- Base definitions are validated by the same
  [`tools/validate_content.py`](../../tools/validate_content.py) that validates mods, in the
  same run.
- A mod may override or patch any base definition by id.
- **No system may name a specific content id in code.** Systems query the registry by type
  and tag.

## Consequences

### What gets better

- The modding system cannot quietly rot, because breaking it breaks the base game first.
- Content authoring for the base game *is* modding practice, so the SDK gets exercised every
  day by the people best placed to notice its rough edges.
- A modder's mental model is the developers' mental model — one loader, one schema set, one
  error format.

### What gets worse

- Base content cannot take shortcuts that would sometimes be convenient: no hardcoded
  references, no bypassing validation for a quick prototype, no "just this once" special case.
- Some engine-level features must be expressed as data even where code would be shorter.
- Load-order and override semantics must be correct from Phase 1, before anything needs
  them.

### What this commits us to

- The Phase 1 gate includes: *a test mod adds a product, overrides a base product, and
  vetoes a `sale_attempted` event — with no engine code changed.*
- Any pull request that gives base content a privileged path is rejected on sight; it is
  [one of the five rules](../../CONTRIBUTING.md#the-five-rules).
- If a new content type cannot be expressed as data, **the architecture has drifted and gets
  corrected before more content is authored on top of it.**

## Alternatives considered

| Option | Why it lost |
| --- | --- |
| Base content compiled in, mods layered on top | Faster to start, and the exact failure mode described above |
| A privileged "core" set plus a moddable layer | The line moves. It always moves. |
| Mods as scripts only, no data layer | Excludes the data modder — the tier that determines whether a community forms at all |
