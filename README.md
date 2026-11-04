# Closing Time

A first-person night-shift thriller set at Marlow's Market. This repository currently contains the **M1 environment slice**: an explorable convenience store, checkout, stocked aisles, refrigeration, office, stockroom, rear corridor, and a small night parking lot. Story and customer interactions are still to come.

Open `project.godot` in **Godot 4.6.3** and press **F6** on `scenes/world/market_root.tscn`, or **F5** from the project. From a terminal:

```sh
godot --path .
```

WASD walks, mouse looks, Shift walks faster, B toggles subtle head bob, Escape releases or recaptures the mouse. Click the game to recapture it. The front entrance is held open for exploration; the rear delivery door is closed. This milestone uses a temporary inspection controller.

The desktop renderer is Forward+, with MSAA 2×. World scale is meters; eye height is 1.62 m. No VHS filter is applied. The register and security monitor are static environmental props.

## Check and reproduce

```sh
bash scripts/validate_project.sh
# Render five views from the running Godot scene at 1600 × 900:
godot --path . -- --capture
# Regenerate original textures, audio and Blender models:
python tools/textures/generate.py  # Pillow required
python tools/audio/generate.py
blender --factory-startup -b --python tools/blender/build_market.py
# Reimport after changing generated models:
godot --headless --editor --path . --import --quit
```

Validation exercises import/parsing, collision rays, capsule sweeps, and keyboard/mouse movement. It does not replace playing the scene. Logs and screenshots go to the local ignored `local/` directory.

Environment meshes, fictional labels, surface maps, and electrical room tone were generated from the included source scripts with AI assistance. No assets, branding, characters, or dialogue from other games are included. See `ASSET_CREDITS.md`.

## Customer movement review

The two customer models have eased movement, slower browsing, interpolated animation,
turn animations and walk playback matched to travel speed. To record both existing
customer visits with automated scan/payment using the actual renderer:

```sh
bash tools/capture_customer_motion.sh  # Godot and FFmpeg required
```

This writes a silent 960 × 540 MP4, screenshots, sequential frames and renderer metadata
to the ignored `local/customer-motion/after/` directory (MP4 in its parent directory).
The simulation runs at a fixed 30 FPS and the capture samples every second frame for
15 FPS playback. This is visual review footage, not a performance benchmark. Normal
play still requires the player to scan and collect payment.
