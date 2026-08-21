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

## Door correction

The first V12 install retained V11's procedurally painted door family. Its
three broad longitudinal bands made the camera-near edge read as a detached
beam rather than the slim leaf in the approved room image. The correction
keeps the existing 512×320 canvas, hinge `(488, 18)`, SpriteKit anchor
`(0.953125, 0.94375)`, state lengths, collision, and travel registration.
`process_office_door_reference_v12.py` isolates the supplied image's measured
door bbox, excludes the adjacent floor, and uniformly maps those approved
pixels into the live registration. Mid/open states compress that same painted
leaf toward the fixed hinge; hover states change colour only.

The built-in Image Generator was used to resolve the intended surface read
before the deterministic extraction was authored. Its production prompt was:

> Use case: precise-object-edit
>
> Asset type: transparent raster master for an isometric SpriteKit game door
>
> Primary request: replace the broad three-plank beam treatment with the
> reference-faithful edge-on door leaf: a slim, heavily foreshortened strip of
> worn dark brown timber, subtle warm top edge, nearly black narrow underside,
> low contrast and period-appropriate aged varnish.
>
> Composition/framing: preserve the exact diagonal axis, hinge at upper-right,
> free end at lower-left, and long edge-on silhouette.
>
> Constraints: one door leaf only; no frame, wall, floor, lettering, readable
> front face, text, or watermark.

The generated study was not installed: direct extraction from the approved
room reference is more faithful and is now the final runtime authority.
