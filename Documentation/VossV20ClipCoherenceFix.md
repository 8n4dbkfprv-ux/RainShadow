# Voss clip coherence — V20 idle and walk

**Date:** 2026-08-13 · **Baseline audited:** `2624b5fa` "Replace Voss gameplay
art with portrait-first V20" · **Verdict:** two of the three reported artifacts
were the pipeline and are fixed; the third is the master art and is not fixable
downstream.

Reported from gameplay: Voss's colour shifts between frames, he pops as though
growing, and the standing idle looks like it rotates. No master was regenerated
for this work — all 156 master and source approvals in
`approval_ledger_v20.json` were still valid afterwards, and only the 17 derived
QA review renders were re-stamped.

## Summary

| # | Symptom | Cause | Status |
|---|---|---|---|
| 1 | Wardrobe colour shifts across a loop | Palette refitted per frame | **Fixed** — 210 colours per idle loop → 63 |
| 2 | Idle appears to rotate / body drifts | Registration centred the silhouette bbox | **Fixed** — worst centroid drift 4.95px → 0.85px |
| 3 | Pops/grows when he starts moving | Idle and walk masters disagree by up to 32% | **Not fixable in the pipeline** — see below |

Everything is measured over the 112 shipped locomotion cells (40 `VossIdle.atlas`,
72 `VossWalk.atlas`). The 96 seat cells were deliberately left untouched and came
back byte-identical.

## 1. The palette was refitted per frame

`crunch._quantise_material_clusters` ran k-means (`_colour_centroids`) and a
median cut (`_region_ramp`) on **each frame's own pixels**. Deterministic, but
frame-dependent: no two frames of an animation could share a palette by
construction. A four-frame idle loop shipped **210 distinct colours** where the
palette budget is 64, and mean value swung 19.9% between adjacent phases.

Fixed by fitting one `ClipPalette` per clip over the clip's pooled pixels and
quantising every frame against it — in `crunch.crunch()` *and* in
`crunch.finalise()`, which re-imposes the palette and would otherwise refit one
pass later and undo it.

The masters also carry real exposure drift (the idle masters vary ~15% in mean
value between phases of one loop), which a shared palette alone cannot absorb:
common entries, different distribution over them. `crunch.normalise_clip_exposure`
levels each clip to its own median first, scaling all three channels by one
factor so it cannot move a hue. Median correction across the 112 frames is 2.6%;
only eight frames want more than 12%, all walk masters visibly mis-exposed
against their own gait.

| | before | after |
|---|---|---|
| worst colours in one loop | 416 | 63 |
| worst value swing in one loop | 53.6% | 11.1% |

## 2. Registration centred the bbox, not the body

`register_crunched` composited at `(FRAME_SIZE - figure.width) // 2`. The bbox is
exactly as wide as the furthest-out pixel, so a swinging arm or a flaring coat
hem pushed the whole body the other way — which reads as the character sliding or
yawing on the spot.

Now registered on the mass centroid (`body_axis_x`). Chosen by measuring bbox,
torso-band, hip-band, foot-band and mass anchors against how *still* the result
is — mean IoU between adjacent frames — rather than against any one landmark:

| anchor | idle IoU | walk IoU | worst idle drift | worst walk drift |
|---|---|---|---|---|
| bbox (was) | 0.902 | 0.787 | 1.91px | 4.95px |
| torso band | 0.897 | 0.787 | 1.11px | 4.52px |
| hip band | 0.902 | 0.779 | 1.80px | 7.57px |
| foot band | 0.885 | 0.672 | 5.31px | 27.15px |
| **mass** | 0.901 | **0.791** | **0.91px** | **0.85px** |

Two gates moved with the policy, and both moved *because* the policy moved, not
to accommodate bad art:

- `head_jitter_max` 2.0 → 6.0. The old 2.0 was what bbox-centring produced by
  construction — the head sits at the top of the bbox that was being pinned. It
  was measuring the registration, not the character.
- The bbox-centre check for idle/walk became a sanity bound
  (`body_axis_bbox_tolerance`, 8px). A walking figure with a leg thrown forward
  has its bbox ahead of its body. The seat cells keep the tight 2px bbox gate;
  `register_crunched(body_axis=)` defaults to off so they and every older
  installer are unaffected.

`processing.runtime_registration_offsets` is now empty. The two hand-authored NW
nudges patched, for two cells, exactly the drift this fixes for all 112 — and
left in place they double-corrected NW walk to 2.06px against a 2.0px gate.

## 3. The size pop is the master art

Voss changes size the instant he starts walking. Measured on the shipped art,
median rendered anatomy, idle → walk:

