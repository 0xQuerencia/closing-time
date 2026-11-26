#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
source_dir="$PWD"
output="$source_dir/local/cooler"
project="$source_dir"
phase=after
mkdir -m 700 -p "$output/xdg" "$output/runtime"
export XDG_DATA_HOME="$output/xdg" XDG_CONFIG_HOME="$output/xdg" XDG_CACHE_HOME="$output/xdg"
export XDG_RUNTIME_DIR="$output/runtime" CLOSING_COOLER_CAPTURE_DIR="$output"
unset DISPLAY WAYLAND_DISPLAY WAYLAND_SOCKET
if [[ "${1:-}" == --before ]]; then
  phase=before
fi
if [[ "$phase" == before && -d "$output/baseline" ]]; then
  project="$output/before-project"
  mkdir -p "$project/tools"
  cp -a --reflink=auto assets gameplay scenes tests project.godot "$project/"
  cp -a tools/capture_cooler.gd "$project/tools/"
  cp -a "$output/baseline/." "$project/"
  godot --headless --audio-driver Dummy --path "$project" --editor --import --quit \
    > "$output/import-before.log" 2>&1
fi
LIBGL_ALWAYS_SOFTWARE=1 LP_NUM_THREADS=2 \
  xvfb-run -a -e "$output/xvfb-$phase.log" -s '-screen 0 1440x900x24 -nolisten tcp' \
  godot --path "$project" --display-driver x11 --audio-driver Dummy --resolution 1280x800 \
    --fixed-fps 60 --script "$project/tools/capture_cooler.gd" -- "$@"
