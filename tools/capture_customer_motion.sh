#!/usr/bin/env bash
# Capture real engine frames for review; output stays in ignored local/.
set -euo pipefail
cd "$(dirname "$0")/.."
command -v godot >/dev/null
command -v ffmpeg >/dev/null
mkdir -p local/customer-motion
godot --path . --fixed-fps 30 -- --capture-customers --after > local/customer-motion/after.log 2>&1
if rg -n 'SCRIPT ERROR|ERROR:|stalled' local/customer-motion/after.log; then
  exit 1
fi
rg 'CUSTOMER MOTION CAPTURE COMPLETE' local/customer-motion/after.log
ffmpeg -y -framerate 15 -i local/customer-motion/after/frame_%05d.jpg \
  -c:v libx264 -crf 20 -pix_fmt yuv420p local/customer-motion/after.mp4 \
  > local/customer-motion/encode-after.log 2>&1
printf '%s\n' 'Saved local/customer-motion/after.mp4 (silent, 960x540, 15fps).'
