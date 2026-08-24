# City ward 1950s V1 — Infinity Engine outdoor lock

- Generated: 2026-08-24
- Mode: built-in Image Generator + deterministic Python compose
- Intent: Rebuild Act I Harborpoint districts as Infinity Engine outdoor AREs
  set in a rainy American port city, 1952–1956. Camera and search-map contract
  stay Baldur's Gate: EE. Period is 1950s, not medieval, not cyberpunk.

Supersedes the V3 city perspective lock for *content*. The camera lock is
unchanged: `city_perspective_lock_v03.md` + `ie_projection.BGEE`.

## Projection lock (mandatory — paste into every generate call)

Canonical constants: `ArtSource/Processing/ie_projection.py` (`BGEE`).

| Parameter | Value |
|---|---|
| Elevation | `asin(0.75)` ≈ 48.59° |
| Azimuth | 45° |
| Ground axes on screen | 36.87° from horizontal (slopes **exactly ±0.75**) |
| Ground foreshortening | 0.750 |
| Height foreshortening | ≈ 0.6614 |
| Ground circle | 16:12 ellipse |
| Nav diamond | 128×96 |
| Projection | Orthographic — **no vanishing point, no horizon** |
| Verticals | Stay vertical |

Pass a **geometric seed jig** (`ArtSource/Generated/CityDistrict/V2/WardRebuild/jigs/*.png`)
as `reference_image_paths`. The jig already has the cobble lattice and block
volumes on ±0.75. Paint over it. Do not invent a second camera.

## World / plate contract

| | Value |
|---|---|
| World | **4096 × 3072** world units (4:3, BG 80×60-tile proportion) |
| Plate | **8192 × 6144** px (2.00 art px / world unit) |
| Search / light / height | **256 × 256** (`ceil(4096/16) × ceil(3072/12)`) |
| Aspect of a lot seed | 1:1 crop of one iso diamond |

Do not anisotropically resize. `fit_to_aspect` then uniform scale only.

## 1950s Harborpoint — what to paint

Rain-slick **asphalt** with granite kerbs and faded crosswalks, not medieval
cobble as the only surface. Brick tenements and walk-up shopfronts with
**iron fire escapes**, canvas awnings that are **solid colour** (no stripes —
stripes pollute the axis estimator), neon cocktail / pawn / diner signs,
tungsten streetlamps, parked **1950s sedans** (not modern, not fantasy
carriages), overhead tram wires, harbor haze, puddles that mirror neon.

Palette: wet charcoal, oxblood brick, tarnished brass, restrained amber
windows, cool rain fill. Night-pinned.

Human scale: doors ≈ 1.15–1.20 standing adults. Cars near adult roof height.
Three-storey terraces ≈ 6 adults. Not monumental.

## Hard avoid

- Aerial panorama, top-down map, vanishing-point perspective
- 2:1 dimetric / ~26–30° "isometric" (the generator's prior — the jig fights it)
- Striped awnings, zebra-stripe shopfronts, high-contrast chevrons on roofs
- People, UI, labels, watermarks, readable logos of real brands
- Cyberpunk purple neon, modern glass towers, SUVs, LED billboards
- Baking open door leaves into the plate (leaves are separate sprites)
- Anisotropic stretch, letterbox bars, a horizon strip

## Generation workflow

1. Render the geometric seed jig (`make_city_ward_seed_jigs.py`).
2. Generate the painted master over that jig (this prompt).
3. Affine-correct with `generate_city_ward_rebuild_v01.py` (structure tensor
   → one vertical-preserving affine onto ±0.75, office V20 method).
4. Gate the master **and** the seated composite:
   `qa_plate_projection.py` ≤ 1.5°, `qa_plate_density.py` ≥ 2.0 px/unit,
   lot spill check. Best-of-N. Refuse off-lock art.

## District notes

| Slug | 1950s read |
|---|---|
| `sable_row` | Lower ward tenements, Voss's stoop, diner neon, fire escapes |
| `wharf_ladder` | Shipping sheds, rope, wet timber, harbor cranes far |
| `riverside` | Iron stairs, river sheen, brick warehouses |
| `harborpoint_pd` | Limestone precinct, globe lamps, radio mast |
| `lila_street` | Boarding houses, laundry lines, corner grocer |
| `civic_records` | Granite annex, civic steps, bronze doors (closed) |
