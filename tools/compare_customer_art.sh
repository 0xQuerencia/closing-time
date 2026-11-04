#!/usr/bin/env bash
# Actual store routes, same fixed simulation/cameras, retained fallback and new art.
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p local/m32
for variant in cordatix vinrax; do
  godot --path . --fixed-fps 30 -- --capture-customers --after \
    "--customer-art=$variant" "--art-comparison=$variant" > "local/m32/$variant.log" 2>&1
  if rg -n 'SCRIPT ERROR|ERROR:|stalled' "local/m32/$variant.log"; then exit 1; fi
  rg 'CUSTOMER MOTION CAPTURE COMPLETE' "local/m32/$variant.log"
  ffmpeg -y -framerate 15 -i "local/m32/$variant/frame_%05d.jpg" \
    -c:v libx264 -crf 20 -pix_fmt yuv420p "local/m32/$variant.mp4" \
    > "local/m32/encode-$variant.log" 2>&1
done
ffmpeg -y -i local/m32/cordatix.mp4 -i local/m32/vinrax.mp4 \
  -filter_complex '[0:v][1:v]hstack=inputs=2:shortest=1,drawtext=text=cordatix:x=20:y=20:fontsize=28:fontcolor=white:box=1:boxcolor=black@0.65,drawtext=text=vinrax:x=980:y=20:fontsize=28:fontcolor=white:box=1:boxcolor=black@0.65' \
  -c:v libx264 -crf 20 -pix_fmt yuv420p local/m32/comparison.mp4 \
  > local/m32/encode-comparison.log 2>&1
printf '%s\n' 'Saved local/m32/comparison.mp4 (left Cordatix, right Vinrax).'
