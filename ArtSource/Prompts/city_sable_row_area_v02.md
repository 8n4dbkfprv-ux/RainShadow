# Sable Row area plate — V2 (full Infinity Engine block)

- Generated: 2026-08-16
- Mode: Imagine / Cursor image-edit of finished-block geom seeds + whole-area jig
- Intent: Paint every surveyed diamond as a **finished terrace block** so the
  stitched flatten reads as one Infinity Engine outdoor ARE — not modular
  L-strips on empty brown lots.
- Supersedes: `city_sable_lot_masters_v05.md` (L-terrace / sparse pad)
- Camera lock: `ArtSource/Prompts/city_perspective_lock_v03.md` (unchanged)
- Layout lock: surveyed 12 diamonds in `sable_iso_lots.json` / `CityBlockGrid`
  (do **not** invent a new street plan)

## Why

Sable Row already has IE world size (4096×2304) and a WED split
(streets plate + lot crops + door leaves). The painting still looked modular:
empty diamond pads, shallow L-terraces, edge strips without architecture.

A full IE area plate is **one painting** shot through one orthographic camera.
Generators cap at 1024, so we author twelve registered tiles on the existing
lattice and stitch. Play keeps the WED split; the flatten is the IE plate.

## The ask, in one line

**Repaint each lot as a finished block with footprint on slopes ±0.75, street
terraces on both near kerbs, and an enclosed courtyard — no raw empty pad.**

## Reference inputs, in order

1. That lot’s geom seed under
   `ArtSource/Generated/CityDistrict/V2/SableRow/LotMasters/GeomSeeds/<lot>_geom.png`
   — finished-block volume on the lock (~0.13°). Authoritative for camera and
   massing. Door stoops are stamped at runtime anchors.
2. `LotMasters/AreaJig/sable_area_jig_v02_preview.png` — whole-district neighbour
   context so shared walls and lighting read as one painting.
3. `ArtSource/Generated/BGEEProjectionCandidates/city_sable_row_block_v03_candidate.png`
   — craft / night lighting / packed tenement style only. One junction at 1536;
   not the layout.
4. `Documentation/InfinityEngineGroundProjection.png` — elevation, 16:12 ellipse.
5. `office_suite_plate.png` — materials only. Not for camera or layout.

**Do not pass** current `city_sable_lot_*` crops, terrace sprites, or V5 masters.
They hold the sparse / off-lock prior.

## Finished block (not a warehouse deck)

| | value |
|---|---|
| Footprint near edges | slopes **±0.75** (±36.87°) |
| Pad half-width : half-depth | **584 : 438 = 1.333** |
| Frontage (heroes) | **1168** world units (full pad) |
| Wings | deep street terraces on both near kerbs |
| Interior | enclosed courtyard (painted courtyard floor + far wall) — not empty `ground_v02` |
| Roof | pitched lids on terraces; **not** a helipad deck over the whole diamond |
| Verticals | perfectly vertical |
| Doors | only the dark openings the jig marks; leave empty (runtime leaves) |

No high-contrast striped awnings, banners, or signage — they outvote ground
axes in `qa_plate_projection`.

## Lots (generate in this order)

| Order | Lot | Notes |
|---|---|---|
| 1 | `harborWest` | Harbor Street terrace; tenement + shop doors |
| 2 | `harborVoss` | Voss stoop + gatehouse + garage — paint openings where jig marks; stoop wall is **not** locked to v01 anymore |
| 3 | `southWest` / `southEast` | Camera-near south row |
| 4 | `upperWest` / `upperEast` | Upper terrace |
| 5 | `skylineWest` / `skylineEast` | Far skyline strips |
| 6 | `edge_*` | Plate-edge clips |

## Resolution

- Native painted frontage ≥ **2336 px** for heroes (1168 × 2.00), or run
  `composite_sable_lot_density.py --frontage 1168` after a 1024 return.
- `detail` ≥ 1.10; never naked Lanczos.
- PNG; pack canvas is 3200.

## Acceptance

```bash
python3 ArtSource/Processing/qa_plate_projection.py <master.png> --tolerance 2.75
python3 ArtSource/Processing/install_sable_lot_masters.py
python3 ArtSource/Processing/qa_sable_area_bake.py
```

Gates (fatal, shared tolerance 2.75°): master + seated camera, detail ≥ 1.10,
px/unit ≥ 2.00, spill ≤ 2%, doors landed/total.

## Pipeline

```bash
swift test --scratch-path /tmp/RainShadowSwiftPM --filter CityLayoutDump
python3 ArtSource/Processing/bake_sable_area_plate.py          # diamond AABB crops
python3 ArtSource/Processing/make_sable_lot_master_seeds.py    # finished blocks + area jig
# generate / density-composite masters → LotMasters/*_master.png + masters.json
python3 ArtSource/Processing/install_sable_lot_masters.py
python3 ArtSource/Processing/qa_sable_area_bake.py
```

Use `GeomSeeds/` (on-lock) for Cursor. Use `GeomSeeds/Precomp/` only for Imagine.
