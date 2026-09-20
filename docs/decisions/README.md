# Architecture decision records

[← Docs](../README.md)

An ADR records **a decision, its context, and what it costs** — so that six months later
nobody has to re-derive the reasoning, and nobody re-litigates a settled argument from
scratch.

## When to write one

Write an ADR when you:

- resolve an ambiguity the [specification](../design/README.md) does not cover;
- **deviate** from the specification (this one is not optional — it is the whole reason the
  spec can be treated as a starting position rather than a cage);
- change the public mod API — schemas, event names, event payloads;
- pick one of several reasonable technical options where the loser is not obviously wrong.

Do **not** write one for ordinary implementation choices that the next person could change
freely without consequences.

## How

1. Copy [`0000-template.md`](0000-template.md).
2. Number it sequentially. Never renumber an existing ADR.
3. Link it from the specification section it affects, and from the pull request.
4. **ADRs are immutable once merged.** To change a decision, write a new ADR that
   supersedes the old one, and mark the old one superseded with a link forward.

## Status values

| Status | Meaning |
| --- | --- |
| **Proposed** | Under discussion, not yet acted on |
| **Accepted** | In force |
| **Superseded by ADR-NNNN** | Replaced. The old record stays, because the reasoning is still useful. |
| **Rejected** | Considered and declined. Kept so it is not re-proposed blind. |

## The record

| # | Decision | Status |
| --- | --- | --- |
| [0001](0001-engine-godot.md) | Build on Godot 4.7, not Unity | Accepted |
| [0002](0002-setting-board-game-cafe.md) | The setting is a late-night board game cafe | Accepted |
| [0003](0003-project-name-poggywoggy.md) | The project is named PoggyWoggy | Accepted |
| [0004](0004-licensing-mit-and-cc-by.md) | Code MIT, content and assets CC BY 4.0 | Accepted |
| [0005](0005-base-game-ships-as-a-mod.md) | The base game ships as a mod and holds no privileges | Accepted |
| [0006](0006-steam-as-the-test-distribution-channel.md) | Steam is the test distribution channel, via SteamPipe from CI | Accepted |
