#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
version=4.6.3-stable
base="https://github.com/godotengine/godot-builds/releases/download/$version"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
curl -fsSL --retry 3 "$base/Godot_v${version}_linux.x86_64.zip" -o "$work/engine.zip"
unzip -q "$work/engine.zip" -d "$work"
engine="$work/Godot_v${version}_linux.x86_64"
chmod +x "$engine"
curl -fsSL --retry 3 "$base/Godot_v${version}_export_templates.tpz" -o "$work/templates.zip"
# Only the Web templates are needed on the hosting build machine.
target="$HOME/.local/share/godot/export_templates/${version/-/.}"
mkdir -p "$target"
unzip -jo "$work/templates.zip" 'templates/web*.zip' -d "$target"
mkdir -p build/web
"$engine" --headless --audio-driver Dummy --path . --editor --import --quit
"$engine" --headless --audio-driver Dummy --path . --export-release "${GODOT_WEB_PRESET:-Web}" build/web/index.html
for file in index.html index.js index.wasm index.pck; do
  test -s "build/web/$file"
done
