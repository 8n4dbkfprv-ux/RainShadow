# Office door V10.1 — leaf/frame redo for locked black-gap

- Generated: 2026-07-26
- Mode: built-in Image Generator for leaf/frame props
- Wall openings already locked at **1.70×** visible Voss (do not regenerate walls)
- Clear opening / leaf canvas: **291×640** source px (H/W **2.20**); plate gap ≈ **177×390**
- Problem being fixed: upright black gap reads correctly, but shipped leaf/frame/hinges look like mismatched cropped cards; fallen leaf overshoots the frame

## Detective reference

`200 / 512 × 232 = 90.625` world = **229.430** shell-plate pixels

| Feature | V10.1 |
|---|---:|
| Voss visible body | 229.430 plate px |
| Clear door opening (plate) | 177.273×390 px |
| Opening / Voss height | 1.700× |
| Opening H/W | 2.200 |
| Leaf processing canvas | 291×640 |
| Wall face (frozen) | 505 px |
| Handle height | 0.575× Voss above threshold |

## Reference images

1. `RainShadow Shared/Resources/Art/Atlases/VossIdle.atlas/voss_standing_idle_s_00.png` — scale only
2. `ArtSource/Generated/Office/door_detective_reference_v10/ig_ref_opening_dimension_card.png` — exact black-rectangle proportion the leaf must fill
3. `ArtSource/Generated/Office/door_detective_reference_v10/ig_ref_black_gap_with_frame.png` — in-scene black gap + slim frame (fit authority)
4. Prior V10 leaf/frame only for wood/glass material language — not for wrong proportions

## Image Generator — exterior leaf

```text
Use case: stylized-concept
Asset type: production game prop source for a late-1990s CRPG
Primary request: Create one upright front-elevation 1940s private-detective office door leaf that exactly fills a tall narrow black doorway opening with height-to-width ratio 2.20. Bake the agency lettering onto the frosted upper glass as two centered lines reading exactly "H. VOSS" above "PRIVATE INVESTIGATOR" in simple dark period sans lettering. This is a new leaf asset sized for the locked wall gap.
Input images: Image 1 is Harlan Voss (scale only). Image 2 is the dimension card — the black rectangle is the exact clear opening the leaf must fill (about 1.70× Voss body height, H/W 2.20). Image 3 is the in-scene black gap with slim wood frame for proportion. Image 4 is prior door material reference only.
Scale relationship: opaque door body height about 1.70 times Voss's visible standing body height; height-to-width about 2.20. Do not make a wide or squat door. The generated source will be normalized to 291×640 after generation.
Subject: a single dark battered walnut wood door leaf with frosted glass upper lite, simple stile-and-rail construction, one small period brass doorknob on the latch stile; NO frame, NO wall, NO free-floating hinge hardware, NO hinge knuckles.
Style/medium: richly pre-rendered late-1990s isometric PC CRPG prop language but drawn as a straight-on upright elevation (NOT an already-sheared dimetric parallelogram); painterly baked wood; warm upper-left lighting.
Composition/framing: centered upright rectangle filling most of the frame, modest chroma padding only, clean silhouette, no perspective taper, no foreshortening.
Scene/backdrop: perfectly flat solid #00ff00 chroma-key background for local removal.
Constraints: the background must be one uniform #00ff00 color with no shadows, gradients, texture, reflections, floor plane, or lighting variation. Keep the object fully separated with crisp edges. Do not use #00ff00 in the object. No cast shadow, contact shadow, reflection, person, wall, floor, logo, watermark, furniture, or extra objects. Do not include the detective from Image 1. Do not draw the door already projected onto a wall slope. Do not draw hinges.
Avoid: dimetric/isometric parallelogram leaf; stretched or squashed proportions; black background; ornate Victorian carving; modern flush door; door wider than the dimension-card black rectangle; chunky freestanding frame around the leaf.
```

## Image Generator — internal leaf

```text
Use case: stylized-concept
Asset type: production game prop source for a late-1990s CRPG
Primary request: Create one upright front-elevation frosted interior office door leaf matching the exterior leaf materials and the same 2.20 height-to-width clear opening. Bake the agency lettering onto the frosted glass as two centered lines reading exactly "H. VOSS" above "PRIVATE INVESTIGATOR". This is a new internal leaf asset.
Input images: Image 1 is Harlan Voss (scale only); Image 2 is the dimension card black rectangle; Image 3 is the new exterior leaf (match materials/lettering).
Scale relationship: opaque body about 1.70 times Voss's visible standing body height, height-to-width about 2.20.
Subject: single dark walnut interior door leaf with frosted glass, simple rails/stiles, small dark knob; no frame, no wall, no hinges.
Style/medium: late-1990s pre-rendered CRPG prop; upright front elevation only (not wall-sheared); warm upper-left light.
Composition/framing: centered upright rectangle, full leaf, modest padding.
Scene/backdrop: perfectly flat solid #00ff00 chroma-key background.
Constraints: uniform #00ff00 background only; crisp separation; no cast shadow; no person; no wall; no already-dimetric shear; no black background; no hinges.
Avoid: stretched proportions; perspective taper; freestanding room scenery; wide door.
```

## Image Generator — exterior frame

```text
Use case: stylized-concept
Asset type: production game prop source for a late-1990s CRPG
Primary request: Create one slim, complete wooden doorframe/casing ring whose EMPTY clear opening matches the tall narrow black gap (height-to-width 2.20, about 1.70× Voss). Upright front elevation. This is a new frame asset.
Input images: Image 1 is Harlan Voss (scale only); Image 2 is the dimension card; Image 3 is the in-scene black gap with frame; Image 4 is the new exterior leaf (opening must match that leaf).
Scale relationship: clear opening about 1.70 times Voss's visible standing body height with height-to-clear-width 2.20. Outer width no more than about 1.22 times the clear opening width. Keep casing slim — not a freestanding box.
Subject: dark battered wood jamb-and-header ring with subtle inner stop/reveal and a very thin threshold; no wall, no door leaf, no glass, no character, no hinges, no knobs, no hinge knuckles.
Style/medium: late-1990s pre-rendered CRPG prop; upright elevation (processor will apply wall shear later); match leaf walnut and warm upper-left light.
Composition/framing: centered upright frame, full object, generous padding, clean silhouette, empty black or chroma interior opening.
Scene/backdrop: perfectly flat solid #00ff00 chroma-key background.
Constraints: uniform #00ff00 only; crisp edges; no cast shadow; no leaf; no hinges; no person; no wall; no black background outside the opening.
Avoid: thick freestanding box frame; ornate Victorian carving; already-dimetric parallelogram; painted hinge tabs.
```

## Processing

- Props only: `process_office_door_lettered_v01.py` (default / `ship_props`) after copying new masters to `ArtSource/Generated/Office/Props/` as:
  - `office_door_leaf_ig_v101_chroma.png`
  - `office_internal_door_leaf_solo_chroma_v101.png`
  - `office_door_frame_ig_v101_voss_reference_chroma.png`
- Soften baked shell hinge knuckles via `process_office_door_aperture_v10_fix.py` (reduce knuckle paint) or leave aperture and skip knuckle paint.
- QA: `verify_door_shell_fit.py` → `ArtSource/Generated/Office/door_detective_reference_v10/`
