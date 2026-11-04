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
