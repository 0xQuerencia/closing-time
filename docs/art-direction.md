# Closing Time — art restoration gate

The owner's earlier Blender market and PSX-char GLBs are the visual reference. Restore recognizable authored silhouettes, textured materials, muted colors and practical lighting. No new primitive stand-ins as final art. Nearest texels, a 360-line world finish, modest palette quantization, and no heavy chromatic split. UI stays readable at native resolution.

## Playtest and release
- `Web Art Reference`: previously used, credited office/exterior meshes and selected NPCs; not an original-only release.
- `Web` and `Linux`: original-only migration; retain the existing exclusions.
- Editor: pass `-- --art-reference` to view the same art comparison.
- Jamie and Leon: preserve the owner-authored PSX-char GLBs.
- Apartment and Route 9: original blockouts still need fully modeled, UV-painted replacement kits; consistent post-processing is not a substitute.
- Remaining cast: author distinct silhouettes, heads, hair, clothes and texture atlases; do not reuse recolored Jamie as finished cast.
- Visual approval before release: compare actual renders of title exterior, apartment, road cockpit, market aisle, checkout, office CRT, staff and shoppers. Verify interactables, navigation, camera feeds, loading and mobile/desktop performance. No claim of final visual quality without review.

The opening now reuses the existing handset GLB, authored surface textures and the actual market shell at the end of Route 9. The reference apartment desk also reuses the previously selected mesh. No claim that the remaining bed, kitchen, car interior or female cast has been remodeled.

## PSX pack integration

The 44 approved GLBs now live in assets/models/psx_pack. The production scene uses the pack for office props, scanner/CRT, apartment furniture and evidence objects, exterior wagon and fixtures, the cockpit and roadside trees. Baked market fixtures remain until their layout-specific stock and collision coordinates can be verified; never hide the entire retail mesh to replace a single prop. The pack is original static art, not a replacement for the rigged cast.

The batched retail GLB is trimmed only in collision-derived fixture regions; original endcaps and restock slots remain. New counter, 12 shelf modules, six cooler cases and an animated cash drawer replace the old fixture visuals. The original game collision geometry and glass overlays remain. If the expected mesh shape changes, the replacement is skipped rather than corrupting unrelated art.
