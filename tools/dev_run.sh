#!/usr/bin/env bash
# Multi-instance dev launch (skeleton guide §4).
# Usage: tools/dev_run.sh [N]   - launches N windowed instances (default 2)
# with --platform=enet --name=P<i>. First instance should Host, others Join.
set -u
N="${1:-2}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="${GODOT:-godot}"

for i in $(seq 1 "$N"); do
  X=$(( 60 + (i - 1) * 660 ))
  Y=$(( 60 + ((i - 1) / 2) * 420 ))
  "$GODOT" --path "$ROOT" --position "$X,$Y" -- --platform=enet --name="P$i" &
done
wait
