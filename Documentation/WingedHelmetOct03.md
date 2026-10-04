# Winged helmet — October 3

Superseded by [the reference correction pass](WingedHelmetRefinedOct03.md).
The original source and staged assets remain available for comparison.

The user supplied `Unknown-7 copy.png` and selected the latest armored Voss as
the target. The reference is copied to `ArtSource/Blender/WingedHelmetOct03/reference.png`.
The design uses an iron dome, pointed crown reinforcement straps, a small crown
spike, a riveted brow band, arrow-ended nasal, pointed cheek guards and tall wings.
The wings are interpreted as layered sculpted metal feathers, using the existing
V7 generated steel textures and separate edge/fastener shading.

## Sources and scope

- `Voss_WingedHelmet_Paperdoll.blend`: latest V8 armored Voss with the new helmet.
- `Voss_WingedHelmet_Animations.blend`: the same helmet bound to the existing
  `head` bone, retaining the V8 walking grip and exact sword attachment.
- `Before_Helmet_Revision.blend`: incremental copy before any geometry change.
- Live MCP recipes reproduce core construction, wings, assembly, transfer,
  preservation checks and rendering. Run core, wings and assembly against the
  backup; assembly includes the cheek-clearance patch. The review renderer
  extends the portrait camera once and records that padding in the scene.

The replacement helmet has 18,354 vertices, 37,107 edges, 19,081 faces and 36,052
triangles before bevel evaluation. Every component is closed; there are zero
boundary or non-manifold edges. The original helmet had 978 vertices, 1,637
edges, 673 faces and 1,346 triangles. Separate closed feather/rivet components
intentionally overlap at their mountings. No body simplification is included.

`preservation.json` compares the protected body/source, armor and sword geometry,
UVs, weights, transforms and render visibility, plus rest/pose bones and all
original actions against the preceding files. All checks pass for both sources.
The final cheek-guard taper raises 98 lower vertices by up to 35 mm to clear
the armor collar during head turns. `armor_clearance.json` checks evaluated
helmet/armor triangles in all 11 idle and 10 walking poses, with zero overlaps.

## Registration and packaging

The wings require additional portrait headroom. The paperdoll is **768×1344**,
with **256 pixels added above** the old 768×1088 image. Original layers align at
`(0,256)`; the body has not been scaled. `paperdoll_helmet.png` is the transparent
body-occluded helmet layer; `paperdoll_equipped.png` is the complete PBR preview.
Do not squeeze the extended image into the old aspect ratio or crop the wings.

Gameplay renders use a 384×384 canvas at orthographic scale 2.58: the original
256×256 / 1.72 projection is retained in the center, padded by 64 source pixels
per edge. `package_winged_helmet_oct03.py` subtracts that padding in its affine
registration and retains the V8 body sampling boxes, 128×128 native canvas,
`(64,46)` pivot, seven-region palette support and all authored facings.
336 independent renders expand to 1,200 idle/walk frames using the existing
65-frame idle holds and ten-frame walk. The helmet is head-weighted throughout;
there is no per-frame resizing or separate animation timing.

Run:

```sh
python3 ArtSource/Processing/package_winged_helmet_oct03.py
```

The package also prepares a 384×384 icon and actual indexed composites with the
V8 sword and V7-material armor. Source texture images are packed in the blends.
The model, material and handoff work is asset-only; no runtime Swift is changed.

## Current checkout boundary

The checkout now selects the September 28 character and has no October equipment
integration. The user explicitly chose preparation on the later armored Voss.
Consequently these assets are **staged, not installed into that older runtime**.
`validation.json` records the compatible V8 body hash; use these helmet frames
with that matching body and equipment integration. Existing gameplay resources
and the current VossCHMF authority remain untouched.

Final validation passed for all 1,200 frames. Every frame name matches the V8
body; the minimum source-image edge margin is 37 pixels. Front, three-quarter,
back, full paperdoll and all-direction indexed composites were reviewed.
`walking_preview.gif` shows four facings. The final review receipt binds the
source and indexed payload hashes. Current runtime hash remains unchanged.
