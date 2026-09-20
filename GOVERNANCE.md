# Governance

Small project, plain rules. This document exists so that nobody has to guess who decides
what, and so that the answer does not change depending on who is asking.

## Roles

| Role | How you get it | What it means |
| --- | --- | --- |
| **Contributor** | Open a PR that gets merged | Your name in `CREDITS.md` |
| **Reviewer** | Invited after sustained, good review on an area | Your review can approve PRs in that area |
| **Maintainer** | Invited by existing maintainers, by consensus | Merge rights, release rights, listed in [`CODEOWNERS`](.github/CODEOWNERS) |
| **Project lead** | The repository owner | Final call when consensus does not arrive, and the tiebreak on design |

Roles are earned by work and given away as fast as they are earned. If you are reviewing
well in one area, expect to be asked.

## How decisions get made

1. **Ordinary changes** — one maintainer approval, CI green, merge.
2. **Design changes** — open a [design proposal](https://github.com/phififofum/ope/issues/new?template=design_proposal.yml).
   Discussion happens on the issue, in public. If it changes the specification, it lands as an
   [ADR](docs/decisions/README.md) in the same PR as the change.
3. **Public API changes** (definition schemas, event names, event payloads) — two maintainer
   approvals, an ADR, and a note in [`CHANGELOG.md`](CHANGELOG.md) under the
   [compatibility policy](docs/modding/README.md#compatibility-policy).
4. **Disagreement** — argue it in the thread. Design pillars break ties, in the order they are
   listed in the [README](README.md#design-pillars). If that does not settle it, the project
   lead decides and writes down why.

Nothing about the design is settled by seniority. "Which pillar does this serve?" is a
question anybody can ask anybody.

## What the spec is, and is not

The design brief in [`docs/design/`](docs/design/) is a **starting position, not a cage**. It is
deliberately opinionated so that work can proceed without a meeting. When it turns out to be
wrong — and it will be, somewhere — deviate, and write down what and why.

Deviating silently is the problem. Deviating with an ADR is the process.

## Releases

Semantic versioning, applied to the **public mod API**:

- **Major** — a definition schema field is removed or repurposed, or an event payload changes
  shape. Breaks mods.
- **Minor** — new definition types, new fields, new events. Existing mods keep working.
- **Patch** — fixes and content that break nothing.

Deprecated events warn for one full minor cycle before removal. The changelog follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## If the project stalls

If no maintainer has merged anything for six months, any contributor with three merged PRs
may ask to be made a maintainer, and the lead should say yes or hand the project on. The
licences ([MIT](LICENSES/MIT.txt) and [CC BY 4.0](LICENSES/CC-BY-4.0.txt)) mean a fork is
always available and always legitimate. That is the point of them.
