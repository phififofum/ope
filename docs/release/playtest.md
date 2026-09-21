# Cutting a build for playtesters

[← Docs](../README.md) · [Shipping to Steam](steam.md)

The short version: **Actions → Release → Run workflow → type a version → Run.**
About ten minutes later there is a public pre-release with a Windows zip and a Linux zip
attached, and a link you can send to anyone.

No terminal, no local engine, no signing keys.

---

## What it does

1. Builds Linux and Windows from a clean checkout, using the engine version pinned in
   [`.godot-version`](../../.godot-version) — the same one a contributor builds with
   locally.
2. Boots the exported Linux binary headless and fails the run if the content registry
   comes up short. This catches the failure that only appears after packaging: a file the
   game reads at runtime that never made it into the export.
3. Creates the tag, publishes it as a **pre-release**, and attaches both zips.
4. Leaves Steam alone unless you ask for it and the secrets exist.

## Versions

Use `0.1.0-playtest.N` while the game is pre-1.0 and being handed to friends. The leading
`v` is added for you.

These tags are snapshots for testing. They are **not** releases of the
[public mod API](../modding/README.md#the-public-api-surface) — schemas and event names may
still move without a major version until `v1.0.0`, and
[CHANGELOG.md](../../CHANGELOG.md) says so.

A version that already exists fails the run rather than moving the tag, because somebody
may already have downloaded the old one.

## What a playtester sees

The release page carries the install instructions and the control scheme, so nobody has to
find a README first:

- **Windows** — unzip, run `poggywoggy.exe`. Windows warns that the publisher is unknown,
  because the build is not code-signed: **More info → Run anyway**.
- **Linux** — unzip, `chmod +x poggywoggy.x86_64`, run it.
- **macOS** — not built yet.

Everything the game needs is inside the one file. There is no installer and nothing is
written outside the folder it runs in.

## From a terminal instead

Pushing a `v*` tag does the same thing:

```bash
git tag -a v0.1.0-playtest.1 -m "first playtest build"
git push origin v0.1.0-playtest.1
```

## Why the workflow tags itself

It would be tidier for the UI button to push a tag and let the tag trigger the release.
It would also do nothing: GitHub does not fire workflows from a push made with
`GITHUB_TOKEN`, which is a deliberate guard against a workflow triggering itself forever.
So the one workflow creates the tag and cuts the release in the same run.
