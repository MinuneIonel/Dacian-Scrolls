#!/usr/bin/env bash
# Downloads the pinned Godot build into .godot-bin/godot and verifies its checksum.
set -euo pipefail
VERSION="4.5.1-stable"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BIN="$ROOT/.godot-bin"
if [[ -x "$BIN/godot" ]] && "$BIN/godot" --headless --version 2>/dev/null | grep -q "^4.5.1.stable"; then
  echo "godot $VERSION already present"; exit 0
fi
mkdir -p "$BIN"; cd "$BIN"
BASE="https://github.com/godotengine/godot/releases/download/$VERSION"
ZIP="Godot_v${VERSION}_linux.x86_64.zip"
curl -fsSL -o "$ZIP" "$BASE/$ZIP"
curl -fsSL -o SHA512-SUMS.txt "$BASE/SHA512-SUMS.txt"
grep " $ZIP\$" SHA512-SUMS.txt | sha512sum -c -
unzip -oq "$ZIP" && mv "Godot_v${VERSION}_linux.x86_64" godot && rm "$ZIP"
chmod +x godot
./godot --headless --version
