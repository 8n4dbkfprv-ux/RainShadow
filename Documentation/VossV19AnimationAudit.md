# Voss animation audit — V19 installed payload

**Date:** 2026-08-09 · **Commit audited:** `ac98f4c3` "Install the V19 Imagine
portrait-first Voss redo over the V18 runtime." · **Verdict:** the installed
payload is broken and the Swift suite already says so.

No runtime art was changed by this audit. The only code change is a guardrail in
`ArtSource/Processing/install_voss_v19.py` (see "Guardrail installed" below).

## Summary

The Voss animation problems are entirely in the **art payload**. The runtime
animation code is correct and was not changed.

| # | Defect | Severity |
|---|---|---|
| 1 | The whole rear hemisphere (`n`, `nnw`, `nw`) is drawn as **front views** | ships a visible bug in every scene |
| 2 | Walk "cycles" are 8 independently generated stills, not cycles | continuous boiling/jitter while moving |
| 3 | Seated desk idle jitters — silhouette IoU down to 0.59 against a 0.86 gate | visible at the desk, which is the opening shot |
| 4 | `swift test` is **red**: 46 failures, all Voss assets | shipped red |
| 5 | The installer waived every gate that would have caught 1–3 | the process failure behind all of it |

## 1. The rear hemisphere is a front view

Every `n`, `nnw` and `nw` cell — standing idle *and* walk, 36 cells — renders
Voss facing the camera: face, open coat, shirt and tie all visible. Walk him
up-screen and he moonwalks toward you. With east-side mirroring this covers
`.north`, `.northNorthWest`, `.northWest`, `.northNorthEast` and `.northEast` —
**5 of the 16 facing bins**, and `.northEast` is the office desk's primary view.

This is in the masters, not the raster stage.
`ArtSource/Generated/Characters/Detective/PreRendered3DV19/Frames/voss_idle_n_*_chroma_v19.png`
are all front renders, even though `Anchors/voss_anchor_back_chroma_v19.png` is a
correct back view. The generator ignored the back scaffold for the north
directions; the prompt contract at `ArtSource/Prompts/character_imagine_portrait_v19.md`
is where that has to be fixed before any regeneration.

Measured with the installer's own `_rear_forbidden_fraction` (fraction of body
pixels matching a front-only material):

| cell | V19 shirt / skin | V18 `110530Z` | V17 `162446Z` |
|---|---|---|---|
| `idle_n_00` | **1.48% / 4.30%** | 0.00% / 0.00% | 0.00% / 0.00% |
| `idle_nnw_00` | **3.14% / 5.68%** | 0.00% / 1.22% | 0.00% / 0.00% |
| `idle_nw_00` | **2.25% / 5.15%** | 0.00% / 1.47% | 0.00% / 0.00% |
| `walk_n_00` | **0.96% / 4.11%** | 0.00% / 1.87% | 0.00% / 0.00% |

Shirt separates cleanly: a correct rear or three-quarter-rear cell paints **no**
front shirt at all. Skin is noisier — hands swing into view on a three-quarter
back — so skin is only diagnostic on the pure `n` cells.

Caveat for any rollback: V18 `110530Z` is not clean either. Its
`voss_standing_idle_n_03` flips to a front view for one frame of the four-frame
breath loop (4.32% skin), so the back-facing idle blinks a face once per cycle.

## 2. The walk cycles are not cycles

The eight frames per direction are independently generated stills at different
framings, poses and body scales — not phases of one gait. Measured over the
installed payload against the pipeline's own gates:

- **crown jitter 19.5px** on the 512 canvas, against a **≤2px** gate. At the
  180×180 display size that is ~7 screen pixels on a ~70px figure: the head
  wanders about a tenth of body height, frame to frame.
- **head scale pulse 1.39×**, **torso pulse** past 1.25× — the actor grows and
  shrinks inside a single cycle.
- **stride phase**: a real 8-frame cycle peaks twice (two steps). 7 of 9
  directions peak 3–4 times, with stride spread swinging e.g. `s` =
  `[50, 100, 39, 32, 46, 50, 39, 39]`.

Confirmed at the source: the green-screen keyframes in `PreRendered3DV19/Frames/`
are eight different framings of eight different poses. No registration or
re-ordering pass can fix this — the frames do not belong to one another.

For context, V19 is the **worst** archived payload on crown jitter; every prior
version sits at 4–7px.

## 3. Seated desk idle

`VossSeatScaleTests` measures the seated idle against its own neutral pose:
silhouette IoU falls to **0.59** (gate 0.86) and centroid drift reaches 6px
(gate 2px). The eight seated "breath" frames are unrelated poses, so Voss
twitches at the desk through the opening scene.

## 4. The suite is red

```
swift test --scratch-path <path outside iCloud>
→ 369 tests, 46 failures — all Voss assets
```

- `VossSeatScaleTests.allSeatedAndTransitionCellsMeetBakedAssetGates` — 44
  issues: head width outside 19...29 (3 cells), SE head-width ratio outside
  0.90...1.10 (12), neutral centroid drift > 2px (13), neutral-mask IoU < 0.86
  (14), clip-wide head drift > 1.30 (2).
- `VossWardrobeColorTests.rearCellsDoNotPaintFrontGarmentsOntoVossBack` — 2
  issues: *"processed idle N has 0.096 of body pixels near front-only shirt"*
  and *"processed walk N has 0.012"*, against a ≤0.005 gate.

