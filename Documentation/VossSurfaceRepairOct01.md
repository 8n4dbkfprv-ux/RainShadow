# Voss surface repair — October 1

The reported hand holes were dark surface marks caused by six skin triangles
sampling neighboring dark areas of the packed texture atlas. A topology audit
found zero boundary edges, zero nonmanifold edges and zero inconsistent winding
edges. All seven body materials have opaque alpha. Plain-material renders
confirmed that the apparent punctures were absent from the geometry.

Close-ups identified four clusters: the back of the right hand, two spots on
its finger surface, and a small spot on the left fingers. Front, back and both
side full-body reviews found no additional confirmed holes. Natural clothing
seams, finger gaps and the armor's authored openings are retained.

The repair translates UV coordinates on faces 5314, 905, 776, 476, 503 and
238577 by small integer texel offsets into neighboring skin texture. Selection
was checked against dense triangle samples including bilinear-filter neighbors,
then verified in before/after renders. No texture was repainted. The patch
changes 18 UV loops; all other UV loops, vertex coordinates, topology, material
IDs, skin weights, bones and animation keyframes are unchanged. This retains
the preceding little-finger deformation repair and the sword's palm attachment.

## Sources and reproduction

Current sources are under `ArtSource/Blender/VossSurfaceRepairOct01`:

- `Voss_SurfaceRepair_Paperdoll.blend`
- `AnimationProduction/Voss_Rustic_Animations.blend`
- `Equipment/Voss_Equipment_Animations.blend`

`uv_patch.json` records original/repaired UV values and face/vertex identities.
`apply_patch_via_live_mcp.txt` checks every original value before applying the
patch to an incremental copy of the previous hand-repair source.
`verify_source_via_live_mcp.txt` writes the bounded-change and topology audit
to `model_preservation.json`. Authoring, review and rendering use live Blender
MCP; no standalone Blender process is required.

`render_body_via_live_mcp.txt` retains the existing neutral-material recipe,
camera, denoising and calibration. It re-renders the 420 neutral animation
views. Region-ID passes and shadow geometry are reused because neither depends
on UVs. The body is then encoded into all 1,556 frames using the recorded crop
boxes, preserving registration. The paperdoll's PBR and neutral passes are
re-rendered at 768×1088; the original region-ID pass is reused.

Equipment renders use a uniform body holdout with no texture or UV input.
Geometry, poses, gear and camera are unchanged, so the 1,008 equipment source
renders and three paperdoll overlays are reused exactly. The updated equipment
Blender source includes the UV repair for future authoring. Its 3,600 indexed
frames are staged and compared against the prior installed equipment.

`ArtSource/Processing/package_voss_surface_repair_oct01.py` provides `watch`,
`stage-body`, `stage-equipment` and `install`. Installation requires the source
audit, staged Swift check and hash-bound visual review, and preserves the
previous runtime under `output/voss-surface-repair-oct01/RuntimeBeforeSurfaceRepair`.
VossCHMF identity, palette support, animation timing and chair endpoints remain
the runtime contract. Navigation, shaders and item behavior are unchanged.

## Installed verification

The surface-corrected paperdoll and all 1,556 animation frames are installed.
The body blob SHA-256 is
`237cf80bb0ef6de755c635c369a30e50997c42829a72f71cce58c8d81f31b47e`;
decoded RGBA is
`4e3198fc964fbfbdb5cac3384f2db4f1aaeb644247eec72847af98e669ccd1fa`.
`VossCurrentRuntimeTests` pins these reviewed values.

Across 420 source views, 408 native planes are identical to the preceding hand
repair. Thirteen pixels change across twelve views, with a maximum of two per
view. Every silhouette and shadow mask is identical. All three equipment index
blobs remain byte-identical. `native_comparison.json` records the comparison;
`reused_input_validation.json` verifies 1,470 reused UV-independent inputs.

- The staged Swift candidate check passes, including palette, timing and chair
  endpoint/reversal contracts.
- 118 Swift tests in 11 suites pass after installation.
- macOS Debug and iOS Simulator Debug builds succeed; 16 bundle checks per
  platform match the reviewed resources, including decoded inventory pixels.
- All 33 live equipment/inventory checks and all 21 office/chair checks pass.
  Captures and logs are in `output/voss-surface-repair-oct01`.
- No iOS device execution was performed. The corrected paperdoll source is
  left open in Blender for inspection.

The streaming encoder also retries Pillow's incomplete-PNG `SyntaxError` while
Blender writes a frame; the completed-frame stage still requires every source
and validates the full bundle. This was observed during the rebuild and the
remaining frames were encoded successfully after rendering completed.
