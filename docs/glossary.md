# Glossary

[← Docs](README.md)

Terms that mean something specific here, in the order you are likely to meet them.

## The loops

**Loop A — the floor.** The substrate: library, cafe inventory, zone design, cleaning,
deliveries. Continuous and ambient. [Spec](design/03-loop-a-floor.md)

**Loop B — the counter.** Verification: documents, people, entitlements, officials. The
primary loop and the reason the game exists. [Spec](design/04-loop-b-counter.md)

**Loop C — the kitchen.** Orders, stations, timers, table service. Co-primary with B.
[Spec](design/05-loop-c-kitchen.md)

**Loop D — the case.** Sealed product, singles, authentication, grading. The gamble.
[Spec](design/06-loop-d-case.md)

**The collision.** Two or more loops demanding attention at once. Not a failure state —
**the thing the game is about.**

## Verification

**Artifact.** Anything inspectable: an ID, a note, a manifest, a receipt, a trading card, a
returned game's component list.

**Definition.** A JSON object with an `id`, a `type` and a schema-validated body. Everything
in the game is one. [Reference](modding/definition-types.md)

**Document type.** A definition describing an artifact's fields, layout and security features.
A trading card is a document type — that is deliberate.

**Forgery vector.** One named, weighted way an artifact can be wrong. Vectors are
combinatorial: one definition can apply to every document type with a given field.

**The three kinds of wrong.** *Internal inconsistency* (the artifact contradicts itself),
*external inconsistency* (it contradicts the world), *physical defect* (its construction is
wrong). Every document type needs vectors of all three.
[Spec](design/04-loop-b-counter.md#the-three-kinds-of-wrong)

**Tell.** A single ambient behavioural signal that fires when something is off. Correlated with
guilt, **never determinative of it.** Never a UI marker.

**Tier.** How far into the campaign something appears. Tools have one; forgery vectors have
one. **A vector's tier must be ≥ the tier of at least one tool that can catch it**, or the
encounter is a coin flip — enforced in CI.

**Verdict surface.** The five options at the end of an encounter: approve, decline, partial,
confiscate, call it in. **Partial should be the most-used option in skilled play.**

**Scrutiny budget.** The core resource. A shift contains more checkable material than
checkable time, so attention is continuously allocated. Reputation is how you allocate it.

**The two axes.** The artifact and the person holding it, scrutinised independently and
scaling against each other.

**The long con.** A seller who builds genuine trust over many honest transactions before the
one that matters. Rare by design — if common, the mechanic curdles.

**The innocent middleman.** Someone selling a fake they bought in good faith. Honest, clean
record, real counterfeit. Correct play is refusing and explaining why.

**Rule accretion.** The real difficulty curve: the number of rules you must remember grows
while the time to apply them does not.
[Spec](design/04-loop-b-counter.md#rule-accretion--the-real-difficulty-curve)

**The binder.** The in-world reference, generated from the same definitions that enforce the
rules, so it cannot drift — and mod content appears in it automatically.

**The ledger.** The persistent record of people: photos, history, flags, your own notes. Turns
strangers into recognisable faces.

## Systems

**ContentRegistry.** The typed, queryable store every definition lands in at boot. Systems
query it by type and tag; **no system ever names a content id in code.**

**Event bus.** The only permitted cross-system communication. Notification, query and
cancellable events. Mods get the same bus and the same veto power.

**Director.** Schedules encounters against a tension curve instead of rolling dice. Load-aware,
streak-aware, and fully data-driven — "brutal mode" is a JSON file, not a fork.

**Tick.** The fixed 20 Hz logic step, decoupled from framerate. With seeded RNG streams it
makes a session reproducible from a save plus an input log.

**Seeded RNG stream.** A named random source (`spawn`, `forgery`, `cat_mood`, `breakage`)
so that determinism survives across systems.

**Bot player.** A scripted agent that plays through the real input layer. Not good at the game
— a liveness and progression probe. [Spec](design/13-testing-and-verification.md#4-the-bot-player)

## Progression

**Money, reputation, standing.** Three currencies, deliberately not convertible. Money buys
things; reputation buys customers; standing buys permission.

**Strike.** A compliance failure, tracked per licence. Three suspends the licence. Strikes
decay with clean operation and **cannot be bought off.**

**Undercover.** A compliance authority testing you. Late in the campaign, indistinguishable
from an ordinary customer — **the only defence is consistent process.**

**The audit loop.** Late-game verification turned inward: finding staff mistakes through
footage, reconciliation and variance. Same verb, new object.

## Modding

**Base game as a mod.** The rule that `content/` holds no privileges.
[ADR-0005](decisions/0005-base-game-ships-as-a-mod.md)

**Namespace.** The prefix on every id — `base:` for shipped content, the mod's own id for
mod content. What stops two mods colliding.

**Add / override / patch / extend.** The four ways to change the game.
[Guide](modding/README.md#four-ways-to-change-the-game)

**`affects_gameplay`.** The manifest flag that decides whether a mod mismatch blocks a
multiplayer join or merely warns.

**Sidecar.** The `.license.json` file beside every asset recording source, author, licence and
modifications. Missing one fails the build.

## Process

**Phase and gate.** The ten sequential build phases, each with a CI-verified gate. **No work
from a later phase begins early.** [Work order](design/14-work-order.md)

**ADR.** An architecture decision record: the decision, its context, and what it costs.
[Index](decisions/README.md)

**Pillar.** One of the five design principles, applied **in order** to break ties.
[Spec](design/01-vision.md#design-pillars)
