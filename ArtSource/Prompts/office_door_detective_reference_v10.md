# Office door V10 — shorter detective-relative openings

- Generated: 2026-07-26
- Mode: built-in Image Generator for leaf/frame props; wall-locked aperture patch for shell/suite openings
- Character authority: shipped `VossIdle.atlas/voss_standing_idle_s_00.png`
- Clear opening: **1.25×** visible Voss, H/W **2.20** (≈130×287 plate px)
- Wall crowns frozen at V9 face height (505 px); only doorway recess pixels change

## Detective reference

`200 / 512 × 232 = 90.625` world = **229.430** shell-plate pixels

| Feature | V10 |
|---|---:|
| Voss visible body | 229.430 plate px |
| Clear door opening | 130.455×287 px |
| Opening / Voss height | 1.250× |
| Opening H/W | 2.200 |
| Wall face (frozen) | 505 px |
| Handle height | 0.575× Voss above threshold |

## Image Generator — exterior leaf

```text
Use case: stylized-concept
Asset type: production game prop source for a late-1990s CRPG
Primary request: Create one upright front-elevation 1940s private-detective office door leaf with frosted upper glass panel. Bake the agency lettering onto the glass as two centered lines reading exactly "H. VOSS" above "PRIVATE INVESTIGATOR" in simple dark period sans lettering. This is a new leaf asset.
Input images: Image 1 is Harlan Voss, the shipped standing detective and the sole human scale reference; Image 2 is the prior approved office door leaf used only for material, wood color, frosted glass, and wear reference.
Scale relationship: the opaque door body height is about 1.25 times Voss's visible standing body height with height-to-width ratio about 2.20. The generated source will be normalized after generation.
Subject: a single dark battered walnut wood door leaf with frosted glass upper lite, simple stile-and-rail construction, one small period brass doorknob on the latch side; no frame, no wall, no hinges visible as separate hardware clusters.
Style/medium: richly pre-rendered late-1990s isometric PC CRPG prop language but drawn as a straight-on upright elevation (NOT an already-sheared dimetric parallelogram); painterly baked wood; warm upper-left lighting matching Image 2.
Composition/framing: centered upright rectangle, full leaf visible with modest padding, clean silhouette, no perspective taper.
Scene/backdrop: perfectly flat solid #00ff00 chroma-key background for local removal.
Constraints: the background must be one uniform #00ff00 color with no shadows, gradients, texture, reflections, floor plane, or lighting variation. Keep the object fully separated with crisp edges. Do not use #00ff00 in the object. No cast shadow, contact shadow, reflection, person, wall, floor, logo, watermark, furniture, or extra objects. Do not include the detective from Image 1. Do not draw the door already projected onto a wall slope.
Avoid: dimetric/isometric parallelogram leaf; stretched or squashed proportions; black background; ornate Victorian carving; modern flush door.
```

## Image Generator — internal leaf

```text
Use case: stylized-concept
Asset type: production game prop source for a late-1990s CRPG
Primary request: Create one upright front-elevation frosted interior office door leaf matching the exterior leaf's materials. Bake the agency lettering onto the frosted glass as two centered lines reading exactly "H. VOSS" above "PRIVATE INVESTIGATOR". This is a new internal leaf asset.
Input images: Image 1 is Harlan Voss (scale only); Image 2 is the exterior leaf material/lettering reference.
Scale relationship: opaque body about 1.25 times Voss's visible standing body height, height-to-width about 2.20.
Subject: single dark walnut interior door leaf with frosted glass, simple rails/stiles, small dark knob; no frame, no wall.
Style/medium: late-1990s pre-rendered CRPG prop; upright front elevation only (not wall-sheared); warm upper-left light.
Composition/framing: centered upright rectangle, full leaf, modest padding.
Scene/backdrop: perfectly flat solid #00ff00 chroma-key background.
Constraints: uniform #00ff00 background only; crisp separation; no cast shadow; no person; no wall; no already-dimetric shear; no black background.
Avoid: stretched proportions; perspective taper; freestanding room scenery.
```

## Image Generator — exterior frame

```text
Use case: stylized-concept
Asset type: production game prop source for a late-1990s CRPG
Primary request: Create one slim, complete wooden doorframe/casing ring with an empty clear opening sized for the separate door leaf. Upright front elevation. This is a new frame asset.
Input images: Image 1 is Harlan Voss (scale only); Image 2 is the door leaf (material and clear-opening proportion); Image 3 is the prior frame (finish reference only).
Scale relationship: clear opening about 1.25 times Voss's visible standing body height with height-to-clear-width 2.20. Outer width no more than about 1.20 times the clear opening width.
Subject: dark battered wood jamb-and-header ring with subtle inner stop/reveal and a very thin threshold; no wall, no door leaf, no glass, no character, no hinges, no knobs.
Style/medium: late-1990s pre-rendered CRPG prop; upright elevation (processor will apply wall shear later); match leaf walnut and warm upper-left light.
Composition/framing: centered upright frame, full object, generous padding, clean silhouette.
Scene/backdrop: perfectly flat solid #00ff00 chroma-key background.
Constraints: uniform #00ff00 only; crisp edges; no cast shadow; no leaf; no hinges; no person; no wall; no black background.
Avoid: thick freestanding box frame; ornate Victorian carving; already-dimetric parallelogram.
```

## Processing

- Aperture patch: `ArtSource/Processing/process_office_door_aperture_v10.py`
- Prop ship (no wall rebuild): `process_office_door_lettered_v01.py` (default / `ship_props`)
- QA: `verify_door_shell_fit.py` → `ArtSource/Generated/Office/door_detective_reference_v10/`
