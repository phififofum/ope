# 15 · Risks, non-goals and open questions

[← The work order](14-work-order.md) · [Index](README.md) · [Next: Post-v1 roadmap →](16-post-v1-roadmap.md)

---

## Risks, ranked by what would actually sink this

| Risk | Why it matters | Mitigation |
| --- | --- | --- |
| **Scope.** v1.0 as specified is a large commercial game. | The most likely failure by a wide margin. | [Phase gates](14-work-order.md) mean a stop at any phase leaves something coherent and shippable. Phase 2 is a complete small game. |
| **The skeleton gets compromised under pressure.** | Everything in [12](12-content-manifest.md) depends on [02](02-architecture.md) holding. A shortcut in Phase 1 is discovered in Phase 6. | Phase 1's gate is non-negotiable. The base-game-as-mod rule makes violations visible. |
| **Blindness to feel.** | Tests prove it runs, not that it is fun. Pacing, weight and readability cannot be unit-tested. | Bot player and telemetry get close; visual regression closes part of it. **Accept that Phase 8 needs human eyes. Plan to play at Phase 2 and Phase 5 regardless.** |
| **Verification becomes tedious.** | If checking an ID is a chore rather than a thrill, the whole thesis collapses. | Tools must feel good. Encounter frequency must vary. Partial verdicts keep it from being binary. Tune on telemetry. |
| **CC0 assets read as asset-flip.** | Real reputational risk for the finished game. | The [retexture and kitbash pass](11-art-audio-licensing.md#the-asset-flip-risk) is a scheduled phase, not a stretch goal. Procedural documents help enormously. |
| **Multiplayer desync.** | Hard to debug, and it arrives late. | Determinism and seeded RNG from Phase 1 make it reproducible. Five-client headless tests run from Phase 4. |
| **Content authoring stalls.** | Hundreds of definitions is a lot of judgement calls. | Schemas frozen before Phase 6. Generate in batches against the validator. Quality gates catch drift. |

## Explicit non-goals for v1.0

Stated so nobody wanders into them:

- **No procedural city, no driving, no leaving the premises** beyond the immediate frontage
- **No combat.** A robbery is a tense scripted event you survive, not a fight you win.
- **No romance, no dating sim**, no dialogue trees beyond transactional exchange
- **No cat breeding or collection metagame**
- **No console or mobile ports, no web build**
- **No dedicated servers, no matchmaking, no host migration**
- **No real brands, real currencies, real jurisdictions, real publishers, or reproductions of
  real identity documents or real trading cards.** Everything is fictional-but-plausible.
  **This is a legal requirement as much as a design one.**
- **No microtransactions, no live service, no battle pass, no loot boxes** — and, given
  [Loop D](06-loop-d-case.md), **no real-money purchases of any kind**
- **No in-game voice chat**
- **No telemetry that leaves the machine without consent**

## Open questions

None of these block the build — there is a default for each — but they are the decisions
where a human preference beats a reasonable guess. Answer them by opening a
[design proposal](https://github.com/phififofum/ope/issues/new?template=design_proposal.yml)
and they become [ADRs](../decisions/README.md).

| # | Question | Default if unanswered |
| --- | --- | --- |
| 1 | **Setting specificity.** A fictional city that reads as New York, or a deliberately unplaceable generic one? Affects art, dialogue and document design. | Fictional city, strong NYC flavour, no real names |
| 2 | **Tone.** Warm and comedic, or dry and slightly bleak? Both work, and they produce different games. | Warm with a dry edge — the humour comes from the situations, not from jokes |
| 3 | **Failure severity.** Can you lose the shop outright, or is the floor a bad week you dig out of? | No permanent loss in the standard campaign; permadeath as a challenge mode |
| 4 | **Session length.** Is a session a day, a week, or open-ended? Affects save granularity and co-op scheduling. | A day is a natural stopping point; saves are continuous |
| 5 | **How grey is the grey market?** The Act IV thread can be mild (unlicensed suppliers) or dark (knowingly handling stolen goods). | Mild-to-moderate — real stakes, no criminal fantasy |
| 6 | **How much of the cafe's drinks programme is alcohol?** Changes the carding profile of an entire shift. | Beer and wine only; the late-hours door does the heavy carding |
