# V14 crunch — BG1 sprite craft

Status: **installed**. Supersedes the V7 crunch described in
[PaperdollBGEESpriteRedoPlanV11.md](PaperdollBGEESpriteRedoPlanV11.md) §3 and
[PaperdollBGEESpriteRedoPlanV12.md](PaperdollBGEESpriteRedoPlanV12.md).
Scope: both leads, 217 gameplay body cells across five atlases.

## Why

V7's parameters (80px native body, 64-colour global median cut) were chosen by
`qa_pixelation_ab_v01.py`, committed 2026-07-23, which composited its candidates
at the camera of that day: **9%** body-to-visible-height. The camera was reframed
to **13%** on 2026-08-06 (`b1cc1a42`, `7dfc838b`) to match original Baldur's Gate
play density. The crunch was never re-validated at the new framing, so its
"at play scale" verdict was stale.

Research into how Infinity Engine sprites were actually built found three craft
deltas, each measured against the then-shipped `voss_standing_idle_sw_00.png`:

1. **Soft silhouette.** Classic IE BAM v1 stores no semi-transparent pixels —
   creature sprites are 1-bit alpha. BG:EE added palette alpha only for UI and
   spell icons, not creature animations. Our frames were **70.3% fully opaque**;
   the rest was a soft fringe that nearest-upscaling smeared into a 2.5px haze.
2. **Area-biased palette.** BG avatar palettes are per-material gradient ramps
   (skin / hair / metal / leather / major / minor / armour), not one global cut.
   A global median cut allocates entries by pixel area: our head region got
   **19 distinct colours over 349 px** while the coat got **102 over 7013 px**.
3. **Raster density.** BG1 resolved a standing adult in ~50 native rows at the
   same ~13% screen fraction. We spent 80 — about 1.6× finer than the era.

## What V14 is

Selected as variant **E** of `qa_pixelation_ab_v02.py`, which rebuilt the study
at the real 13% camera (and fixed two flaws in v01: it composited at 9%, and it
quantised the whole canvas while the shipped V7 quantised opaque pixels only).

| | V7 | V14 |
|---|---|---|
| native body rows | 80 | **56** |
| silhouette alpha | soft (LANCZOS) | **1-bit, hardened at 50%** |
| palette | 64-entry global median cut | **per-material ramps, 64 entries** |
| pre-crunch contrast pull | 0.68 | **1.00 (removed)** |
| texture body / canvas / pivot | 200px / 512 / FOOT_Y 434 | unchanged |

Implementation: [`ArtSource/Processing/crunch.py`](../ArtSource/Processing/crunch.py).
It replaces five near-duplicate copies of the crunch — `pixelize_figure` (V3),
`pixelize_figure_v7`, `pixelize_shared` (desk chain), and the A/B study's — with
one parameterised `crunch()`. `pixelize_figure_v7` survives as a thin wrapper
because six scripts import it, so every installer that monkey-patches it onto
`raster.pixelize_figure` picks up V14 without further change.

Three details worth knowing:

- **Hard alpha without breaking geometry.** Binarising at 50% drops the alpha
  16–127 fringe, shrinking the body about a pixel per side. The gates measure the
  bbox at alpha ≥ 16, so a naive binarise would fail the 198–202 standing-height
  and `footY == 433` contracts by construction. `_native` instead converges on the
  request height so the *binarised* body is what gets normalised, re-downsampling
  from full resolution each pass rather than rescaling the 1-bit raster.
- **Segmentation happens at master resolution.** `_skin_mask` is tuned for the
  master, where the face is thousands of pixels; on a 56-row figure it collapses
  to single digits. `_coat_mask` is broad enough that warm skin satisfies every
  one of its terms, so skin is taken inside the head band first and the coat gets
  the rest. Coverage is *area*-resampled down — point sampling a 4%-area region
  through a 20× reduction loses it entirely.
- **Palette last.** `crunch.finalise` re-applies the ramps at the final write
  (`install_locked_frame_v12`, `save_frame_v7`, `save_frame_v11`). The installers
  grade every frame toward the seated desk pose *after* the crunch, and those are
  continuous multiplies — without this the shipped frame carried ~235 distinct
  colours instead of 64. In the Infinity Engine the palette *is* the sprite.

## Measured result

217 body cells, new vs the V13 runtime snapshot
(`ArtSource/Generated/Characters/RuntimeBackupPreRendered3DV13`):

| atlas | fully opaque % | luma sd | distinct colours |
|---|---|---|---|
| VossIdle | 100.0 / 69.6 | 30.7 / 34.9 | 44 / 122 |
| VossWalk | 100.0 / 67.9 | 30.0 / 34.4 | 50 / 123 |
| VossSeatTransitions | 100.0 / 67.1 | 40.8 / 37.6 | 82 / 123 |
| VossSeatedIdle | 99.9 / 75.6 | 34.6 / 32.2 | 58 / 100 |
| LilaArrival | 100.0 / 55.5 | 35.3 / 52.6 | 57 / 57 |

Reference: a real BG paperdoll asset (`ArtSource/References/BGEE/bgee_avatar_color_slots_paperdoll.png`,
29×63) measures 100% opaque, luma sd 45.7.

### Known shortfall: contrast on locomotion

