# Shipping a test build to Steam

[← Docs](../README.md)

This is the whole path from a clean checkout to a build your testers can install from their
Steam library. It works today: [Phase 0](../design/14-work-order.md#phase-0--foundation)
exports a real Linux and Windows build, and that build is what gets uploaded.

> [!NOTE]
> What Phase 0 exports is a boot screen that loads the content registry and reports what it
> found. **That is the point** — it proves the whole chain (build → depot → branch →
> someone else's machine) before there is a game riding on it. The first build worth playing
> arrives at [Phase 2](../design/14-work-order.md#phase-2--vertical-slice).

## What you need once, on Steamworks

1. **An app.** A Steamworks account and an appid. Testing on a store app you have not
   released is fine; testers install it from a key or a playtest.
2. **Two depots**, one per platform. Note their ids — Linux and Windows.
3. **A builder account.** Create a *separate* Steam account for uploads, give it only
   "Edit App Metadata" + "Publish App Changes to Steam" on this app, and **turn off Steam
   Guard mobile for it** (email Guard is fine). Never use your personal account in CI.
4. **A branch to upload to.** Make one called `playtest` (or `beta`) in the app's SteamPipe
   settings, and set a password if the testers are not already restricted.
5. **Steam Playtest** (optional, and the nicest option for testers): Steamworks →
   *Playtest* creates a separate free app testers can request access to. It has its own appid
   and its own depots, so point the VDFs at those instead.

## What this repository gives you

| File | What it does |
| --- | --- |
| [`export_presets.cfg`](../../export_presets.cfg) | Linux and Windows export presets, with the content JSON included in the pack |
| [`steam/app_build.vdf`](../../steam/app_build.vdf) | SteamPipe app build script |
| [`steam/depot_linux.vdf`](../../steam/depot_linux.vdf) · [`steam/depot_windows.vdf`](../../steam/depot_windows.vdf) | Depot mappings |
| [`.github/workflows/release.yml`](../../.github/workflows/release.yml) | Builds both platforms on a tag, attaches them to a GitHub release, and uploads to Steam when the secrets exist |

## Building locally

With Godot 4.7.2 and its export templates installed:

```bash
# from a clean checkout
godot --headless --path . --import                   # first run only
godot --headless --path . -- --smoke-test            # sanity: content loads, exit 0

mkdir -p build/linux build/windows
godot --headless --path . --export-release "Linux"            build/linux/poggywoggy.x86_64
godot --headless --path . --export-release "Windows Desktop"  build/windows/poggywoggy.exe

# verify the exported build, not just the project
./build/linux/poggywoggy.x86_64 --headless -- --smoke-test
```

The last line matters. **A build that runs in the editor and fails when exported is the
normal failure**, and it is almost always a file that lives outside the resource system —
content JSON, a locale file, a mod — that is missing from `include_filter` in
`export_presets.cfg`.

## Uploading by hand, the first time

Do this manually once before trusting CI with it.

```bash
# 1. Fill in your ids
$EDITOR steam/app_build.vdf steam/depot_linux.vdf steam/depot_windows.vdf

# 2. Dry run: set "preview" "1" in app_build.vdf, then
steamcmd +login <builder_account> +run_app_build "$PWD/steam/app_build.vdf" +quit

# 3. Read the output. It lists every file it would send. Then set preview back to 0 and
#    run it again for real.
```

The first interactive login will ask for a Steam Guard code and write a `config.vdf`. That
file **is a logged-in session** — it is gitignored, and it is what CI needs as a secret.

Then, in the Steamworks web UI: *Builds* → find your build → set it live on `playtest`.
**The VDFs deliberately do not do this for you.**

## Uploading from CI

[`release.yml`](../../.github/workflows/release.yml) runs on a version tag
(`v0.1.0`) or manual dispatch. It always builds and always attaches artifacts; **it uploads to
Steam only when the secrets are present**, so a fork or a contributor's tag cannot publish
anything.

Add these repository secrets:

| Secret | What it is |
| --- | --- |
| `STEAM_USERNAME` | The builder account's login name |
| `STEAM_CONFIG_VDF` | The base64 of that account's `config.vdf` after a successful local login: `base64 -w0 ~/.steam/config/config.vdf` (macOS: `~/Library/Application Support/Steam/config/config.vdf`) |
| `STEAM_APP_ID` | Your appid |
| `STEAM_DEPOT_LINUX` · `STEAM_DEPOT_WINDOWS` | Depot ids |

Then:

```bash
git tag -a v0.1.0 -m "Phase 0 pipeline build"
git push origin v0.1.0
```

Upload targets the `playtest` branch by default. Change it with the workflow's
`steam_branch` input on a manual run.

### If the Steam step fails

| Symptom | Cause |
| --- | --- |
| `Login Failure: Account Logon Denied` | `STEAM_CONFIG_VDF` is stale or from an account with mobile Guard on. Log in locally again, re-encode, replace the secret. |
| `Failed to find depot` | The depot ids in the VDFs and the secrets disagree, or the depot is not attached to the app |
| Upload succeeds, testers see nothing | The build is uploaded but not set live on a branch. That is on purpose — go and set it live. |
| Build runs in CI, crashes for testers | Almost always `include_filter`. Run the exported binary, not the project. |

## What to tell testers

The Phase 0 build opens a window, reports what content loaded, and exits when closed. There
is nothing to play yet. What you want back from it:

- **Does it launch at all** on their machine — driver-level failures show up here and nowhere
  else.
- **Does the definition count match** what CI reported. A mismatch means the pack is
  incomplete.
- Windows SmartScreen and Linux distro friction: unsigned builds get warnings, and it is
  worth knowing which ones before there is an audience.

## Before the store page goes public

Not needed for a playtest, but they arrive together, so they are listed here to be noticed
early:

- **Content survey.** [Loop D](../design/06-loop-d-case.md) simulates opening sealed
  product with random contents. Steam requires disclosure of *in-game purchases* and of
  gambling-like content; **there are no real-money purchases in this game, ever**, and the
  simulated gamble is disclosed honestly. Say so plainly in the survey rather than hoping
  nobody asks.
- **Capsule art and a trailer** are a Phase 8 job, not a Phase 0 one.
- **Attribution.** [`CREDITS.md`](../../CREDITS.md) is generated from asset licence records
  and is what the in-game attribution screen renders. CC BY assets *require* that screen —
  it is a licence condition, not a courtesy.
- **No real brands, currencies, jurisdictions, publishers or reproductions of real identity
  documents or trading cards.** Fictional-but-plausible throughout. This is
  [a legal requirement as much as a design one](../design/15-risks-and-non-goals.md#explicit-non-goals-for-v10).

## Steam integration in the game itself

Deliberately absent for now. `NetTransport` exists so that Steam lobbies and NAT
punch-through can be added later as a swap-in module with **zero changes to game code**, and
the mod manifest is Workshop-compatible from day one. Neither is v1 work — see
[16 Post-v1 roadmap](../design/16-post-v1-roadmap.md).

Direct IP and LAN are what multiplayer testing uses until then.
