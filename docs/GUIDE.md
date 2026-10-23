# Kingmakers RP: phone-only guide

Everything below works from an Android phone: a browser for GitHub, a file
manager (for example ZArchiver) and [Termux](https://f-droid.org/packages/com.termux/).

GitHub's settings pages are easiest in a mobile browser with **Desktop site**
turned on; the GitHub app does not show repository settings.

---

## 1. Test the APK

### 1.1 The game engine file (`libGame.so`)

The APK needs `libGame.so`, the GTA SA engine. It is Rockstar's code, so it is
**not** in this repository and must never be committed or shared.

This client was made for one specific build of that file: a modified, renamed
`libGTASA.so` re-linked for 16 KB pages. The client uses fixed memory
addresses inside it, so an unmodified `libGTASA.so` from the store version of
the game will crash. The matching file has this SHA-256 fingerprint:

```
4c6a7445e30b27afdda781302e4db9bac89c28fc1181b68b1eef16f84d6a282e  (8,943,088 bytes)
```

Check a file in Termux with `sha256sum libGame.so`. The **Build APK** action
also checks it and shows a warning if it does not match.

### 1.2 Give the build a private download link

1. Upload your `libGame.so` to a file host that gives a direct download link,
   for example Dropbox (change the end of the share link to `?dl=1`).
   Anyone with the link can download the file, so keep it private.
2. On GitHub open **Settings → Secrets and variables → Actions → Secrets →
   New repository secret**. Name: `GAME_LIB_URL`, value: the link.
3. Open **Actions → Build APK → Run workflow** to build again.
4. When the run is green, download `samp-mobile-debug-apk` at the bottom of the
   run page, extract it with ZArchiver and install `KingmakersRP-debug.apk`
   (allow installing from unknown sources when asked).

### 1.3 Game files on the phone

The client reads everything from `/storage/emulated/0/GTA/`:

* the game data from your own copy of GTA SA for Android;
* `GTA/SAMP/settings.ini`. The app creates a basic one on first launch;
  edit it to set your name and server:

  ```ini
  [client]
  name=YourName
  host=1.2.3.4
  port=7777
  ```

  `host`/`port` are ignored when a built-in server is set (section 3).

When Android asks, allow **All files access**, otherwise the game cannot read
`/storage/emulated/0/GTA/`.

### 1.4 If it crashes

The client writes its log to `/storage/emulated/0/GTA/logcat.txt`. Open it in
a file manager and copy the last 50 lines into the chat with Claude, together
with what you did right before the crash.

---

## 2. Get a server (VPS)

The open.mp server only runs on **x86** Linux, so it cannot run on the phone.
Rent the smallest Ubuntu 22.04/24.04 **x86_64** (not ARM) VPS from any
provider. 1 CPU and 1 GB RAM is plenty for a small server.

If the provider has a firewall in its control panel, allow **UDP port 7777**.

### 2.1 Install

In Termux:

```bash
pkg update
pkg install openssh
ssh root@<vps-ip>
```

Then, on the VPS:

```bash
curl -fsSL https://raw.githubusercontent.com/kingmakers2001inc-lang/SAMP-Mobile/main/server/install-vps.sh | bash
```

Run the same command again whenever you change the gamemode on GitHub. It
updates the server and keeps your accounts, config and bans.

| Task | Command (on the VPS) |
|---|---|
| Live log | `journalctl -u kingmakers-server -f` |
| Restart | `systemctl restart kingmakers-server` |
| Edit settings | `nano /opt/kingmakers-server/config.json`, then restart |

### 2.2 Make yourself admin

1. Join the server with the app and register.
2. On the VPS:

   ```bash
   apt-get install -y sqlite3
   sqlite3 /opt/kingmakers-server/scriptfiles/kingmakers.db "UPDATE accounts SET admin = 3 WHERE name = 'YourName';"
   ```

3. Reconnect. Admin level 3 can then promote others in game with
   `/makeadmin [id] [level]`.

---

## 3. Built-in server address

To make the app always connect to your server:

1. On GitHub open **Settings → Secrets and variables → Actions → Variables →
   New repository variable**.
2. Add `SERVER_HOST` with your VPS IP (for example `1.2.3.4`) and, if you
   changed the port, `SERVER_PORT` (default `7777`).
3. Run **Actions → Build APK → Run workflow** and install the new APK.

Remove the variables and rebuild to go back to `settings.ini`.

---

## 4. Gameplay

Players register with a password the first time and log in after that. Cash,
bank balance, house, score, skin, position, wanted level, jail time and admin
level are saved.

| Command | Who | What it does |
|---|---|---|
| `/help` | everyone | List commands |
| `/stats` | everyone | Money, score, wanted level, job |
| `/car [400-611]` | everyone | Spawn a vehicle |
| `/heal`, `/pos` | everyone | Heal, show position |
| `/work` | everyone | Delivery job: drive to the marker, earn $300-800 |
| `/police` | not wanted | Go on or off police duty |
| `/arrest [id]` | police | Jail a wanted player within 5 m (60 s per star, $500 per star reward) |
| `/quitjob` | everyone | Leave your job |
| `/balance`, `/deposit [amount]`, `/withdraw [amount]` | at an ATM | Bank. ATMs are the green $ icons (City Hall, Bank of LS, Unity Station, Grove Street, Vinewood) |
| `/transfer [id] [amount]` | everyone | Send money from your bank to another player's bank |
| `/buyhouse`, `/sellhouse` | at a house | Buy a house for sale (green house icon, $25,000-$500,000); selling refunds half |
| `/enter`, `/exit` | house owner | Go into and out of your private house. After dying you respawn at home |
| `/goto`, `/gethere [id]` | admin 1+ | Teleport |
| `/kick [id] [reason]`, `/clearwanted [id]`, `/announce [text]` | admin 1+ | Moderation |
| `/ban [id] [reason]` | admin 2+ | Ban |
| `/setmoney [id] [amount]`, `/makeadmin [id] [0-3]` | admin 3 | Management |

Killing another player gives 2 wanted stars (police killing a wanted player
does not). The gamemode is `server/gamemodes/kingmakers.pwn`. Every change is
compiled and tested automatically by the **Build Server** action.
