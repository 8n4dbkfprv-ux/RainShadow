# Riverside district — BG:EE camera (V3)

- Generated: 2026-08-15
- Mode: Cursor Image Generator
- Projection lock: `city_perspective_lock_v03.md` / `ie_projection.py` `BGEE`
- Process: chroma-key + `fit_to_aspect` / `fit_canvas` via
  `process_city_districts_v02.py` helpers (riverside-only; do not run `main()`)
- After install: `qa_plate_projection.py`, `measure_city_door_apertures.py`,
  re-derive street-side portal approaches if the aperture moves

## Intent

Replace the shipped Riverside ground + four modular landmarks + two door leaves
so the playable district matches the Baldur's Gate: EE orthographic camera
already used by SearchMap (16×12) and locomotion (0.75). Keep the **current
embankment layout** so authored nav (obstacles, spawns, portal approach) still
lands on walkable cobble.

Do **not** flip `ie_projection.ACTIVE`. Office and the other five districts stay
on the legacy camera until their props are regenerated.

## Shared camera lock (paste into every call)

```text
CRITICAL CAMERA: Baldur's Gate: EE orthographic projection — elevation asin(0.75) ≈ 48.59°, azimuth 45°, ground axes at 36.87° from horizontal (slopes ±0.75), height foreshortening ≈ 0.661, verticals perfectly vertical, no vanishing point, no horizon; a circle on the ground is a 16:12 ellipse. Do not use retired 2:1 dimetric / ~30° elevation. Style: late-1990s pre-rendered Infinity Engine–era painterly CRPG, soft native raster, no PBR gloss. Cool rain-blue night, sparse warm amber. No people, no UI, no text, no watermark, no logos.
```

## Ground underlay (16:9)

Empty playable plate. Preserve the shipped riverside layout: wet cobble walkway
occupies the upper-right two-thirds; dark river water the lower-left third;
a thick stone masonry quay wall runs diagonally between them. Pools of amber
lamp light on wet stone. Remove stairs, buildings, railings, lamps, posts,
characters, props — ground and water only.

## Landmark solos (3:4, chroma `#00FF00`)

Isolated props, generous green clearance, empty doorway apertures (no baked
leaf). Ground-contact diamond must read 36.87°.

1. `iron_stairs` — rusted iron stair flight up to a stone doorway frame; empty
   black aperture; small cobble base.
2. `river_watch` — small weathered timber watch booth on a stone plinth; empty
   doorway on the camera-near-right face; warm window on the left face.
3. `rail_lamp` — low mossy stone quay wall segment with three iron posts, one
   a glowing lantern, and a rope-wrapped timber piling. No door.
4. `abutment` — short thick mossy stone wall chunk with a rope-wrapped timber
   bollard. No door.

## Door leaves (3:4, chroma `#00FF00`)

1. `door_iron_stairs` — heavy riveted metal-and-wood industrial door, NE face.
2. `door_river_watch` — weathered timber door with a 2×2 frosted-glass upper
   pane, NE face.
