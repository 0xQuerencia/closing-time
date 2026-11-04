#!/usr/bin/env bash
set -u
cd "$(dirname "$0")/.."
if [[ ! -f project.godot ]]; then
  echo '[NOT BUILT] No project.godot yet. This is a design starter pack; Codex must implement M0 first.'
  exit 2
fi
if command -v godot >/dev/null 2>&1; then G=godot;
elif command -v godot4 >/dev/null 2>&1; then G=godot4;
else echo '[MISSING] Godot executable not found'; exit 3; fi

echo 'Running Godot headless editor import and exit...'
"$G" --headless --path . --editor --import --quit
status=$?
if [[ $status -ne 0 ]]; then echo "[FAIL] Editor import exit code: $status"; exit "$status"; fi
# Import validates resources but not gameplay, visual quality or all runtime paths.
echo '[PASS] Headless import completed. THIS IS NOT A VISUAL OR GAMEPLAY TEST.'
echo 'Now open the GUI, play real scenarios and capture the shot list.'
