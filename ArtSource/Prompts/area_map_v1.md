# RainShadow detective-office area map V1

Date: 2026-07-19  
Generator: built-in Image Generator  
Generated source: `exec-85cb996d-0b33-4b68-bdce-02583960370f.png`

## Reference roles

- `office_composite_v01.png`: authoritative RainShadow location, projection, room geometry, prop placement, and lighting reference.
- [Baldur's Gate: Enhanced Edition manual](https://forums.beamdog.com/uploads/FileUpload/05/81c68bc0f572253a76ca721cb81f6a.pdf): functional reference only—map button on the left panel, visited areas lit, unexplored areas dark, current positions shown as dots, and important-place markers.
- [Beamdog 2.0–2.3 release notes](https://files.beamdog.com/files/BG-2.0-2.3-ReleaseNotes.pdf): functional reference only—optional area-map walkability/background information.
- The generated map does not reuse Baldur's Gate artwork, symbols, locations, labels, borders, or other franchise assets.

## Final prompt

```text
Use case: stylized-concept
Asset type: full-screen local area map texture for the RainShadow noir isometric CRPG
Primary request: Create an original local-area map of the current location, Elias Vale's detective office, using Image 1 only as the authoritative spatial and material reference. Translate the room into a readable late-1990s pre-rendered isometric CRPG map convention, with RainShadow's film-noir visual language.
Input images: Image 1 is the current office composite and must control room geometry, window and door placement, and the recognizable placement of desk, visitor chair, filing cabinet, radiator, coat rack, and rug.
Scene/backdrop: One isolated single-room office plan floating within deep charcoal-black unexplored space. Reveal the entire office. The wall footprint and furniture arrangement must match Image 1. Include the blue rainy window on the upper-left wall and the door on the upper-right wall.
Style/medium: Original painterly pre-rendered isometric area-map illustration, fixed 2:1 dimetric feeling, reduced detail and value-grouped readability, aged charcoal paper texture, noir rather than fantasy.
Composition/framing: Wide landscape image. Center the full room with generous dark margins for an overlay frame. Make doorways, floor boundaries, and major furniture instantly readable at phone scale. No external UI frame; artwork only.
Lighting/mood: Desk lamp is a restrained warm amber pool; window is a cool rain-blue accent; most of the office is low-key sepia and smoke-black.
Color palette: near-black charcoal, worn walnut, tobacco brown, tarnished brass, oxblood traces, rain blue, warm amber.
Materials/textures: dry-brushed paper grain, softened pre-rendered detail, scuffed wood floor, aged plaster, subtle vignette.
Constraints: Preserve the current office layout from Image 1. No people. No text or labels. No location pins or player markers; those will be drawn at runtime. No UI chrome. No transparency. No modern blueprint grid. No fantasy architecture.
Avoid: Baldur's Gate logos, franchise symbols, copied UI borders, medieval ornament, parchment scroll edges, bright saturated colors, photorealistic camera perspective, modern 3D gloss, pixel-art blocks, watermark.
```

## Runtime contract

- Source and runtime image: 1774×887 opaque sRGB PNG.
- Retained source: `ArtSource/Generated/UI/Map/map_detective_office_v01.png`.
- Former runtime derivative: `Resources/Art/UI/Map/map_detective_office_v01.png` (superseded by V2 and no longer bundled).
- SpriteKit owns the gunmetal/oxblood full-screen frame, title and location copy, close control, point-of-interest markers, and live player-position marker.
- The left action rail and compass-map icon are code-rendered so their hit area, hover state, and viewport anchoring remain deterministic.
