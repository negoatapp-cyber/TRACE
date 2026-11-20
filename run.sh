#!/bin/sh
set -eu
cd "$(dirname "$0")"
engine=${GODOT:-godot}
case "${1:-atlas}" in
  atlas) scene=marseille ;;
  quartier) scene=lauriers ;;
  test) scene=ilot_grey ;;
  *) echo "Usage: ./run.sh [atlas|quartier|test] [options Godot]" >&2; exit 2 ;;
esac
if [ "$#" -gt 0 ]; then shift; fi
if [ ! -s assets/sons/amb_jour_loop.wav ] && python3 -c 'import numpy' 2>/dev/null; then
  python3 .tools/son_generer.py
fi
"$engine" --headless --editor --import --path . >/dev/null
exec "$engine" --path . "res://scenes/$scene.tscn" "$@"