| direction | head | shoulder |
|---|---|---|
| s | 21px → 17px (**−19.0%**) | 71px → 67px (−5.6%) |
| wsw | 22px → 25px (**+16.3%**) | 64px → 56px (−13.3%) |
| nnw | 18px → 22px (**+25.7%**) | 66px → 56px (−15.3%) |

The cause is that the idle and walk masters are not the same character. Their
scale-free head/shoulder ratios disagree by **32.6% on wsw** and 22.2% on nnw:

| dir | s | ssw | sw | wsw | w | wnw | nw | nnw | n |
|---|---|---|---|---|---|---|---|---|---|
| head/shoulder disagreement | −2.5% | −1.1% | −9.0% | **+32.6%** | −7.4% | −14.2% | +4.2% | **+22.2%** | +0.5% |

No uniform scale can match both a head and a shoulder that disagree by 32%.
Five normalisation schemes were measured, scored as the worst error in head *and*
shoulder size across the idle/walk boundary:

| descriptor | mean | worst |
|---|---|---|
| bbox height (shipped) | 8.6% | 14.5% |
| shoulder width | 9.1% | 27.1% |
| head width | 9.1% | 27.1% |
| sqrt(area) | 8.8% | 13.6% |
| geometric mean of multiple bands | 13.4% | 33.7% |

A geometric mean of head and shoulder predicted better on paper (8.6% → 4.5%),
but **did not survive the raster**: rebuilt and re-measured it came back 9.6% →
10.2%, i.e. slightly worse. At `native_rows = 56` the head is about six pixels
across, so a correction of a few percent cannot be expressed — it rounds to the
same six pixels, or to the wrong five, and the 3.57× upscale to the 200px texture
multiplies that rounding into 3–4 output pixels.

The same resolution limit rules out letting the body height float to carry a
breath or a stride: any within-clip height travel re-rounds the head, measured at
up to **1.40×** head-width ratio on nnw. The 200px height pin is empirically the
best available behaviour at this native resolution, and was kept.

**This needs a master regeneration, not a pipeline change.** In priority order:

1. **wsw** — 32.6% head/shoulder disagreement between its idle and walk sets
2. **nnw** — 22.2%, and the worst colour drift of any clip before the fix
3. **wnw** (14.2%), **sw** (9.0%), **w** (7.4%)

`s`, `ssw`, `nw` and `n` agree to within 4.2% and need nothing. The target is that
a direction's idle and walk masters render the same character at the same size;
generating a direction's idle and walk in one pass, from one anchor, is what would
achieve it.

## Gates added

The standing idle went four asset versions with nothing gating it. The only idle
check was that every cell was 198–202px tall, which the raster forces and so
cannot fail. Four idle gates existed in the manifest
(`idle_centroid_drift_max`, `idle_neutral_iou_min`, `adjacent_crown_retreat_max`,
`head_width_drift_ratio_max`) and were never applied to a frame —
`validate_manifest_contract` only asserted the manifest *said* `2.0`.

- `_validate_motion` now runs over idle as well as walk (`MOTION_CLIPS`), with
  the gait-specific checks kept walk-only.
- New `centroid_drift_max` (2.0px), the gate that now carries the registration.
- New clip-palette gate: a clip may not carry more distinct colours than one
  palette has entries. This is exact and cheap, and directly encodes the fix.
- Swift mirrors both: `everyIdleDirectionHoldsStillAndKeepsOnePalette` is new,
  and `VossAtlasFrameMetrics.centroidX` / `VossAtlasFrame.opaqueColors` were
  added to support them.

`test_voss_v20_pipeline.py` gained a `VossClipCoherenceTests` suite that builds
its own clips from `synthetic_master()`, so no master regeneration can make it
pass or fail. Each of the three fixes has a test that fails when that fix alone is
reverted, including a control asserting that per-frame quantisation *does* overrun
one palette — so the shared-palette test cannot quietly stop proving anything.

## Verification

```bash
python3 ArtSource/Processing/install_voss_v20.py stage
python3 ArtSource/Processing/qa_voss_v20.py
python3 ArtSource/Processing/install_voss_v20.py install --confirm-runtime-replace V20
python3 ArtSource/Processing/test_voss_v20_pipeline.py
swift test --scratch-path <path outside iCloud>
```

Order matters: the stage report binds the approval-ledger hash and the install
binds the QA report to the stage, so a ledger or art change means re-running all
three. Build outside the iCloud-synced checkout — `shutil.copy2` carries xattrs
into the bundle and `codesign` rejects it.

Expected diff: **exactly 112 cells change**, 40 `VossIdle.atlas` and 72
`VossWalk.atlas`, with all 96 seat cells and every other asset byte-identical.
Anything outside those 112 means the clip refactor leaked.
