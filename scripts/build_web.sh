#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
G="${GODOT:-godot}"
mkdir -p build/web
touch build/.gdignore
staging="$(mktemp -d "$PWD/build/.web.XXXXXXXX")"
trap 'rm -rf -- "$staging"' EXIT
"$G" --headless --path . --editor --import --quit
"$G" --headless --path . --export-release Web "$staging/index.html"
python3 - "$staging" <<'PY'
from pathlib import Path
import shutil
import sys
from zipfile import ZipFile, ZIP_DEFLATED

root = Path(sys.argv[1])
for name in ("index.html", "index.js", "index.wasm", "index.pck"):
    p = root / name
    if not p.is_file() or not p.stat().st_size:
        raise SystemExit(f"Missing or empty export file: {p}")
files = sorted(p for p in root.iterdir() if p.is_file())
package = root / "closing-time-web.zip"
with ZipFile(package, "w", ZIP_DEFLATED) as archive:
    for p in files:
        archive.write(p, p.name)
size = package.stat().st_size
print(f"Web ZIP: {size / 1_000_000:.2f} MB")
if size > 80_000_000:
    raise SystemExit("Web ZIP exceeds 80 MB release budget")
for p in files:
    shutil.copy2(p, Path("build/web") / p.name)
package.replace("build/closing-time-web.zip")
PY
