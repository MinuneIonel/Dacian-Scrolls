#!/usr/bin/env bash
# Balance simulator. Usage: tools/balance.sh <data_root> <encounter_id|all> <n> <good|random|both> [--party=a,b] [--level=N] [--items=id:n] [--seed=S]
# Example: tools/balance.sh tests/fixtures/data all 300 both
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
exec "$ROOT/tools/godot.sh" --headless -s res://tools/balance.gd -- "$@"
