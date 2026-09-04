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
over slopes 0.25–1.0, and **0.13°** on a full BG:EE lattice. The default
`TOLERANCE_DEG` is now **1.5°** (tightened from the 4.0° migration band once
the V20 office masters landed); all eight shipped plates pass it.

> A first attempt using a plain 3×3 Sobel was **wrong**: hard-rasterised lines
> alias and snap orientations to 0/26.6/45°. It reported a true 36.87° grid as
> 45°. Always calibrate this tool against a synthetic grid before trusting a
> verdict from it.

## Runtime plates — 9/9 on the BG:EE lock (city Human Scale V3, 2026-08-26)

| Plate | Measured axes | Worst delta |
|---|---|---|
| `office_suite_plate` | +36.75 / −36.56 | **0.31° PASS** (V20 affine re-fit of the approved V03 noir plate) |
| `office_shell_base` | +36.87 / −36.67 | **0.20° PASS** (V20 affine re-fit of the V19 shell) |
| `city_building_interior_v01` | +36.57 / −36.87 | **0.30° PASS** |
| `city_sable_row_block` | +38.04 / −35.88 | **1.17° PASS** (Human Scale V3) |
| `city_wharf_ladder_block` | +35.46 / −36.87 | **1.41° PASS** |
| `city_riverside_block` | +36.48 / −37.49 | **0.62° PASS** |
| `city_lila_street_block` | +37.12 / −37.14 | **0.27° PASS** |
| `city_civic_records_block` | +38.32 / −35.78 | **1.45° PASS** |
| `city_harborpoint_pd_block` | +37.22 / −36.25 | **0.62° PASS** |

### City Human Scale V3 — native detail and actor-sized doors (2026-08-26)

The installed V2 flatten enlarged a 1365×1024 whole-area painting to
8192×6144. Its file dimensions reported 2.00 px/world-unit while the painted
architecture contained only about 0.33 true source px/world-unit. One-storey
shopfronts consequently read 6–10 standing adults tall and blurred at play
zoom. `qa_plate_density.py` could not expose that because it counted the final
canvas rather than the source content.

`build_city_human_scale_v03.py` replaces that scale model without changing the
4096×3072 world or the 8192×6144 runtime contract:

- 72 unique 1024px lot paintings are projection-corrected and seated as 31–34
  small frontages per district at 3.13 true source px/world-unit;
- one named 1254px landmark per district is seated at 1:1 plate scale, yielding
  2.00 source px/world-unit and 3.66–6.81× adult building bodies;
- the authored portal threshold places a complete 80.5-world-unit aperture and
  a native-detail 256×384 door leaf at 1.145× the 70.3125-unit standing actor;
- district area records export zero general props, preventing old modular
  façades from drawing over the continuous plate;
- every install uses unlink-before-copy and refuses any plate outside the 1.5°
  projection lock, 2.00 source-density floor, body bands, or door band.

Install and grade:

```bash
python3 ArtSource/Processing/build_city_human_scale_v03.py --install
python3 ArtSource/Processing/qa_plate_projection.py --shipped
python3 ArtSource/Processing/qa_plate_density.py
python3 ArtSource/Processing/qa_area_door_scale.py --measure
python3 ArtSource/Processing/qa_area_bundle.py
```

### City ward rebuild V1 — IE outdoor ARE (1950s Harborpoint, 2026-08-24)

This V1 section is retained as history. It shipped at **4096×3072** world units
with **8192×6144** monoliths and **256×256** sidecars, matching the 4:3
proportion but not a literal 80×60-tile WED. The current contract is
**5120×3840**, **320×320**, and a 5×5 grid of 2048×1536 texture pages; see
`Documentation/InfinityEngineCityAreas.md` and
`build_city_ie_80x60_pages_v01.py`.

Pipeline: `make_city_ward_seed_jigs.py` draws on-lock geometric jigs;
Image Generator paints 1950s lot masters over those jigs;
`generate_city_ward_rebuild_v01.py` paints iso streets + block volumes,
affine-corrects masters (office V20 method), seats them, and emits the
architecture mask. Search maps are then rebaked from the Swift catalog so
the PNG and the obstacle bands agree. First city `.ht.png` files ship.

Prompt lock: `ArtSource/Prompts/city_ward_1950s_v01.md`.
Install: `python3 ArtSource/Processing/generate_city_ward_rebuild_v01.py --install`
then `swift test --scratch-path /tmp/RainShadowSwiftPM --filter AreaExportTests`.

Kit art stays registered to the original twelve surveyed lots;
three extra camera-far diamonds (`CityBlockGrid.all` beyond `.surveyed`)
block and cover the new depth.

