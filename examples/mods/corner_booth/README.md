# Corner Booth

**Tier 2 — content modder.** A fixture, an asset, and the licence record that ships with
it. Every asset carries a `.license.json` sidecar naming its source, author and licence;
CI fails without one, and `CREDITS.md` is generated from them.

`affects_gameplay` is `false`, so a player without this mod can still join a host who has
it — they see a warning rather than a blocked join.

```bash
tools/validate_mod.sh examples/mods/corner_booth
```
