# Closing Time

A short first-person horror game set on one night shift at Marlow's Market. You are Jamie, the night clerk. Serve the few customers who come in, do your chores, and notice when something is wrong. A fired ex-clerk has a spare key. Plan on about 10 to 15 minutes.

It is a human threat, not a monster: no jumpscares, no ghosts. There are three endings: get out the front door, lock yourself in the office and hold out until the police arrive, or get caught and try again from the checkpoint.

## Play

```sh
godot --path .            # Godot 4.6.3
godot --headless --path . --export-release "Linux" build/linux/ClosingTime.x86_64   # Linux build
```

| Key | Action |
| --- | --- |
| WASD, mouse | move, look |
| Shift | run (noisy: Leon hears it) |
| E | use, scan, talk, hide |
| F | look closely |
| Q | put an item down |
| 1 / 2 / 3 | choose a reply |
| Tab | phone |
| T | phone light |
| G | shift guide |
| Esc | pause |

The game saves a checkpoint at the start of the shift and again before the final stretch. Continue on the title screen reloads the last one.

## Staying oriented

The paper in the top-right is the complete shift checklist. During play, the **NEXT** card in the upper-left chooses the most useful unfinished step and tells you where to start and what interaction to use. Customer and security tasks take priority over routine chores, so follow that card when several tasks are open. Press `G` at any time for the full control and current-task guide; it is also available from the title and pause menus.

## Check and reproduce

```sh
bash scripts/validate_project.sh
# Render five views from the running Godot scene at 1600 × 900:
godot --path . -- --capture
# Inspect refined shelf packaging and coffee props without retro post effects:
godot --path . -- --capture-assets
# Capture the in-game NEXT card and full Shift Guide:
godot --path . -- --capture-reference --guide
# Regenerate original textures, audio and Blender models:
python tools/textures/generate.py  # Pillow required
python tools/audio/generate.py
blender --factory-startup -b --python tools/blender/build_market.py
# Reimport after changing generated models:
godot --headless --editor --path . --import --quit
```

Validation runs seven headless stages: import and parsing, the world, gameplay systems, mouse look, the story, security (doors, power, cameras) and the threat (Leon's pathing and senses, hiding, all three endings, retry, saves and menus). `godot --path . -- --qa-gameplay` drives the real renderer with synthetic key and mouse input, and `-- --timed-playthrough [--ending=escape|secured|caught_then_secured] [--pace=slow]` plays a scripted run in real time and prints how long each stretch takes. That bot is a script, not a human playtest. It does not replace playing the game. Logs and screenshots go to the local ignored `local/` directory.

The game code, tests, environment meshes, fictional labels, surface maps and sounds were produced with AI coding assistants working from the author's design and direction, and generated from the source scripts included here. No assets, branding, characters, or dialogue from other games are included. See `ASSET_CREDITS.md`.

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

## Customer character art

Customer 1 uses **Vinrax's PSX Casual Male**, with the original 256px texture and
nine retargeted clips from the licensed Cordatix sampler. Customer 2 retains the
Cordatix office worker. Attribution and source links are in `ASSET_CREDITS.md`.
The M3.1 movement, browsing, blending and transaction logic are preserved.

```sh
# Retained Cordatix customer 1 fallback:
godot --path . -- --customer-art=cordatix
# Actual store-route comparison (Godot and FFmpeg):
bash tools/compare_customer_art.sh
# Isolated rig/animation comparison; Cordatix at x=-0.65, Vinrax at x=+0.65:
godot --path . scenes/tests/vinrax_character_test.tscn --fixed-fps 30 -- --capture-test
# Import and skeleton/duration checks:
godot --headless --editor --path . --import --quit
godot --headless --path . --script tests/vinrax_rig_tests.gd
# Rebuild from the original Vinrax source archive and existing Cordatix GLB:
blender -b --factory-startup --python-exit-code 1 --python tools/blender/retarget_vinrax.py
blender -b --factory-startup --python-exit-code 1 --python tools/blender/validate_vinrax.py
```

Store comparison footage is written to ignored `local/m32/comparison.mp4`, with
Cordatix on the left and Vinrax on the right. It uses identical camera positions,
fixed-step movement sequences and automated scan/payment. Individual recordings,
engine screenshots and capture metadata are saved beside it. No store geometry,
lighting, routes or gameplay rules are changed by this comparison mode.
