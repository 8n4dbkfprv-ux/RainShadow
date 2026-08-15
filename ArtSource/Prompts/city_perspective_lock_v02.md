# City perspective lock V2

> **Retired.** Superseded by [`city_perspective_lock_v03.md`](city_perspective_lock_v03.md)
> (Baldur's Gate: EE orthographic projection — elevation asin(0.75), ground axes
> ±0.75, diamond 128×96). Keep this file only as the historical V2 brief for
> masters painted before the projection adoption.

- Generated: 2026-07-31
- Mode: built-in Image Generator only
- Intent: Freeze the Act I city-district camera, materials, and human scale so every Harborpoint outdoor plate matches the shipped detective-office suite.

## Mandatory reference inputs

1. **Image 1 — Office suite plate** (`RainShadow Shared/Resources/Art/Areas/DetectiveOffice/office_suite_plate.png`)  
   Authoritative for: fixed 2:1 dimetric projection, late-1990s pre-rendered CRPG material language, painterly baked textures, cool rain / warm lamp value range, no modern PBR gloss.
2. **Image 2 — Office shell** (`office_shell_base.png`) when a cleaner empty-architecture read helps registration.  
   Authoritative for: orthographic dimetric pitch, wall/floor diamond feel, pure-black exterior silhouette treatment when a cutaway edge is needed.

Do **not** copy office furniture, interior partition layout, or room contents into city plates. Use the office only for camera + material lock.

## Shared constraints (paste into every city V2 prompt)

```text
Style/medium: richly pre-rendered late-1990s isometric PC CRPG environment art; painterly baked textures; modest native-resolution softness; no modern PBR gloss; match the RainShadow detective-office suite plate camera and materials.
Composition/framing: fixed 2:1 dimetric / orthographic CRPG camera — same elevated three-quarter view as the office suite plate; no free pitch, yaw, or perspective FOV; fill a 16:9 landscape canvas; no horizon strip, no UI, no labels, no watermark, no characters, no readable text or logos.
Lighting/mood: cool blue rain-wet night; sparse warm amber windows and street lamps; charcoal, wet slate, midnight blue, tarnished brass, restrained amber.
Scale: compact human-scale CRPG density — doors a little over one adult body height (the runtime holds openings at `targetDoorBodyMultiple` = 1.15× the drawn adult); cars near adult height; multi-story facades several body-heights tall but not monumental set dressing; leave clear wet cobble / pavement navigation lanes.
Avoid: aerial panorama, top-down map, modern photoreal city, purple neon cyberpunk, baked fog-of-war haze over the playable center, graybox placeholders, franchise copies, people, vehicles dominating the frame.
```

## Runtime targets

| Class | Master | Runtime | Notes |
|---|---|---|---|
| District block (map) | Generator 16:9 | 2048×1152 | Area-map plate; buildings may be baked |
| District ground underlay | Generator 16:9 | 2048×1152 | Streets/pavement only; play underlay ships 1:1 (`environmentScale = 1`), so one plate pixel is one world unit |
| Landmark / building modules | Chroma sheet or solo | 512×512–768 canvases | Depth-sorted props; empty doorway apertures only (no baked door leaves) |
| Outdoor door leaves | Chroma solo/sheet | 256×384-class crops | Separate `city_door_*` props; see `city_door_leaves_v01.md` |
| Street props | Chroma sheet | 512×341-class crops | Shared across districts |

## Districts in this lock

`sableRow`, `wharfLadder`, `riverside`, `harborpointPD`, `lilaStreet`, `civicRecords`

Blue Room / Wardour Street is intentionally excluded until earned.
