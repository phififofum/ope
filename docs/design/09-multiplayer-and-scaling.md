# 09 · Multiplayer and scaling

[← Progression and staff](08-progression-and-staff.md) · [Index](README.md) · [Next: Onboarding and interface →](10-onboarding-and-interface.md)

---

## Topology

Host-authoritative, one player hosting, up to four joining. No dedicated servers in v1. The
host's simulation is ground truth; clients predict movement and interaction locally and
reconcile.

At five players in a small interior the bandwidth and CPU demands are modest — **this is not
a networking-hard game, and the architecture should stay boring on purpose.**

All transport sits behind a `NetTransport` interface. v1 ships `ENetMultiplayerPeer` for
direct IP and LAN. Steam lobbies and NAT punch-through arrive later as a swap-in module
with zero changes to game code.

## What is replicated

| Category | Model | Rationale |
| --- | --- | --- |
| Player position, look, held item | Client-predicted, host-reconciled | Responsiveness matters most here |
| Inventory and shop state | Host-authoritative, delta-replicated | Correctness over latency |
| **Verification encounters** | **Host-authoritative; artifact truth never leaves the host** | **Prevents a modified client reading the answer** |
| Cats | Host-simulated, interpolated on clients | Behaviour must be consistent |
| Economy, time, progression | Host only, broadcast | Single source of truth |
| Cosmetics, UI state, camera | Local only | Never replicate what nobody else sees |

The emphasised row matters. Ground truth for whether an artifact is forged stays on the
host and is transmitted only as the fields a client's currently-held tool reveals. **This is the
one place where a security-minded design decision is worth the extra work, because the
entire game is built on not knowing.** It is treated as a security property, not a balance one
— see [SECURITY.md](../../SECURITY.md).

## Role division at each player count

| Players | Natural division | Feel |
| --- | --- | --- |
| **1** | Triage constantly. The kitchen opens only between rushes. Fully viable, deliberately tight, and the best way to learn the systems. | Solitary and deliberate |
| **2** | Counter and kitchen, trading off the floor between them. | Tight, high-communication |
| **3** | Counter, kitchen, floater. The floater shelves, cleans, receives deliveries, runs component checks and covers whoever is drowning. | **The target experience** |
| **4** | The floater splits: one on receiving and the back room, one on the floor and events. Deliveries get properly verified for the first time. | Comfortable, broader |
| **5** | Add the card counter as a dedicated station, or a back-office role running cameras, the ledger and staff audit. | Ambitious, specialised |

**Three is the design centre.** Its defining quality: *the floater is always slightly behind*.
That is correct and should not be tuned away. The floater is the pressure-release valve and
the person who notices things, and the role should feel important rather than menial —
which is why receiving, pest control, cat care, component checks and the ledger all live there.

**No station is locked.** Roles are emergent from where you stand and what you pick up, not
assigned from a menu.

## Shared verification

The best co-op moments in this game are two players disagreeing about an ID. Support it
explicitly:

- Any player can pick up an artifact and inspect it; others see the inspection happening
- A **second-opinion gesture** hands the artifact across, visibly, to another player
- Tools are physical and shared — the UV torch is *somewhere*, and it might be in the back
- **The verdict belongs to whoever is at the register**, so disagreement has to be resolved
  socially rather than by a vote UI
- **Consequences are collective.** Nobody gets a personal strike.

## Co-op and distributed memory

