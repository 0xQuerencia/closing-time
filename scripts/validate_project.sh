#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
if command -v godot >/dev/null 2>&1; then G=godot
elif command -v godot4 >/dev/null 2>&1; then G=godot4
else echo '[MISSING] Godot executable not found'; exit 3; fi
mkdir -p local
"$G" --headless --path . --editor --import --quit > local/validation-import.log 2>&1
if rg -n 'SCRIPT ERROR|ERROR:' local/validation-import.log; then
  echo '[FAIL] Godot reported import/parser errors'; exit 1
fi
echo '[PASS] Godot import and parsing'
"$G" --headless --path . -- --test-world > local/validation-world.log 2>&1
if rg -n 'SCRIPT ERROR|ERROR:' local/validation-world.log; then
  echo '[FAIL] Godot reported runtime errors'; exit 1
fi
rg 'TEST PASS|TESTS COMPLETE' local/validation-world.log
echo '[PASS] Engine collision checks. Render and manual input checks are separate.'
"$G" --headless --path . -- --test-gameplay > local/validation-gameplay.log 2>&1
if rg -n 'SCRIPT ERROR|ERROR:' local/validation-gameplay.log; then
  echo '[FAIL] Godot reported gameplay test errors'; exit 1
fi
rg 'GAMEPLAY TESTS COMPLETE' local/validation-gameplay.log
echo '[PASS] Gameplay systems: interaction, checkout, dialogue, tasks, customer cycles'

"$G" --headless --path . --script tests/mouse_capture_tests.gd > local/validation-mouse-capture.log 2>&1
if rg -n 'SCRIPT ERROR|ERROR:' local/validation-mouse-capture.log; then
  echo '[FAIL] Godot reported captured-mouse HUD errors'; exit 1
fi
rg 'MOUSE CAPTURE TESTS COMPLETE' local/validation-mouse-capture.log
echo '[PASS] Centered mouse look through the gameplay HUD'
"$G" --headless --path . -- --test-story > local/validation-story.log 2>&1
if rg -n 'SCRIPT ERROR|ERROR:' local/validation-story.log; then
  echo '[FAIL] Godot reported story test errors'; exit 1
fi
rg 'STORY TESTS COMPLETE' local/validation-story.log
echo '[PASS] Story: state machine, once-only beats, chores, clues and a full accelerated night'
