#!/bin/bash
# Prepares Claude Code cloud sessions to build and test the open.mp server
# (server/build.sh and server/tests/run.sh). The Android APKs need the
# Android SDK/NDK and the game files, so they are left to GitHub Actions.
set -euo pipefail

if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

cd "$CLAUDE_PROJECT_DIR"

# The open.mp server and the Pawn compiler are 32-bit Linux binaries
missing=()
for pkg in libc6:i386 libstdc++6:i386 libatomic1:i386 jq; do
  dpkg -s "$pkg" > /dev/null 2>&1 || missing+=("$pkg")
done
if [ ${#missing[@]} -gt 0 ]; then
  dpkg --print-foreign-architectures | grep -qx i386 || dpkg --add-architecture i386
  apt-get update -qq
  DEBIAN_FRONTEND=noninteractive apt-get install -y -qq "${missing[@]}"
fi

# Download open.mp and compile the gamemode once into server/dist (gitignored).
# Re-run server/build.sh after editing the gamemode.
if [ ! -x server/dist/omp-server ]; then
  server/build.sh
fi
