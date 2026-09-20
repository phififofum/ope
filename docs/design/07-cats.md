# 07 · Cats

[← Loop D](06-loop-d-case.md) · [Index](README.md) · [Next: Progression and staff →](08-progression-and-staff.md)

---

**The cats are a mechanical pillar, not set dressing.** The real-world shop cat exists for a
reason — rodent control — and that reason connects directly to two systems the game already
has. Building them as a cosmetic pet would waste the best idea in the design.

## The three jobs

### 1. Pest control

Rats are a genuine failure vector in [Loop A](03-loop-a-floor.md). They are attracted by
rubbish, spilled food, expired stock and kitchen waste; **they chew through cardboard** —
which, in a room holding four hundred board games and a case of singles, is a much sharper
threat than it would be in a grocery store — and they are an automatic fail on a health
inspection.

A cat patrols, hunts, and suppresses the rat population on a real timer. A room with no cat
needs traps and exterminator visits, which cost money and are strictly worse. **The cat is the
best answer to a real problem, which is what makes adopting one feel earned rather than
given.**

### 2. Counter assistance

A bonded cat sitting on the counter reacts to people. Not with a verdict — see
[the tool contract](04-loop-b-counter.md#the-tool-contract) — but with a **tell**. Tail flick,
flattened ears, the slow stare, leaving the counter entirely.

Cats respond to elevated nervousness and hostility in the encounter's hidden state, and
different cats have different sensitivities and different false-positive rates. A twitchy cat
that hisses at everyone is useless; a calm one that only reacts to real trouble is the best tool
in the building. **Crucially the cat is noisy data — it points attention, it never resolves.**

### 3. Reputation and regulars

Customers notice the cat. Some come specifically for the cat. A well-kept, visible cat lifts
foot traffic and customer patience measurably. A visibly neglected one does the opposite,
and a cat on the kitchen pass is a health-inspection risk — a real tension the player has to
manage rather than optimise away.

## Adoption

Cats are not bought. They arrive.

| Route | Trigger |
| --- | --- |
| The stray at the back door | Appears during dead hours after the first rat problem. Feed it repeatedly and it stays. |
| Shelter adoption | Unlocked at reputation tier 2. You choose from a rotating roster. |
| The customer's cat | A regular can no longer keep theirs. A story beat, and the cat comes with baggage. |
| The litter | If two cats are resident and unfixed. A mixed blessing, and a nudge toward the vet. |
| Mod-supplied | Any `cat` definition a mod adds enters the same pools |

**A room supports up to three resident cats.** Beyond two, territorial behaviour starts
costing more than the extra coverage returns — a deliberate soft cap that makes the third
cat a real decision.

## Personality as data

Each `cat` definition carries traits drawn from a weighted pool: `vigilant`, `lazy`, `skittish`,
`social`, `territorial`, `hunter`, `thief`, `vocal`, `nocturnal`, `escape_artist`.

Traits modify hunting effectiveness, counter sensitivity, false-positive rate, customer
reaction and mischief frequency. Shipped examples:
[`content/definitions/cat/`](../../content/definitions/cat/).

> An `escape_artist` will get out the front door during the evening rush and the room will
> stop while five players try to catch it. **That is not a bug to be designed out; that is the
> best five minutes of somebody's session.**

## Care

Ambient [Loop A](03-loop-a-floor.md) work with real consequences, not a nag meter.

- Food and water bowls, refilled from stock you could otherwise sell
- Litter tray — neglect it and it is a cleanliness and inspection problem
- Vet visits: shots, fixing, illness, the occasional expensive emergency
- Play and attention, which builds bonding
- Sleeping spots, scratching posts, the box on the counter

**Bonding is the progression axis.** A newly arrived cat hides, hunts poorly, and gives no
counter tells. A bonded cat patrols confidently, works the counter, and comes when called.
Bonding is **per player** in co-op — the cat has a favourite, and that is a running joke the
game should support with visible behaviour.

## Mischief

Cats generate work, which is entirely the point under
[pillar 2](01-vision.md#design-pillars). Knocked-over displays, cat on the warm register, cat
asleep in the box you need, cat on the tournament table mid-round, cat in the walk-in when
the door was open, cat bringing you a rat as a gift during a health inspection. All of these
are events on the bus and all are moddable.

## Scope discipline

**No breeding sim, no genetics, no cat-collection metagame.** Three cats, deep behaviour,
strong personality. The cats should feel like animals that live in your shop, not like a system
to be optimised.

> If the implementation finds itself building a cat stat sheet with numbers the player can
> see, it has gone wrong.
