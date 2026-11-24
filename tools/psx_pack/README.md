# Marlow's Market — PSX prop library v0.1

44 original low-poly **3D** prop and environment meshes inspired by the approved visual reference boards for Closing Time. No reference-sheet screenshots are used as meshes or atlas images. Surfaces are constructed with explicit polygon profiles, UV mapping and deterministic pixel artwork. The existing game name, setting and maroon work vest are preserved.

## Contents

- `models/`: 44 self-contained glTF 2.0 binary files (`.glb`), 7,232 triangles, 1,206,436 bytes combined.
- `textures/`: separate 256×256 PNG atlases (one per model).
- `source/`: editable Wavefront OBJ + MTL files, importable in Blender; texture links point to `../textures/`. The original source generator is `build_assets.py`.
- `renders/` and `asset-sheet-*.png`: real CPU rasterized renders from the GLB geometry, not generated concept images.
- `manifest.json`: exact measured triangle counts, vertex counts, mesh node names, file sizes and meter-scale bounds.
- `godot/`: a standalone Godot 4 project containing an asset gallery and optional static collision-proxy scenes.
- `install_closing_time.py`: dry-run-first integration helper for the existing Closing Time repository.
- `validate_assets.py`: independent GLB import and structural verification.

## Import

GLBs embed their albedo atlases and use a nearest-filter sampler, flat face normals, one material per model, roughness 0.92 and metallic 0. No external image dependencies. Coordinates: meters, Y up, +Z generally faces the viewer; the wagon nose faces -Z, and the dashboard and wiper are built in the existing cockpit's local coordinates. CRT `OriginalCRTGlass`, scanner `ScanWindow` and cash drawer `Drawer` are independent mesh nodes, so their materials/positions can be changed without affecting the main mesh. The cash drawer's open position is the authored default pose.

Open `godot/project.godot` in Godot 4, import, then run the gallery. The gallery rescales assets solely for presentation; individual GLBs and proxy scenes retain their authored meter scale. Proxy scenes use approximate AABB collisions for placement tests only. Use the game's existing carefully authored collision and interaction geometry when integrating. The bed, desk and kitchen replacement preserves existing collider nodes; the visual models do not replace their logic.

## Existing game integration

From the extracted pack:

```sh
python3 install_closing_time.py /path/to/closing-time
python3 install_closing_time.py /path/to/closing-time --apply
```

Make a clean Git feature branch first. The installer checks the expected source patterns before changing files. It copies the GLBs, inserts a loader and switches the original-office factory, scanner, exterior wagon/dumpster, apartment visual replacements and cockpit visuals. Use the ordinary `Web` export preset, not the older credited `Web Art Reference` preview. It does not replace the baked market shelf, cooler or checkout layout; those meshes have placement-specific collision and gameplay dependencies. The standalone replacements for those are in the pack for deliberate integration.

## Verification and limits

All GLBs were independently imported using trimesh, verified for indexed triangle counts, finite geometry, valid UV bounds and non-degenerate faces, then rasterized from the exported data. The source scripts compile with Python 3. Godot and Blender binaries are not present in the build environment: no engine runtime or `.blend` validation is claimed. The pack is import-ready static geometry, not a fully playtested game release. Glass on the cooler is represented by open cabinet fronts and product geometry; true transparent animated doors still need engine setup. Store shelf stock is decorative, not linked to inventory. This is a prop batch, not new skinned characters: preserve the existing Jamie/Leon rigs and author the other cast separately. The geometry recreates the design direction rather than being an exact 3D reconstruction of the reference images.

To regenerate: `python3 -m pip install numpy Pillow` then `python3 build_assets.py`. Optional independent validation: `python3 -m pip install trimesh` then `python3 validate_assets.py`. Render sheets: `python3 render_assets.py` (uses DejaVu Mono on the preview-render machine; no font files are bundled). Text on the asset artwork is rasterized with Pillow's default font.