### Office V20 BG:EE lock authority — generated, gated and installed

`BGEEReferenceV20` puts the office on the lock without repainting it.
`generate_office_reference_rebuild_v20.py` measures the approved V03 noir
plate's two interior ground-line families (structure tensor: +0.9082 / −0.6917
y-down) and applies one global vertical-preserving affine that sends them to
exactly ±0.75, anchored so the rear floor corner lands at (2400, 480) and the
camera-near tip at y = 2150. The V19 shell is re-registered by the same method
(its own measured families). Both installed plates now grade at **0.31°** /
**0.20°** worst delta — an 17× improvement over the 5.40° AR0809 override.

The painted floor *silhouette* is not parallel to the boards in the V03 source
(wall bases fit ~0.49/0.29 after the warp), so the navigation diamond is
**derived, not copied**: `office_room_plan.py` fits the maximum-area exact
±0.75 parallelogram anchored at the painted rear corner and inscribed in the
warped painted-floor quad (72.6% coverage; the remainder stays painted but
sealed). Every hand-authored plan coordinate in `office_layout_plan.py` was
re-expressed through the paint (`migrate_office_plan_coords_v20.py`: old basis
→ plate pixels → V20 affine → new basis), so props, approaches and the client
path keep their original paint-relative registration. The door threshold now
derives its `a` from the painted door polygon instead of a hand constant.

`export_office_area_record.py` (new) regenerates the world-space geometry in
`office_suite.area.json` from the layout plan — the missing exporter that let
the area record drift silently. `bake_area_searchmap.py` then rebakes
`office_suite.sr.png`; `qa_area_searchmap.py` floods 1,147 reachable cells
from the default entrance with **no stranded authored point** and the
letterbox margin correctly sealed. `qa_ie_projection.py` passes end to end
(room-plan slopes exactly 0.75) for the first time under `ACTIVE = BGEE`.
Install: `install_office_reference_rebuild_v20.py --install` (preflight runs
`qa_ie_projection.py` and grades both staged plates).

### Office V17 exact AR0809 room-envelope authority — superseded by V20

`BGEEReferenceV17` corrects V15's measured depth mismatch. The V17 ImageGen
source owns the brick, timber, lighting, windows and fireplace; deterministic
plane registration owns geometry. The 1600×900 AR0809 guide is uniformly scaled
by 2.56 onto the 4096×2304 runtime canvas. All five room control points have
**0.0 px** error, floor depth/width is **0.575758**, and the long/short ratio is
**1.711110**, exactly matching the guide. The current empty suite plate and
shell base are pixel-identical; five desk/seat elements remain live.

Exact AR0809 geometry conflicts with the separate BG:EE direction estimator:
the plate measures **+31.71°/−42.27°** (5.40° from ±36.87°), while the
reference measures +32.17°/−39.14°. A texture-only ImageGen correction pass
could not change that estimator without moving the silhouette, so V17 gates the
AR0809 directional-depth signature instead. `qa_office_reference_rebuild_v17.py`
also gates source/reference identities, exact geometry, pure-black exterior and
pixel-identical regeneration. `qa_office_layout_v17.py` gates prop containment,
window clearance and support contacts; `office_layout_plan.py` gates exact paths
in both door states. Prompt: `ArtSource/Prompts/office_reference_rebuild_v17.md`.

### Office V15 AR0809-inspired authority — retained provenance

`BGEEReferenceV15` replaces the V14 plaster box with a full Image Generator
redraw of the AR0809 long-room silhouette: stone/brick masonry, wooden
floorboards, two small high windows, a compact lit fireplace, and walls that
taper to point cutaways at both side tips. ImageGen supplies every visible
room pixel; deterministic processing applies only one uniform scale and
translation. The floor long/short ratio is **1.683**, the registered plate
grades **+39.17°/−37.56°** (worst delta **2.30°**), and exact paths pass in
both door states.

`generate_office_reference_rebuild_v15.py` reproduces the architecture plate,
two window masks and metrics. `qa_office_reference_rebuild_v15.py` gates
source identities, AR0809 proportion, tapered tips, uncropped framing,
pure-black exterior, projection and deterministic reproduction.
`qa_office_layout_v15.py` and `office_layout_plan.py` gate prop containment,
support contact and exact navigation. The atomic V15 installer copies nine
allowlisted runtime assets. Prompt and hashes:
`ArtSource/Prompts/office_reference_rebuild_v15.md`.

### Office V14 room-envelope authority — retained provenance

