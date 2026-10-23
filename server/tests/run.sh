#!/usr/bin/env bash
# Runs the gamemode test against a server built by server/build.sh.
# Usage: server/tests/run.sh <built-server-dir>
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
SERVER="$(cd "$1" && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

cp -a "$SERVER/." "$WORK/"
rm -f "$WORK/scriptfiles/kingmakers.db"
LD_LIBRARY_PATH="$WORK/qawno" "$WORK/qawno/pawncc" "$HERE/kmtest.pwn" \
  -i"$WORK/qawno/include" -o"$WORK/filterscripts/kmtest.amx"
jq '.announce = false | .max_bots = 2 | .pawn.side_scripts = ["filterscripts/kmtest"]' \
  "$WORK/config.json" > "$WORK/config.json.tmp"
mv "$WORK/config.json.tmp" "$WORK/config.json"

(cd "$WORK" && timeout -s KILL 30 ./omp-server > server.log 2>&1) || true
grep -E "\[TEST\]|\[Error\]|Kingmakers RP gamemode loaded" "$WORK/server.log" || true
grep -q "\[TEST\] ALL PASSED" "$WORK/server.log"
