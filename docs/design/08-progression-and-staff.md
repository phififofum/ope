# 08 · Progression, economy and staff

[← Cats](07-cats.md) · [Index](README.md) · [Next: Multiplayer →](09-multiplayer-and-scaling.md)

---

## Three currencies, deliberately not convertible

**Money buys things. Reputation buys customers. Standing buys permission.**

A player who is rich but disreputable and a player who is broke but trusted face genuinely
different problems, and that is what stops the campaign collapsing into a single optimisation
curve.

### Money

Revenue from table time, food and drink margin, retail margin, library rental, event fees, and
the case. Costs from stock, wages, rent, utilities, licences, fines, vet bills, repairs and waste.
Utilities scale with fixture count and equipment condition, which means an ageing fridge
bleeds money twice — once in power and once in spoilage.

**Tune so that the first week is genuinely tight.** Running out of cash before the evening
rush because you over-ordered perishables is the lesson the opening exists to teach.

### Reputation

A slow-moving score driving footfall, customer patience and archetype mix. Raised by
cleanliness, stock availability, fair pricing, accurate orders, complete library copies, well-run
events and a visible well-kept [cat](07-cats.md). Lowered by spoilage, filth, stock-outs,
gouging, wrong orders, missing components and wrongful refusals.

**Reputation changes the kind of customer you get, not just the number.** A high-reputation
room draws regulars and families. A low-reputation one draws opportunists, and the forgery
rate climbs — a feedback loop the player can feel tightening around them.

### Standing

Your record with regulators, and it gates the `licence` tree. Standing is **not purchasable**,
which is the whole reason it is a separate currency.

## Licences

Each licence unlocks categories, carries a cost and a renewal, and **raises the stakes of the
verification loop** — the more you are permitted to sell, the more there is to get wrong.

| Licence | Unlocks | Verification burden added |
| --- | --- | --- |
| General retail | Baseline cafe and retail | None |
| Food service | The kitchen, [Loop C](05-loop-c-kitchen.md) | Health inspections, temperature logs, allergen handling, cross-contamination |
| On-premise alcohol | Bar service | ID checks, hour restrictions, service refusal, intoxication judgement |
| Counter nicotine | A small revenue line | ID checks. Kept deliberately — cheap carding surface. |
| **Secondhand dealer** | Buying from the public | **Seller ID captured on every trade-in, holding periods before resale, logged provenance, records available to police** |
| Sanctioned event organiser | Tournaments and leagues | Event legitimacy, prize-payout ceilings, age divisions, eligibility |
| High-value transaction handling | Large card purchases and payouts | Identity capture and reporting thresholds |
| Distributor account | Direct publisher allocation | Counterfeit and grey-import detection, allocation rules, promo policy |
| Late-hours permit | The room goes adults-only after a cutoff | **Carding at the door, not the counter** — high volume, fast, queue pressure |

**The secondhand dealer licence is the standout.** Buying used goods from the public is
genuinely regulated — seller ID capture, holding periods, records available to police — and it
is exactly the mechanic the person-verification layer wants.

Shipped licence definitions: [`content/definitions/licence/`](../../content/definitions/licence/).

### Where carding actually happens

| Trigger | Frequency | Character |
| --- | --- | --- |
| Every trade-in | Constant | The law requires a valid ID recorded against every purchase from the public |
| Bar service | Heavy in evenings | Classic age checks, plus refusal-of-service judgement |
| Late-hours door | Nightly after the cutoff | High volume, fast, queue pressure — the purest carding minigame |
| Age-rated product | Occasional | 18+ titles, certain party games |
| Tournament registration | Event days | Age divisions, eligibility, guardian consent for minors |
| Prize payouts | Event days | Above a threshold, identity capture and reporting |
| Membership accounts | Ongoing | Identity tied to borrowing privileges and outstanding library items |

## The strike system

Compliance failures produce strikes, tracked **per licence**. This is the game's spine of
consequence.

1. **First strike** — fine, warning letter, a note on the record.
2. **Second strike** — larger fine, and a compliance-check period during which undercover
   attempts become markedly more frequent. **The game gets harder precisely when you are
   least able to afford it.**
3. **Third strike** — that licence is suspended for a fixed period. The associated category is
   pulled and the revenue stops.

Strikes decay slowly with clean operation. They never vanish instantly and **they cannot be
bought off**.

### Undercover operations

A compliance authority periodically sends someone who is testing you: underage buyers with
real IDs, a trade-in with deliberately thin provenance, an after-hours service attempt.

Early on these are detectable with attention. Later they are indistinguishable from ordinary
customers, which is the correct answer: **the only defence is consistent process.** This is the
mechanic that makes the game's central discipline — check everyone, every time, even when
it is slow and even when they are annoyed — pay off rather than merely feel virtuous.

## Campaign shape

