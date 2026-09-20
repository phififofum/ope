# Licensing

PoggyWoggy is free software with free assets, and pillar 5 —
*free as in freedom, all the way down* — is a build gate rather than an aspiration.

## The split

| What | Licence | SPDX |
| --- | --- | --- |
| Code — `core/`, `systems/`, `ui/`, `tools/`, `tests/`, `addons/` (ours) | [MIT](LICENSES/MIT.txt) | `MIT` |
| Content definitions, schemas and design documentation | [CC BY 4.0](LICENSES/CC-BY-4.0.txt) | `CC-BY-4.0` |
| Original art and audio we make | [CC BY 4.0](LICENSES/CC-BY-4.0.txt) | `CC-BY-4.0` |
| Third-party art, audio and fonts | Their own — **CC0 or CC BY only** | per sidecar |
| Third-party code in `addons/` | Their own, recorded in `CREDITS.md` | per addon |

Why the split: MIT keeps engine code maximally reusable, including by people who want to
build something else entirely out of the verification engine. CC BY 4.0 is the right licence for
creative work, travels well between projects, and is what most of our upstream asset sources
already use.

> [!NOTE]
> **This is a decision, not a law of nature.** It is recorded in
> [ADR-0004](docs/decisions/0004-licensing-mit-and-cc-by.md) with the alternatives that were
> weighed. If the project owner wants copyleft instead, that is a one-ADR change while the
> contributor list is still short — and much harder later.

## Allowed asset licences

**Allowed:** `CC0-1.0`, `CC-BY-4.0` (and earlier CC BY versions), `OFL-1.1` for fonts.

**Not allowed, ever:** `CC-BY-NC-*` (cannot ship in a commercial or even potentially
commercial release), `CC-BY-SA-*` (viral in a way that conflicts with the code licence),
`CC-BY-ND-*`, anything unlicensed, and anything whose provenance you cannot link to.

"We'll swap it later" is not a plan. Assets get embedded, referenced, and forgotten; by the
time anyone notices, the swap costs a release.

## Every asset carries its papers

Each asset file has a `.license.json` sidecar beside it:

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

`tools/licence_audit.py` walks the tree and:

- **fails CI** if any asset lacks a sidecar, or carries a licence outside the allowed list;
- **generates** [`CREDITS.md`](CREDITS.md) from the sidecars, so attribution cannot drift from
  what is actually shipped.

This is a hard gate, not a warning. Run it before you push:

```bash
python3 tools/licence_audit.py --check   # what CI does
python3 tools/licence_audit.py --write   # regenerate CREDITS.md
```

Mods are held to the same standard: the mod validator checks sidecars, and the mod manager
surfaces a mod's licence summary to players.

## The Freesound trap

Freesound licenses **per sound**, not per site. Roughly half the catalogue is CC0; the rest is
CC BY or CC BY-NC, and CC BY-NC cannot ship. Check each sound's own licence field. The audit
tool refuses anything that is not CC0 or CC BY — treat that as the backstop, not the process.

## Fonts

OFL or CC0 only. Documents need a credible variety of typefaces, because typeface
inconsistency is itself a forgery tell — so the bundled set is deliberately broad, and each face
carries its own sidecar like everything else.

## Contributing

By contributing you license your work under the licences above. There is no CLA and you keep
your copyright. See [CONTRIBUTING.md](CONTRIBUTING.md#licensing-your-contribution).
