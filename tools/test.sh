#!/usr/bin/env bash
# Runs the test suite headless. Usage:
#   tools/test.sh                      all of tests/unit and tests/integration
#   tools/test.sh tests/bot            another directory
#   tools/test.sh --filter=rng         only files or tests whose name contains "rng"
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DIRS=(); ARGS=()
for a in "$@"; do
  if [[ "$a" == --* ]]; then ARGS+=("$a"); else DIRS+=("$a"); fi
done
[[ ${#DIRS[@]} -eq 0 ]] && DIRS=(tests/unit tests/integration)
DIRLIST=$(IFS=,; echo "${DIRS[*]}")
GODOT_REIMPORT=1 "$ROOT/tools/godot.sh" --headless res://tests/framework/runner.tscn -- --dirs="$DIRLIST" "${ARGS[@]}"