`BGEEReferenceV14` replaces the V13 architecture with a full built-in Image
Generator redraw based on the supplied Baldur's Gate room-shape reference.
ImageGen supplies every visible room pixel; deterministic processing only
plane-registers those pixels onto the shipping envelope. The floor is an exact
closed parallelogram with slopes ±0.75 and a **1.649:1** long/short ratio, all
wall uprights are **135 source pixels**, and the camera-near corner retains an
explicit **11.1%** black margin so the room is not cropped.

`generate_office_reference_rebuild_v14.py` reproduces the architecture plate,
two six-pane masks and metrics. `qa_office_reference_rebuild_v14.py` gates
source identities, exact closure, room aspect, constant wall height, uncropped
framing, pure-black exterior, projection, fireplace/adult scale and
deterministic reproduction. `qa_office_layout_v14.py` gates prop containment,
window clearance, surface contact and desk/chair separation, while
`office_layout_plan.py` validates exact closed/open-door runtime paths before
emitting Swift. The atomic V14 installer copies nine allowlisted runtime assets.
Prompt and hashes: `ArtSource/Prompts/office_reference_rebuild_v14.md`.

### Office V13 approved-reference authority — retained provenance

`BGEEReferenceV13` retains V12's uniformly registered redraw while rebuilding
the NW wall and distributing two exact six-pane window copies into equal
wall-axis bays. The architecture plate, masks, furnished bake and 1.5°
projection gate are reproduced deterministically by
`generate_office_reference_rebuild_v13.py` and `bake_office_plate.py`.

The door remains separate and interactive. The final V12 family uses a frozen
1536×1024 native-detail transparent master fitted to the small camera-near door
in the approved 1613×975 reference. It preserves the V11 512×320 canvas, image
hinge `(488,18)`, anchor `(0.953125,0.94375)`, and state semantics, but displays
at 0.28 with a 34.5 px texture thickness. This replaces the enlarged, pixelated
reference crop without changing collision or travel geometry.
`qa_office_reference_rebuild_v13.py` checks source identities, equal window
spacing, continuous plaster, masks, projection and deterministic reproduction;
`qa_office_layout_v13.py` gates prop containment, aperture clearance, support
contact and desk/chair separation before the V13 installer copies runtime art.

### Office V11 1950s registration authority — retained provenance

`BGEE1950sV11/office_v11_geometry.json` is the single registration manifest
for the compact 1950s redraw. The supplied 1613×975 RGB image (SHA-256
`6fbb06a6bf54e821bcdf7ae5e86aecc998ed594b4869c79dbc78bb41d770bd19`)
is used only for composition, style, and measurements. One uniform
`4096/1613 = 2.5393676379417234` scale crops 33.84375 px of black margin at the
top and bottom; X and Y are never stretched independently and zero supplied
pixels enter an output. Full provenance is frozen in
`ArtSource/Prompts/office_1950s_bgee_v11.md`.

`generate_office_1950s_bgee_v11.py` deterministically projects six original
ImageGen sources through that manifest. Its 4096×2304 RGB plate grades
**+36.70°/−36.97°, 0.17° worst delta**, and measures **2.5316 px/world unit**.
`qa_office_reference_lock_v11.py` reports `ALL_PASS=True`, including pure-black
exterior, deterministic hash reproduction, two locked steel/blind apertures,
both-window rain-mask coverage, near-window-only hover, cold-fireplace/no-hot-
pixel checks, no baked door pixels, and all door endpoint/angle/thickness/hinge
checks.

The separation is deliberate:

- background pixels bake the two fixed casement/blind assemblies and the cold
  fireplace;
- rain, cool/blind lighting, `office.window`, and near-only hover remain
  registered overlays/regions;
- the tiny door is a separately registered 512×320 state family sharing image
  hinge `(488,18)` and SpriteKit anchor `(0.953125,0.94375)`;
- fireplace collision/cover, wall polygons, door stamping, and the 16×12 search
  map remain geometry records generated from the same manifest.

The explicit 17-target V11 allowlist is installed. Runtime plate/mask hashes,
area-export parity, registered resource membership, navigation, Swift tests,
the macOS build, and shipping-scene captures are separate verified evidence.

### Office V10 tavern-hall rollback provenance

`generate_office_tavern_bgee_v10.py` constructs the 4096×2304 architecture
against the exact BGEE basis and the Feldepost AR3351 floor diamond, then
registers generated material passes without moving the floor geometry.
`install_office_tavern_bgee_v10.py` performs every projection, density,
state-registration, scale, and sole-entrance check before writing production
assets. Pillars and the NW-wall stair run are baked architecture. The only
entrance is on the camera-near/right cutaway; its open state is a dark edge-on
timber sliver rather than a conventional readable door face. Runtime state
textures share a fixed hinge and 512×320 canvas.

