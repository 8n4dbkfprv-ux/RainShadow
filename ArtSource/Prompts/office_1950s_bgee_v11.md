# Detective office V11 — 1950s registered rebuild

- Production date: 2026-08-20
- Namespace: `ArtSource/Generated/Office/BGEE1950sV11/`
- Status: six original ImageGen sources ingested, including the dimensional
  relief correction for both fixtures; deterministic V11 plate, masks, hover
  overlay, and door-state family generated and explicitly installed.

## Reference contract

The supplied `5ff32cc9-0ffc-4be5-9660-69aeac1b31e3.png` is a
**composition, painterly-style, and measurement reference only**. It is not a
source plate and is never cropped, traced, edited, or composited into a shipped
asset.

| Property | Locked value |
|---|---|
| Native image | 1613x975 RGB |
| SHA-256 | `6fbb06a6bf54e821bcdf7ae5e86aecc998ed594b4869c79dbc78bb41d770bd19` |
| Measured ground axes | +36.19 degrees / -35.75 degrees |
| Worst delta from BG:EE | 1.12 degrees |
| Pixel policy | zero supplied-reference pixels in V11 outputs |

The geometry manifest records fantasy window framing, fire, embers, glow,
orange illumination, and the black crop margins as contamination to exclude.
The redraw keeps only the compact composition and measured registrations.

## Uniform reference transform

Reference-space measurements map onto the 4096x2304 V11 plate with one scale:

```text
uniformScale    = 4096 / 1613 = 2.5393676379417234
sourceCropTop   = sourceCropBottom = 33.84375 px
targetX         = sourceX * uniformScale
targetY         = (sourceY - sourceCropTop) * uniformScale
```

Only the reference's black vertical margin is cropped to reach 16:9. X and Y
are never scaled independently. `qa_office_reference_lock_v11.py` currently
measures 0.0006 px worst registration error across the locked points.

## ImageGen source requests

Tool: built-in `image_gen.imagegen`. The local reference was supplied as
Image 1 for composition and painterly style only. Each call requested a
brand-new source image, not an edit. The resulting files were copied into the
V11 namespace and are the only generated pixels admitted by the deterministic
composer.

### 1. Floor material

> Generate a brand-new source texture; do not edit, crop, trace, or reproduce
> pixels from Image 1. Asset: seamless dark 1950s detective-office wooden floor
> material, flat orthographic material swatch, straight-on, no perspective.
> Narrow aged oak boards, muted umber and walnut, original hand-painted
> late-1990s isometric CRPG material craft, neutral diffuse light, no orange
> firelight. Tileable, no objects, text, or void; high-resolution raster for
> deterministic BG:EE +/-36.87-degree floor projection.

### 2. Wall material

> Generate a brand-new source texture; do not edit, crop, trace, or reproduce
> pixels from Image 1. Asset: seamless painted-plaster wall material, flat
> orthographic material swatch, straight-on, no perspective. Aged warm
> grey-beige plaster with a dark olive-grey undertone, hairline cracking,
> nicotine-era discoloration, and restrained mottling; original hand-painted
> late-1990s isometric CRPG material craft. Neutral diffuse light, no cast
> shadows, window shafts, or orange firelight. Tileable, no fixtures; source for
> deterministic BG:EE wall projection.

### 3. Steel casement and blinds

> Generate a brand-new source fixture; do not edit, crop, trace, or reproduce
> pixels from Image 1. Asset: one complete 1950s institutional steel casement
> office window with built-in Venetian blinds. Straight-on orthographic
> elevation, centered full fixture with generous transparent padding. Narrow
> dark-painted steel frame, two tall casement lights, slender muntins, old
> glass, compact cream-grey blinds partly lowered, and a period metal sill;
> aged paint, grime, and rain streaking. Cool dim daylight, no orange light.
> Genuinely transparent, with no wall, scenery, text, or fantasy ornament; RGBA
> source for deterministic wall projection, aperture, rain, and hover masks.

### 4. Cold fireplace

> Generate a brand-new source fixture; do not edit, crop, trace, or reproduce
> pixels from Image 1. Asset: compact cold 1950s detective-office fireplace and
> hearth. Straight-on orthographic elevation. Restrained civic-office dark
> slate and worn pale stone, squared mantel, small empty blackened firebox, old
> iron grate, soot, and shallow hearth. Completely extinguished: no burning
> logs, flame, ember, smoke, glow, warm spill, or orange pixels. Original
> hand-painted late-1990s isometric CRPG craft under neutral dim ambient light.
> Transparent, no wall, props, or fantasy ornament; RGBA source for
> deterministic projection and separately registered collision and cover.

ImageGen returned the two fixture requests as RGB images with a painted
checkerboard rather than real alpha. This is recorded rather than hidden:
`ingest_office_1950s_sources_v11.py` deterministically keys those backgrounds,
writes normalized RGBA crops, and records their crop and coverage in
`office_v11_source_manifest.json`.

### Dimensional relief correction

The first fixture pair still read as surface decoration after projection. Two
replacement ImageGen requests therefore made depth an explicit source property:

