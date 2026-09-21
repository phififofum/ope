# Security Policy

## Supported versions

| Version | Supported |
| --- | --- |
| `main` | ✅ Yes |
| Tagged releases | ❌ None yet — the project is pre-release |

## Reporting a vulnerability

**Do not open a public issue for a security problem.**

Use GitHub's private reporting: **Security → Advisories → Report a vulnerability** on this
repository. That channel is visible only to maintainers.

Please include:

- What the issue is, and what an attacker gets out of it.
- Steps to reproduce, ideally with a minimal mod or save file.
- The commit or release you tested against.
- Whether you have disclosed it anywhere else.

**What to expect:** an acknowledgement within 3 working days, an assessment within 10, and
credit in the advisory and in [`CREDITS.md`](CREDITS.md) unless you would rather stay
anonymous. If we disagree that something is a vulnerability, you get a written reason rather
than silence.

## What counts

This is a moddable, host-authoritative co-op game. The interesting attack surface is not a
web server — it is the mod loader, the save system and the network layer.

**In scope:**

- **Mod sandbox escapes.** A mod reading or writing outside its own directory, reaching the
  network, or executing arbitrary commands on the host.
- **Malicious save or mod packages.** A crafted `.pck`, `.zip`, save file or definition that
  causes code execution, path traversal (`../` in a manifest), or a zip bomb.
- **Peer-to-host attacks.** A client that can crash the host, corrupt store state, or execute
  code on other players' machines.
- **Verification-truth leakage.** A modified client learning whether an artifact is forged
  before the player has inspected it. The entire game is built on not knowing, so this is a
  security property, not a balance one. See
  [the replication table](docs/design/09-multiplayer-and-scaling.md#what-is-replicated).
- **Unconsented data leaving the machine.** Telemetry is local-only by design.

**Out of scope:**

- Single-player cheating, save editing, or a host modifying their own game. Your store, your
  rules.
- A mod you installed deliberately doing what it says on the tin. We sandbox against
  accidents and hostile packages, not against your own informed consent.
- Bugs with no security consequence — those are [ordinary issues](https://github.com/phififofum/ope/issues/new/choose).

## Never transmitted between peers

Stated as policy because it is easier to hold than to recover: **mod definitions, scripts and
assets are never transmitted peer to peer.** Joining a host compares mod manifests and
reports mismatches. It never downloads code. Any design that would require it is rejected.

## Disclosure

Coordinated. We will agree a date with you, fix it, publish an advisory, and credit you. If a
fix is going to take longer than 90 days we will tell you why rather than let the clock run out
quietly.
