# Winged helmet — rear-reference revision, October 3

This revision supersedes `WingedHelmetFittedOct03`. The user supplied a rear
reference showing details absent from the earlier interpretation. Sources,
references and reproducible live Blender MCP recipes are in
`ArtSource/Blender/WingedHelmetRearOct03/`. `Before_Rear_Revision.blend` preserves
the preceding paperdoll; `front_reference.png` and `back_reference.png` preserve
the supplied digital artwork.

## Rear construction

The back now has a curved central reinforcement with five rivets, two pointed
crown straps, and a broad steel binding around the mail's lower edge. Narrow
riveted strips bind its sides. The lower and side binding follow the existing
mail drape and blend between the existing head and chest bones with the mail;
the crown, shell and wings stay head-bound. No bones or original actions change.

The shared long flight feathers have relief and quills on both faces. Each wing
also has two staggered rows of small rear coverts and a continuous rolled holder enclosing both faces,
replacing the flat, largely unornamented backs. There are 18 shared flights and
38 coverts on each face: 94 physical feathers per wing, with 56 represented on
each face. These counts describe the constructed interpretation, not an exact
count claimed from the illustration.

The mail links now follow the curtain's local slope, overlap more densely and
stop beneath the upper edge of the steel binding. There are 672 modeled links;
covered lower rows were removed so no links poke through the binding. The
previously established shell fit, front crown design, face guards and collar
clearance geometry are retained. The fitted mail flares and rises around Voss's
raised collar rather than copying the unsupported vertical drape of the empty
helmet illustration.

## Sources and reproduction

Open `Before_Rear_Revision.blend` through live Blender MCP. Execute
`build_core_via_live_mcp.txt`, `build_wings_via_live_mcp.txt`,
`assemble_via_live_mcp.txt` and `transfer_via_live_mcp.txt` in order. The builders
read `geometry_helpers.txt`. Material slot 5 identifies the mail binding so
assembly assigns it the same head/chest blend as the flexible curtain.

Final source names remain `Voss_WingedHelmet_Paperdoll.blend` and
`Voss_WingedHelmet_Animations.blend`. Temporary holdout and render states must
not be saved over them. Reopen a saved source after rendering.

The assembled helmet has 82,304 vertices, 162,859 edges, 82,667 faces and 160,384
triangles before bevel evaluation. Every component is closed: zero boundary or
non-manifold edges. Components intentionally overlap at mounts and joins.
`armor_clearance.json` and `body_clearance.json` record evaluated triangle checks
for all eleven idle and ten walking poses. `preservation.json` compares the
protected V8 geometry, UVs, weights, transforms, original bones and nine actions.

## Staged assets

`ArtSource/Processing/package_winged_helmet_rear_oct03.py` validates and packages
336 source views into 1,200 idle/walk frames for the compatible V8 body, using
the established 128×128 indexed canvas and `(64,46)` pivot. The paperdoll remains
768×1344 with original layers offset by `(0,256)`. Neither body scale nor sprite
registration changes. The icon, transparent paperdoll helmet layer, detailed
front/side/back views and indexed equipment composites accompany the sources.

Gameplay rendering omits subpixel bevels as in the preceding fitted revision;
saved sources and detailed paperdoll retain them. During sprite rendering the
viewport switches temporarily to solid shading and the render interface is
locked to avoid unnecessary preview work; the saved source UI is restored when
reopened.

These assets are staged for the user-selected latest armored Voss. They are
**not installed into the older September 28 runtime**. Preserve its VossCHMF
authority. `validation.json` records the compatible body hash and
`review_receipt.json` binds the final source/payload hashes to reviewed outputs.

## Completed validation

All 336 source views rendered without errors and packaged into 1,200 frames.
The minimum source-image edge margin is 51 pixels. All 29 preservation checks
pass, every helmet vertex has normalized weights, and all 21 distinct idle/walk
poses clear the evaluated body and armor meshes. Front, side, rear, paperdoll
and all-direction equipped walking/idle sheets were visually reviewed. The
installed September 28 runtime hash is unchanged. Final hashes are recorded
in `review_receipt.json` and `validation.json`.