Value contrast was the third delta, and V14 does **not** fix it on idle and walk —
luma sd fell from ~34.9 to ~30.7. Removing the 0.68 pull raises contrast going
*into* the crunch (the same frame straight out of the crunch measures 39.7), but
`seated_authority_lock` and the installers' luminance gates then grade it back
down. An attempt to claw it back inside `finalise`, by expanding contrast about
each region's mean before re-ramping, reached sd ~36 but pushed Voss's charcoal
trousers into saturated navy and shifted Lila's emerald dress toward olive; it
was removed. Fixing this properly means changing where colour grading sits
relative to the crunch, which trades against the wardrobe-consistency invariant
`VossWardrobeColorTests` enforces. Out of scope here; recorded so it is not
rediscovered.

The seat chain moved the right way (37.6 → 40.8) because it is graded once rather
than gated per frame.

### Chair clips specifically

`qa_crunch_v14_seat_clips.py` renders every frame of stand-up, sit-down and
seated idle through one foot-anchored window, before and after, so crown rise and
head pulsing are readable down the strip.

| clip | crown rise | head width, drift |
|---|---|---|
| stand-up SE | 154→200, monotonic (V7: 155→200) | 21–22, **1.048** (V7 1.136) |
| stand-up NE | 154→200, monotonic (V7: 155→200) | 21–26, **1.238** (V7 1.120) |
| seated idle NE | flat 154 (V7 155) | flat 26, **1.000** |

Stand-up SE and the seated idle are *steadier* than V7. Stand-up NE is the one
clip that got looser, and it is the reason the drift gate moved to 1.30 — the NE
chain is a rear three-quarter view whose head band samples hair rather than face,
so a 1-bit edge quantises it harder. Worth an eye in game; it is the single
weakest spot in the rebake.

## Gate changes

A 1-bit silhouette at 56 native rows puts the head about **6 native pixels**
across, so one pixel of edge is ~17% of its width. The old head-width bands were
finer than the raster can now resolve and were re-baselined against measurement:

- `process_voss_desk_ne_v12.py`: `head_bounds` 24…31 → **19…29** (measured 21…26).
- `VossSeatScaleTests.swift`: NE band 25…29 → **19…29**; clip-wide drift
  1.12 → **1.30**, matching `validate_shared_scale_chain`'s existing tolerance.
  NE measures 1.24, SE 1.05.

Everything else holds unchanged: 198–202 standing height, 150–160 seated,
`footY == 433`, bbox centre within 2px, IoU ≥ 0.86, sit-down cells pixel-equal to
reversed stand-up.

Two fixes were needed along the way:

- `clean_blend` in `install_voss_idle_walk_seated_match_v02.py` composes the walk
  cycle's pass-position frames (02 and 06) from two crunched cells, producing a
  weighted alpha along the band where the silhouettes disagree. Those 18 frames
  came out ~50% opaque until it called `crunch.harden_alpha`.
- `wardrobe_match_to_idle` matched the coat toward the idle's *measured* coat but
  the face toward the frozen `SEATED_FACE` constant. Under V14 the idle face
  settles near 147/102/60 against the constant's 155/110/68, which showed as a
  face pop at the stand→idle handoff (delta 15.85 against a gate of 6.0). It now
  targets the idle's measured face, and closes the residual with a *multiplicative*
  scale on the head band rather than an additive delta — adding a constant lifts
  hair, collar and coat shoulders by the same amount as skin, which at 56 native
  rows flattened the head into a pale blob. Handoff endpoints are also written
  with `install_locked_frame_v12(..., finalise=False)`: re-ramping after the match
  snapped the band's non-skin pixels back onto the torso coat ramp and undid it.
  Face delta is now 0.85–0.86.

## Known side effect

28 idle/walk cells now register their feet on row **434** rather than 433.
`bob_cell` shifts the whole canvas down 1px to make a pass-position frame; under
V7 the soft bottom row absorbed it, so the measured foot never moved. With a hard
edge the bob is real. It breaks no gate and is 0.65 screen pixels at play scale,
but if planted feet must be exact, re-register after the bob.

## Reproducing

```bash
cd ArtSource/Processing
python3 process_voss_desk_ne_v12.py                       # NE seat chain
python3 -c "import process_pre_rendered_characters_v12 as v12, \
process_pre_rendered_characters_v3 as raster; \
from process_pre_rendered_characters_v7 import pixelize_figure_v7; \
raster.pixelize_figure = pixelize_figure_v7; v12.process_voss_desk_chain_se()"
python3 install_voss_idle_walk_seated_match_v02.py         # idle + walk + handoff
python3 -c "import process_pre_rendered_characters_v11 as v11, \
process_pre_rendered_characters_v3 as raster; \
from process_pre_rendered_characters_v7 import pixelize_figure_v7; \
raster.pixelize_figure = pixelize_figure_v7; v11.process_lila()"
python3 process_lila_departure_facing_fix_v01.py
python3 process_lila_departure_nw_v01.py
python3 qa_crunch_v14_compare.py                           # before/after sheets
```

Order matters: the seat chains must run **before**
`install_voss_idle_walk_seated_match_v02.py`, whose `lock_standup_handoff()`
grades the transition endpoints against the freshly installed standing idles.

Then `swift test`. On an iCloud-synced checkout codesign rejects the test bundle
("resource fork, Finder information, or similar detritus"); build outside the
synced tree with `swift test --scratch-path <path outside iCloud>`.
