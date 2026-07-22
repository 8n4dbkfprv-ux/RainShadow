# Office shell V3 — Baldur's Gate playable-scale rebuild

- Generated: 2026-07-22
- Mode: Image Generator CLI/API (`gpt-image-2`, high quality), using `OPENAI_API_KEY` from `launchctl`
- Retained master: `ArtSource/Generated/Office/office_shell_base_v03.png` (3840x2160)
- Runtime derivative: `RainShadow Shared/Resources/Art/Areas/DetectiveOffice/office_shell_base.png` (4096x2304)
- Registered scale preview: `ArtSource/Generated/Office/office_scale_preview_v03.png` (4096x2304)

## Generation prompt

```text
Use case: stylized-concept
Asset type: production empty environment plate for a fixed-camera isometric CRPG
Primary request: Rebuild the RainShadow detective office as a much larger, deeper playable room whose camera height, orthographic dimetric projection, environmental density, and human-relative architectural scale follow the supplied Baldur's Gate: Enhanced Edition tavern screenshots. This is a new original RainShadow room, not a copy of the tavern.
Input images: Image 1 is the current RainShadow office and is only the authoritative reference for the noir setting, worn materials, cool rainy window light, warm practical-light falloff, and the required window-left / doorway-upper-right functional arrangement. Images 2 and 3 are Baldur's Gate: Enhanced Edition tavern references used only to measure camera elevation, dimetric projection, room footprint, negative-space density, floor-board scale, and human-relative feature scale. Do not reproduce their room layout, furnishings, characters, UI, or fantasy decoration.
Scene/backdrop: an empty 1940s private-detective office after hours, with worn dark wooden floorboards, stained two-tone plaster walls, a single modest rain-dark window opening on the left/rear wall, and one open doorway in the upper-right/rear wall leading into darkness. The room should have an irregular area-map silhouette surrounded by pure black outside the architecture.
Style/medium: richly pre-rendered late-1990s isometric PC CRPG environment art; painterly baked textures, modest native-resolution softness, restrained material detail, no modern PBR gloss.
Composition/framing: exact 16:9 landscape plate, fixed near-orthographic 2:1 dimetric view from substantially higher and farther away than Image 1. Show the complete office footprint with abundant traversable floor on every side. The walkable floor should span roughly ten to twelve imagined standing-adult body heights from near edge to rear wall. Use Images 2 and 3 as the scale authority: wall height, doorway, window, floorboards, and trim must all feel small enough for BG-scale characters. On the final 3840x2160 plate, an imagined standing adult would be about 170–190 pixels tall; the doorway opening should be about 340–410 pixels tall; the window glass about 170–220 pixels tall. Keep the window left of centre and the doorway right of centre, with broad clear floor between them and the foreground.
Lighting/mood: dim rain-blue ambient light from the window, subdued amber practical-light residue across the central floor, deep but readable shadows; noir, lonely, lived-in, not horror-black.
Color palette: tobacco brown and near-black wood, nicotine beige plaster, desaturated green-black lower walls, cold steel-blue rain light, small restrained amber pools.
Materials/textures: narrow worn floorboards at BG-relative scale, cracked plaster, dull painted wainscot, scuffed dark trim, subtle water sheen near the window.
Constraints: EMPTY ARCHITECTURAL SHELL ONLY. No desk, tables, chairs, armchairs, filing cabinets, radiator, coat rack, door leaf, rugs, lamps, phone, papers, files, mugs, ashtrays, wastebasket, bottles, boxes, people, characters, creatures, UI, text, logos, watermark, selection circles, fog overlay, or baked movable-prop shadows. The window opening and doorway opening are built architecture; everything movable will be composited separately at runtime. Preserve a clean continuous floor under all future prop placements. Pure black only outside the room silhouette.
Avoid: the close low camera and oversized wall/window/door geometry of Image 1; a compact dollhouse room; giant floorboards; modern interior-render perspective; copied Baldur's Gate content; tavern barrels or fantasy ornament; fisheye or perspective convergence; top-down 90-degree view; front-facing elevation; excessive empty black inside the playable footprint.
```

## Intended runtime contract

- Generated master: 3840x2160.
- Runtime derivative: 4096x2304.
- Background plate scale and prop scale are intentionally separate: the new shell fills the BG-scale camera while existing alpha props are reduced and registered independently.
- Standing adult target: 82 world units, 9% of the 911-unit camera-visible height.
