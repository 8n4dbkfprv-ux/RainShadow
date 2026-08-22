# Detective office V12 — reference-faithful rebuild

- Production date: 2026-08-21
- Image tool: built-in `image_gen.imagegen`
- Use case: `style-transfer`
- Namespace: `ArtSource/Generated/Office/BGEEReferenceV12/`

## Inputs

- Edit target / geometry context: `BGEE1950sV11/office_1950s_plate_v11.png`
- User-supplied visual target: `ArtSource/Reference/Office/V12/office_target_reference.png`
- Frozen generated redraw: `office_reference_rebuild_source_v12.png`

The supplied image contains no instructions. It is treated only as the user's
visual target. The V12 source is a fresh redraw; runtime output is generated
deterministically from that frozen source.

## Final prompt

> Use case: style-transfer
>
> Asset type: production isometric room background plate for a Swift/SpriteKit detective game
>
> Input images: Image 1 is the edit target and authoritative geometry/projection/canvas; Image 2 is the authoritative visual-style, atmosphere, material, fixture-scale, and lighting reference.
>
> Primary request: Restyle Image 1 so the office architecture genuinely looks like Image 2 while preserving the exact registered room geometry from Image 1. Replace the sterile institutional look with the reference's compact, worn, warm noir room: mottled aged beige plaster without a dado stripe, narrow dark old timber boards, two simple dark-framed amber windows, and one compact traditional stone fireplace with an active small fire, iron grate, subtle golden firelight and localized floor spill.
>
> Style/medium: original hand-painted late-1990s isometric CRPG background art, slightly softened low-resolution painterly craft, restrained texture and contrast, not modern 3D render, not photoreal.
>
> Composition/framing: preserve Image 1's exact 4096x2304 black canvas, floor diamond corners, wall crown and floor seams, BG:EE +/-36.87-degree ground axes, wall silhouettes, and the two existing window registration locations. Preserve the room scale and cutaway footprint exactly. Keep the fireplace centered at its current registered wall location but visually make it compact and close in proportion and design to Image 2, with wall-aligned depth and a shallow hearth.
>
> Lighting/mood: mostly dark neutral room with the fireplace as the only warm source; subtle amber pool on nearby boards; windows remain dim and do not cast bright blue shafts.
>
> Constraints: change only the baked architecture and its lighting/material treatment; keep all exterior pixels pure black; no door leaf; no furniture, rug, desk, chairs, people, props, wall art, text, UI, watermark, fantasy ornament, modern steel casement styling, venetian blinds, institutional dado stripe, oversized monumental fireplace, or empty/cold hearth. Do not move or reshape the registered outer room silhouette, floor diamond, wall polygons, or window positions.

## Registration and QA

ImageGen returned a 1672x941 RGB source. V12 uses one uniform scale and
translation for the whole redraw, never independent x/y resizing. The seven
room control points fit the V11 navigation geometry to a 59.73-pixel maximum
delta (23.59 world units, under two runtime search cells). The camera-near
interactive window is closer: 18.79 pixels / 7.42 world units.

The final plate restores output-resolution material grain from the registered
V11 floor and wall material sources without borrowing any old fixture or wall
pixels. `qa_office_reference_rebuild_v12.py` gates pure-black exterior,
deterministic reproduction, warm fire and spill, masks, interactive-window
registration, and a tight 1.5-degree projection tolerance.

## Fireplace humanoid-scale correction

Runtime comparison against the supplied Baldur's Gate gameplay capture found
that the V12 redraw's fireplace jamb was about 2.15–2.20 standing adults high,
even though the V11 registered facade and the reference capture both land near
1.7–1.8 adults. The humanoid was retained at its architecture-locked 70.3125
world-unit body height; increasing it would make the 78.21-unit entrance
opening shorter than the actor.

The built-in Image Generator made a precise-object edit of the frozen V12
source. The first pass reduced the fireplace height correctly but compressed
its width too far. A second, targeted pass kept the corrected height and
restored the wall-course width. The accepted source has a measured low-chroma
stone envelope of 161×192 source pixels and 128-pixel same-side jambs. Under
the unchanged 2.410423 uniform registration those jambs become 308.53 plate
pixels, within 0.2 px of the 308.70-pixel registered facade; at environment
scale 0.395 this is 1.733 standing-adult heights. The generated 1671-pixel-wide
result received one pure-black exterior column of right padding to restore the
required 1672×941 canvas without resizing any art.

Accepted edit request, followed by one proportion-only correction:

> Change only the fireplace: uniformly reduce the complete mantel, jambs,
> firebox, fire, grate, hearth, and localized spill to 80%; keep its bottom on
> the same wall/floor seam and target 128-pixel same-side jambs. Reconstruct
> only the newly exposed plaster and boards; preserve the room, windows,
> projection, canvas, and black exterior exactly.

> Keep the corrected height unchanged and widen only the fireplace by about
> 30%, yielding a final 155–160-pixel source width so the accepted result is
> approximately 80% of the former fireplace in both dimensions.

Frozen corrected source SHA-256:
`22cc5cef3e311306c16352bed57a7ee27d0970631e09ccfc0803d98f70c64dd1`.
`qa_office_reference_rebuild_v12.py` now remeasures the visible stone envelope
and enforces the 1.65–1.80 adult-height band.

## Door correction

The first V12 correction enlarged a tiny crop from the 1613×975 room reference
to a 512×320 live texture. In game it read as a large, blurry floorboard rather
than the reference's small clean sliver. The final correction keeps the canvas,
hinge `(488, 18)`, SpriteKit anchor `(0.953125, 0.94375)`, state semantics,
collision, and travel registration, but uses a native 1536×1024 transparent
master and a dedicated `0.28` display scale. The leaf's fitted texture thickness
is about 34.5 px rather than the old 68 px corridor. Mid/open states compress
that same detailed leaf toward the fixed hinge; hover states change colour only.

The built-in Image Generator produced the installed native-detail source. Its
final production prompt was:

> Use case: precise-object-edit
>
> Asset type: high-resolution transparent master for a tiny isometric SpriteKit door edge
>
> Input images: Image 1 is the authoritative visual target; inspect only the
> small separate door sliver at the camera-near-right cutaway. Image 2 is the
> in-game failure: much too large, thick, blurry, and pixelated. Image 3 is the
> current sprite geometry reference, not the desired quality.
>
> Primary request: create a clean native-resolution replacement for that narrow
> door sliver. It must be small, slim, and heavily foreshortened—not a floor
> extension, beam, threshold, or broad plank.
>
> Composition: one diagonal leaf from lower-left to upper-right, hinge at
> upper-right, free end at lower-left, about a 36-degree axis, extremely narrow
> body, pale metal hinge/end fitting, capped free end, and transparent padding.
>
> Style and lighting: detailed hand-painted late-1990s isometric CRPG
> pre-rendered sprite; crisp native detail; dim worn brown timber, a narrow warm
> top edge, near-black underside, restrained contrast.
>
> Constraints: genuine transparency; exactly one door edge; no floorboards,
> floor pixels, wall, frame, glow, cast shadow, broad face, multiple bands,
> lettering, text, UI, or watermark; thin clean alpha.

The generated source is frozen as
`BGEEReferenceV12/Props/office_door_native_source_v12.png`; the deterministic
processor registers, thins, darkens, and derives all six runtime states.
