# Area master regeneration — BG:EE projection

The projection lives in the painted pixels. Everything else — the nav diamond,
the floor-plan basis, ground ellipses, graybox shears — only describes the art
that is actually installed. So the adoption is **staged**: the pipeline knows
both cameras and is currently drawn to the legacy one, and it switches when the
art does.

`ArtSource/Processing/ie_projection.py` defines `BGEE` (the target) and
`LEGACY_V2` (what the shipped plates are), and selects one:

```python
ACTIVE: GroundProjection = LEGACY_V2   # flip to BGEE together with on-lock masters
```

Every pipeline module derives its geometry from `ACTIVE`, and
`qa_ie_projection.py` fails if any of them drifts, or if `ACTIVE` is set to
`BGEE` while `office_room_plan` is still fitted to the legacy plate.

## Why it is staged rather than switched

Switching the pipeline ahead of the art does not produce "BG:EE art" — it
produces a floor plan that disagrees with the painting. Forcing the room-plan
axes to ±0.75 against the installed plate stretches the authored floor diamond
away from the painted floor:

| Floor corner | Old (matches paint) | BG:EE slopes | Shift |
|---|---|---|---|
| rear | 1932, 752 | 1932, 752 | 0 px |
| east | 2744, 1139 | 2744, 1362 | +223 px |
| near tip | 2189, 1450 | 2189, 1778 | **+328 px** |

Camera-near props would sit up to ~328 px below the painted floor on a 2304 px
plate, while the planner still reports `ALL CHECKS PASS` because it is
self-consistent — just consistent with a plate that does not exist. That is why
the guard exists.

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

## Riverside V3 — first installed try-out (2026-08-15)

Riverside is the one district that can be tried without flipping
`ie_projection.ACTIVE` or re-fitting the office. The V3 ground plate
(`city_riverside_ground_v03.png`, 16:9 request / 3:2 generator output)
grades **+36.28 / −37.66, worst 0.79°** after `fit_to_aspect` to 2048×1152.

Installed by `ArtSource/Processing/install_riverside_bgee_v03.py` (do **not**
run `process_city_districts_v02.main()` — that walks every district):

- play underlay `city_riverside_ground_v02.png`
- assembled block + HUD map from `compose_city_district_preview.py`
- four landmarks + two door leaves, chroma-keyed to 512×640 / 256×384
- `CityDistrictLayout.SourceDoorAperture.buildingIronStairs` /
  `buildingRiverWatch` re-measured off the new canvases
- sprite and spawn points moved onto painted stone; obstacle AABBs left
  on the V2 layout so the 7,202-cell reachability baseline does not move

`ACTIVE` stays `LEGACY_V2`. Flood-fill the new spawns on macOS (`path`, never
`route`) before tightening obstacles to the V3 pier.

## City districts V3 — all six installed (2026-08-15)

Every Act I city ground is now on the lock after `fit_to_aspect` to 2048×1152.
Install with `ArtSource/Processing/install_city_districts_bgee_v03.py` (do **not**
run `process_city_districts_v02.main()`).

| Installed ground | Axes | Worst |
|---|---|---|
| `city_riverside_ground_v02` | +36.28 / −37.66 | 0.79° |
| `city_sable_row_ground_v02` | +38.91 / −36.84 | 2.04° |
| `city_lila_street_ground_v02` | +39.02 / −36.89 | 2.15° |
| `city_wharf_ladder_ground_v02` | +34.71 / −35.45 | 2.16° |
| `city_harborpoint_pd_ground_v02` | +34.94 / −33.90 | 2.97° |
| `city_civic_records_ground_v02` | +33.24 / −32.97 | 3.90° |

**6/6 city grounds PASS.** Landmark sheets and door strips are chroma-sliced
into `Props/CityDistrict/V2`. Door apertures on the five new facades were
re-measured off 50 px grids into `SourceDoorAperture` (Riverside already
had V3 numbers). Obstacle AABBs stay on the V2 layout so the reachability
baselines do not move; spawn and a few building points were nudged onto
painted stone.

The office is **not** installed. The best on-lock candidate remains
`ArtSource/Generated/BGEEProjectionCandidates/office_suite_plate_bgee_v05_candidate.png`
(3.76°). Swapping it still requires re-fitting `office_room_plan` and
rewriting `OfficeNavigationLayout.swift` on macOS.

## These remaining candidates are NOT installable as-is

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

## The adoption, in order

1. Produce office + district masters at full runtime resolution, on-lock, from
   `office_suite_plate_bgee_v05.md` and `city_perspective_lock_v03.md`.
   Gate each with `qa_plate_projection.py` before accepting.
2. Re-fit `office_room_plan.py` (`REAR`, axis lengths, `WALL_FACE_H`, doorway)
   against the new shell, and update `INSTALLED_AXIS_*` in `qa_ie_projection.py`.
3. Flip `ie_projection.ACTIVE` to `BGEE`.
4. Rebuild suite plate, partition, lettered door, prop registrations; regenerate
   UI rings and markers (they become 128×96 with a true 16:12 ellipse).
5. `office_layout_plan.py` must print `ALL CHECKS PASS: True`, then `--write`.
6. Flood-fill the runtime SearchMap (`path`, never `route`).
7. `process_city_districts_v02.py`, then `measure_city_door_apertures.py` and
   `qa_city_door_registration.py`; re-derive street-side portal approaches
   (~120–150 units out from `nearestWalkablePoint`, unrounded).
8. Run `RainShadowCoreTests` on macOS outside the iCloud-synced tree.
9. Characters: `ArtSource/Prompts/character_camera_lock_bgee_v01.md`, installed
   only in the AGENTS.md order.

Steps 1–3 belong in one commit. Splitting them is the split state described above.

## Already done in-repo

- `ie_projection.py` two-camera model with the `ACTIVE` selector
- `qa_ie_projection.py` consistency guard (fails on a premature flip)
- `qa_plate_projection.py` calibrated measurement gate
- Docs / prompt locks (city V3, office suite V5, character lock)
- Whole pipeline reading its geometry from one place
- District slicer aspect fix
- Graded candidate masters

All pipeline edits are **inert**: regenerating every affected asset and the Swift
layout reproduces main's own generator output byte for byte (46/46 assets and
`OfficeNavigationLayout.swift` at matching SHA-256).

## Two pre-existing staleness problems, left alone deliberately

Found while proving inertness, both present on `main` and both outside the scope
of a projection change:

1. **`OfficeNavigationLayout.swift` is stale.** Running main's own
   `office_layout_plan.py` rewrites it with a 727/784-line diff — the committed
   file came from a room plan scaled ~1.221× (the 0.733 suite plate) while
   `office_room_plan.py` now says 0.60. Regenerating it changes runtime
   geometry, which needs the Swift suite to verify.
2. **`generate_office_zone_props_v01.py` is destructive.** It overwrites
   Image-Generator masters with procedural placeholders
   (`office_case_board.png`: 101 KB → 2 KB). Do not run it unless you intend
   that.
