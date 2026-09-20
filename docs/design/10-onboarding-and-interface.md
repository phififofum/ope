# 10 · Onboarding, interface and accessibility

[← Multiplayer](09-multiplayer-and-scaling.md) · [Index](README.md) · [Next: Art and audio →](11-art-audio-licensing.md)

---

## Teach by arrival, not by instruction

Four loops is a lot to teach, and the standard failure is a tutorial wall that front-loads
everything and is forgotten by the time it matters. **Each loop enters the game at a moment
when the player is otherwise idle enough to absorb it.**

### The opening premise

You have inherited the place. It is half-shelved, filthy, the previous owner left notes, and
there is a cat. This framing does three things: it justifies a small starting range, it makes the
first tasks obviously necessary rather than arbitrary, and **the notes give a diegetic home
for every piece of instruction the game needs to deliver.**

### The first hour, beat by beat

| Time | Beat | Teaches |
| --- | --- | --- |
| 0–10 min | Open up. Clean, reset tables, shelve a returned stack. | Movement, the floor, the library |
| 10–20 min | First customers. Seat them, lend them a game, take a drink order. | The transaction and table service |
| 20–30 min | **A returned game is missing two pieces.** | [Loop B](04-loop-b-counter.md) arrives — the component check, the gentlest possible verification |
| 30–40 min | The kitchen. Lunch tickets start. | [Loop C](05-loop-c-kitchen.md) arrives |
| 40–50 min | Someone wants to sell a card. The previous owner's loupe is in the drawer. | [Loop D](06-loop-d-case.md) arrives, and verification gets teeth |
| 50–60 min | Evening. All four loops at once, briefly, at low intensity. | **The collision. The actual game.** |

**Opening on the component check is deliberate:** it teaches the checklist verb on something
with no adversary behind it, so the first real authentication lands on a player who already
knows how to look.

That last beat is the pitch delivered as an experience rather than a description. Everything
before it exists to make it legible.

### Teaching principles

- **No modal tutorial popups.** Instruction is diegetic: the laminated card at the register, the
  previous owner's notes, a regular who explains something, an invoice that demonstrates its
  own format.
- **Teach the verb, withhold the answer.** The game shows how to hold an ID under a UV
  light. It never shows what a valid overlay looks like — that is the reference binder's job,
  and finding out is the game.
- **The first mistake is cheap and scheduled.** Every player should fail one verification within
  the first hour with a forgiving consequence. A player who has never failed does not know
  the system has teeth.
- **Nothing is gated behind reading.** Every instruction has a physical or audio equivalent.
- **Fully skippable** for returning players, and for the second person in a group who has
  already played.

### Co-op onboarding

A specific and commonly botched case: one experienced player brings in two who have never
played.

- New players joining an established shop get a short contextual primer on the station they
  first approach, not the full tutorial
- The laminated checklist card is always readable at the register, so a newcomer put on the
  counter has a reference
- **An experienced player can demonstrate** — an inspection performed by one player is
  visible in full detail to anyone standing at the counter
- [Rush mode](05-loop-c-kitchen.md#rush-mode) is the recommended on-ramp for a
  brand-new group: one loop, twenty-five minutes, no campaign commitment

### The reference layer

Because this game asks players to remember things, it must also let them look things up. **A
physical in-world binder** at the register holds jurisdiction formats, set legality windows,
licence hour restrictions, promo policies and payout ceilings. Consulting it costs time, which
keeps it honest. It grows as licences unlock.

Crucially it is **generated from the same definitions that drive the rules**, so it can never be
out of date — and mod-added content appears in it automatically with no extra work from the
modder.

---

## The diegetic-first rule

**If information can live in the world, it lives in the world.** Screens are a last resort. This is
not stylistic preference — it is the reason inspection feels like inspection rather than
form-filling. *A UI panel listing an ID's fields has already destroyed the game.*

| Information | Where it lives |
| --- | --- |
| Order tickets | A printer, spitting paper you physically read |
| Checklist | A laminated card taped to the register |
| Jurisdiction and set reference | A ring binder you open and turn pages in |
| Prices | Shelf labels and a price gun |
| Inventory levels | The shelves themselves, and a clipboard in the back |
| Library loans | The lending book, and the gap on the shelf |
| Cash position | The drawer, and a ledger |
| Time | A wall clock |
| Staff schedule | A pinned rota in the back |
| Camera feeds | A monitor bank in the office |
| House rules | A board the group writes on |
| Cat status | The cat. Look at it. |
| Sealed stock | The rack it sits on. Standing in front of it is where you decide whether to sell it or open it. |
| What you pulled | The case, and the wall behind the counter |
| Deliveries and reordering | The back door |

Permitted non-diegetic HUD, kept minimal: an interaction prompt, held-item indicator, player
nameplates in co-op, and subtitles. Nothing else by default.

## The inspection interface

The single most important interaction in the game.

- **Two hands.** One artifact, one tool. Hand slots are visible and limited, and that limitation
  is a design feature.
- **Free rotation** on the held artifact with mouse or stick. No snapping to canonical angles.
- **Continuous zoom**, not stepped, with documents rendered as vector text so they stay
  crisp at any magnification.
- **The counter is a workspace.** Set things down, arrange them, compare. Objects persist
  where you put them.
- **Never pause.** Inspection happens in real time with the world running. This is the whole
  tension.
- **One-handed operation must be possible** for accessibility — every two-handed comparison
  has a set-down-and-compare equivalent.

## The kitchen interface

- **Station-relative context.** Standing at the griddle shows griddle affordances and nothing
  else.
- **Timers are audible first, visual second.** [Loop C](05-loop-c-kitchen.md) should be
  playable substantially by ear, which is what frees the eyes for
  [Loop B](04-loop-b-counter.md).
- **Cook state is read off the food**, not off a progress bar. Colour, sizzle, smoke, sound. A
  progress bar over a sandwich is the lazy version and is reserved as an accessibility option.
- **Orders in flight are the tickets on the rail.** No order-queue UI panel.

## Controls

Full keyboard-and-mouse and full gamepad support, **both first-class from Phase 2**. Every
binding remappable.

Gamepad needs particular care on the inspection interface — rotation on the right stick, tool
on a trigger, zoom on the other. **If a gamepad player is meaningfully worse at verification,
the interface is wrong rather than the player.**

## Accessibility

Non-negotiable, specified early because retrofitting is expensive.

> **No verification cue may depend on colour alone.** Every colour-carried signal has a shape,
> pattern or text equivalent. This is the single most important accessibility rule in the game,
> because colour is doing real work in forgery detection.

- **Colourblind modes** covering all three common types, validated against the actual
  document set rather than a test card
- **Scalable UI and subtitle text**, 1.0× to 2.0× minimum
- **Subtitles for all speech**, with speaker labels and directional indicators for off-screen
  audio — critical because the door chime and the kitchen timer are gameplay signals
- **A visual equivalent for every audio cue**, toggleable
- **Remappable everything**, including hold-versus-toggle for all held actions
- **Adjustable timer tolerance** as a difficulty option rather than an accessibility ghetto
- **Motion and head-bob reduction**, FOV control, camera shake toggle
- **Memory-assist option** surfacing active rules contextually at the counter — offered
  plainly, without penalty, and not buried in a submenu
- **Dyslexia-friendly font option that applies to documents too** — and this one needs care,
  because typeface *is* a forgery vector. The correct implementation substitutes the reading
  face while preserving relative typographic differences, so the mechanic survives.

That last point is the kind of thing that gets discovered at the end and done badly. **Design
the document renderer with it in mind from the start.**
