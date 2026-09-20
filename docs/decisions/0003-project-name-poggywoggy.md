# ADR-0003 · The project is named PoggyWoggy

- **Status:** Accepted
- **Date:** 2026-09-20
- **Affects:** every document, the repository, the eventual store page

## Context

The project has been called **BODEGA** (while it was a corner shop) and then **TABLE
STAKES** (a working title adopted when
[the setting moved to a board game cafe](0002-setting-board-game-cafe.md)). Neither had
been committed to. Other candidates on the table: *Double Sleeve*, *Mint Condition*, *Nine
Lives Games*, *The Back Table*, *Last Call Games*.

Two of those names describe the *mechanic* (TABLE STAKES, Double Sleeve) and one
described a *setting we no longer have* (BODEGA). A name that describes the mechanic
promises a serious game about risk; the actual room is warm, loud, slightly sticky, and has a
cat on the counter.

## Decision

The game and the project are called **PoggyWoggy** — one word, two capitals.

In fiction, it is the name on the sign, and the previous owner is not around to explain it.
That is load-bearing: [the onboarding premise](../design/10-onboarding-and-interface.md) is
that you have inherited a place full of someone else's decisions, and **a name you would not
have chosen is the first of them.**

## Consequences

### What gets better

- It is searchable, unclaimed in this space, and short.
- It sets the tone honestly: warm with a dry edge, which is
  [the default answer to the tone question](../design/15-risks-and-non-goals.md#open-questions).
  A player who expects a bleak border-post sim from the title would be mis-sold; the game is
  funnier than that and more forgiving than that.
- It gives the fiction a free joke that the tutorial can use rather than explain.

### What gets worse

- It says nothing about what the game *is*. Every piece of marketing copy has to carry that
  weight — the store page needs a subtitle doing real work, and this document's first
  sentence is that subtitle.
- It is harder to spell out loud than *Table Stakes*.
- Existing material carrying the old names is now wrong. Where a document still says BODEGA
  or TABLE STAKES, **the current specification wins and the old label is not content.**

### What this commits us to

- `PoggyWoggy` in prose, `poggywoggy` in identifiers, package names and URLs.
- The in-fiction cafe shares the name, and the sign is a prop the player can look at.
- The repository is still called `ope`; renaming it is a one-click change the owner can make,
  and GitHub redirects the old URL.

## Alternatives considered

| Option | Why it lost |
| --- | --- |
| TABLE STAKES | Accurate, professional, and promises a colder game than this is. Also crowded as a title. |
| BODEGA | Names a setting the project no longer has |
| Double Sleeve · Mint Condition | Legible only to people already in the hobby; both read as card-only, hiding three of four loops |
| Nine Lives Games · The Back Table · Last Call Games | Pleasant, generic, and forgettable — each sounds like a real shop rather than a game about one |
