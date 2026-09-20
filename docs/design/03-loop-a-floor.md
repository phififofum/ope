# 03 · Loop A — the floor

[← Architecture](02-architecture.md) · [Index](README.md) · [Next: Loop B →](04-loop-b-counter.md)

> **Weight: substrate.** Continuous, ambient, genuinely enjoyable, and the first thing a
> player should want to delegate. When a phase runs long, this is what gets cut.

---

The floor has two halves that share one floor plan: **the cafe**, which is inventory and
service, and **the game store**, which is library and retail. They generate different work on
different clocks, and the fact that they compete for the same square footage is the central
strategic tension of the whole game.

## Half one: the cafe

- Ordering against lead times from suppliers with distinct reliability and legitimacy profiles
- Chilled, frozen and ambient storage classes with real degradation clocks
- Expiry rotation, which is the neglect-punisher
- Espresso machine, taps, fridges, grinder — each with runtime wear, service intervals and
  failure states
- Consumables the kitchen burns through: cups, lids, napkins, wrappers
- Waste, bins, recycling, cardboard breakdown
- **Spills**, which matter far more here than in a grocery store, because they happen on
  tables with games on them

## Half two: the game store

Games exist in three fundamentally different populations, and confusing them is a real and
punishable mistake.

| Population | What it is | Its work |
| --- | --- | --- |
| **The library** | Games to play here. Borrowed, played, returned. | Shelving and sorting, component checks on return, sleeve and box repair, replacing chewed parts, tracking who has what |
| **Retail** | Games to buy. Sealed, priced, faced. | Ordering, pricing, facing, theft exposure, restocking hot titles |
| **The case** | Singles and sealed collectibles ([Loop D](06-loop-d-case.md)) | Pricing against a live market, display arrangement, the highest shrink risk in the building |

### The component check

The standout mechanic here. **Every returned library game is checked against its component
list** — 104 wooden cubes, 5 meeples, 1 first-player marker. Missing pieces mean a game that
cannot be lent again until replaced.

It is a checklist scrutiny task, it is genuinely how the business works, and it runs on the
same engine as [Loop B](04-loop-b-counter.md). It also scales beautifully: a light filler game
is a ten-second check; a heavy 400-component game after a six-hour session is a real
decision about whether you have time.

Library copies carry condition and completeness state that decays with play, which gives the
retail-versus-library allocation a real cost: **putting your copy in the library earns rental and
table revenue but destroys it slowly; keeping it sealed preserves value but earns nothing.**

## Zone design — the layout puzzle at building scale

The floor is a placeable grid, and a cafe has zones with properties that interact. Designing
the space well is a genuine, replayable puzzle with no single correct answer.

| Zone | Wants | Conflicts with |
| --- | --- | --- |
| Quiet play tables | Low noise, good light, near the library | Events, the counter queue, the door |
| Tournament / event space | Space, power, sightlines for adjudication | Everything quiet |
| Teaching tables | Near the counter so staff can explain rules mid-shift | Deep-game tables that want to be left alone |
| The library wall | Reachable from every table, browsable | Takes wall space the retail shelves also want |
| Retail shelving | High visibility, near the door and the counter | The card case, which wants the same spot |
| The card case | Direct counter sightline, always watched | Everything else that wants to be near the counter |
| Kitchen and cafe counter | Short travel to tables, extraction, plumbing | Noise, smell, and food near cardboard |
| Bar | Sightline for ID checks, near the social tables | Quiet zones |

### What makes it a puzzle rather than a layout screen

- **Noise propagates.** A tournament twelve feet from a two-player quiet game ruins both.
  Walls, shelving and distance attenuate it. Noise is a simulated field, not a per-zone flag.
- **Food and games do not mix.** Table service revenue is high, and spills destroy library
  copies. Designating food-free tables costs revenue and protects inventory, and that choice
  recurs constantly.
- **The counter's sightline is finite.** You can watch the card case, the retail shelves or the
  door — not all three. Everything you cannot see is shrink exposure, and shrink on singles
  is brutal.
- **Travel time is real.** Fetching a game from the far wall during a rush costs the same
  seconds the kitchen charges for walking.
- **Table mix is a bet.** Two-, four- and six-player tables serve different crowds at different
  times. Get the mix wrong and you turn people away with empty tables in the room.
