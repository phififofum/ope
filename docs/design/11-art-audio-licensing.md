# 11 · Art, audio and asset sourcing

[← Onboarding and interface](10-onboarding-and-interface.md) · [Index](README.md) · [Next: Content manifest →](12-content-manifest.md)

---

## Art direction

**Stylised low-poly world, high-fidelity documents.** The split is load-bearing rather than
aesthetic. The world can be chunky and readable — it is furniture you navigate. **Documents
must survive close scrutiny at high zoom, because scrutiny is the game's verb**, and a
low-poly ID card texture is unreadable at the range the game requires.

### The resolution: documents are not art assets at all

They are **generated at runtime** from `document_type` definitions as 2D `Control` node
hierarchies — vector layouts, real text, procedural security features, and procedurally
applied wear, print artefacts and forgery perturbations.

This gives crisp text at any zoom, makes every forgery vector a data-driven transform rather
than a hand-drawn variant, and means a modder can add a new document type in JSON
without opening an image editor. **It is the single highest-leverage technical decision in the
art pipeline** — and it matters even more for cards and box art than it did for IDs, because
card faces are cheap to author as data and ruinous to author by hand.

### World direction

Warm, cluttered, over-lit fluorescents against a dark street. Shelves to the ceiling. **Density
over polish.** The place should feel like it has been there for thirty years, and the honest
way to hit that with CC0 assets is heavy use of decals, stickers, hand-written signs, taped-up
event posters and surface grime rather than bespoke geometry.

## Sourcing

All sources **CC0 or CC BY**. Nothing CC BY-NC, CC BY-SA, or of unclear provenance. Full
policy in [LICENSING.md](../../LICENSING.md).

| Source | Use | Licence |
| --- | --- | --- |
| Kenney | Props, UI, fonts, audio. Tens of thousands of assets in a consistent visual language — the primary source. | CC0 |
| Quaternius | Rigged, animated characters and creatures, including cats | CC0 |
| KayKit | Themed prop packs, filling the gap between the two | CC0 (most packs) |
| Poly Haven | PBR textures and HDRIs — the realism layer on surfaces | CC0 |
| ambientCG | 1,500+ PBR materials | CC0 |
| Freesound | SFX — **per-sound licence, must be filtered** | Mixed |
| Sonniss GDC bundles | Professional SFX libraries | Royalty-free, verify terms per bundle |

> **The Freesound trap.** Freesound licences per *sound*, not per site. Roughly half the
> catalogue is CC0; the rest is CC BY or CC BY-NC, and CC BY-NC cannot ship in a commercial
> game. The asset ingest tool must refuse any download whose licence field is not CC0 or
> CC BY. **Do not leave this to human discipline.**

### The asset-flip risk

Shipping Kenney and Quaternius unmodified is recognisable to experienced players, and that
is a real reputational risk for the finished game. **Budget for a retexture and kitbash pass in
Phase 8**: same geometry, new materials, shop-specific decals and signage. That converts
"free asset game" into "game with a coherent look." Procedural documents help enormously,
because the things players stare at longest are generated rather than sourced.

## Licence compliance, automated

Every asset carries a `.license.json` sidecar next to it:

```json
{
  "file": "content/assets/props/display_case.glb",
  "source": "https://kenney.nl/assets/some-pack",
  "author": "Kenney",
  "license": "CC0-1.0",
  "retrieved": "2026-09-20",
  "modifications": "retextured, UVs adjusted"
}
```

- **CI fails the build** if any asset lacks a sidecar or carries a disallowed licence. This is a
  hard gate, not a warning.
- [`tools/licence_audit.py`](../../tools/licence_audit.py) generates
  [`CREDITS.md`](../../CREDITS.md) and the in-game attribution screen from the sidecars, **so
  credits can never drift from reality.**
- The same rules apply to mods: the mod validator checks sidecars, and the mod manager
  surfaces a mod's licence summary to players.

## Audio

**Audio does more work here than the visuals.** A late-night cafe is a soundscape: the cooler
compressor cycling, the door chime, the espresso grinder, dice on wood, the fluorescent hum,
distant traffic, a table laughing two zones away, the radio nobody changes.

- **The door chime is a gameplay signal** — you must be able to hear someone enter from the
  back room. Directional, unmissable.
- **Distinct timer audio per kitchen station**, because Loop C is played by ear as much as by
  eye.
- **Verification ambience.** When an encounter begins, the mix ducks slightly and the room
  quietens. Subtle, never a stinger — **the game must not announce that this one is
  suspicious.**
- **Room tone changes by zone.** A quiet-play corner and the event space sound different,
  and that is how [noise propagation](03-loop-a-floor.md#zone-design--the-layout-puzzle-at-building-scale)
  is communicated.
- **Cat audio carries real information:** the hunting chirp, the warning growl, the specific
  yowl of a cat that has got outside.
- **Per-cat vocal variation**, so players recognise which cat is complaining.
- **Music is sparse and diegetic** — the shop radio, which players can change, and which is a
  mod hook.

## Fonts

OFL or CC0 only. Documents need a credible variety of typefaces **because typeface
inconsistency is itself a forgery tell** — bundle a deliberately broad set of open licensed
faces so that "wrong font for this jurisdiction" is a detectable vector.

Remember the accessibility constraint from
[10](10-onboarding-and-interface.md#accessibility): the dyslexia-friendly font option must
substitute the reading face while preserving *relative* typographic differences, or it deletes a
mechanic.
