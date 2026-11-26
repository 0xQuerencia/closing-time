#!/usr/bin/env bash
# Pass an imported baseline or work project, an output directory, and optionally --headless.
set -euo pipefail
project="$(realpath -- "${1:?Pass a Godot project directory}")"
out="$(realpath -m -- "${2:?Pass a capture output directory}")"
script="$(realpath -- "$(dirname -- "$0")/capture_playable.gd")"
mode="${3:-}"
mkdir -m 700 -p -- "$out" "$out/xdg" "$out/runtime"
export XDG_DATA_HOME="$out/xdg" XDG_CONFIG_HOME="$out/xdg" XDG_CACHE_HOME="$out/xdg"
export XDG_RUNTIME_DIR="$out/runtime" CLOSING_OPENING_CAPTURE_DIR="$out"
unset DISPLAY WAYLAND_DISPLAY WAYLAND_SOCKET
args=(--path "$project" --audio-driver Dummy --resolution 1280x800 --fixed-fps 60 --script "$script")
if [[ "$mode" == --headless ]]; then
  godot --headless "${args[@]}" > "$out/headless.log" 2>&1
elif [[ -z "$mode" ]]; then
  LIBGL_ALWAYS_SOFTWARE=1 LP_NUM_THREADS=2 \
    xvfb-run -a -e "$out/xvfb.log" -s '-screen 0 1440x900x24 -nolisten tcp' \
    godot --display-driver x11 "${args[@]}" > "$out/capture.log" 2>&1
else
  echo "Unknown mode $mode" >&2
  exit 2
fi
