# Opening art source

The base revision is cooler PR #24 at `c4a717c5defad7651eed7c6443af362a3ea2b36d`. The two local reference images, `current-apartment.png` and `Closing-Time-01-rainy-arrival.png`, guided composition, finish, and lighting. All new artwork comes from editable geometry and seeded pixel generators. The reference images contributed no textures, meshes, or pixels.

| Asset | Editable source |
| --- | --- |
| Apartment room and props | `scenes/apartment/apartment_art.gd` and `tools/opening/apartment_atlas.py` |
| Wagon and dashboard | `tools/opening/wagon.py` and `tools/opening/wagon_atlas.py` |
| Route pavement and shoulder | `scenes/route9/route9_art.gd` and `tools/opening/road_textures.py` |
| Roadside and market trees | `scenes/opening/roadside_trees.gd` |
| Marlow's frontage | `scenes/opening/storefront_art.gd` and `scenes/world/exterior_dressing.gd` |

The wagon generator uses the project's cooler GLB writer. It writes a 512-square atlas and nine editable mesh definitions. The four wheel nodes share one mesh. Both playable scenes instantiate `route9_wagon.glb`. The original market shell, door, glass, and interior remain the geometry behind the new near storefront trim. The distant Route 9 frontage shares the market's fascia design, font, brick, and plaster.

The apartment uses a 512-square prop atlas and two repeating 256-square textures. The Route 9 and parking lot pavement share a repeating 256-square asphalt texture. The shoulder uses a separate 256-square aggregate texture. All authored dimensions are in metres.

## Rebuild and capture

Run the generators from the project directory with Python and Pillow. Import the resulting assets in Godot 4.6.

```sh
python tools/opening/apartment_atlas.py
python tools/opening/wagon.py
python tools/opening/road_textures.py
godot --headless --audio-driver Dummy --path . --editor --import --quit
```

Pass an imported copy of the base revision and the imported art-pass project to the same capture script. The script opens the actual Godot scenes and uses a separate data directory for each run. Each graphical run saves seven PNGs and a log with draw-call and primitive counts. Append `--headless` to log the same camera transforms, apartment collision hash, and geometry budgets without a display.

```sh
tools/opening/capture_playable.sh /absolute/path/to/imported-baseline /tmp/opening-before
tools/opening/capture_playable.sh . /tmp/opening-after
```

Render the GLB on its own with Blender. Append `rear` to the arguments for the rear three-quarter view.

```sh
blender --background --factory-startup --threads 2 --python-exit-code 1 \
  --python tools/opening/photograph_wagon.py -- /tmp/wagon-model.png
```
