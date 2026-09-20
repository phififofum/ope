# 01 · Vision and pillars

[← Index](README.md) · [Next: Architecture →](02-architecture.md)

---

## The pitch

PoggyWoggy is a first-person co-op sim for 1–5 players about running a late-night board
game cafe — the kind with a wall of games to borrow, a kitchen, a card counter, and a cat
asleep on the display case. You cook, you run events, you shelve four hundred boxes, and
you stand behind the glass deciding whether the card someone just slid across it is real,
and whether the person sliding it is.

## The thesis

**Scrutiny is a budget, and you never have enough of it.**

Every session presents more things worth checking than there is time to check. Card
authenticity, condition grades, IDs at the bar, payment fraud, trade-in collections of
uncertain origin — all of it arrives while a kitchen ticket burns and a tournament needs
adjudicating.

The skill is not in checking everything. It is in knowing what to check — and that judgement
is built from two sources that reinforce each other: **what you know about cards, and what
you know about people.**

## The four loops, and their weighting

Four loops, and they are not equal. Two are why you play, one is the gamble that funds and
threatens the others, and one is the space they all happen in.

| Loop | Weight | Cadence | Player fantasy | Reference |
| --- | --- | --- | --- | --- |
| **[B — The Counter](04-loop-b-counter.md)** | Primary | Punctuated, high-attention | Catch the thing that's wrong before it costs you | Quarantine Zone, Contraband Police |
| **[C — The Kitchen](05-loop-c-kitchen.md)** | Co-primary | Bursty, escalating, dexterous | Hold a system together as it speeds up | PlateUp, Overcooked |
| **[D — The Case](06-loop-d-case.md)** | Recurring hook | Slow burn, spiky | Hope, and the bookkeeping that follows it | TCG Simulator |
| **[A — The Floor](03-loop-a-floor.md)** | Substrate | Continuous, ambient | Build a space people want to spend six hours in | Supermarket Together |

B and C are the hands-on skill loops and receive the majority of design, content and polish
effort. D is the hook that makes a session feel like it had a story in it. A is maintenance —
genuinely enjoyable, genuinely necessary, and the first thing a player should want to
delegate.

**This weighting has teeth.** When a phase runs long and something must be cut, it is cut
from A. When there is a polish pass to spend, it is spent on B and C. When
[content targets](12-content-manifest.md) need trimming, products go before documents or
recipes.

### How they interleave

A is the floor you stand on. B interrupts you. C is the timer you are always already behind
on. **The signature session texture is being mid-sandwich when someone puts a
questionable ID on the counter, and having to decide which one can wait.**

That collision is the game. Design toward it: B and C peak at overlapping times, and the
room is small enough that both queues are always visible and audible from anywhere in it.

### The fusion moment

The single encounter the whole design exists to produce: **to buy a card, you must check
the card and card the person, in the same transaction.**

Someone slides a high-value single across the glass. You authenticate the card — backlight,
loupe, weight, print pattern. You grade its condition. You verify the seller's ID, because the
law says you record one. You check their history in the ledger. You weigh what the two tell
you against each other: a clean ID and a clean history make the card more plausible; a card
that fails one test makes the person's story matter far more.

And all four checks are running while a kitchen ticket burns and someone at table six wants
a rules ruling.

## Design pillars

When an ambiguity arises that the specification does not cover, it resolves in favour of
these, **in order**. This is the tiebreak, and it is the one every contributor is allowed to
invoke against anybody.

1. **Scrutiny is the verb.** The signature moment is *noticing*. Not clicking fast, not
   memorising — noticing. Every system should generate things worth looking closely at;
   every tool should extend what "closely" means.
2. **Never idle, never overwhelmed.** A player with nothing to do is a bug. So is a player who
   cannot triage. Automation must convert one kind of work into another kind of work, never
   into no work.
3. **The skeleton outranks the content.** Systems are data-driven from the first commit. A
   new product, customer, document, tool, cat or verification rule must be addable as data
   by a modder with zero engine code. If content can only be added in code, the system is
   wrong and gets rebuilt.
4. **Co-op is the default reading.** Single-player is co-op with four empty chairs. No
   mechanic assumes a solo player; none requires five.
5. **Free as in freedom, all the way down.** Engine, tooling, art, audio, fonts. Every asset
   carries a machine-readable licence record. No "we'll swap it later."

## The design centre is three players

Five is the ceiling, not the target. The realistic, common session is three, and every tuning
decision, content pacing curve and floor plan assumes three unless stated otherwise.

Three players means one on the counter, one on the grill, one floating — and **the floating
player is the one who is always slightly behind, which is exactly right.** Full scaling model
in [09 Multiplayer and scaling](09-multiplayer-and-scaling.md).

## What makes this worth building

- **Nobody has made it.** Supermarket Together occupies the shop-sim space; TCG Simulator
  occupies the card space and has no multiplayer, which is the complaint that started this.
- **The verification domain is genuinely deep.** Card authentication and document checking
  are two halves of one loop: IDs give crisp, rule-driven checks with unambiguous right
  answers; cards give physical, tool-driven, judgement-heavy ones. A game with only the
  first is Papers Please. A game with only the second is an eye test. **Both, interleaved, is
  the design.**
- **Four distinct co-op stations before anything strains:** cafe counter, kitchen, card
  counter, event floor.
