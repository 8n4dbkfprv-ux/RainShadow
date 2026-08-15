# Area master regeneration — BG:EE projection

The projection lives in the painted pixels. Everything else — the nav diamond,
the floor-plan basis, ground ellipses, graybox shears — only describes the art
that is actually installed. So the adoption is **staged**: the pipeline knows
both cameras and is currently drawn to the legacy one, and it switches when the
art does.

`ArtSource/Processing/ie_projection.py` defines `BGEE` (the target) and
`LEGACY_V2` (what the shipped plates are), and selects one:

```python
ACTIVE: GroundProjection = BGEE   # flipped with the V5 office + V3 city masters
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

## Shipped plates — office on the lock, composed city blocks still off

| Plate | Measured axes | Worst delta |
|---|---|---|
| `office_suite_plate` | +32.98 / −34.73 | 3.89° **PASS** (V7 proportion lock) |
| `office_shell_base` | +32.98 / −34.73 | 3.89° **PASS** (same V7 pixels) |
| `city_sable_row_block` | +22.65 / −28.46 | 14.22° |
| `city_wharf_ladder_block` | +32.70 / −19.26 | 17.61° |
| `city_riverside_block` | +12.59 / −12.78 | 24.27° |
| `city_harborpoint_pd_block` | +43.01 / −16.36 | 20.51° |
| `city_lila_street_block` | +50.80 / −25.43 | 13.93° |
| `city_civic_records_block` | +20.86 / −21.20 | 16.01° |

Office **2/2 PASS**. The six `city_*_block` rows are *composed* scenes
(ground + buildings) and still fail this table; grade the installed
`city_*_ground_v02` plates instead (6/6 PASS, see City districts V3).

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

Every Act I city ground is now on the lock after `fit_to_aspect` to 2048×1152
(V3) and then the V4 density overlay to 4096×2304. Install grounds with
`ArtSource/Processing/install_city_grounds_density_v04.py` (do **not**
run `process_city_districts_v02.main()`).

| Installed ground (V4) | Axes | Worst | px/unit |
|---|---|---|---|
| `city_riverside_ground_v02` | +35.96 / −37.11 | 0.91° | 2.00 |
| `city_wharf_ladder_ground_v02` | +35.08 / −36.21 | 1.79° | 2.00 |
| `city_lila_street_ground_v02` | +39.08 / −37.20 | 2.21° | 2.00 |
| `city_sable_row_ground_v02` | +39.19 / −36.83 | 2.32° | 2.00 |
| `city_harborpoint_pd_ground_v02` | +34.07 / −33.73 | 3.14° | 2.00 |
| `city_civic_records_ground_v02` | +32.98 / −32.95 | 3.92° | 2.00 |

**6/6 city grounds PASS** camera and density. Landmark sheets and door strips
are chroma-sliced into `Props/CityDistrict/V2`. Door apertures on the five
new facades were re-measured off 50 px grids into `SourceDoorAperture`
(Riverside already had V3 numbers). Obstacle AABBs stay on the V2 layout so
the reachability baselines do not move; spawn and a few building points were
nudged onto painted stone. World size, navigation and camera are unchanged —
`CityDistrictScene` still draws the texture at `worldArtSize` 2048×1152.

## Office V5 — installed (2026-08-15)

The on-lock candidate is now the runtime suite and shell:

`install_office_bgee_v05.py` uniformly contains the 1536×1024 (3:2) master
onto 4096×2304 at `SUITE_PLATE_SCALE=0.60` (no 16:9 centre-crop — that
sheared off the wall crowns). Installed plate grades **+33.06 / −34.63,
worst 3.81° PASS** after `qa_plate_projection` crops letterbox void.

Room-plan fit (slopes exactly ±0.75):

| | value |
|---|---|
| `REAR` | (1934.3, 389.2) |
| `AXIS_NW` | (−863.2, 647.4) |
| `AXIS_NE` | (1028.8, 771.6) |
| partition | `a=0.426`, door `b=0.377–0.533` |
| exterior door | `(0.0, 0.863)`, clear opening 125×290 (1.63× body) — **wrong, see V7** |
| `paintedRoomSourceRect` | (1047, 646, 1999, 1379) y-up |

`ie_projection.ACTIVE` is **BGEE**. `office_layout_plan.py` prints
`ALL CHECKS PASS`; `OfficeNavigationLayout.swift` was re-emitted.
UI rings/markers are 128×96 / 64×48. Flood-fill the runtime SearchMap
on macOS (`path`, never `route`) before treating this as ship-final.

Furniture prop *art* is still the legacy-camera set; only positions moved.

## Office V7 — walls shortened, floor still un-fitted (2026-08-15)

V5 was on the camera but the exterior door column was a warehouse.
`install_office_bgee_v07.py` compresses only the plaster band above a fixed
lintel plane, so the floorboards, wainscot and door are untouched and the floor
diamond does not move:

| at the door column | V5 | V7 |
|---|---|---|
| wall face | 369 px | **272 px** |
| clear opening | 198 px | 199 px |
| door / wall | 54% | **73%** |
| plaster above the head | 171 px (a whole extra adult) | 73 px |
| implied ceiling | ~3.78 m | **~2.8 m** |

Installed plate grades **+33.02 / −34.79, worst 3.85° PASS**. `BAKED_DOORWAY_H`
went 290 → 198 and the door now reads **1.118× the standing detective**, back
inside `OfficeInteriorScale.Band.door` (1.10–1.30). Before that it was 1.629×,
which is why Voss read as a child beside his own door.

**The floor diamond is still not fitted to any plate.** `bgee_v07_metrics.json`
says so directly — `"note": "Floor diamond unchanged"` — and echoes back the
same `REAR` / `AXIS_*` that `office_room_plan.py` already held. Shortening the
walls made that worse, not better: the painting now starts at y = 570, so the
authored rear corner at y = 389 sits **above the artwork entirely**, and the
near tip is still 151 px below its bottom edge. The Swift suite is at 131
issues, essentially where it was before the wall fix — the two faults are
independent.

## The fit faults the installers left behind

Each of these cost real time. All are code, not art.

### The measurement is emitted and then not copied

`install_office_bgee_v05.py` measured the plate correctly, wrote the result to
`ArtSource/Generated/Office/bgee_v05_metrics.json`, and ended with a note:

> Copy REAR/AXIS_*/WALL_FACE_H into office_room_plan.py

Nobody did. The shipped diamond has never been the installer's measurement.
V7 then re-emitted the *room plan's* values as if they were a fresh
measurement, which makes the metrics file look like corroboration when it is
an echo. **Diff the metrics against `office_room_plan.py` before believing
either.**

### `fit_diamond` has two bugs of its own

Even copied, the V5 numbers would have been wrong:

1. **It snaps the unit square to the clipped paint, not the room.** The master
   is cropped at y = 1657, but the installer also measures the two camera-near
   edges, and *those* meet at **(2065.2, 1824.6)** — the room's real near
   corner. Solving to the crop makes the unit square describe a smaller room
   than the one painted, so the painted exterior doorway lands at **b = 1.08**,
   outside its own floor, along with the coat rack and umbrella stand. It also
   contradicts `office_room_plan.py`'s own docstring, which says the geometric
   near tip belongs in the black with walkable `FLOOR_*` stopping on the paint.
2. **The rear guard clamps onto the wall crown.** `if rear_y < y0 + 40:
   rear_y = y0 + 80` puts the "floor" rear corner 80 px below the top of the
   *painting*, which is wall, not floor. That is why the shipped value is
   389 while `floorDiamondTracksPaintedWallShoes` expects 740–800.

Solving instead against the two near-edge lines through `REAR` puts every
painted feature back inside the unit square and keeps both slopes exactly on
the lock.

### The door aperture is stored twice

`office_layout_plan.py` keeps its own `SHIPPING_EXTERIOR_OPENING_SIZE`
independently of `office_room_plan.BAKED_DOORWAY_*`. Fixing one leaves the
other stale, and the *emitted* Swift follows the layout-plan copy.

## Why the office keeps landing at 3.8°

Both office masters came in at 3.81° and 3.85° — 96% of the 4.0° tolerance,
twice. That is systematic, and the cause is visible in the inputs:

| | generator input | result |
|---|---|---|
| City districts V3 | passing grounds **+ cobble lattice as camera lock** | 0.79° – 3.90°, five of six under 3° |
| Office V5 / V7 | prose only, **plus the previous master as reference** | 3.81°, 3.85° |

The districts were handed a *geometric* reference; the office was handed a
paragraph. The Riverside log line names the trap outright: *"shipped V2 refs
pull the generator back to ~26°"*. V7 is a compress-pass off the V5 master, so
it inherited V5's slope by construction and never had a chance to correct.

### 4.0° is too loose to gate on

The tolerance was chosen to separate the lock from the retired 2:1 camera
10.3° away, not to hold the lock. What it actually permits, over the room's
~1900 px run:

| off-lock | drift across the room | in adults |
|---|---|---|
| 4.00° | 197 px | **1.11 body heights** |
| 3.85° (shipped) | 190 px | 1.07 |
| 2.00° | 101 px | 0.57 |
| **1.50°** | **76 px** | **0.43** |

A ground line that should reach the far wall at one height arrives a whole
adult away. And this cannot be absorbed in code: the runtime is hard-locked at
0.75 by shipped GemRB-derived constants — `ActorLocomotionPacing.
verticalProjectionScale`, the 16×12 search map, the 16:12 selection rings — so
art below the lock makes actors drift off the painted floorboards as they walk.

### The prompt still asks for the wrong door

`office_suite_plate_bgee_v05.md` says *"doorway about two imagined adult
heights"*. `Band.door` is 1.10–1.30, and a real 2.03 m door against a 1.75 m
adult is 1.16×. Every master generated from that line comes back with oversized
architecture, and the wall height follows the door.

### Recommended order for the next office master

1. Tighten `TOLERANCE_DEG` in `qa_plate_projection.py` from 4.0 to **1.5**, so
   the gate decides rather than judgement.
2. Feed a **geometric camera lock** — the office's equivalent of the cobble
   lattice — not prose. `Documentation/InfinityEngineGroundProjection.png` is
   the reference grid.
3. **Do not pass V5 or V7 as source art.** That is what holds the slope shallow.
4. Fix the doorway line to ~1.2 adult heights and the ceiling to ~1.8.
5. Only then re-fit the floor diamond. Fitting a plan that forces ±0.75 onto
   art drawn shallower is a compromise by construction, and it is why every fit
   attempted so far has landed 100–150 px out somewhere.

## City grounds are on the lock but under-resolved (2026-08-15)

All six city grounds pass the projection grade and still read wrong in play:
the streets look like oversized stonework while the buildings look right.
Measured, the geometry is not the problem —

| | measured | expected |
|---|---|---|
| paving module | 0.12 – 0.19 m | granite sett 0.10 – 0.20 m ✓ |
| street width | 7 – 10 m | terraced side street 9 m ✓ |
| ground per screen | 15.8 × 11.9 m | BG1's own playfield: 11.9 × 11.9 m ✓ |

The camera is right too: our screen shows the same ground *depth* as BG1, and
is wider only because 16:9 is wider than 4:3.

What is wrong is resolution. `qa_plate_density.py` measures art pixels per
world unit, which is fixed at install because a plate is drawn to a fixed world
size:

| | px/unit | vs the actor | magnified at play zoom |
|---|---|---|---|
| Voss (512 px canvas over 180 units) | 2.84 | — | 1.28× |
| office suite plate | 2.53 | 0.89× | 1.43× |
| every `city_*_ground_v02` (V3, 2048) | **1.00** | **0.35×** | **3.63×** |
| every `city_*_ground_v02` (V4, 4096) | **2.00** | 0.70× | 1.82× |

The V3 ground was the only asset in the scene being magnified, and by 3.6×.
Every sett was painted ~10 px and drawn ~36 device px. That was the whole of
the "streets look too big" report — a fine texture blown up, not a coarse one
painted. The 2048×1152 file was itself an upscale of a **1536×1024**
candidate (`fit_to_aspect` → 1536×864 → `PLATE_SIZE`). True source density
was **0.75 px/unit**.

### What the fix did (V4, 2026-08-15)

Both halves, or neither works — and a third trap:

1. **Native stonework at the output pixel scale.** The generator capped at
   1536, so this is option 1 from `city_ground_density_v04.md`: keep the V3
   macro and paint 16 px setts / 56 px flags on the BG:EE axes. A naked
   Lanczos to 4096 is refused (`assert_not_naked_upscale`).
2. **`process_city_districts_v02.PLATE_SIZE` is (4096, 2304).** It was
   (2048, 1152); every installer used to downscale to it.

Raising `PLATE_SIZE` on its own adds pixels and no detail — that is why the
overlay exists. The runtime needs no change at all: `CityDistrictScene` draws
the texture at `worldArtSize`, so the world size, navigation and camera are
untouched by a denser plate.

### Separately: a district is small for an area

A district covers **33.7 × 25.3 m** of ground (≈850 m²) — 2.13 screens across.
Infinity Engine areas run roughly 32–100 adults wide; ours is 29. That is at or
below the smallest BG area, which is why a "ward" reads as a single junction.
Enlarging it is a world-size and navigation change, not an asset swap, so it is
noted here rather than folded into the density fix.

## These remaining candidates are NOT installable as-is

They are deliberately **not** wired into the runtime. Three hard blockers:

1. **Resolution.** Candidates are 1536×1024. Runtime office plates are
   4096×2304; city grounds are now also 4096×2304 via the V4 overlay, not
   via a 2.7× upscale of a new office-class master. `AssetManifest` still
   requires masters at or above runtime dimensions for a *new* plate.
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
`PLATE_SIZE` (then 2048×1152). When the master is not already 16:9 that scales x and y by different
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