| Act | In-game span | The question it asks |
| --- | --- | --- |
| **I — Opening** | Weeks 1–2 | Can you keep the lights on? |
| **II — Establishing** | Weeks 3–6 | Can you grow without losing control of quality? |
| **III — The shop you wanted** | Weeks 7–12 | Can you run four loops at once? |
| **IV — Pressure** | Weeks 13–20 | Adaptive adversaries, organised fraud, the grey-market offer |
| **V — Endless** | Beyond | Seeded challenge runs, leaderboards, community scenarios |

**Act IV should contain a real choice with teeth:** a supplier offers product well below
market with paperwork that will not survive an audit. Taking it is viable, profitable and
genuinely risky. Refusing it is viable and harder. **The game should not tell the player which
was correct.**

---

## Staff and the late game

Hiring, without the game collapsing into an idle manager. The answer is a single design rule:

> **Staff do not remove work. Staff convert work you were doing into work you now have to
> supervise.**

Every hire trades a task you performed for an oversight task you did not have before.
Headcount changes what your job is; it never reduces how much job there is. **A player with
five staff should be busier than a player with none** — differently busy, at a higher level of
abstraction, but never idle.

Hiring priority follows the loop weighting. [Loop A](03-loop-a-floor.md) is hired out first and
most completely. [Loop C](05-loop-c-kitchen.md) second and partially, because a cook who is
merely adequate is still a real cost in accuracy. [Loop B](04-loop-b-counter.md) last,
reluctantly, and never fully — the counter is what the player came for, and delegating it is the
decision that creates the audit loop.

**The intended late-game shape** is a player who has bought their way out of the stockroom
and into a shift where they run the counter and the kitchen at a tempo that would have been
impossible in Act I. That is the reward, and it is a reward of *more* action rather than less.

### The roles

| Hire | Takes over | Hands you back |
| --- | --- | --- |
| Library steward | Shelving, sorting, component checks | Misshelved games, skipped checks, damage not logged |
| Counter staff | Routine transactions | Verification audit — they will approve things you would have refused, and any trade-in they were permitted to take |
| Floor and tables | Resets, spills, bins, litter tray | Scheduling, and the tables they skip |
| Kitchen staff | Routine orders | Quality control, waste review, and the orders they get wrong |
| Floor watch | Deterrence, shrink reduction | Incident review, and judgement calls about their judgement calls |
| Night manager | An entire shift | The morning-after reconciliation — the densest audit in the game |
| **Game teacher / event judge** | Teaching rules, running events, rulings | **Quality visible only in retention — auditing them means watching who stops coming back** |

The game teacher is the most interesting hire in the game precisely because their output is
almost unmeasurable in the short term.

### The audit loop

The late game's core activity, and **a new instance of [Loop B](04-loop-b-counter.md) rather
than an absence of it**.

Staff make mistakes at a rate set by their `staff_role` error profile, their training level, their
fatigue, and the shift's pressure. Those mistakes are **recorded but not reported**. Nobody
tells you the new hire took a trade-in without an ID. You find out by:

- Reviewing camera footage against flagged transactions
- Reconciling the register against the day's sales
- Noticing inventory variance that does not match recorded sales
- Receiving the fine three days later and working backwards
- Spotting the pattern across a week — this person's shifts have a shrink problem

**Same verb — scrutiny — new object.** It uses the same engine, the same tools (the ledger,
the cameras) and the same `rule` definitions.

### Hiring is itself a verification encounter

Candidates arrive with a work history you can check, references you can call, and credentials
that may be fabricated. A candidate lying about their experience is a Loop B encounter
wearing a different hat — and one who passes verification but has a quiet problem you only
discover three weeks in is the late game working as intended.

### Training, trust and permissions

Staff improve at tasks they repeat. Training costs **your** time, shadowing them, and is the
main lever on error rate. A trained employee can be granted progressively more discretion,
explicitly:

| Permission | Risk it creates |
| --- | --- |
| Handle age-restricted sales | Strikes against your licence, not theirs |
| Accept deliveries | Bad stock enters your inventory unchecked |
| Take trade-ins | The single most expensive permission in the game |
| Process refunds | Refund fraud, and collusion |
| Open and close | Cash handling, and the keys |
| Access the case | Shrink on the highest-value goods you own |

**Granting permissions is how a player chooses their own late-game difficulty**, and it is a
much better lever than a slider because it is made of decisions with reasons attached.

### The guardrails

- **Never full automation.** No configuration of staff runs the shop without a player. Maximum
  coverage is roughly 70% of routine tasks; the remainder is oversight that cannot be
  delegated.
- **Staff cost scales faster than their output.** Wages, training time, turnover and error cost
  mean the fifth hire is rarely obviously correct.
- **Turnover is real.** Staff quit — over pay, over treatment, over a bad shift pattern.
  Retention is a system, and losing a trained employee in Act IV genuinely hurts.
- **Staff are not player substitutes in co-op.** In a five-player game they handle overflow and
  the shifts nobody wants to play. They never make a player redundant.