[Rule accretion](04-loop-b-counter.md#rule-accretion--the-real-difficulty-curve) becomes a
genuinely social mechanic, and it is the best argument for three players.

Forty rules across four players is a natural specialisation. Somebody becomes the person
who knows the promo policy. Somebody knows the alcohol hours cold. **When that player is
on a break, in the back, or absent from the session entirely, the group has a hole in its
knowledge — and discovering the hole mid-transaction, out loud, is exactly the kind of
moment this game exists to produce.**

Support it explicitly: shared access to the binder, the ability to call another player over to a
counter, and a **house-rules board** where the group writes its own policies down for each
other.

## Join, drop and persistence

- **Drop-in at any time**, into a clean spawn at the back door with no pause.
- **Drop-out** hands anything carried to the floor and reassigns owned tasks. A disconnect
  must never lose shop state.
- **Host migration is out of scope for v1** — documented as a v1.1 candidate, with the save
  system written so it does not preclude it.
- **Progression is the host's shop.** A joining player contributes to and plays in the host's
  save. Personal cosmetics and statistics travel with the player. This avoids the
  save-fragmentation problem that plagues co-op progression games.
- **Reconnection within a grace window** restores the player to their prior state.

## Voice and presence

No built-in voice chat in v1 — everyone is on Discord. **Do invest in presence:** visible
pointing, a ping that puts a marker in world space, readable held items, name tags that fade
with distance, and clear audio cues for the door, the kitchen timer and the delivery bell.
Coordination should be possible without anyone typing.

## Mods in multiplayer

The host's mod set is authoritative. On join, the client receives the host's mod manifest and
compares. Mismatches produce a clear, itemised screen: which mods are missing, which
versions differ, which are cosmetic-only and therefore safe.

- Gameplay-affecting mismatches (`affects_gameplay: true`) **block** the join.
- Cosmetic-only mismatches **warn** and continue.
- **Mod definitions are never transmitted between peers.** No automatic downloading of
  arbitrary code, ever.

## How scaling actually works

The naive approach — scale customer volume by headcount — produces a game that feels
identical at every count and therefore pointless to play together. The good version scales
differently along different axes.

| Axis | Scaling | Why |
| --- | --- | --- |
| Customer arrival rate | Sub-linear, roughly ×(1 + 0.55 per extra player) | More players should mean more comfort as well as more work |
| Kitchen order rate | Sub-linear, and only once the kitchen is staffed by a player | A solo player should not be punished for opening the griddle |
| **Verification encounter rate** | **Flat per shift, not per player** | **The suspicious encounters are the content. Everyone should see them.** More players means more eyes on the same encounters, not more encounters each. |
| Forgery difficulty | Flat | Never punish a group for being a group |
| Maintenance load | Near-linear | More people means more mess, and it gives the floater a job |
| Income and costs | Sub-linear income, linear costs | Keeps progression pace comparable across counts |
| Progression pace | Normalised to within ~15% across all counts | A trio and a solo player should reach Act III in comparable real time |

## Solo is a first-class mode

Not a concession. Solo play is how most people will learn the systems and how some will
prefer to play.

- The kitchen is **optional** solo — openable between rushes, closeable during them, with no
  penalty for a closed griddle beyond forgone revenue
- Staff arrive slightly earlier in the progression curve, because delegation is the solo answer
  to the floater role
- The director is more aggressive about not stacking a hard encounter onto an active order
- One quality-of-life allowance: a solo player can leave an artifact held on the counter and
  return to it without the customer walking

### Two players

The tightest configuration and, for many groups, the most intense. Counter and kitchen, with
the floor neglected between them. Tune so that two players can keep the room clean but
must choose when. **The ideal two-player session has one moment per shift where both of
them are wrong about where they should be standing.**

### Four and five

Extra players should unlock **depth, not throughput**. At four, receiving becomes a properly
staffed station and deliveries get verified rather than waved through — which turns on a
whole content family a trio realistically skips. At five, the back-office role runs cameras, the
ledger and staff audit, and the forensic layer comes alive.

> **The design rule: no content is locked behind player count, but some content is only
> practical above a count.** A trio *can* verify deliveries; they will just usually decide not to,
> and pay for it occasionally. That is a fine outcome, and it gives the fourth player
> something real to be.

## Difficulty is a separate axis

Player count is not difficulty and **must never be conflated with it**. Presets are director
profiles plus economy multipliers, all data-driven.

| Preset | Changes |
| --- | --- |
| **Relaxed** | Lower forgery rate, forgiving timers, no strike escalation, generous economy |
| **Standard** | As specified throughout these documents |
| **Tight** | Higher suspicious rate, harsher patience, faster expiry, thin margins |
| **Brutal** | Adaptive adversaries from the start, no tool hints, strikes never decay |
| **Custom** | Every multiplier exposed individually |

Each preset is a JSON file. Player-count scaling applies on top of whichever preset is active,
and the two must be independently tunable, so that a trio on Brutal and a solo player on
Relaxed are both coherent experiences.

## Testing requirement

The [bot player](13-testing-and-verification.md#4-the-bot-player) runs the full campaign at
**every player count from 1 to 5, on every preset, across multiple seeds**. Any count or
preset that soft-locks, stalls economically, or finishes more than 15% off the reference pace
is a Phase 5 gate failure.
