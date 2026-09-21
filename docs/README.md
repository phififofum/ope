# Documentation

Everything written down about PoggyWoggy, arranged by what you came here to do.

> [!NOTE]
> The project is in **design stage**. Documents in `design/` describe what is *specified*,
> not what is *built*. [ROADMAP.md](../ROADMAP.md) is the honest status.

## By task

| I want to… | Read |
| --- | --- |
| Understand the game | [design/01-vision.md](design/01-vision.md) |
| Understand the code before writing any | [design/02-architecture.md](design/02-architecture.md) |
| Add content or write a mod | [modding/README.md](modding/README.md) |
| Look up a definition type's fields | [modding/definition-types.md](modding/definition-types.md) |
| Know why something is the way it is | [decisions/](decisions/) |
| Decode a term | [glossary.md](glossary.md) |
| See what happens next, in what order | [design/14-work-order.md](design/14-work-order.md) |
| Cut a build for playtesters, without a terminal | [release/playtest.md](release/playtest.md) |
| Build and ship a test build to Steam | [release/steam.md](release/steam.md) |

## The specification

Seventeen documents, numbered in reading order. Full index and reading advice:
**[design/README.md](design/README.md)**.

The three that are load-bearing — where a mistake is expensive and a shortcut is fatal —
are [02 Architecture](design/02-architecture.md),
[13 Testing and verification](design/13-testing-and-verification.md), and
[14 The work order](design/14-work-order.md).

## Conventions in these documents

- **Present tense describes the design**, not the software. "The director schedules
  encounters" means that is how it is specified to work.
- **Bold is for load-bearing statements** — the ones that change what you build.
- Numbers are targets, not measurements, until Phase 9 replaces them with telemetry.
- Where a document says *must*, *never* or *non-negotiable*, it is reporting a rule that has
  a cost attached and a reason recorded.
