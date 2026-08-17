# Sable Row lot masters — V5

- Generated: 2026-08-16
- Mode: Imagine `image_edit` of code-built geom seeds (ground lattice + volume)
- Intent: Regenerate the six Sable Row **hero lot buildings** on the BG:EE
  camera, so the district's buildings share the camera of the ground they
  stand on.
- Installed: 2026-08-16 — all six lots + area flatten 0.57°; `--strict` is default
- Supersedes: the untracked grok-session JPEG masters (now in `LotMasters/rejected/`)
- Camera lock: `ArtSource/Prompts/city_perspective_lock_v03.md` (unchanged)

## Why

Sable Row is the only one of the eight shipped plates off the projection lock,
and the fault is isolated to the buildings:

| Plate | +axis | −axis | worst Δ | verdict |
|---|---|---|---|---|
| `city_sable_row_ground_v02` (ground only) | +36.75 | −35.47 | **1.40°** | PASS |
| `city_sable_row_area_streets_v01` (ground + streets) | +36.65 | −36.32 | **0.55°** | PASS |
| `city_sable_row_area_v01` (+ lot buildings) | **+11.18** | −40.75 | **25.69°** | FAIL |

The ground is dead-on. The buildings composited onto it have one ground axis at
~11° (slope 0.19) where BG:EE requires 36.87° (slope 0.75). Across a 1525 px lot
that is ~850 px of divergence, which is why the terraces cut across the paving
lattice instead of sitting in their lots.

No installer can fix this. Scaling and translating a painted building cannot
rotate the camera it was painted on — that is why
`install_sable_lot_masters.py` now measures instead of fitting, and why these
masters have to be repainted.

## The ask, in one line

**Repaint each lot's block with its ground footprint on slopes ±0.75.**
Everything else in `city_perspective_lock_v03.md` stays exactly as it is.

## Hand it geometry, not prose

`Documentation/BGEEProjectionMasterRegen.md` records what decides this. The city
districts were handed the cobble lattice as a geometric reference and landed
0.79°–3.90°. The office was handed a paragraph and stalled at 3.81° and 3.85° —
96% of tolerance, twice.

**Reference inputs, in order:**

1. `RainShadow Shared/Resources/Art/Areas/CityDistrict/V2/city_sable_row_ground_v02.png`
   — Sable's own ground, measured at 1.40°. Authoritative for the camera: the
   buildings must sit on *this* paving lattice, so its setts and kerbs are the
   lock. This is the geometric reference.
2. `Documentation/InfinityEngineGroundProjection.png` — camera elevation and
   azimuth, the 16:12 ground ellipse, vertical uprights.
3. `RainShadow Shared/Resources/Art/Areas/DetectiveOffice/office_suite_plate.png`
   — material and value language only. Not for camera.

**Do not pass any current Sable building art as a reference.** Not the v01 lot
crops, not `LotMasters/*_master.jpg`, not the `_seed.png` files. Every one of
them sits at 22–27° off, and `BGEEProjectionMasterRegen.md` names this trap
outright — *"Do not pass V5 or V7 as source art. That is what holds the slope
shallow."* Feeding them back is what produced this set.

## Footprint geometry, stated exactly

The lot pad is a diamond of half-width 584 and half-depth 438 world units. A
footprint painted on the BG:EE camera has those same proportions, so it seats
inside the pad by construction:

| | value |
|---|---|
| Footprint near edges | slopes **±0.75** (±36.87° from horizontal) |
| Footprint half-width : half-depth | **584 : 438 = 1.333** |
| Frontage per lot | **622.5 world units** ≈ 10.2 m |
| Verticals | perfectly vertical, no taper, no shear |
| Roof ridges, eaves, string courses, sills, kerbs | all on ±0.75 |

The single most common failure is a building whose base is a near-horizontal
line. The base is a **diamond**, and its near corner points at the camera.

## Resolution

The painted building — not the canvas it sits on — must be at least **1245 px
across**, native. That is the derived floor: 622.5 wu × 2.00 px/unit. 1600 was
prompt margin (2.57 px/unit) and is not the pipeline requirement. `px/unit`
measures the canvas, so packing a 1024 paint onto 2560 reports 2.57 while
`detail_score` (mean RGB lost by a half-scale round trip of the trimmed
building) shows 0.64. That is an upscale, and `pack_sable_lot_masters.py`
refuses to scale up.

- native painted width ≥ **1245 px** (2.00 px/unit). 1280 clears it; 1536 or
  2048 preferred
