# V15 crunch — BG:EE raster-density parity

**Status: shipped.** `crunch.ACTIVE = V15`; all 233 runtime cells rebaked
2026-08-17 (Voss via `install_voss_v21.py`, Lila via `v11.process_lila()`
with `RAINSHADOW_PRESERVE_WARDROBE=1`).

## Why V14 did not look like BG:EE

BG:EE sprites are pre-rendered at **the same raster density as the area
plate** — 1 sprite pixel = 1 background pixel at 100% zoom — and the EE
engine smooths both together with bilinear filtering when zoomed. V14
rasterised the body at 56 native rows and nearest-upscaled to the 200 px
texture body, then the runtime drew it with `.nearest`. At the office plate's
2.53 art-px per world unit, sprite pixels were **~3.2× coarser than the floor
they stood on** (0.80 px/wu), which BG:EE never exhibits. That mismatch —
not the palette, not the pose — is what read as "too chunky".

## What V15 changes (`ArtSource/Processing/crunch.py`)

| axis | V14 | V15 | why |
|---|---|---|---|
| native rows | 56 | **200** | 2.84 px/wu ≈ plate parity (1.12×); selected by `qa_pixelation_ab_v03.py` at the shipped 9% camera |
| alpha | 1-bit | **1-bit (unchanged)** | classic BAMs are 1-bit; on-screen softness comes from runtime `.linear`, exactly like the EE zoom. Keeps every `{0,1,255}` gate valid |
| palette | 64 ramps | **128 ramps** (`ramp_steps` 16) | 64 entries band visibly once 200 rows of shading survive |
| soften radius | 3.4 | **1.2** (now spec-owned) | 3.4 was sized for the 56-row grid; at 200 rows it only destroyed detail |
| grading | none | **highlight-only value expansion ×1.35** about the body's median luma, applied before the palette fit | measured luma sd 29.0 → 40.2 against the BG paperdoll reference 45.7 |

Runtime (Swift): character atlas textures load with `.linear`
(`GameArt`, both actor nodes); `ActorSceneLighting.officeInterior` blend
0.10 → 0.30 with a darker tint so Voss sits in the dark room like a
lightmap-tinted BG sprite; contact shadows enlarged and raised to BG blob
weight (party 0.55, npc 0.46, falloff exponent 1.25).

Unchanged contracts: 512×512 cells, 200 px body, `FOOT_Y` 434 / visible
foot row 433, corner alpha-1 sentinels, mass-centroid registration. The
Swift gates read `palette_colors` (now 128) from the V21 manifest.

## The grade earned its shape the hard way

Three failed forms preceded the shipped highlight-only curve. Each failure
was caught by an existing gate — do not re-simplify the curve without
re-running all of them:

1. **Fixed pivot 120, symmetric** — crushed Lila's dark emerald dress
   (median luma ~40) to an unreadable near-black silhouette.
   `clientDepartureWardrobeMatchesArrivalEmeraldNotChromaGreen` caught it.
2. **Median pivot, symmetric** — walked charcoal trouser/boot shadows down
   into the tie's luma window on the rear key (tie and trousers share
   near-neutral chroma; only value separates them). The Python rear-tie gate
   caught it.
3. **Uncapped gain** — one clipped highlight channel (255,247,176) rotated
   its chroma into the shirt window and put 24 rear-coat pixels past the
   0.1% rear-shirt Swift gate on idle N 02. The per-pixel gain cap
   (no channel may reach 255) makes post-grade chroma mathematically
   identical to source, which is also why the wardrobe hue gates cannot
   move: they all measure brightness-normalised RGB.

The clip palette is fitted to **graded** pixels (`build_clip_palette`
grades its pooled sample), otherwise the per-frame ramp snap pulls the
contrast right back out.

## Gate recalibrations that came with the density change

Both were measurement-resolution artifacts, recalibrated in Python and
Swift together — physically *stricter* than their V14 effective values:

- **Planted-foot deadband ±2 → ±1 px** (`foot_lead` /
  `VossAtlasTestSupport.footLead`). The 56-row raster could only express
  foot leads in 3.57 px steps, so ±2 counted any single-native-pixel lead;
  at V15 an honest 2 px lead was read as "even" and WSW/WNW — which do
  exchange feet — failed.
- **Rear-tie window scoped to the tie-plausible torso strip**
  (`_rear_forbidden_fraction(region=…)`). At 200 rows the rear key honestly
  keeps ~3% neutral-dark boot/hem shadow inside the tie's value window
  (305 of 335 hits in the bottom fifth of the body, zero where a tie could
  hang); V14 measured 0 only because downsampling blended those shadows
  into brown. A real painted-on tie still lands hundreds of pixels inside
  the scoped strip. Swift has no rear-tie gate, so no waiver relationship
  changed; the body-wide rear-shirt gate is untouched.

## Lila: the departure scripts are stale — do not run them

`process_lila_departure_facing_fix_v01.py` and
`process_lila_departure_nw_v01.py` bake from the **V10 swing-coat**
`*_combined_gen` masters and overwrite the emerald-dress departure cells
that `v11.process_lila()` (the current authority, from the V11 emerald
strips) has already written. Running them after v11 recreates the exact
"changed clothes mid-scene" defect the pacing test was re-anchored to catch.
This supersedes the AGENTS.md Lila ordering, the same way
`process_voss_desk_ne_v01.py` was superseded by v12.

## Verification record (2026-08-17)

- `install_voss_v21.py stage` + `install`: all Python gates pass.
- Swift: `VossAtlasV20ValidationTests`, `VossSeatScaleTests`,
  `VossWardrobeColorTests`, `ActorLocomotionPacingTests` all pass against
  staging and installed runtime. Full suite: 774 tests, 38 issues — all 38
  reproduced on a clean `HEAD` worktree (stale office-geometry family:
  `OfficeInteriorScaleTests` 27, `NavigationMapTests` 9,
  `ActorFootprintTests` 2); zero regressions.
- Hash-diff vs pre-rebake snapshot: 217/233 cells changed, 16 unchanged —
  all sixteen the deliberately transparent `VossSeatedArms` placeholders.
- Composite grids (`PixelationAB/v15_grid_*.png`): every phase of every
  direction eyeballed; rears carry no face/shirt, seat endpoints match the
  standing idles, Lila is emerald in all 25 cells.
- A/B sheets: `PixelationAB/qa_playscale_sheet_v03.png`,
  `qa_zoom_sheet_v03.png`.
- Advisory: `qa_wardrobe_separation_check.py --shipped` reads lower hue
  spreads at V15 than V14. Its "solid cluster" 8% share threshold is the
  reason — the honest raster shrinks the shirt's pixel share below it (the
  56-row blocks inflated it), so the metric compares browns against browns.
  The binding separation gates (Swift locked-palette coverage ≥ 0.70,
  installer per-material scores ≤ 0.18) all pass. Recalibrate that advisory
  before trusting it on V15 cells.
