#!/usr/bin/env bash
# Renders a scene for a few frames and saves a PNG you can look at.
# Usage: tools/shots.sh res://src/modes/menu/menu.tscn [out.png] [frames] [WxH]
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCENE="$1"; OUT="${2:-$ROOT/shots/$(basename "${SCENE%.*}").png}"; FRAMES="${3:-30}"; SIZE="${4:-1280x720}"
mkdir -p "$(dirname "$OUT")"
case "$OUT" in /*) ;; *) OUT="$PWD/$OUT";; esac
GODOT_REIMPORT=1 xvfb-run -a -s "-screen 0 ${SIZE}x24" "$ROOT/tools/godot.sh" --rendering-driver opengl3 \
  --resolution "$SIZE" res://tools/shot_runner.tscn -- --scene="$SCENE" --out="$OUT" --frames="$FRAMES" "${@:5}"
echo "$OUT"