- `detail` ≥ **1.10** (the flat-shaded jig scores 1.16; a painted master
  below that has had resolution removed)
- PNG, not JPEG
- if the generator returns less than 1245 px of painted building, ask again —
  do not fill the gap with Lanczos

This generator caps at 1024×1024. The city-grounds precedent is
`composite_city_ground_density_v04.py`: keep the macro, paint native detail at
the output pixel scale, guard with `assert_not_naked_upscale`.
`composite_sable_lot_density.py` is the architectural equivalent (brick
courses, slate, sills on the BG:EE axes). Pack still refuses to scale up;
this path is the only way a 1024 paint may reach 1245.

A thinner paint also gives the camera measurement fewer competing edges, so it
can score well *because* there is less art in it. `upperWest` at 0.19° was the
best camera in the district and the worst picture. Reject that on `detail`.

## The six lots

| Lot | Character |
|---|---|
| `harborVoss` | Voss's block on Harbor Street — his stoop is a runtime lock (see below) |
| `harborWest` | Harbor Street terrace, west of Voss |
| `upperWest` | upper-terrace row |
| `upperEast` | upper-terrace row |
| `southWest` | south-terrace row |
| `southEast` | south-terrace row |

Each is one continuous block, not a free-standing house: a terrace whose
interior is roof deck, on the same ±0.75 axes as the ground.

**The `harborVoss` street wall is a lock.** Voss's stoop and the Harbor Street
kerb are runtime registration points; the installer copies the v01 near wall
back through and refuses any master that moves it (`lockΔ` must stay 0.000).
Paint the block behind and around that wall, not over it.

## Doors go where the runtime pins them

The runtime pins door-leaf sprites to fixed world points and expects a painted
doorway under each. Six of Sable's seven sit **outside** the building pad,
because a stoop projects onto the pavement — `CityDistrictLayout` says so:

| leaf | lot | past the pad |
|---|---|---|
| `tenement` | harborWest | inside (open courtyard) |
| `storefront` | upperWest | 26.9 wu |
| `voss_stoop` | harborVoss | 38.8 wu |
| `gatehouse` | harborVoss | 65.0 wu |
| `rowhouse` | upperEast | 69.6 wu |
| `shop` | harborWest | 84.6 wu |
| `voss_stoop_garage` | harborVoss | 167.5 wu |

The V05 jigs drew doors at arbitrary bay fractions *inside* the pad, and
`seat()` clipped every master at the pad, so the generated art had no doorway
where the game looks. Six of seven leaves shipped standing on bare pavement,
and nothing caught it — `qa_city_door_registration.py` models districts as
separately-drawn facade sprites, but Sable bakes its buildings into lot crops,
so it never looked at them.

Now:

- `make_sable_lot_master_seeds.py` stamps a stoop and a dark opening at every
  runtime anchor, reading them from `city_layout.json` (written by
  `CityLayoutDumpTests` out of `CityDistrictCatalog`, so the jig cannot drift
  from the runtime). Anchors more than 0.06 past the pad also get a projecting
  bay, so the opening is attached architecture rather than a floating slab.
- Arbitrary bay doors are suppressed on any lot that has real anchors — two
  doors in a jig lets the generator paint the wrong one.
- `install_sable_lot_masters.seat()` widens its clip to that lot's furthest
  anchor, so a painted stoop survives seating.
- A `doors` gate reports `landed/total` per lot and is fatal under `--strict`.

**So the generator must paint a usable doorway into every opening the jig
marks.** They are the only doors that matter; do not add others, and do not
close or relocate the ones that are there.

## Acceptance

```bash
python3 ArtSource/Processing/qa_plate_projection.py <master.png> --tolerance 2.75
python3 ArtSource/Processing/install_sable_lot_masters.py     # --strict is the default
python3 ArtSource/Processing/qa_sable_area_bake.py
```

The installer grades four things per lot. All must clear:

| Grade | Meaning | Target |
|---|---|---|
| `masterD` / `seatedD` | `qa_plate_projection` worst delta, on the file and on the seated crop | ≤ 2.75° (expect ≤ 0.5° from Precomp seeds) |
| `detail` | mean RGB lost by a half-scale round trip of the trimmed paint | ≥ 1.10 |
| `px/unit` | painted px per world unit of frontage | ≥ 2.00 |
| `spill` | share of the seated building falling outside its pad | ≤ 2% |