V11 does not delete or rewrite these V10 sources/scripts. They remain the
rollback chain and the measurement history for the superseded tavern-hall
composition; V8/V9 staging is likewise outside the V11 installer allowlist.

> An earlier version of this section claimed the `city_*_block` rows fail
> *because* they are composed scenes (ground + buildings), and told the reader
> to grade the `city_*_ground_v02` plates instead. That was wrong, and the same
> claim sat in `qa_sable_area_bake.py`'s docstring as "building masses pollute
> the axis tensor". Five composed block plates now grade 1.00°–1.27°.
> Composition was never the problem; those plates were simply off-lock, and
> after the V3 regeneration they measure correctly. The belief is what let
> Sable Row ship 25° off under an `ALL CHECKS PASS`.

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

## Sable Row buildings are on a different camera from their own ground (2026-08-16)

Sable Row is the last plate off the lock, and the fault is isolated to the
buildings — not the bake, not the ground, not the composition:

| Plate | +axis | −axis | worst Δ |
|---|---|---|---|
| `city_sable_row_ground_v02` (ground only) | +36.75 | −35.47 | **1.40° PASS** |
| `city_sable_row_area_streets_v01` (ground + streets) | +36.65 | −36.32 | **0.55° PASS** |
| `city_sable_row_area_v01` (+ lot buildings) | +11.18 | −40.75 | **25.69° FAIL** |

One ground axis is painted at ~11° (slope 0.19) where BG:EE requires 36.87°
(slope 0.75); the other is roughly right. Across a 1525 px lot that is ~850 px
of divergence, so the terraces cut across the paving lattice instead of sitting
in their lots. Every Sable building asset shares it — the vendored lot masters
(22–26° off) and the v01 crops they fall back to (22–27° off) alike.

### What `install_sable_lot_masters.py` was doing

It had no camera gate at all. Its only acceptance test was `lockΔ` — an identity
check that the *previously locked* v01 wall pixels had not moved, which is a
different property from the camera. `InfinityEngineGroundProjection.md` step 4
already said to grade every master before installing it; the script never called
`qa_plate_projection`. On top of that it:

- fitted **a scale per lot** from a colour scan for the roof eave, against the
  neighbouring v01 terrace's pixel height — so two lots landed at different
  px/world-unit, which is the giant terrace beside the doll's-house cottage;
- fell through to a **second, silent geometry path** (width-match, then
  back-solving a fake eave) whenever that scan failed, with no warning;
- registered on the **roofline**, not the ground, so any eave error translated
  the whole building vertically;
- admitted new paint only above the near blob's top row (`yy < ny0 + 8`),
  guillotining any master taller or shorter than the v01 terrace;
- read masters from a hardcoded `~/.grok/sessions/…` path of numbered JPEGs.

### What it does now

One district scale stated in world units (`LOT_FRONTAGE_UNITS = 622.5`,
identical for every lot), ground registration on the bake's own `groundPoint`
— which is the diamond's camera-near tip, and lands at the bottom centre of
every lot crop — and three advisory grades printed per lot before anything is
written: `camera`, `density`, and `spill`.

`spill` is a second, independent read on the camera. The pad is a diamond of
half-width 584 and half-depth 438 world units, so a footprint painted on the
BG:EE camera has aspect 584/438 = 1.333 and seats inside the pad by
construction — spill goes to ~0 on its own. A footprint painted flatter has a
wide, shallow base whose ends hang outside a pad that narrows to a point.
Spill is now 0.0–1.3% on the V5 masters.

Masters are vendored with sha256 provenance in `LotMasters/masters.json`, and
the installer refuses a digest mismatch. All six hero lots have PNG masters
under `city_sable_lot_masters_v05.md`, including `harborWest`.

**The gates are fatal by default** (`--no-strict` remains for debug). The V5
lot masters (2026-08-16) cleared camera ≤ 1.49°, density 2.57 px/unit, and
spill ≤ 1.3% on all six hero lots including `harborWest`. The installed area
flatten grades **+36.30 / −36.40, worst 0.57°**. `install_sable_lot_masters.py`
refuses off-lock art.

The Imagine tool caps at 1024×1024. Masters are packed onto 2560×2560 by
`pack_sable_lot_masters.py` (uniform scale, so slopes do not shear). `harborVoss`
needed a roof redeck onto ±0.75 after three generator attempts landed 2.11°.
The v01 near wall remains a lock on that lot (stoop / Harbor Street kerb);
`qa_sable_area_bake.py` grades Voss minus that lock. The shipped block plate
is the flatten, and it is on the camera.

