# Office suite plate — BG:EE human-scale proportion lock (V7)

- Generated: 2026-08-15
- Mode: plaster-band compress of the on-lock V5 master
- Supersedes: `office_suite_plate_bgee_v05.md` (camera kept; warehouse height rejected)
- Projection lock: `Documentation/InfinityEngineGroundProjection.md` /
  `ArtSource/Processing/ie_projection.py`
- Process: `ArtSource/Processing/install_office_bgee_v07.py`

## Why V5 was rejected on height

Measured at the exterior door column of the installed V5 plate:

| quantity | measured |
|---|---|
| wall face at the door column | 369 px |
| door clear opening | 198 px |
| door / wall | 54% |
| implied ceiling | 3.78 m |
| blank plaster above the door head | 171 px = 1.75 m — a whole extra adult |

The ground camera was fine (3.81° PASS). The wall:door ratio was a warehouse.

## What V7 does

Re-places the V5 1536×1024 master the same way (`SUITE_PLATE_SCALE=0.60`,
uniform contain — no 16:9 crop, no anisotropic stretch) and compresses only
the plaster band above a fixed lintel plane. Floorboards, wainscot, door
openings, and wall shoes do not move.

Target at that same door column:

| quantity | target |
|---|---|
| door clear opening | 198 px (unchanged) |
| wall face | 271 px |
| door / wall | 73% |
| plaster above the lintel | 73 px ≈ one head |
| implied ceiling | ~2.8 m if the door is ~2.05 m |

New generated plates that asked for short walls (v07a/b, v08a/b) copied the
cathedral height from the V5 reference and missed the 4° ground lock
(4.70°–9.11°). Do not prefer those.

## After the lock lands

1. Keep `REAR` / `AXIS_*` (floor unchanged). Set `WALL_FACE_H` / `BAKED_DOORWAY_H`
   from the door column.
2. `python3 ArtSource/Processing/office_layout_plan.py` then `--write` if green.
3. Update `OfficeInteriorScale.paintedRoomSourceRect` from the new opaque bbox.
4. Grade the installed 4096×2304 plate with `qa_plate_projection.py`.
