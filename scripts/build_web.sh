#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
G="${GODOT:-godot}"
mkdir -p build/web
"$G" --headless --path . --editor --import --quit
"$G" --headless --path . --export-release Web build/web/index.html
python3 - <<'PY'
from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED
root = Path("build/web")
for name in ("index.html", "index.js", "index.wasm", "index.pck"):
    p = root / name
    if not p.is_file() or not p.stat().st_size:
        raise SystemExit(f"Missing or empty export file: {p}")
out = Path("build/closing-time-web.zip")
with ZipFile(out, "w", ZIP_DEFLATED) as archive:
    for p in sorted(root.rglob("*")):
        if p.is_file():
            archive.write(p, p.relative_to(root))
size = out.stat().st_size
print(f"Web ZIP: {size / 1_000_000:.2f} MB")
if size > 80_000_000:
    raise SystemExit("Web ZIP exceeds 80 MB release budget")
PY
