# Winged helmet reference corrections — October 3

Superseded by [the feather and head-fit revision](WingedHelmetFittedOct03.md).

This revision supersedes `WingedHelmetOct03` for the latest armored Voss. The
user asked to correct remaining differences from `Unknown-7 copy.png`. Sources,
reference, live MCP recipes and prepared assets are in
`ArtSource/Blender/WingedHelmetRefinedOct03/`.

## Shape corrections

- Taller double brow band, with a blank upper band and lower rivet row.
- Notched crown reinforcement shapes traced from the reference, a smaller crown
  spike and a continuous central crest/nasal with horizontal clasps.
- Narrow curved face rails instead of broad angular cheek plates. Their lower
  ends sweep forward to clear the armor collar while retaining the drawn length.
- Curved wing stems, staggered upper feathers and downward lower feathers,
  replacing the straight radial fan. Small concealed attachments replace the
  broad mounting plates. Wing proportions follow the reference's dome/brow scale.
- Shallow feather ridges with smooth surfaces and sharp boundaries; existing
  packed V7 steel textures and edge materials are retained.

The drawing supplies the front silhouette. Depth, rear construction and fitting
around Voss remain a 3D interpretation. The face remains visible. No body, head,
rig, armor, sword or action edits are part of this revision.

## Sources and reproducibility

`Before_Refinement.blend` preserves the first winged helmet. The earlier V8
`Before_Helmet_Revision.blend` is the starting scene for reconstruction. Through
live Blender MCP, execute `build_core_via_live_mcp.txt`,
`build_wings_via_live_mcp.txt` and `assemble_via_live_mcp.txt` in that order.
Then use `transfer_via_live_mcp.txt` for the animation source. The old broad-cheek
clearance recipe is not used in this revision.

The helmet has 27,036 vertices, 54,675 edges, 27,973 faces and 53,404 triangles
before bevel evaluation, with zero boundary or non-manifold edges. Separate
closed feathers, plates and fasteners intentionally overlap at their joints.
`preservation.json` passes all 29 checks against the preceding V8 sources:
protected geometry, UVs, weights, transforms, visibility, rest/pose bones and
all nine original actions are unchanged. `armor_clearance.json` records zero
helmet/armor triangle intersections across 11 idle and 10 walking poses.

## Rendering and staging

The source files are `Voss_WingedHelmet_Paperdoll.blend` and
`Voss_WingedHelmet_Animations.blend`. Review and animation rendering recipes run
through live Blender MCP; do not save temporary holdout/render states over the
sources. Reopen a saved source after rendering.

Registration remains identical to the first winged helmet: a 768×1344 paperdoll
adds 256 pixels above the old portrait without scaling the figure. Original
layers align at `(0,256)`. Gameplay renders use 384×384 with 64 source pixels
of padding around the original 256×256 projection. Packaging retains the V8
body's sampling grid, 128×128 indexed canvas, `(64,46)` pivot and palette support.

Run `ArtSource/Processing/package_winged_helmet_refined_oct03.py` after rendering
336 source views. It validates and stages 1,200 idle/walk frames, a transparent
paperdoll helmet layer, inventory icon and equipment composites. The walking
preview recipe assembles four facings from the actual indexed layers.

These are prepared for the user-selected latest armored Voss. They are **not
installed into the current September 28 runtime**, which lacks that equipment
integration. Use the matching V8 body hash recorded in `validation.json`.
`review_receipt.json` binds final source/payload hashes to the reviewed outputs.

Final validation: all 1,200 frame names match the compatible body, all 336
source views are complete and unclipped (minimum edge margin 45 pixels), and
front/three-quarter/back/full-body plus 16-direction indexed composites were
visually reviewed. The current VossCHMF runtime hash remains unchanged.
