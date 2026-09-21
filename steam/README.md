# Steam build scripts

SteamPipe configuration for uploading a build to a Steam branch.
**[docs/release/steam.md](../docs/release/steam.md) is the guide** — this directory is just
the files.

| File | What it is |
| --- | --- |
| [`app_build.vdf`](app_build.vdf) | The app build script: which depots, where the content is, which branch |
| [`depot_linux.vdf`](depot_linux.vdf) | Linux depot mapping |
| [`depot_windows.vdf`](depot_windows.vdf) | Windows depot mapping |

## Before the first upload

Replace three placeholders with the real values from your Steamworks app:

| Placeholder | Where | What to put |
| --- | --- | --- |
| `480` | `app_build.vdf` → `appid` | Your app id |
| `481` | `app_build.vdf` + `depot_linux.vdf` | Your Linux depot id |
| `482` | `app_build.vdf` + `depot_windows.vdf` | Your Windows depot id |

App id `480` is Valve's public test app (Spacewar). It is left in deliberately so that a
misconfigured run fails somewhere harmless rather than publishing to a real store page.

## Two things that are deliberate

**`setlive` is empty.** Builds upload, then get set live on a branch from the Steamworks web
UI by a person. Automating "set live on default" is how a broken build reaches players at
2am. CI can set a *playtest* branch live explicitly — see the guide.

**`preview "0"` means a real upload.** Set it to `1` for a dry run that validates the script
and prints what would be sent without touching the content servers. Do that first.

## Never commit

`steam_appid.txt`, your `config.vdf`, Steam Guard tokens, or anything from the Steamworks
SDK. They are in [`.gitignore`](../.gitignore); leaving them out is not optional, because a
leaked `config.vdf` is a logged-in session.
