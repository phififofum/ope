# ADR-0006 · Steam is the test distribution channel, via SteamPipe from CI

- **Status:** Accepted
- **Date:** 2026-09-20
- **Affects:** [14 The work order](../design/14-work-order.md), `export_presets.cfg`, `steam/`, `.github/workflows/release.yml`, [the Steam guide](../release/steam.md)

## Context

Testers need builds they can install without being handed a zip and an explanation. Steam
handles installation, updates, crash-free distribution to Windows and Linux, and branch
access control — and it is where the game would ship anyway.

The question was *when*. The instinct is to wire up distribution once there is something
worth distributing, at [Phase 2](../design/14-work-order.md#phase-2--vertical-slice). That
instinct is wrong in a specific way: **a distribution pipeline that has never run is a
pipeline that does not work.** Export presets omit a runtime-read file, depot mappings miss
the `.pck`, credentials turn out to be wrong — all of it discovered on the day the first
playable build exists, which is the worst possible day.

## Decision

**Ship the release pipeline in Phase 0, and prove it with a build that does almost nothing.**

Phase 0's gate now includes exporting Linux and Windows from a clean checkout and
uploading the result to a Steam branch. What gets uploaded is a boot screen that loads the
content registry and reports what it found — deliberately trivial, and sufficient to prove
the whole chain end to end.

Three things are deliberate about the setup:

1. **The engine is fetched by pinned URL in CI**, not through a wrapper action, so the
   commands in CI are exactly the commands in
   [the guide](../release/steam.md#building-locally) and a CI failure reproduces on a laptop.
2. **A build is never set live automatically.** `setlive` is empty in `app_build.vdf`, and CI
   uploads to a `playtest` branch. Setting a build live is a human action in the Steamworks
   web UI.
3. **The Steam job skips rather than fails when secrets are absent**, and is restricted to
   this repository's owner, so a fork or a contributor's tag cannot publish anything.

The exported build is smoke-tested in CI *as an exported binary*, not as a project. That
catches the single most common packaging failure: a file read at runtime that is missing
from `include_filter`.

## Consequences

### What gets better

- Distribution is a solved problem before it is an urgent one.
- Testers get one-click installs and automatic updates from Phase 2 onward.
- The export path is exercised on every tagged build, so packaging regressions surface
  within a commit or two of being introduced rather than at release.

### What gets worse

- Phase 0 grew: a real `project.godot`, a boot scene, export presets, depot scripts and a
  release workflow, before any gameplay exists.
- A Steamworks app, depots and a dedicated builder account are now prerequisites for the
  full pipeline — though everything except the upload step works without them.
- CI downloads the engine and export templates (~1.4 GB) on a cache miss, which makes a
  cold release run slow.

### What this commits us to

- `include_filter` in `export_presets.cfg` stays in sync with everything read at runtime —
  content JSON above all. **Adding a runtime-read file type without updating it is a bug that
  only appears in exported builds.**
- No Steamworks SDK in the game. `NetTransport` keeps Steam networking a later swap-in, and
  the mod manifest is Workshop-compatible from day one; neither is v1 work.
- Store-page obligations get handled honestly when the page goes public: the
  [simulated gamble](../design/06-loop-d-case.md) is disclosed, and **there are no
  real-money purchases of any kind**.

## Alternatives considered

| Option | Why it lost |
| --- | --- |
| Wire up Steam at Phase 2, when there is something to play | The pipeline's first run would be on the day it is most needed. Every failure mode above is discovered under pressure. |
| itch.io, or zips over Discord | Fine for a handful of testers; no automatic updates, no branch control, and it does not exercise the path the game actually ships on |
| GitHub releases only | Already done — CI attaches both builds to a draft release. It is a good backstop, not a way for non-technical testers to install a game. |
| Automate "set live" on the default branch | One bad merge reaches players at 2am |
