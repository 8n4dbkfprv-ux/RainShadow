# Sable Row terraces BG:EE V4

- Generated: 2026-08-16
- Mode: Imagine `image_edit` from the shipped SE terrace
- Intent: Lot-filling iso city blocks on the BG:EE camera at IE 6-adult height.
  Replaces the V2 512×640 cubes on Sable Row. Does **not** regenerate
  `city_terrace_sable_se` (style + Voss door lock).

## Style / camera lock (Image 1)

`RainShadow Shared/Resources/Art/Props/CityDistrict/V2/city_terrace_sable_se.png`

Authority for: iso volume (roof deck, two walls, chimneys), rain-wet brick/slate,
amber windows, empty door holes, late-1990s pre-rendered CRPG paint.

Image 2 when refreshing an existing hero: that hero’s current master (program
lock — tenement+shop, storefronts, rowhouses, canyon wall).

Do **not** use `city_sable_row_block_v02` or modular V2 prompts (retired 2:1 dimetric).

## Shared constraints

```text
Style/medium: richly pre-rendered late-1990s isometric PC CRPG environment art; painterly baked textures; modest native-resolution softness; no modern PBR gloss; match the RainShadow detective-office suite plate camera and materials.
Composition/framing: fixed Baldur's Gate: EE orthographic CRPG camera — elevation asin(0.75) ≈ 48.59°, azimuth 45°, ground axes at 36.87° from horizontal (slopes ±0.75), height foreshortening ≈ 0.661; no free pitch, yaw, or perspective FOV; verticals stay perfectly vertical; a circle on the ground is a 16:12 ellipse; fill a 16:9 landscape canvas; no horizon strip, no UI, no labels, no watermark, no characters, no readable text or logos.
Lighting/mood: cool blue rain-wet night; sparse warm amber windows; charcoal, wet slate, midnight blue, tarnished brass, restrained amber.
Scale: one continuous three-storey-plus-roof city block, about six standing adults tall; doorway openings a little over one adult high and empty (no door leaf); the painted volume fills a diamond lot — deep roof deck, both near walls, chimneys — not a postcard house on a tip.
Avoid: 2:1 dimetric / ~30° elevation, vanishing-point perspective, isolated cube sheds, baked door leaves, ground plate, cobbles, characters, cars, UI, PBR gloss.
```

## Kit

| Dest | Program | Door holes |
|---|---|---|
| `city_terrace_sable_sw` | Brick tenement + wooden shop, joined |
| tenement + shop empty |
| `city_terrace_sable_nw` | Awning storefront terrace | storefront empty |
| `city_terrace_sable_ne` | Long brick rowhouses | one rowhouse empty |
| `city_terrace_sable_south_w` | Near-side canyon: wood house + brick warehouse | none |
| `city_terrace_sable_south_e` | Near-side canyon: brick row | none |
| `city_district_sable_north_skyline` | Distant continuous brick row | none |
| `city_district_sable_corner_shops` | L-shaped corner shops turning 90° | none |

Install: 2240×840, 2.00 px/unit, `fit_to_aspect`, punch holes from
`CityDistrictLayout.SourceDoorAperture.terraceSable*` after measure.

## Runtime

World size 1120×420 (6.0 adults). Seated on the same `IsoLot` near-tips as V3.
SE terrace is not in this kit.
