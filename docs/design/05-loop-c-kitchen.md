# 05 · Loop C — the kitchen

[← Loop B](04-loop-b-counter.md) · [Index](README.md) · [Next: Loop D →](06-loop-d-case.md)

> **Weight: co-primary.** The loop that gives a session its escalation curve.

---

PlateUp is the right ancestor: a kitchen is a machine you build out of layout, routing and
muscle memory, and the pleasure is watching a system you designed survive a rush it was not
quite built for.

A cafe kitchen is a better fit for that than a counter griddle. It has a genuine ticket rail,
**table service** rather than counter handoff, and a drinks programme running in parallel with
food — three concurrent streams instead of one. Table service is the important addition:
food has to travel to a specific table, through a floor plan you designed, past people playing
games on the surfaces you are setting plates down on.

## What we take from PlateUp

| Element | How it lands here |
| --- | --- |
| **Escalating days** | Each in-game day raises the kitchen's customer rate against the same physical space. Day 3 is comfortable; day 18 is a machine running at the edge. |
| **Layout as the real puzzle** | Where the griddle, prep table, fridge, coffee bar and pass sit determines your ceiling. Steps cost seconds and seconds compound. |
| **Progressive automation** | Unlockable equipment removes specific manual steps. Never the whole job, always one step. |
| **Compounding mess** | Dirty surfaces, spilled grease, fouled griddle, overflowing bin. All accumulate under load and all cost you time later. |
| **Failure as a wall, not a fail state** | You do not lose the kitchen. You hit the day where the queue never clears, and that tells you what to rebuild. |
| **Run-based escalation** | Shipped as [Rush mode](#rush-mode). |

**The important divergence:** PlateUp's kitchen is the whole game; here it is one of four. So
the kitchen runs at roughly **60–70% of PlateUp's intensity** at equivalent progression,
because a player also owes attention to the counter. If playtests show the kitchen fully
consuming a player at steady state, reduce its rate — the collision with
[Loop B](04-loop-b-counter.md) is the point, and a kitchen that eats a player whole destroys it.

## The loop

1. **Take the order.** Verbally, with modifications, from a table or the counter. Generated
   from `recipe` definitions crossed with the [modification grammar](#the-modification-grammar).
2. **Hold it in your head.** Tickets are an unlock, not a default. Early on you remember or you
   ask again, and asking again costs patience.
3. **Gather.** Ingredients come from your own shelf and fridge stock. The kitchen consumes
   what [Loop A](03-loop-a-floor.md) maintains, so running out of bread at 8am is an A-failure
   that lands on C.
4. **Prep.** Slice, chop, portion. Some steps can be batched ahead during quiet periods —
   and batching ahead is the highest-skill decision in the loop, because you are betting on
   demand.
5. **Cook.** Griddle, oven and fryer with real timers, heat zones and burn states. Ingredients
   pass raw → cooked → burnt on their own clocks, visibly and audibly.
6. **Assemble and plate.** Build order matters. Accuracy is scored against the full order
   including modifications.
7. **Run it to the table.** Or to the pass, where another player completes the delivery —
   which is the co-op seam. Table service means travel time through your own floor plan.
8. **Clean down.** Griddle scraping, oil changes, wiping, bin runs. Neglect raises burn rates,
   slows every subsequent step, and feeds health inspections.

## Station layout

The kitchen is a placeable grid like the floor, but tighter and with far more consequence.
Stations: griddle, flat-top, fryer, slicer, prep table, cold well, bread rack, plating bench,
coffee bar, holding cabinet, pass, sink, bin.

What makes it a puzzle rather than decoration:

- **Travel time is the dominant cost.** Every step between stations is real seconds under a
  real timer.
- **Chokepoints.** Two players in a one-tile gap is a collision and a lost second. Layouts that
  work solo fail at three.
- **Heat adjacency.** Fryer beside the cold well degrades it. Griddle beside the plating bench
  ruins presentation.
- **Sightline to the counter.** A kitchen player who can see the register queue can help
  triage; one who cannot is isolated. **Layout is therefore a co-op decision.**
- **Batch staging.** Holding cabinets let you pre-build during lulls, at the cost of floor space
  and quality decay.
- **Food near cardboard.** The kitchen's position relative to the library wall and the card
  case is a real anxiety, and there is comedy and tension in it.

The room is small, so every station added takes space from somewhere. **A better kitchen or
more tables is a genuine strategic tension that recurs all campaign.**

## Signature items

All `recipe` data, all moddable. The three-cheese toastie is the house special and should be
what the tutorial teaches.

| Item | Steps | Stations | Role |
| --- | --- | --- | --- |
| Filter coffee | 2 | Coffee bar | Low complexity, relentless at 8am |
| Flat white | 4 | Coffee bar | Extraction and steam are skill windows |
| Three-cheese toastie | 5 | Slicer, prep, griddle | House special; the slicer is the bottleneck |
| Loaded fries | 3 | Fryer | Oil temperature management |
| Hot sandwich | 8 | Griddle, prep, oven | Multiple parallel timers |
| Table platter | 9 | Griddle, fryer, prep | The hardest standard order, and it feeds six |
| Cold plate | 5 | Slicer, prep | Slicer dependency again, under a different rush |
| Milkshake, egg cream | 3 | Cold well | Cold-side variety |

Shipped examples: [`content/definitions/recipe/`](../../content/definitions/recipe/).

## The modification grammar

The reason 45 recipes produce thousands of distinct orders. Modifiers are typed,
composable and defined as data.

| Modifier class | Examples | Effect |
| --- | --- | --- |
| Omission | no onion, no mayo | Removes a step |
| Addition | extra cheese, add bacon | Adds a step and cost |
| Substitution | sourdough instead of white, oat milk | Changes an ingredient |
| Preparation | toasted, well done, extra hot | Changes timing tolerance |
| Portioning | cut in half, plated separately | Adds a finishing step |
| Quantity | two of them, make it three | Multiplies everything |

Modifiers compose, and the combinatorics are where the memory pressure comes from. *Two
toasties, one without onion, both cut in half, and a flat white with oat* is a single order and a
real cognitive load. That is the PlateUp feeling, and it is why the ticket printer is a
meaningful unlock rather than a convenience.

## Progressive automation

Each unlock removes **exactly one** manual step. None removes the job — this is
[pillar 2](01-vision.md#design-pillars) in its most literal form.

| Unlock | Removes | Costs |
| --- | --- | --- |
| Ticket printer | Memorising orders | Counter space, and a queue of paper to read |
| Auto-slicer | Manual slicing | Space, power, cleaning cycles |
| Holding cabinet | Cooking staples to order | Space, quality decay over time |
| Conveyor pass | Walking to the window | Space, and a jam state |
| Condiment dispenser | Manual portioning | Refilling |
| Griddle timer array | Tracking timings by eye | Cost, and dependence on it |
| Self-cleaning fryer | Oil changes | Expensive, and it still fails |
| Second griddle | Serialisation | A large amount of floor space |

## Rush mode

A standalone, opt-in mode and the clearest nod to PlateUp — likely the thing a group
actually replays.

An escalating run at the kitchen alone. Fixed small kitchen, no floor, no verification. Each
day raises customer rate and order complexity. Between days you pick one upgrade from a
random three, and layout changes are free. It ends when the queue overruns you, and it
reports how far you got.

**Why it earns a slot:** it is a 25-minute co-op session for a night when nobody wants a
campaign, it isolates the skill loop, it is a natural leaderboard and seeded-challenge surface,
and it costs very little to build because it reuses the whole of Loop C with a different
director profile and no floor. **Build it in Phase 3, immediately after the kitchen, and treat it
as a first-class mode.**

## The slicer

A dedicated minigame and a deliberate hazard. Thickness matters to the order, slicing takes
time, and the machine must be cleaned between certain products — a cross-contamination
rule health inspectors check. It is the one piece of equipment that can injure a player
character, costing them a shift.

Handled with restraint and no gore: the consequence is a bandaged hand and a staffing
problem.

## How the kitchen intersects everything else

- **Into [Loop A](03-loop-a-floor.md):** consumes shelf inventory, generates waste and
  cleaning work, joins the maintenance rota, and competes for floor space.
- **Into [Loop B](04-loop-b-counter.md):** hot prepared food is excluded from store credit,
  so a customer paying with trade-in credit for a toastie is a verification event, not just a
  sale. **The most elegant intersection in the design, and it should be tutorialised explicitly.**
- **Into [Loop D](06-loop-d-case.md):** food and drink near cards, in a room where both are
  your inventory.
- **Into [cats](07-cats.md):** food smells attract pests, and the kitchen is where the health
  inspector looks hardest — making the cats both an asset and a liability.
- **Into [staff](08-progression-and-staff.md):** the cook is the highest-value hire and the
  hardest to audit, because a wrong order leaves no paper trail. You find out from the complaint.
