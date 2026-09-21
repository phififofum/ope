# 06 · Loop D — the case

[← Loop C](05-loop-c-kitchen.md) · [Index](README.md) · [Next: Cats →](07-cats.md)

> **Weight: recurring hook.** The gamble that funds and threatens the other three, and the
> thing that makes a session feel like it had a story in it.

---

## Why this fits better than it has any right to

Card authentication is one of the richest verification domains that exists in ordinary
commerce. Counterfeits are a real and sophisticated problem, the detection techniques are
physical and tool-driven, and they map onto [the tool tree](04-loop-b-counter.md#the-tree)
almost without modification.

Where an ID gives you six or seven fields to check, a card gives you print rosettes, layer
structure, surface gloss, cut alignment, weight, opacity under light, ink density and font
kerning — **all of them physical, all of them tool-revealed, none of them a menu**.

**The gamble and the scrutiny are the same loop viewed from two sides.** You rip packs
hoping for value; customers bring you cards claiming value. One is hope, the other is doubt,
and they share every system.

## The four activities

### 1. Ripping packs

Sealed product opened by the player. Real tactile ceremony — wrapper, weight, the slow
reveal, one card at a time. Pull rates are data-driven per `card_set` definition.

**The decision, not the odds, is the mechanic.** Every sealed unit in the building is
ordinary stock: it sits on the pack rack, a customer may walk in and buy it, and the
margin on that sale is known. Opening it takes that sale off the table. So a rip is never
priced at what you paid the distributor — it is priced at *what you gave up by not selling
it*, and that is the number [`CardCase.sealed_ledger()`](../../systems/case/card_case.gd)
reports back.

| Form | Packs | Sold under |
| --- | --- | --- |
| Pack | 1 | `base:general_retail` |
| Blister | 3 | `base:general_retail` |
| Bundle | 8 | `base:sealed_distribution` |
| Booster box | a full box | `base:sealed_distribution` |

Packs are ordinary retail, so the gamble is reachable on the first morning. Buying by the
box means buying direct, which is a licence and a standing requirement — the loop opens
small and grows.

A pack is worth less than it sells for, which is the point, and **which the game never
hides**: the ledger tells you exactly how far underwater you are on sealed, and some
players will keep going anyway. That is the honest version of this mechanic.

This is a promise about content rather than about code, so
[`tools/validate_content.py`](../../tools/validate_content.py) enforces it on every set and
every sealed product in the game — a mod's included. A set whose packs pay more than they
cost fails the build.

### 2. Buying singles from the public

The core verification activity. Someone walks in with a binder. You assess authenticity,
assess condition, and make an offer against a buylist that moves with the market. **Every one
of those three is a skill.**

### 3. Grading and consignment

Send a card away to be graded; it comes back weeks later with a number that multiplies or
destroys its value. **Your own condition assessment is a prediction, and the grader is the
scoreboard.** A slow-burn gamble with a genuine skill component, and the best long-tail hook
in the design.

### 4. Running the case

Pricing singles, arranging the display, deciding what to hold and what to move. A market
that drifts on its own, plus set rotations and hype spikes driven by the `event` system.

The case has two halves and the split is the decision. **Stock** is priced and for sale.
The **wall** — the singles case, the lit shelf behind the counter — is not: a card on
display earns nothing until it comes down, and in exchange it shortens the gap between
arrivals for as long as it is up there. Glass holds what glass holds, so showing the
serialised card you just pulled means not showing something else, and selling it means
the wall goes quiet.

## Authentication as a verification family

This slots in alongside the other families in [Loop B](04-loop-b-counter.md), using the same
engine, the same `document_type` machinery (a card is an artifact with fields and security
features) and the same forgery-vector model.

| Technique | Reveals | Tool tier |
| --- | --- | --- |
| Naked eye | Gross errors: wrong colour, obvious font mismatch, bad cut | 0 |
| Comparison to a known real copy | Almost everything, if you have one | 0 |
| Backlight / candling | Internal layer structure — **the single best cheap test** | 1 |
| Loupe | Print rosette pattern versus laser-print dithering | 1 |
| UV | Coating response and surface treatment | 1 |
| Precision scale | Weight outside tolerance | 2 |
| Digital microscope | Ink layering, edge fibres | 3 |
| Database cross-reference | Set legality, print run, known fake variants | 3 |
| **Destructive test** | Definitive — and it destroys the card. If you are wrong, you pay for it. | 4 |

That last row is a beautiful mechanic and should absolutely be built: **a definitive answer
that costs the thing you were asking about.** Using it on a genuine card in front of its owner
is a scene.

## Condition grading as a scrutiny minigame

Separate from authenticity and equally good. The player assesses centering, corners, edges
and surface under magnification and raking light, then commits to a grade. Sub-millimetre
centering judgements, whitening only visible at an angle, a surface scratch that appears
under one light and not another.

**The skill expression: your grade drives your offer.** Over-grade and you overpay.
Under-grade and the seller walks, and word gets around that you lowball. Send it for
professional grading and find out how right you were — with real money riding on the gap
between your judgement and theirs.

## The adversaries

This domain has the best rogues' gallery in the game:

- **The counterfeiter** with genuinely good fakes, improving over the campaign
- **The person who does not know their card is fake**, and who will be upset
- **The resealer** — a box professionally resealed after the hits were pulled, detectable by
  weight and seal geometry. The nastiest vector in the game, because you only find out after
  you open it. Implemented through the back door rather than as a special case: a delivery
  from a supplier with a counterfeit rate marks its lot, a marked unit opens with every
  common present and nothing worth having, and selling one on instead of opening it means
  the customer finds out at home and tells everyone. Verifying deliveries properly is what
  keeps them out of the building.
- **Someone selling a collection that is not theirs**, where the tell is behavioural and
  documentary rather than physical
- **The shill** who inflates local demand for something they are about to dump
- **The altered card**: trimmed edges, recoloured corners, pressed creases. Professional-grade
  fraud requiring tier-3 tools.

## How it intersects everything else

- **Into [Loop B](04-loop-b-counter.md):** same engine, same tools, same verdict surface.
  Authentication is Loop B content, not a separate system.
- **Into [Loop A](03-loop-a-floor.md):** the display case is inventory with pricing, facing and
  theft exposure — singles are the highest-shrink goods in any shop.
- **Into [Loop C](05-loop-c-kitchen.md):** food and drink near cards is a real anxiety.
- **Into [the economy](08-progression-and-staff.md):** sealed product is a capital allocation
  decision competing directly with restocking. Money in cardboard is money not in coffee.
- **Into [staff](08-progression-and-staff.md):** never let staff buy singles unsupervised. The
  audit loop practically writes itself.

## The fusion moment

Stated again because it is the signature encounter of the whole game: **to buy a card, you
must check the card and card the person, in the same transaction.** Authenticate,
grade, verify the seller's ID because the law requires you to record one, check their history
in the ledger — and weigh what the two tell you against each other, while a kitchen ticket
burns and table six wants a rules ruling.

## The responsible-design line

Worth stating explicitly in the spec, because it is the kind of thing that gets sleepwalked
into.

**The gamble is simulated, in-fiction, and played with in-game currency only. No real-money
purchases of any kind**, consistent with [the roadmap](16-post-v1-roadmap.md).

Beyond that, one deliberate design choice: **the game surfaces your true lifetime return on
sealed product in the ledger, plainly and unflatteringly.** Not as a lecture — as bookkeeping,
because a shop owner would know that number. A game about scrutiny should not be coy
about the one set of odds the player is most tempted not to look at.
