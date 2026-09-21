# House Rules

**Tier 3 — script modder.** A mechanic that did not exist before: a trade-in ceiling the
shop sets for itself, a blanket carding policy, and slightly more patient regulars.

It uses the same event bus base systems use:

- `on_attempt` for cancellable events — return a reason to veto, and the player is shown it
- `on` with a query event — contributions aggregate deterministically
- `on` with a notification — observe, never alter

```bash
tools/validate_mod.sh examples/mods/house_rules
```