Scoring every archived payload against the same seat gates:

| payload | seat gates | crown jitter | head pulse |
|---|---|---|---|
| **V19 (installed)** | 44 fail | 19.5px | 1.39× |
| `v18-20260809T110530Z` | 1 fail | 6.0px | 1.00× |
| `v18-20260809T094502Z` | 1 fail | 0.0px | 1.00× |
| `v17-20260808T162446Z` | **pass** | 4.0px | 1.24× |
| V13 | 7 fail | 5.0px | 1.15× |

The two 0.0–6.0px V18 entries are the **upper-body-freeze** bakes — stable, but
they are the "sliding legs under a locked torso" look previously rejected. V17
passes the gates but carries the flat monochrome wardrobe.

## 5. How it shipped: the waivers

`_filter_v19_stage_errors` in `install_voss_v19.py` waived the Python-side
equivalent of every gate above. As shipped it accepted:

| waived condition | gate | waiver allowed |
|---|---|---|
| walk crown jitter | ≤2px | **≤36px** |
| head scale pulse | 1.0× | ≤1.45× |
| torso scale pulse | 1.0× | ≤1.80× |
| planted-foot / foot-lead alternation | — | **skipped entirely** |
| seated idle centroid drift | 2px | ≤40px |
| seated neutral IoU | ≥0.86 | **≥0.40** |
| stand-up crown retreat | ≤4px | ≤80px |
| rear key paints shirt on the back | >0.1% fails | **≤2.5% waived** |

That last row is the one that shipped defect 1. The core V16 gate fires at
0.1%; V19's rear cell measures 1.479% — 14× over — and the ≤2.5% waiver let it
through. The strongest signal was suppressed separately: `validate_staging`
overrides `_rear_forbidden_fraction` to return 0.0 for the tie, so the rear
cell's **14.88% tie** coverage was never compared. The tie suppression itself is
justified (V19's black tie is genuinely indistinguishable from charcoal
trousers) — but nothing replaced the signal it removed.

Two structural problems compounded it:

1. **The rear check samples one cell.** `install_voss_v16.py:1143` reads only
   `voss_standing_idle_n_00.png`. The other 35 rear cells were never measured.
2. **The Python and Swift gate sets diverged.** Waivers looser than their Swift
   counterparts cannot make an install succeed — they only move the failure from
   the installer to a red suite *after* the runtime has been replaced.

## Guardrail installed

`ArtSource/Processing/install_voss_v19.py` only — no assets touched.

- **Waivers narrowed** to `Swift gate + a small raster margin`: crown jitter
  36 → 6px, head pulse 1.45 → 1.15×, torso pulse 1.80 → 1.25×, centroid drift
  40 → 6px, IoU 0.40 → 0.80, crown retreat 80 → 8px, head drift 2.0 → 1.35×,
  seated height 145...175 → 148...162, rise 30...55 → 36...52.
- **Removed outright**: the ≤2.5% rear-shirt waiver, the blanket `planted-foot`
  skip, and the "does not hand off from seated neutral" skip. Those are
  correctness, not craft.
- **Added `_validate_rear_hemisphere`**: measures shirt (all 36 `n`/`nnw`/`nw`
  idle and walk cells) and skin (the 12 pure-`n` cells) against the unsuppressed
  core function, after the waiver pass, so no waiver can reach it.

Verified against three payloads:

| payload | result |
|---|---|
| V19 (installed) | **FAIL — 41 cells rejected** (would have blocked the install) |
| V18 `110530Z` | FAIL — 1 cell (`idle_n_03`, the real one-frame face flip) |
| V17 `162446Z` | **PASS** — 36 rear cells clean |

`python3 ArtSource/Processing/test_voss_v19_pipeline.py` → 13 tests OK.

## Runtime code: no defects found

`DetectiveActorNode.swift`, `ActorLocomotion.swift` and
`ActorLocomotionPacing.swift` were reviewed against the symptoms and are sound:
the 15 Hz tick loop, one authored frame per tick, the 16-bin facing resolve with
hysteresis, east-side mirroring, gradual standing turns, and the
engine-derived pace all check out. `sitDown()` playing
`standUpTextures.reversed()` is correct — the authored `voss_sit_down_*` cells
are byte-identical to the reversed stand-up strip, and `VossSeatScaleTests`
asserts exactly that.

One dead asset, harmless: all 16 `voss_seated_arms_*` cells are fully
transparent. `foregroundArms` is kept hidden (`applySeatedPose` sets
`alpha = 0`, `isHidden = true`) because the NE rear view bakes the hands into
the body cell, and the installer explicitly skips that atlas as "transparent
compatibility cells".

## Recommended next step

The root cause is generation, so the only true fix is to regenerate the V19
masters with the prompt contract corrected so the north directions actually use
`voss_anchor_back_chroma_v19.png`, and so each direction's eight frames come
from one continuous motion rather than eight independent draws. Until then the
narrowed installer will refuse to install a payload with this class of defect.

If an interim rollback is wanted, `v18-20260809T110530Z` is the strongest
archived payload (correct rear views, 1 seat-gate failure, no scale pulse), with
the two caveats above: the locked-torso gait, and the one-frame face flip in
`voss_standing_idle_n_03`.
