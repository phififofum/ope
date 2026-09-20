# 12 · Content manifest for v1.0

[← Art and audio](11-art-audio-licensing.md) · [Index](README.md) · [Next: Testing →](13-testing-and-verification.md)

---

## The benchmark and the strategy

The shop-sim benchmark is Supermarket Simulator: roughly 26 licences unlocking over 150
products, each gated behind a store level. That is the bar **for the shop layer alone**.

Beating it on product count would be a shallow win and a grind to author. PoggyWoggy
exceeds it on two axes at once: more depth in the retail layer, **plus entire content
categories the benchmark has none of** — documents, forgery vectors, recipes, board games,
card sets, cats. The verification layer is where the content advantage is structural rather
than incremental.

## v1.0 targets

| Category | Target | Note |
| --- | --- | --- |
| **Document types** | 28 | IDs across 8 jurisdictions, plus trade-in records, event registrations, membership cards, prize receipts, distributor manifests, inspection notices |
| **Forgery vectors — documents** | 60+ | Combinatorial across document types — the real content depth |
| **Forgery vectors — cards** | 40+ | Counterfeits, resealed product, trims, recolours, pressed creases |
| **Cafe menu items** (`recipe`) | 45 | Food and a drinks programme, with a modification grammar producing thousands of distinct orders |
| **Cafe and retail products** | 120 | A cafe stocks less than a grocer; depth moves elsewhere |
| **Board games** (library + retail) | 250 | Fictional titles with component lists, player counts, weights, play times |
| **Card sets** | 8 | Each with a card pool, pull rates and a rarity structure |
| **Individual cards** | 600+ | Generated within sets from layout templates, so authoring cost is low |
| **Customer archetypes** | 45 | Appearance pools, behaviour weights, dialogue sets |
| **Named recurring NPCs** | 40 | Regulars, repeat offenders, the difficult ones. The ledger needs faces. |
| **Zones and fixtures** | 75 | Zone design needs parts to build with |
| **Licences** | 25 | Each adds verification burden, not just SKUs |
| **Tools** | 22 | The full tree, document and authentication tools both |
| **Suppliers** | 20 | Legitimate, discount and questionable, with distinct legitimacy profiles |
| **Cats** | 12 | Breeds and coats, combined with a trait pool for variety |
| **Staff roles** | 7 | Including the game teacher / event judge |
| **Random events** | 50 | Weather, power cuts, deliveries gone wrong, street closures, local news |
| **Scripted story beats** | 30 | Across the five acts, including the Act IV grey-market thread |
| **Upgrades** | 45 | Space, equipment, security, quality-of-life |
| **Achievements** | 60 | |
| **Locale** | English first, full externalisation | Every string in `loc_string` definitions from day one |

**The totals go up, not down**, compared with a grocery setting. Board games and cards are
cheap to author as data and expensive to author as art — which is exactly why
[procedural artifacts](11-art-audio-licensing.md#the-resolution-documents-are-not-art-assets-at-all)
matter even more here than they did for IDs.

## Why this is achievable

The counts look large but the authoring cost is low, because
[the architecture](02-architecture.md) made everything data. A product is a JSON object. A
forgery vector is a named transform plus a weight. An order is a recipe crossed with a
modification grammar. A card is a template plus a row in a set.

**The expensive work is the systems.** Once the schemas are frozen, content authoring is
bulk generation against a validator.

This is the concrete payoff of [pillar 3](01-vision.md#design-pillars), and it is why the
skeleton must not be compromised for early playability.

## Content quality gates

Volume without coherence is worthless. **Every content batch must pass all of these**, and
the mechanical ones run in CI via
[`tools/validate_content.py`](../../tools/validate_content.py):

| Gate | Enforced by |
| --- | --- |
| Schema validation, zero warnings | CI |
| Every product is reachable through some licence, and every licence unlocks something | CI |
| Every document type has at least three distinct forgery vectors | CI |
| Vectors on a document type span all three [kinds of wrong](04-loop-b-counter.md#the-three-kinds-of-wrong) | CI |
| **Every forgery vector is detectable with at least one tool available at the tier it appears** | CI |
| No tool returns a verdict | CI |
| **Sealed product always returns less opened than sold**, per set and per product | CI |
| Every sealed product names a card set that exists, and every set's pull rates sum to 1 | CI |
| Every asset has a valid `.license.json` | CI |
| Every string is externalised — no literals in scripts or definitions | CI (partial today) |
| No product is strictly dominated by another at the same tier | Review, then balance simulation |
| Every recipe is completable with ingredients purchasable at that stage | Review, then bot player |
| A balance pass shows no category obviously optimal or obviously dead | [Telemetry](13-testing-and-verification.md#telemetry) |

## Localisation

Every player-visible string is a `loc:` key from the first commit. **This is not retrofittable**,
and a definition with a literal string in a name field fails validation.

Translation packs are a [mod](../modding/README.md) like anything else — which means the
community can ship a language the project never planned for, without touching the game.
