#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
G="${GODOT:-godot}"
test -s build/web/index.pck
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
printf 'config_version=5\n[application]\nconfig/name="Isolated pack audit"\n' > "$work/project.godot"
cp scripts/audit_web_pack.gd "$work/audit.gd"
"$G" --headless --audio-driver Dummy --path "$work" --script "$work/audit.gd" -- "$(pwd)/build/web/index.pck"
