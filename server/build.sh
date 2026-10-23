#!/usr/bin/env bash
# Builds a ready-to-run open.mp server with the Kingmakers RP gamemode.
# Usage: server/build.sh [output-dir]   (default: server/dist)
# Needs 32-bit libraries: libc6:i386 libstdc++6:i386 libatomic1:i386
set -euo pipefail

OMP_VERSION="v1.6.7.3218"
HERE="$(cd "$(dirname "$0")" && pwd)"
OUT="${1:-$HERE/dist}"

rm -rf "$OUT"
mkdir -p "$OUT"
curl -fsSL "https://github.com/openmultiplayer/open.mp/releases/download/$OMP_VERSION/open.mp-linux-x86.tar.gz" \
  | tar -xz -C "$OUT" --strip-components=1

# Replace the sample scripts with our gamemode
rm -f "$OUT"/gamemodes/* "$OUT"/filterscripts/*
LD_LIBRARY_PATH="$OUT/qawno" "$OUT/qawno/pawncc" "$HERE/gamemodes/kingmakers.pwn" \
  -i"$OUT/qawno/include" -o"$OUT/gamemodes/kingmakers.amx" -d0 -O1
cp "$HERE/gamemodes/kingmakers.pwn" "$OUT/gamemodes/"

jq '.name = "Kingmakers RP"
  | .language = "English"
  | .pawn.main_scripts = ["kingmakers 1"]
  | .pawn.side_scripts = []' \
  "$OUT/config.json" > "$OUT/config.json.tmp"
mv "$OUT/config.json.tmp" "$OUT/config.json"

echo "Server ready in $OUT (start it with: cd $OUT && ./omp-server)"
