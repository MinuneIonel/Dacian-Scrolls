#!/usr/bin/env bash
# Runs the pinned Godot against this project. Usage: tools/godot.sh [godot args...]
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
[[ -x "$ROOT/.godot-bin/godot" ]] || "$ROOT/tools/get_godot.sh" >&2
# Build the class_name cache on first use (or after new scripts appear).
if [[ ! -f "$ROOT/.godot/global_script_class_cache.cfg" || -n "${GODOT_REIMPORT:-}" ]]; then
  mkdir -p "$ROOT/.godot"
  if ! "$ROOT/.godot-bin/godot" --headless --path "$ROOT" --import >"$ROOT/.godot/import.log" 2>&1; then
    echo "godot.sh: import failed, last lines of .godot/import.log:" >&2
    tail -20 "$ROOT/.godot/import.log" >&2
  fi
fi
exec "$ROOT/.godot-bin/godot" --path "$ROOT" "$@"
