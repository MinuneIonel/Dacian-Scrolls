#!/usr/bin/env bash
# Downloads the Godot export templates matching tools/get_godot.sh, verifies the checksum and
# installs them where the editor looks for them. Usage: tools/get_templates.sh [linux windows macos web]
# With platform names only those templates are extracted (the .tpz is 1.3 GB; installed all ~1 GB).
set -euo pipefail
VERSION="4.5.1-stable"
DEST="${GODOT_TEMPLATES_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/godot/export_templates/${VERSION/-/.}}"
declare -A PATTERNS=([linux]="templates/linux_*" [windows]="templates/windows_*"
                     [macos]="templates/macos.zip" [web]="templates/web_*")
want=("$@"); [[ ${#want[@]} -eq 0 ]] && want=(linux windows macos web)
globs=("templates/version.txt")
missing=0
for p in "${want[@]}"; do
  [[ -n "${PATTERNS[$p]:-}" ]] || { echo "unknown platform '$p' (linux windows macos web)" >&2; exit 2; }
  globs+=("${PATTERNS[$p]}")
  compgen -G "$DEST/${PATTERNS[$p]#templates/}" >/dev/null || missing=1
done
if [[ $missing -eq 0 ]] && grep -qx "${VERSION/-/.}" "$DEST/version.txt" 2>/dev/null; then
  echo "export templates $VERSION already present in $DEST (${want[*]})"; exit 0
fi
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
cd "$TMP"
BASE="https://github.com/godotengine/godot/releases/download/$VERSION"
TPZ="Godot_v${VERSION}_export_templates.tpz"
curl -fsSL --retry 3 -o "$TPZ" "$BASE/$TPZ"
curl -fsSL --retry 3 -o SHA512-SUMS.txt "$BASE/SHA512-SUMS.txt"
grep " $TPZ\$" SHA512-SUMS.txt | sha512sum -c -
unzip -oq "$TPZ" "${globs[@]}"
mkdir -p "$DEST"
mv -f templates/* "$DEST/"
echo "installed export templates $VERSION into $DEST:"; ls -1 "$DEST"
