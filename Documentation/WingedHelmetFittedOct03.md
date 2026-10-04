# Winged helmet — feather construction and head fit, October 3

Superseded by [the rear-reference revision](WingedHelmetRearOct03.md).

This revision supersedes `WingedHelmetRefinedOct03`. The user identified four
remaining problems: feather count, the feather holder, short rear coverage,
and poor fit around Voss's head. The additional digital reference clarified
that the rear coverage is mail and that the feathers have dense overlapping
coverts around a rounded metal holder.

All sources and outputs are in `ArtSource/Blender/WingedHelmetFittedOct03/`.
`Before_Refit.blend` preserves the previous result; `digital_reference.png` and
`sketch_reference.png` preserve both user references.

## Changes

- Each wing now has 56 feathers: ten upper flights, eight lower flights and
  two staggered rows of nineteen small coverts. This is an authored layered
  interpretation of the digital image, not a claim of an exact traced count.
- A continuous rounded holder follows the curved inner outline. Small hinged
  brackets attach it to the shell. Overlapping coverts conceal the feather roots.
- The dome crown drops from 1.838 m to 1.783 m, above the unchanged 1.750 m head.
  Its excess height is reduced from about 88 mm to 33 mm. The brow band is
  shallower, shell depth is reduced, and the guards sit alongside the cheeks.
- The old solid rear skirt is replaced by a backed mail curtain with 840
  modeled links. Its center extends roughly 74 mm below the previous skirt.
  The sides rise over the shoulder plates; the rear flares over the collar.
- The mail gradually blends from the existing head bone to the existing chest
  bone toward its hem. No bones or actions are changed. The rigid helmet and
  wings remain head-bound. Lower feathers curve slightly forward, and the guard
  tips are shaped for clearance at the extremes of the existing head turns.
- Existing packed steel textures are reused. The rounded holders use polished
  steel shading, and the lining is dark and rough. Rivet heads retain their
  round shape after refitting the brow band.

The front reference determines the design. Shoulder clearance, depth and the
mail's drape over Voss's existing raised collar are fitting adaptations; this
is not an exact reproduction of an empty helmet in a flat illustration.

## Authoring and validation

Use the live Blender MCP connection. Open `Before_Helmet_Revision.blend`, then
execute `build_core_via_live_mcp.txt`, `build_wings_via_live_mcp.txt`,
`assemble_via_live_mcp.txt`, and `transfer_via_live_mcp.txt`. Recipes are kept
beside the sources; the first two import `geometry_helpers.txt`. Do not use the
older broad-cheek clearance recipe. `assemble` preserves the material slots
and assigns the mail's blended weights after combining the meshes.

The assembled mesh has 76,058 vertices, 149,403 edges, 75,495 faces and 147,816
triangles before bevel evaluation. Closed components intentionally overlap at
mountings. There are zero boundary or non-manifold edges.

`preservation.json` checks the unchanged V8 body/source, armor and sword meshes,
UVs, weights, transforms and visibility, the original rest/pose bones, and all
nine original actions. Both `armor_clearance.json` and `body_clearance.json`
check evaluated triangle intersections across the eleven distinct idle poses
and ten walking poses. Source files remain separate from temporary render and
holdout states.

## Prepared assets and runtime boundary

Sources: `Voss_WingedHelmet_Paperdoll.blend` and
`Voss_WingedHelmet_Animations.blend`.

Paperdoll registration stays 768×1344, with the original portrait layers offset
by `(0,256)` and no body scaling. Gameplay renders remain 384×384 with 64 pixels
of padding around the original source projection. The packaging script
`ArtSource/Processing/package_winged_helmet_fitted_oct03.py` retains the matching
V8 body sampling grid, 128×128 indexed canvas, `(64,46)` pivot and palette support.
336 source views expand to 1,200 idle/walk frames over sixteen directions.

The inventory icon, equipped paperdoll, transparent helmet layer, front/side/back
close-ups and actual indexed animation composites accompany the sources.
`review_receipt.json` binds final source and payload hashes to the reviewed files.

These assets are staged for the latest armored Voss selected by the user. They
are **not installed into the current September 28 runtime**, which lacks the
later equipment integration. Preserve the current VossCHMF authority. The body
compatibility hash is recorded in `validation.json`.

Gameplay-only rendering omits the helmet's subpixel bevel modifier; the saved
Blender sources and paperdoll retain it. `gameplay_bevel_comparison.json` records
the check on `idle_s_00`: the 180-pixel native helmet silhouette is identical,
and nine pixels change by one palette shade. The preliminary beveled renders
are retained in `Renders/BeveledComparison/` for comparison. This is a render
level-of-detail choice, not a geometry or rig change in the saved sources.

Final validation passed: all 1,200 frame names match the compatible body; all
336 source views are unclipped, with a minimum edge margin of 51 pixels. Both
body and armor intersection checks pass in all 21 distinct poses. All helmet
vertex weights sum to one, and the reopened paperdoll retains its bevel. Front,
side, three-quarter, rear and all-direction indexed composites were reviewed.
The current VossCHMF runtime hash is unchanged.
