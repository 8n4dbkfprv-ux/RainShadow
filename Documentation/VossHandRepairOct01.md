# Voss hand repair — October 1

The later [surface repair](VossSurfaceRepairOct01.md) retains this deformation
fix and corrects 18 UV loops that sampled dark texture patches on the hands.
Its sources and packager are the current installation authority. The hashes
and results below record the preceding hand-weight installation.

Both little fingers had thin pointed artifacts when curled. The resting mesh
was intact, but vertices on each little finger abruptly switched between
little-finger and ring-finger bone influences. Neighboring edges stretched by
as much as 11.68× in the inspected walking pose.

The repair changes skin weights on 635 vertices. A topology-connected distal
little-finger region identifies the correct digit without confusing its inner
surface with the neighboring ring finger. Incorrect ring-finger influences
are removed; existing little-finger joint proportions are normalized. Where
those proportions were missing, six nearby vertices on the same finger supply
them. A bounded smooth transition at the finger base removes the remaining
crease/spike. All edits are recorded in `hand_weight_patch.json` with the
original and replacement weights for every affected vertex.

The mesh remains 120,348 vertices, 361,194 edges and 240,796 triangular faces.
Rest coordinates, topology, UVs, material-region assignments, bone lengths and
animation keyframes are preserved. The inspected patched edges peak at 1.624×
rest length across 17 idle, walk, seated and rising poses. Front, side and
perspective close-ups, plus walking hand renders, record visual review.

## Authoring and production

Sources are under `ArtSource/Blender/VossHandRepairOct01`:

- `AnimationProduction/Voss_Rustic_Animations.blend`: corrected body and all
  existing gameplay actions, retaining VossCHMF identity.
- `Voss_HandRepair_Paperdoll.blend`: existing inventory stance with the same
  corrected weights and equipped-item alignment.
- `Equipment/Voss_Equipment_Animations.blend`: corrected body holdout with the
  existing sword, fitted splint mail and textured helmet.

The live Blender MCP recipes reproduce the body and equipment renders.
`apply_patch_via_live_mcp.txt` applies the recorded weights to a saved incremental
copy of the prior source, validating all original weights before any edit.
`verify_source_via_live_mcp.txt` compares the corrected model against September
30; `model_preservation.json` confirms that only the 635 recorded weights changed.
Gameplay neutral materials retain the original albedo luminance normalization:
linear RGB-to-BW texture × `0.18 / median`, with material medians
`[0.30,0.054,0.52,0.27,0.050,0.075,0.025]`, metallic 0, roughness 0.85 and specular
IOR level 0.12. Original normal maps, AgX and denoising are retained. The
paperdoll uses its separately established constant 0.32 neutral pass, not the
gameplay normalization. This distinction is necessary to preserve both looks.

`ArtSource/Processing/package_voss_hand_repair_oct01.py` reuses the current
palette, projection and registration encoders. `watch` encodes body renders
as they finish; `stage-body` creates all 1,556 body frames and the paperdoll;
`stage-equipment` creates the 3,600 matching equipment frames. Exact idle
holds, chair endpoints and reversed sit sequences are validated.

The shortened fingertip changes the high-resolution silhouette bounds by one
pixel in five walking views. `render_plan.json` records the original crop boxes,
and both body and equipment encoders use those boxes for the shared sampling
grid. This avoids rescaling the entire body when removing a finger spike.
All repaired silhouettes fit inside those original bounds. Across 420 source
views, 98 native planes remain identical; 677 pixels change in total, with at
most six changed pixels in any view. `registration_preservation.json` and
`native_comparison.json` record the measurements.

Before `install`, inspect the review sheets and paperdoll, run
`RusticVossStagingTests` with `RAINSHADOW_RUSTIC_STAGE` pointing at the candidate
bundle, and record a hash-bound `review_receipt.json`. The user authorized
installation of this hand correction. The installer keeps the previous body,
portrait and equipment in `output/voss-hand-repair-oct01/RuntimeBeforeHandRepair`.

This revision retains the current equipment design, independent equip/unequip
behavior, palette support, body scale, camera, navigation and rendering ports.
Equipment is still authored for idle and walking; seated poses show the body
without equipment, as before.

## Installed verification

The repaired paperdoll, all 1,556 body frames and 3,600 matching equipment
frames are installed. The reviewed body blob is
`e910168e70f76cba1190b0f398df61232439355237af363e5268e32364479119`;
decoded frame RGBA is
`d3299aba4911334c1b6c339ecfc3e5411982fc29715bde630304eeccd307b9d4`.
`VossCurrentRuntimeTests` pins both values from the reviewed stage.

- The staged candidate test passes, including timing, palette and chair endpoints.
- 118 Swift tests across 11 suites pass after installation.
- macOS Debug and iOS Simulator Debug builds succeed. Their body/equipment
  manifests, index blobs, body animation inventory and seven inventory images
  match the installed resources (decoded pixels for optimized iOS PNGs).
- All 33 live equipment checks pass, including inventory, equipped walking,
  independent layers and unequipping. All 21 office checks pass, including
  seated free play, rising, walking and area transitions.
- Live captures, build/test logs and bundle verification are in
  `output/voss-hand-repair-oct01`. No iOS device execution was performed.

The corrected paperdoll source is left open in Blender for inspection. The
installation receipt records every installed file hash and the rollback path.
