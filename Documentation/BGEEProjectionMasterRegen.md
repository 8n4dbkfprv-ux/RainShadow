# Area master regeneration — BG:EE projection

Pipeline math, docs, grayboxes, UI rings and `OfficeNavigationLayout.swift` speak
the Baldur's Gate: EE camera (`ArtSource/Processing/ie_projection.py`). This page
tracks the **painted masters**, which are the only place the projection is
actually visible to a player.

## Measuring instead of asserting

"Follows BG:EE" is measurable. Under the IE camera every ground line lands on a
screen slope of ±0.75 (±36.87°) and every upright stays vertical.
`ArtSource/Processing/qa_plate_projection.py` recovers those angles from a plate
with a Gaussian-smoothed structure tensor and grades them against the lock.

```bash
python3 ArtSource/Processing/qa_plate_projection.py --shipped
python3 ArtSource/Processing/qa_plate_projection.py <plate.png> --overlay-dir /tmp/proof
```

Instrument calibration on synthetic grids of known angle: worst error **0.67°**
over slopes 0.25–1.0, and **0.13°** on a full BG:EE lattice. Tolerance for
painterly art is 4.0°, which is comfortably tighter than the 10.3° gap between
the BG:EE lock and the retired 2:1 dimetric camera, so the two cannot be confused.

> A first attempt using a plain 3×3 Sobel was **wrong**: hard-rasterised lines
> alias and snap orientations to 0/26.6/45°. It reported a true 36.87° grid as
> 45°. Always calibrate this tool against a synthetic grid before trusting a
> verdict from it.

## Shipped plates today — all off the lock

| Plate | Measured axes | Worst delta |
|---|---|---|
| `office_suite_plate` | +23.20 / −23.46 | 13.67° |
| `office_shell_base` | +22.80 / −24.35 | 14.07° |
| `city_sable_row_block` | +22.65 / −28.46 | 14.22° |
| `city_wharf_ladder_block` | +32.70 / −19.26 | 17.61° |
| `city_riverside_block` | +12.59 / −12.78 | 24.27° |
| `city_harborpoint_pd_block` | +43.01 / −16.36 | 20.51° |
| `city_lila_street_block` | +50.80 / −25.43 | 13.93° |
| `city_civic_records_block` | +20.86 / −21.20 | 16.01° |

**0/8 on the lock.** Note the city plates do not even agree with *each other*
(riverside ±12.6 against harborpoint +43.0/−16.4), so the V2 "camera lock" was
never actually enforced — it was prose in a prompt with nothing measuring it.

## Candidate masters

`ArtSource/Generated/BGEEProjectionCandidates/` holds a generated pass against
the V5 / V3 prompt locks, best-of after retries:

| Candidate | Measured axes | Worst | Verdict |
|---|---|---|---|
| `city_riverside_block_v03` | +36.33 / −36.11 | 0.76° | PASS |
| `city_wharf_ladder_block_v03` | +36.79 / −35.78 | 1.09° | PASS |
| `city_harborpoint_pd_block_v03` | +36.08 / −34.46 | 2.41° | PASS |
| `city_sable_row_block_v03` | +37.01 / −33.14 | 3.73° | PASS |
| `office_suite_plate_bgee_v05` | +33.11 / −34.58 | 3.76° | PASS |
| `city_lila_street_block_v03_OFFLOCK` | +38.57 / −42.93 | 6.06° | FAIL |
| `city_civic_records_block_v03_OFFLOCK` | +35.64 / −30.21 | 6.66° | FAIL |

**5/7 on the lock.** The two `_OFFLOCK` files are kept only as art-direction
reference; three attempts each kept collapsing back toward the generator's
~26–30° "isometric" prior. They need a human art pass or a 3D re-render.

## These candidates are NOT installable as-is

They are deliberately **not** wired into the runtime. Three hard blockers:

1. **Resolution.** Candidates are 1536×1024. Runtime needs 4096×2304 (office)
   and 2048×1152 (districts). `AssetManifest` requires masters at or above
   runtime dimensions; the office would need a 2.7× upscale.
2. **The office plate is a load-bearing measurement, not just a picture.**
   `office_room_plan.py` fits `REAR`, both axis lengths, `WALL_FACE_H` and the
   baked doorway to the painted shell, and `office_layout_plan.py` places ~25
   props, the partition at `a = 0.39`, the doorway at `b = 0.752–0.800`, seat
   positions and every client path on that fit. Swapping the plate means
   re-fitting all of it.
3. **The Swift gates cannot run on Linux.** `RainShadowCoreTests` needs macOS +
   Xcode. Per AGENTS.md, replacing a runtime payload that a red suite would have
   caught does not pass the payload — it just moves the failure downstream.

## Aspect-ratio trap (fixed)

`process_city_districts_v02.resize_plate` used to resize any master straight to
2048×1152. When the master is not already 16:9 that scales x and y by different
factors and multiplies every ground slope by `sy/sx` — an on-lock 3:2 master
lands at **31.74°**, a 5.13° shear, with nothing reporting a problem.

`fit_to_aspect` now centre-crops to the target aspect before scaling uniformly.
Verified byte-identical on the shipped 16:9 masters (inert), and it holds
36.74° on a 3:2 master that previously sheared to 31.74°.

## Remaining work (needs macOS or a human art pass)

1. Produce office + district masters at full runtime resolution, on-lock, from
   `office_suite_plate_bgee_v05.md` and `city_perspective_lock_v03.md`.
   Gate each with `qa_plate_projection.py` before accepting.
2. Re-fit `office_room_plan.py` (`REAR`, axis lengths, `WALL_FACE_H`, doorway)
   against the new shell. Slopes must stay ±0.75.
3. Rebuild suite plate, partition, lettered door, prop registrations.
4. `office_layout_plan.py` must print `ALL CHECKS PASS: True`, then `--write`.
5. Flood-fill the runtime SearchMap (`path`, never `route`).
6. `process_city_districts_v02.py`, then `measure_city_door_apertures.py` and
   `qa_city_door_registration.py`; re-derive street-side portal approaches
   (~120–150 units out from `nearestWalkablePoint`, unrounded).
7. Run `RainShadowCoreTests` on macOS outside the iCloud-synced tree.
8. Characters: `ArtSource/Prompts/character_camera_lock_bgee_v01.md`, installed
   only in the AGENTS.md order.

## Already done in-repo

- `ie_projection.py` shared constants + helpers; `qa_ie_projection.py`
- `qa_plate_projection.py` calibrated measurement gate
- Docs / prompt locks (city V3, office suite V5, character lock)
- Layout planner half-steps 64/48, diamond 128×96
- Room-plan axis slopes ±0.75
- Graybox / prop / UI ring generators on shared projection
- Selection rings regenerated at 128×96 with a true 16:12 ellipse
- `OfficeNavigationLayout.swift` re-emitted; planner `ALL CHECKS PASS: True`
- District slicer aspect fix
