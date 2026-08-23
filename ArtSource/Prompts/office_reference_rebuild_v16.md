# Detective office V16 — BG-scale interior envelope

- Production date: 2026-08-23
- Goal: each indoor enclosure fits Infinity Engine visual range **14 search cells** (224 world-unit radius, 448 diameter) at `environment = 0.395`, without shrinking Voss or the 9% camera.
- Image tool: `image_edit` from the accepted V15 empty envelope plus a compact ±0.75 floor guide

## Why V16 exists

V15 matched AR0809's long room. That diamond's world diagonal is ~874 units, so stat #262 cannot cover it and indoor fog needed a room-flood exception. BG:EE inns (see `Documentation/Captures/FogBGEEIndoor/`) are compact diamonds on black. V16 shrinks the painted envelope to that contract.

Do not install over V15 until projection, door, windows, prop packing and the search map all pass. `fillsEnclosedRooms` stays on the office until that install.

## Visual references

- Materials / camera: `ArtSource/Generated/Office/BGEEReferenceV15/office_room_envelope_imagegen_v15e.png`
- Size stencil: `ArtSource/Generated/Office/BGEEReferenceV16/office_bgee_plane_guide_v16.png` (construction lines only)
- Fog contract: `Documentation/Captures/FogBGEEIndoor/NOTES.md`

## ImageGen lineage

| File | Role | Projection (`qa_plate_projection.py`) |
|---|---|---|
| `v16_partitioned` | two-room experiment | not shipped |
| `v16_compact_unframed` | single-room experiment | not shipped |
| `v16_guide_bleed` | copied guide colours onto walls | reject |
| `v16a` | compact brick room | FAIL legacy ~26.6° |
| `v16b` | compact brick room, camera preserved | PASS +39.05/−34.66, worst 2.21° |

Frozen source: `office_room_envelope_imagegen_v16b.png` (copied as `office_room_envelope_imagegen_raw_v16.png`).

## Accepted edit request

Keep Image 1's exact camera and floorboard slant. Image 2 is only a size stencil. Shrink Image 1's empty brick office to Image 2's compact footprint in extra black void. Preserve brick, two barred left windows, right-wall fireplace, sconces, vertical corners. Empty architecture only.

## Remaining before install

1. Register `v16b` onto 4096×2304 with uniform scale chosen so the floor's world diagonal ≤ 448 (`generate_office_reference_rebuild_v16.py`).
2. Fit `office_room_plan` target planes to the new silhouette.
3. Compact live/baked props onto the smaller floor (body-locked sizes stay).
4. Rebake plate, search map, map art.
5. `qa_office_visual_range.py` must PASS; then drop `fillsEnclosedRooms` on the office.