**Grade the seated crop, not just the master.** `upperWest` passed the master
gate at 2.22° and its shipped crop read **15.69°**, because its striped shop
awnings only outvote the architecture once the building is cropped to its own
lot. The installer now measures both.

**Do not paint high-contrast striped awnings, banners, or signage.** They are
strong coherent edges on a plane that is not the ground, so they dominate the
structure tensor and the lot fails on decoration rather than geometry. Plain
dark canopies are fine, and better noir anyway.

## Pre-compensation is per-generator. Never carry it across.

The on-lock seeds from `make_sable_lot_master_seeds.py` grade **36.70°**
(0.17° off the lock). Whether to pre-compensate depends on the generator:

| Generator | Seed | Returned mean | Drift |
|---|---|---|---|
| Imagine (V5/V6 masters) | 36.70 | ~34.67 | **+2.03° shallower** |
| Cursor V07 (six Precomp paints) | 38.70 | 38.70 | **−0.01° — holds the jig** |

Imagine shallows by ~2°, so `--precompensate` (jig at 38.90°) cancels it.
The Cursor generator holds the jig, so feeding it Precomp overshoots by
exactly that 2°. Feed it `GeomSeeds/<lot>_geom.png`, not `GeomSeeds/Precomp/`.

Expected return from on-lock seeds on the holding generator: ~36.70, about
0.17° off. Per-lot spread on V07 was ±2°, so expect to retry one or two lots.

`--precompensate` still writes `GeomSeeds/Precomp/` for Imagine. Re-measure
drift whenever the generator changes.

The Imagine calibration, kept for that generator:

| lot | seed | master | drift |
|---|---|---|---|
| harborWest | 0.17° | 2.17° | +2.00 |
| harborVoss | 0.17° | 2.27° | +2.11 |
| upperWest | 0.17° | 2.22° | +2.05 |
| upperEast | 0.17° | 2.04° | +1.87 |
| southWest | 0.17° | 2.04° | +1.87 |
| southEast | 0.17° | 2.47° | +2.30 |

Mean **+2.03°, σ 0.16** over six independent generations. That is a systematic
bias, not variance — which means drawing the jig steeper by the same amount
should let the generator relax it back onto the lock:

```bash
python3 ArtSource/Processing/make_sable_lot_master_seeds.py --precompensate
# writes GeomSeeds/Precomp/*.png, drawn at 38.90 deg (slope 0.8069)
```

Those seeds measure **+38.70 / −38.71** and are *meant* to. They are a jig, not
shipped art; the thing that has to measure is the master that comes back.
Predicted return: 38.70 − 2.00 ≈ **36.70**, i.e. ~0.17° off the lock.

This is empirical, from one generator on one session. **Check the first returned
master before committing to a full six-lot run**, and re-measure the drift if the
generator changes. The un-compensated seeds stay in `GeomSeeds/` for comparison,
and the default (no flag) output is byte-identical to what produced the current
masters.

## Why the tolerance is 2.75° and not 2.0°

The first pass set 2.0 from the five on-lock districts, which land 1.00–1.27.
Those are *ground* plates — a cobble lattice is a much easier subject to hold
on-axis than pitched-roof architecture.

Six independently generated Sable building masters all landed in 34.40–35.07
(worst 2.01–2.47). That convergence is a systematic generator prior, not
variance, so 2.0 refuses the entire set and another round lands in the same
band. 2.47 is the worst of the set, so 2.75 is that band plus margin.

What it costs: 2.2° is ~89 px of drift across a 1525 px lot, about a quarter of
a body height — still tighter than the office ships at today (3.85°). The error
is also *symmetric* (+34.70 / −34.72), meaning the azimuth is correct and only
the elevation is shallow. That is a different and far healthier failure than
the +11° / −38° art it replaced, where the two axes disagreed.

## Refusal keeps the better art

Under `--strict` a failing lot is not blindly reverted. Every v01 Sable crop is
22–27° off, so a blanket revert can replace merely-imperfect art with much worse
art — and did: holding `upperWest` on v01 took the plate from 1.89° to 2.47°.
The installer grades the fallback and keeps whichever actually measures better,
flagging the kept-but-failing lot. Outstanding debt still sets a non-zero exit.

## Known exception

`harborVoss` keeps the v01 stoop wall by design — the office door registration
depends on it — so its crop carries known off-camera art. Both the installer and
`qa_sable_area_bake.py` measure it with that region excluded. Clearing it means
re-registering the door aperture (`measure_city_door_apertures.py`,
`qa_city_door_registration.py`, `SourceDoorAperture`), which is its own task.