### V5 masters installed — the plate is on the lock (2026-08-16)

Six masters regenerated at 2560x2560 PNG under
`ArtSource/Prompts/city_sable_lot_masters_v05.md`. The flatten went
**25.69 deg to 1.89 deg**, and `qa_plate_projection.py --shipped` is **8/8** for
the first time.

Two corrections to how that result was first reported:

- "the previous cubes were 0.57 deg on the flatten" conflated the *streets*
  plate (`city_sable_row_area_streets_v01`, ground + furniture, **no
  buildings**) with the area flatten. The flatten with buildings was 25.69. The
  move is 25.69 to 1.89, not 0.57 to 2.03.
- Three lots still measured 15-27 deg afterwards, which was not mentioned.
  `seat()` started from `orig.copy()` and only *overwrote* where the new master
  was opaque, so the v01 far rank survived underneath and above the new
  frontage. That is what made lots read as two buildings. `seat()` now clears
  superseded v01 paint across the whole crop -- the bake's crops do not overlap,
  so every painted pixel in a crop belongs to that lot. southEast went 26.46 to
  2.48 on that change alone.

Clearing the far ranks leaves the blocks visibly sparse. That is structural, not
an art fault: the bake's lot crops span only **53-71% of the buildable pad**, so
a pad-filling building cannot be stored in them. Widening them is a
`bake_sable_area_plate.py` change.

### The residual is a symmetric elevation error, not the roofs

All six masters land 34.40-35.07, symmetric to within 0.5 deg. Symmetric means
the azimuth is right and only the elevation is shallow -- a different and far
healthier failure than the +11 / -38 art it replaced.

It is not the pitched roofs. Grading masters by region, the ground lines read
34.7-35.0, the same as the roofs; the error is uniform through the whole image.

A uniform vertical stretch of `tan(36.87)/tan(34.7)` = 1.083 would put the
ground axes exactly on the lock and keep verticals vertical, but height
foreshortening moves the wrong way (0.72 to 0.78 when it should be 0.66),
leaving buildings ~18% too tall. Not worth it for 2.2 deg.

### Two gate faults this exposed

1. **The gate measured the master, never the result.** `upperWest` passed at
   2.22 deg and its shipped crop read **15.69** -- its striped shop awnings are
   strong coherent edges on a non-ground plane, and they outvote the
   architecture once the building is cropped to its lot. The installer now
   grades the seated composite too.
2. **Refusal reverted to worse art.** Every v01 Sable crop is 22-27 deg off, so
   a blanket revert on failure took the plate from 1.89 to 2.47. Refusal now
   grades the fallback and keeps whichever measures better, flagging the lot and
   still returning non-zero.

`CAMERA_TOLERANCE_DEG` is **2.75**, and `qa_sable_area_bake.py` imports it
rather than restating it -- two tools disagreeing about what "on the lock" means
is how this shipped 25 deg off to begin with. The rationale for 2.75 over 2.0 is
in the prompt doc.

### What is left

- `upperWest`: regenerate without striped awnings. Only lot still failing.
- `harborVoss`: keeps the v01 stoop wall by design (office door registration).
  Both tools measure it with that region excluded. Clearing it means
  re-registering the door aperture.
- Blocks read sparse until the lot crops are widened.

## Sable Row area plate V2 — full IE block (2026-08-16)

Supersedes the sparse L-terrace pass. Every surveyed diamond is now a finished
terrace + courtyard block on full-pad diamond-AABB crops (1168 wu frontage).

| Gate | Result |
|---|---|
| Area flatten | **+36.60 / −36.69, worst 0.27° PASS** |
| `qa_sable_area_bake.py` | ALL CHECKS PASS (edge strips waived per-lot) |
| Shipped plates | 8/8 on the lock |
| Swift city suites | LayoutGrid / DoorRegistration / Scale / WorldExtent / LayoutDump PASS |

Pipeline: `bake_sable_area_plate.py` (diamond AABB) →
`make_sable_lot_master_seeds.py` (finished blocks + area jig) → density
composite → `install_sable_lot_masters.py`. Prompt:
`ArtSource/Prompts/city_sable_row_area_v02.md`. Play still uses the WED split
(streets plate + lot crops + door leaves). Geom-seed craft is the on-lock
structure; a painted Imagine pass against those seeds remains the art upgrade.

### What is left (post-V2)

- Paint unique per-lot craft on the geom seeds (Imagine / Cursor edit) so the
  flatten does not read as twelve copies of one block.
- Unique street dressing on `area_streets_v01` (replace repeated lamp stamps).
- Plate-edge tip `edge_2_-3` remains a thin clip; camera waived there.

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
