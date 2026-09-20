# ADR-0002 · The setting is a late-night board game cafe

- **Status:** Accepted
- **Date:** 2026-09-20
- **Affects:** [01](../design/01-vision.md), [03](../design/03-loop-a-floor.md), [04](../design/04-loop-b-counter.md), [06](../design/06-loop-d-case.md), [08](../design/08-progression-and-staff.md), [12](../design/12-content-manifest.md)

## Context

The project began as a bodega sim: a 24-hour corner shop, with verification at the counter
as the primary loop. The alternative under consideration was a board game cafe that also
runs a card counter and a small shop.

The deciding question was not "which is more charming" but **which setting gives each of
the three loves — the scrutiny, the kitchen, the gamble — its best available expression.**

## Decision

**The board game cafe**, in its strongest form: a late-night cafe that also runs a card
counter and a small retail shop. A real business type.

## Consequences

### What gets better

- **Verification depth.** Card authentication and grading are physical, tool-driven, and
  gradable in difficulty almost without limit. A cafe with a liquor licence keeps ID checks
  anyway, so nothing is lost from the document layer.
- **The gamble becomes native** rather than bolted on. Sealed product, singles and grading
  are load-bearing instead of an addition.
- **The kitchen fits better.** A cafe kitchen with a ticket rail and table service is closer to
  PlateUp than a counter griddle was.
- **Four distinct co-op stations** before anything strains: cafe counter, kitchen, card
  counter, event floor — plus a whole content family (running events) the bodega lacked.
- **Novelty.** Nobody has made this. Supermarket Together already occupies the other space.
- **The fusion moment**: to buy a card you must check the card and card the person, in one
  transaction. That is the signature encounter of the whole game and the cafe is the only
  setting that produces it.

### What gets worse

Be clear-eyed about it:

- **The bodega's Loop A was better.** Grocery restocking, expiry rotation and fridge
  maintenance generate steady ambient work that a smaller cafe inventory will not.
  *Replacement:* game library management — hundreds of boxes to shelve, sort, repair and
  replace, and every returned game checked against its component list. Which is, conveniently,
  another checklist scrutiny task and entirely on-thesis.
- **Lost:** benefits eligibility, the full officials-and-impostors cast, and late-night street
  texture. *Partly recovered:* the secondhand dealer licence makes police contact routine,
  health inspectors and fire marshals still visit, and
  [entitlement reconciliation](../design/04-loop-b-counter.md#entitlement-reconciliation)
  reproduces the basket-against-a-list mechanic through store credit, tax-exempt
  certificates and organised-play kits.
- Warmer, lower-stakes, less thematic grit than 4am on a street corner.

### What this commits us to

- Document verification stays first-class. **Card authentication does not replace it** — a
  game with only documents is Papers Please; a game with only cards is an eye test. Both,
  interleaved, is the design.
- The licence tree is relabelled to cafe equivalents, with the **secondhand dealer** licence
  as the standout.
- Loop A is rewritten around library, table service and cafe inventory.
- Roughly two sections rewritten, four relabelled, ten untouched — which is the payoff of
  having made everything data.

## Alternatives considered

| Option | Why it lost |
| --- | --- |
| The bodega | Better maintenance substrate and more setting grit, but the gamble is thin (lottery, bolted on), the kitchen is a worse PlateUp fit, and the space is already occupied |
| Both, as selectable shop types | Doubles the content bill before either is good. Deferred: it is a [post-v1 possibility](../design/16-post-v1-roadmap.md) precisely because everything is `fixture` and `licence` composition. |
