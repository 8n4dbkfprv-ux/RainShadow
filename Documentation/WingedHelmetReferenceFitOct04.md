# Winged helmet and rear collar — October 4

This revision supersedes `WingedHelmetReferenceOct04`. The user prioritized the
longer rear helmet reference and authorized adjusting the upper rear armor collar
where needed. The paired sources and live Blender MCP recipes are under
`ArtSource/Blender/WingedHelmetReferenceFitOct04/`.

## Geometry and materials

The mail curtain is approximately 50 mm longer, with a shallower hem curve and a
broad continuous steel binding. Its lower portion follows the neck and shoulder
clearance envelope; it does not retain the earlier exaggerated rearward flare.
Binding and lining offsets follow the actual surface normal, preventing the dark
lining from emerging through the lower rim. Alternating tilted mail links are
spaced by surface arc length.

The curved wing holders have a slimmer cross-section. Each wing has 18 shared
flight feathers and three rows of 19 coverts on each face: 132 physical feathers,
with 75 represented on each face. Thin pale vanes have local UV edge shading and
fine barb relief, separate from the polished metal holders. The rear crown has a
continuous central riveted strap, two pointed side straps, and a taller brow band.

The upper rear armor fit changes 15,877 vertices, with a maximum displacement of
65.6 mm. It is bounded to rear y > 0.02, z > 1.38, |x| < 0.18 with smooth falloff.
Topology, UVs, weights, front armor and the rest of the character are preserved.
The original armor is retained in the incremental source backup.

The final helmet has 237,506 vertices, 469,899 edges, 235,869 faces and 468,060
triangles before modifier evaluation. All mesh components are closed. The source
is detailed production geometry for sprite rendering, not a real-time game mesh.

## Source authority and reproduction

- `Voss_WingedHelmet_Paperdoll.blend` is the detailed paperdoll master.
- `Voss_WingedHelmet_Animations.blend` contains the paired helmet and armor on
  the existing V8 animation rig.
- `Before_Reference_Revision.blend` retains the preceding helmet and armor.
- `Before_Helmet_Revision.blend` retains the protected original V8 paperdoll.

Use the live Blender MCP server. Open `Before_Reference_Revision.blend`, then run
`fit_rear_collar_via_live_mcp.txt`, the core and wing builders, assembly, and
transfer. Each recipe is an independent execution namespace; helper names may
otherwise shadow the caller's variables. Review the incremental core and wing
files and the rendered front, side and rear views. The clearance-envelope recipe
is a retained diagnostic experiment; it is not part of final source reproduction. Do not save temporary render
holdout or isolated-reference states over either master.

Run `verify_via_live_mcp.txt` and `check_fit_via_live_mcp.txt` on the final sources.
The preservation audit compares body/source/sword geometry, UVs, weights, object
transforms, rest/pose bones and nine original actions; armor coordinates outside
the authorized region remain unchanged. The fit audit passes all 21 distinct
idle/walk poses with zero intersecting triangle pairs against both body and armor. Wait for each timer to finish before
opening another file or starting another timer.

## Paired asset handoff

`render_review_via_live_mcp.txt` produces full-character and separate helmet/armor
paperdoll layers on a 768 × 1344 canvas. Older 768 × 1088 layers retain their exact
registration at offset (0, 256). `render_animations_via_live_mcp.txt` produces 336
views per layer. Render ordering groups cameras by action/frame and equipment,
with the original projection and registration intact.

Run `ArtSource/Processing/package_winged_helmet_reference_fit_oct04.py` using the
workspace Python runtime. It stages 1,200 helmet and 1,200 armor frames, validates
the native bundles and creates equipped contact sheets. `make_walking_preview.txt`
and `validate_handoff.txt` produce the animated preview and final handoff audit.
Source canvases are 384 × 384 with the original 256-pixel window centered inside;
native output remains 128 × 128 with pivot (64, 46).

The helmet layer includes body and adjusted-armor holdouts. Its manifest therefore
requires the paired `VossSplintMail` bundle by SHA-256. Both layers must travel
together. The unchanged sword is copied only for complete equipped previews.
The helmet can still be inspected independently in the detailed Blender source.

These assets target the user's selected latest armored Voss (`SwordMaterialsV8Oct01`).
They are staged, not installed into the older September 28 runtime in this checkout.
The latter remains VossCHMF; no actor, palette, navigation or render-port source is
changed. Bundle validation, source hashes and preservation receipts accompany the
handoff. The final render remains a 3D interpretation of the illustrated reference.