> Create a brand-new dimensional 1950s institutional steel casement window
> relief, using Image 1 only as a composition/style reference and reproducing
> none of its pixels. Show a genuinely recessed opening with visible plaster
> reveal, projecting sill, steel frame thickness, old glass, and Venetian
> blinds. Paint it for the NW office wall: vertical jambs and a −36.87-degree
> wall course, neutral cool light, no wall field, lettering, fantasy ornament,
> or orange light.

> Create a brand-new dimensional cold 1950s office fireplace relief, using
> Image 1 only as a composition/style reference and reproducing none of its
> pixels. Show a projecting mantel with visible top and return planes, deep
> sooty empty firebox, substantial jambs, iron grate, brass rail, and a shallow
> hearth projecting onto the floor. Paint it for the NE wall: vertical jambs
> and a +36.87-degree wall course. No flame, logs, embers, smoke, glow, warm
> spill, orange light, wall field, lettering, or fantasy ornament.

The deterministic ingester keys the returned RGB checker fields and freezes
`steel_window_relief_fixture_v11.png` and
`cold_fireplace_relief_fixture_v11.png`. The composer then corrects only the
top-envelope course with a vertical affine shear and scales uniformly; it does
not flatten the relief into the wall aperture.

## Frozen source identities

| Role | ImageGen source | Mode / size | SHA-256 | Deterministic normalized fixture |
|---|---|---:|---|---|
| Floor | `floor_material_source_v11.png` | RGB 1254x1254 | `fe2bb2ac7d35d305ae7a58c1ea1ab504aa2ed6845e6d40d45a9ede6d8a502ef4` | n/a |
| Wall | `wall_material_source_v11.png` | RGB 1254x1254 | `467307c46e14a7862e4169f8e59ce378e801a7329f3d1295e2e5c3ebc92388c6` | n/a |
| Window | `steel_window_source_v11.png` | RGB 1254x1254 | `1af2c4b039341137f5dd2bd72ef558227d7e758995db56d68027d82c231dbdab` | `steel_window_fixture_v11.png`, RGBA 775x908, `5deb89d6911bf78e1954d3b9ead4ecb97130abdc9b0d7d32f85ec8ea86acc201` |
| Fireplace | `cold_fireplace_source_v11.png` | RGB 1254x1254 | `8e8061591a101c623cc1acae605964d2194b5d89c1c5e32540191c7ace5dc9da` | `cold_fireplace_fixture_v11.png`, RGBA 790x706, `b4c76775875e39bae3bc9adb9a234730c9086cd914ee1ca09278d7be44fcbcdf` |
| Window relief | `steel_window_relief_source_v11.png` | RGB 1672x941 | `bb185b972925e93ea04fefee463ae5f4b211c50f47ff1c80205c11d5f62ecf7b` | `steel_window_relief_fixture_v11.png`, RGBA 531x836, `3184b93514e37ea29c28f8243fdddb02b477427eb588f085eae0b8d7412a5187` |
| Fireplace relief | `cold_fireplace_relief_source_v11.png` | RGB 1672x941 | `fab24ab1b465e3e64bfa1d21fefe7d6734e386b6e064a3a2441b69279ed829bb` | `cold_fireplace_relief_fixture_v11.png`, RGBA 700x856, `33cfab38fafacbed3a4676a69fc70faa51b944c320df0b884bf71c991adaaaea` |

## Registered output contract

- The 4096x2304 RGB plate bakes the two fixed steel/blind windows and the cold
  fireplace. It contains no door leaf.
- `office_window_glass_mask_v11.png` registers rain to all eight glass panes
  across both windows. `office_window_near_hover_overlay_v11.png` registers
  hover only to the camera-nearer interactive aperture.
- The fireplace's pixels, floor obstacle, and cover polygon share
  `office_v11_geometry.json`; it has no hotspot, flame, ember, glow, or sound.
- The 512x320 door states remain independent registered visuals. All share the
  image hinge `(488, 18)`, SpriteKit anchor `(0.953125, 0.94375)`, material,
  angle, and thickness. Mid/open lengths are 81.5%/63.8% of closed.
- Background pixels, door states, interaction regions, wall/cover polygons, and
  the 16x12 search map are separate systems registered through one geometry
  manifest, following the behavioral separation of TIS, WED, ARE, and door
  state coordination without emitting literal Infinity Engine formats.

## Verified staging results

`qa_office_reference_lock_v11.py` currently reports `ALL_PASS=True`:

- plate 4096x2304 RGB; pure-black exterior;
- 2.5316 art pixels per world unit;
- measured projection +36.70/-36.97 degrees, 0.17-degree worst delta;
- deterministic regeneration hash identical;
- two baked casements; glass mask 100% on both, hover 100% on near only;
- cold fireplace has zero hot/orange pixels;
- no baked door pixels;
- door endpoint, bbox, angle, length, thickness, hinge, and hover-alpha gates all
  pass for closed, mid, and open.

The explicit 17-file allowlist has been installed. Exported-area parity,
registered-resource tests, macOS build, and shipping-scene capture review pass;
the capture is stored under `BGEE1950sV11/Captures/`.
