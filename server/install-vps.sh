#!/usr/bin/env bash
# Installs (or updates) the Kingmakers RP server on an Ubuntu/Debian x86 VPS
# and runs it as a systemd service. Run as root:
#   curl -fsSL https://raw.githubusercontent.com/kingmakers2001inc-lang/SAMP-Mobile/main/server/install-vps.sh | bash
# Set BRANCH=<name> to install from another branch.
set -euo pipefail

REPO="kingmakers2001inc-lang/SAMP-Mobile"
BRANCH="${BRANCH:-main}"
DIR="${DIR:-/opt/kingmakers-server}"
SERVICE="kingmakers-server"

if [ "$(id -u)" -ne 0 ]; then
  echo "Run this as root (or with sudo)." >&2
  exit 1
fi

dpkg --add-architecture i386
apt-get update -qq
apt-get install -y -qq curl jq libc6:i386 libstdc++6:i386 libatomic1:i386 > /dev/null

id -u omp > /dev/null 2>&1 || useradd --system --home "$DIR" --shell /usr/sbin/nologin omp

SRC="$(mktemp -d)"
trap 'rm -rf "$SRC"' EXIT
curl -fsSL "https://codeload.github.com/$REPO/tar.gz/$BRANCH" | tar -xz -C "$SRC" --strip-components=1

bash "$SRC/server/build.sh" "$SRC/dist"

# On updates keep the existing config, bans and saved data
if [ -d "$DIR" ]; then
  rm -rf "$SRC/dist/config.json" "$SRC/dist/bans.json" "$SRC/dist/scriptfiles"
fi
systemctl stop "$SERVICE" 2> /dev/null || true
mkdir -p "$DIR"
cp -a "$SRC/dist/." "$DIR/"
chown -R omp:omp "$DIR"

cat > "/etc/systemd/system/$SERVICE.service" <<UNIT
[Unit]
Description=Kingmakers RP open.mp server
After=network-online.target

[Service]
User=omp
WorkingDirectory=$DIR
ExecStart=$DIR/omp-server
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
UNIT

systemctl daemon-reload
systemctl enable --now "$SERVICE"

if command -v ufw > /dev/null && ufw status | grep -q "Status: active"; then
  ufw allow 7777/udp
fi

IP="$(curl -fsS https://api.ipify.org || echo "<your-server-ip>")"
echo
echo "Kingmakers RP server is running. Players connect to: $IP:7777"
echo "Logs:    journalctl -u $SERVICE -f"
echo "Restart: systemctl restart $SERVICE"