- **Throughput versus dwell.** Cafes make money two ways: table time and food. Tight seating
  maximises covers; comfortable seating maximises how long people stay and how much they
  order. A genuine, permanent tension.

## Maintenance: the ambient work

This is the [pillar 2](01-vision.md#design-pillars) engine. Every task below generates work on
its own clock, so a player is never without something to do.

| Task | Trigger | Neglect consequence |
| --- | --- | --- |
| Table reset and wipe-down | Every session ending | Turnover collapses; tables sit dirty and unusable |
| Component checks | Every library return | Incomplete games, angry customers, dead inventory |
| Shelving and sorting the library | Returns | Nobody can find anything; browse time balloons |
| Restocking retail and facing | Sales | Lost sales |
| Cafe restock and expiry rotation | Time, sales | Spoilage, health inspection |
| Equipment service | Runtime hours | Espresso machine failure at 8am is a catastrophe |
| Cleaning, spills, bins | Traffic | Cleanliness, inspections, damaged stock |
| Pest control | Food waste | **Rats destroy cardboard** — see [07 Cats](07-cats.md) |
| Card case upkeep | Sales, market drift | Mispriced singles, and theft you did not notice |

## The ordering chain

1. **Browse supplier catalogues.** Each `supplier` definition has a catalogue, lead time,
   minimum order, price tier and — crucially — a legitimacy profile. The cheap guy is cheap
   for a reason.
2. **Place the order.** Cash leaves now; goods arrive on a lead time. Over-ordering
   perishables is the classic beginner's grave.
3. **Receive the delivery.** A truck arrives at the back door. This is a
   [verification moment](04-loop-b-counter.md), not a cutscene.
4. **Store it.** The back room has finite shelving and finite floor. Chilled and frozen goods
   degrade outside their storage class on a timer.
5. **Stock the shelf.** Carry boxes, cut them open, place units. Facing matters: a well-faced
   shelf sells measurably better.
6. **Price it.** Per-SKU pricing against a moving market price.
7. **Break down the box.** Flatten it, take it to the back. Boxes left out block aisles and tank
   the cleanliness score.

## Pricing and demand

Each product has a `market_price` that drifts daily within a band. Player price relative to
market drives a demand multiplier along a **soft elasticity curve** — no cliff edges, because
cliff edges teach players to look up a number instead of reading the room.

| Price vs market | Effect |
| --- | --- |
| Well under | High volume, thin margin, shelves empty faster than you can restock |
| At market | Baseline |
| Modestly over | Slightly lower volume, better margin — the sustainable zone |
| Far over | Sharp volume drop, reputation penalty, customers photograph the price tag |

Convenience premium is real and modelled: proximity, time of day, and a product's `urgency`
tag all raise tolerable markup. **Nobody haggles over a 2am phone charger.** That asymmetry
is where the interesting pricing decisions live.

## Expansion

The room grows in discrete, expensive steps, each unlocking new systems rather than just
more floor:

1. **The original room** — a counter, a kitchenette, six tables, one wall of games
2. **Proper kitchen** — unlocks [Loop C](05-loop-c-kitchen.md) at full depth
3. **The card counter** — unlocks [Loop D](06-loop-d-case.md)
4. **Event space** — tournaments, leagues, the fourth station
5. **The back room** — storage, repair bench, the office, cameras and the ledger
6. **Bar licence and buildout** — alcohol, later hours, a different crowd, and ID checks in force
7. **The mezzanine** — quiet deep-game tables, the thing your regulars will love most

## Time and rhythm

A day is roughly 25 real minutes at default speed, divided into shifts with distinct demand
profiles and customer mixes.

| Shift | Character | Dominant loop |
| --- | --- | --- |
| Morning | Coffee, pastries, a few people working | C, then B |
| Midday | Steady, low intensity — the building shift | A |
| Afternoon | Schools out, teaching tables fill, library churn peaks | A and B |
| Evening rush | Dinner, bar service, the room is full | B and C together |
| Event night | Tournament pressure, judge calls, prize payouts | B, with D |
| Late night | Low volume, high scrutiny. Odd characters. Adults-only after the cutoff. | B |
| Dead hours | Almost no customers. Deliveries, deep cleaning, restocking, cat time. | A |

**The dead hours are deliberate and must not be compressed away.** They are the breathing
room where players rebuild, plan, and talk to each other — the co-op social glue — and they
make the rushes feel like rushes.
