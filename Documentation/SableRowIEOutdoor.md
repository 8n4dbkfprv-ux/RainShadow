# Sable Row — Infinity Engine outdoor redo (v01)

Historical pilot notes, followed by the current V15 authority. All six Act I
districts use the literal 80×60 paged-area contract documented in
`InfinityEngineCityAreas.md`; Sable Row is the first district migrated to a
single full-frame monolithic painting.

## Current V15 authority

- One 12800×9600 painting:
  `ArtSource/Generated/CityDistrict/V2/IEMonolithV15/masters/sable_row.png`.
- The Voss apartment, streets, roofs, parked cars, lights and weathered 1950s
  architecture are all in that image. The 25 runtime pages are crop-only
  storage; `visualSprites` and general area `props` remain empty.
- Voss's baked warm stoop is registered at `(2600, 325)` with exact approach
  `(2680, 258)`. Its runtime aperture is 211 px / 84.4 world units = 1.20×
  adult. Closed/open path and fog states are gameplay records, not building art
  layered on the plate.
- Build/install: `build_city_ie_monolith_v06.py sable_row --stage
  ArtSource/Generated/CityDistrict/V2/IEMonolithV15 --install`.
- Master origin and neural restoration provenance:
  `IEMonolithV15/masters/sable_row.superres.json`. The final reconstruction
  retains the accepted source geometry at equal weight with neural detail.
- The V15 master is 12800×9600 at 2.5 art px/world unit; its 25 crop-only
  runtime pages are 2560×1920 each.

## Contract

| Piece | Behaviour |
|---|---|
| Day plate | `city_sable_row_day_v01.pages.json` — 25 pages covering 5120×3840 world units |
| Night | `city_sable_row_night_placeholder_v01.pages.json` via `nightPlateTextureName` (25 pages; Extended Night swap, not a blue multiply) |
| Roofs | Painted into the plate; search map keeps type **13** |
| Closed street doors | Painted into the plate (no `city_door_*` overlays). ARE door + region polygon for click / Tab outline. Fog-only shroud outdoors (`outdoorDoorShroud`). |
| Open door | Clears the door stamp → LOS through the opening. No indoor room flood. |
| Cover | `wallPolygons` on each lattice diamond (`AreaCoverAuthoring`) |
| Rain | `RainSystem` overlay at reduced density; default actor grade is `cityDay` |

## Bake

```bash
python3 ArtSource/Processing/bake_sable_row_ie_outdoor_v01.py
```

The bake grades whatever `city_sable_row_block_v02.png` currently is, so that
file must be the **IEAreaV04** build before you bake. Rebuild it first:

```bash
python3 ArtSource/Processing/build_city_ie_area_v04.py sable_row --install
```

The bake now re-runs `qa_area_door_scale.py --measure --write-measurements`
after grading, and exits non-zero if any painted door leaves the 1.05–1.35×
band. See "The day grade breaks its own approval" below for why.

### Portal.office stamp

The f266886b human-scale portal take was unseated: the IG crop was ~80×
sharper than the soft plate neighbourhood and read as a lit rectangle on
Voss's stoop. Restore + rebake:

```bash
python3 ArtSource/Processing/unseat_sable_row_portal_office_v01.py
```

**This script reverts the ward's architecture, not just the stamp.** It restores
from the V02 `UnifiedPlates` lineage (`city_sable_row_area_v02.pre_portal.png`),
which predates IEAreaV04. Running it at `c8f94435` silently put Sable Row back
on pre-V04 architecture: the painted door measured **1.55× adult** against the
other five wards' 1.16–1.17×, so every building, window and kerb in the starting
district read roughly twice human scale. Always re-run
`build_city_ie_area_v04.py sable_row --install` after it, or do not run it at
all — V04 paints its own aperture and does not carry the bad stamp.

### The day grade breaks its own approval

`DoorScale/apertures.json` binds each door approval to the SHA-256 of the
installed plate, and this bake *grades* the plate after V04 measured it. The
recorded hash therefore described the ungraded V04 file, and
`qa_area_door_scale.py` reported Sable Row **STALE** forever — a permanently
red row nobody reads, which is exactly how a 1.55× ward reached play. The bake
re-measures against the shipped plate so the approval always describes the
pixels the game draws.

Both plate gates read the plate names out of the area records now, so Sable
Row's day/night pair is graded rather than the `block_v02` nobody draws:

```bash
python3 ArtSource/Processing/qa_plate_projection.py --shipped
python3 ArtSource/Processing/qa_plate_density.py
```

## Xcode

1. Open `RainShadow.xcodeproj` on macOS.
2. Run with `RAINSHADOW_START_SCENE=city` (optional `RAINSHADOW_START_DISTRICT=sable_row`).
3. Tab toggles door / travel outlines. Walk to Voss's stoop (`portal.office`) to exercise open + travel.
4. Suite: `swift test --scratch-path /tmp/RainShadowSwiftPM --filter SableRowIEOutdoor`

## Deferred

- Full Extended Night painting (placeholder only)
- Remaining five wards
- Night-scheduled ambient playback tied to the plate swap
