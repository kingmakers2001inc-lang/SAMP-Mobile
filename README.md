# SAMP Mobile

Android SA-MP client sources for **Grand Theft Auto: San Andreas**.

Choose the version you need:

## SA-MP 2.11

* ARM64 only
* Gloss integration
* 16 KB page size support
* Cache path: `/storage/emulated/0/GTA/`

[Open GTA-2.11 branch](https://github.com/kuzia15/SAMP-Mobile/tree/GTA-2.11)

## SA-MP 2.10

* ARM32 and ARM64 support
* ShadowHook integration
* Cache path: `/storage/emulated/0/GTA/`

[Open GTA-2.10 branch](https://github.com/kuzia15/SAMP-Mobile/tree/GTA-2.10)

## Building on an Android phone (no PC)

This branch contains the **SA-MP 2.11** client sources. Every push is built
by GitHub Actions in the cloud (`.github/workflows/build-apk.yml`), so you only
need a phone:

1. Edit the code (in the GitHub app, in a browser or in Termux with
   `pkg install git` then `git clone` and `git push`).
2. Push. Open the **Actions** tab, select the latest **Build APK** run and
   download the `samp-mobile-debug-apk` artifact.
3. Install the APK and put the game cache in `/storage/emulated/0/GTA/`.

### Game files

`libGame.so` (the GTA SA engine) and the game data belong to Rockstar Games
and are **not** stored in this repository. Take them from your own legally
purchased copy of GTA SA for Android:

* Upload your `libGame.so` somewhere private with a direct-download link,
  then add that link as a repository secret named `GAME_LIB_URL`
  (**Settings → Secrets and variables → Actions**). The build packs it into
  the APK. Without it the APK builds but the game will not start.
* Never commit game files or share an APK that contains them.

Client details: [docs/CLIENT-2.11.md](docs/CLIENT-2.11.md).

## Game server (open.mp)

The `server/` folder holds the **Kingmakers RP** server: a starter gamemode
(`server/gamemodes/kingmakers.pwn`) for the open-source
[open.mp](https://open.mp) server. Every change in `server/` is compiled and
smoke-tested by the **Build Server** action, which uploads a ready-to-run
Linux server as the `kingmakers-server-linux` artifact.

The server only runs on x86 Linux, not on a phone, so rent a small
Ubuntu/Debian VPS and log in from Termux (`pkg install openssh`, then
`ssh root@<vps-ip>`). Then install, or later update, it with one command:

```bash
curl -fsSL https://raw.githubusercontent.com/kingmakers2001inc-lang/SAMP-Mobile/main/server/install-vps.sh | bash
```

It runs as the `kingmakers-server` service on UDP port 7777, starts on boot
and keeps your `config.json` and `scriptfiles/` across updates. To install
from a branch that is not merged yet, add `BRANCH=<branch-name>` in front of `bash`.
Players connect to `<vps-ip>:7777`.

Gamemode commands: `/help`, `/car [400-611]`, `/heal`, `/pos`.

## Repository Structure

The `main` branch contains general project information.

Source code is stored in version-specific branches:

* `GTA-2.11`
* `GTA-2.10`

## Disclaimer

This project is provided for educational and research purposes only.

Grand Theft Auto, Grand Theft Auto: San Andreas and SA-MP are trademarks of their respective owners. This project is not affiliated with or endorsed by Rockstar Games, Take-Two Interactive or the original SA-MP development team.



### News about project

[![Telegram](https://img.shields.io/badge/Join-Telegram-24A1DE?style=for-the-badge&logo=telegram&logoColor=white)](https://t.me/+ou4jTw2Cq8ZiZThi)
