# City perspective lock V3

- Generated: 2026-08-15
- Mode: built-in Image Generator only
- Intent: Freeze the Act I city-district camera, materials, and human scale so every Harborpoint outdoor plate matches the Baldur's Gate: EE orthographic projection used by the detective-office suite.
- Supersedes: `city_perspective_lock_v02.md` (retired 2:1 dimetric / ~30° elevation)

## Projection lock (mandatory)

Canonical constants: `ArtSource/Processing/ie_projection.py` and
`Documentation/InfinityEngineGroundProjection.md`.

| Parameter | Value |
|---|---|
| Elevation | `asin(0.75)` ≈ 48.59° |
| Azimuth | 45° |
| Ground axes on screen | 36.87° from horizontal (slopes ±0.75) |
| Ground foreshortening | 0.750 |
| Height foreshortening | ≈ 0.6614 |
| Nav diamond | 128×96 |
| Ground circle | 16:12 ellipse |
| Projection | Orthographic — no vanishing point, no horizon; verticals stay vertical |

## Mandatory reference inputs

1. **Image 1 — Office suite plate** (`RainShadow Shared/Resources/Art/Areas/DetectiveOffice/office_suite_plate.png`)  
   Authoritative for: BG:EE orthographic projection (after the suite is regenerated under this lock), late-1990s pre-rendered CRPG material language, painterly baked textures, cool rain / warm lamp value range, no modern PBR gloss.
2. **Image 2 — Office shell** (`office_shell_base.png`) when a cleaner empty-architecture read helps registration.  
   Authoritative for: orthographic pitch, wall/floor diamond feel (axes at ±0.75), pure-black exterior silhouette treatment when a cutaway edge is needed.
3. **Image 3 — Projection diagram** (`Documentation/InfinityEngineGroundProjection.png`)  
   Authoritative for: camera elevation/azimuth, 16:12 ground ellipse, vertical uprights.

Do **not** copy office furniture, interior partition layout, or room contents into city plates. Use the office only for camera + material lock.

## Shared constraints (paste into every city V3 prompt)

```text
Style/medium: richly pre-rendered late-1990s isometric PC CRPG environment art; painterly baked textures; modest native-resolution softness; no modern PBR gloss; match the RainShadow detective-office suite plate camera and materials.
Composition/framing: fixed Baldur's Gate: EE orthographic CRPG camera — elevation asin(0.75) ≈ 48.59°, azimuth 45°, ground axes at 36.87° from horizontal (slopes ±0.75), height foreshortening ≈ 0.661; no free pitch, yaw, or perspective FOV; verticals stay perfectly vertical; a circle on the ground is a 16:12 ellipse; fill a 16:9 landscape canvas; no horizon strip, no UI, no labels, no watermark, no characters, no readable text or logos.
Lighting/mood: cool blue rain-wet night; sparse warm amber windows and street lamps; charcoal, wet slate, midnight blue, tarnished brass, restrained amber.
Scale: compact human-scale CRPG density — doors a little over one adult body height (the runtime holds openings at `targetDoorBodyMultiple` = 1.15× the drawn adult); cars near adult height; multi-story facades several body-heights tall but not monumental set dressing; leave clear wet cobble / pavement navigation lanes.
Avoid: aerial panorama, top-down map, modern photoreal city, purple neon cyberpunk, baked fog-of-war haze over the playable center, graybox placeholders, franchise copies, people, vehicles dominating the frame, 2:1 dimetric / ~30° elevation (retired), vanishing-point perspective.
```

## Runtime targets

| Class | Master | Runtime | Notes |
|---|---|---|---|
| District block (map) | Generator 16:9 | 2048×1152 | Area-map plate; buildings may be baked |
| District ground underlay | Generator 16:9 | **4096×2304** | Streets/pavement only. 2048×1152 is **superseded** — at one plate pixel per world unit the ground is magnified 3.6× at play zoom while every sprite on it is native. See `city_ground_density_v04.md`; gate with `qa_plate_density.py` |
| Landmark / building modules | Chroma sheet or solo | 512×512–768 canvases | Depth-sorted props; empty doorway apertures only (no baked door leaves) |
| Outdoor door leaves | Chroma solo/sheet | 256×384-class crops | Separate `city_door_*` props; see `city_door_leaves_v01.md` |
| Street props | Chroma sheet | 512×341-class crops | Shared across districts |

## Districts in this lock

`sableRow`, `wharfLadder`, `riverside`, `harborpointPD`, `lilaStreet`, `civicRecords`

Blue Room / Wardour Street is intentionally excluded until earned.

## Regeneration note

District masters painted under V2 (2:1 dimetric) must be regenerated under V3 before
`process_city_districts_v02.py` is re-run. After regen: re-measure door apertures,
re-derive street-side portal approaches (~120–150 units out from
`nearestWalkablePoint`, unrounded), and flood-fill every spawn on the runtime
search map.
