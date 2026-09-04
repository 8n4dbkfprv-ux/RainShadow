# Replacement Voss V11 — animation handoff in progress

Follow-up: the user approved projection-preserving seated sizing. V12 uses this
unchanged V11 geometry; see `ImportedVossReplacementRuntimeV12.md` for the new
registration contract, production staging and installation status.

Status on 2 September 2026: **not installed**. The user approved correcting the
animation/seat-scale failures found during V10 staging. This pass preserves
the replacement mesh, UVs and all V10 material assignments, including the
user's V09 edits. No head-size or skull-shape change has been made.

## Authority and completed changes

Builder: `ArtSource/Blender/build_meshy_voss_replacement_animation_v11.py`.
Derivative: `ArtSource/Generated/Characters/Detective/ImportedVossReplacementAnimationV11/meshy_voss_replacement_animation_v11.blend`.
The accompanying `animation_authority_v11.json` fingerprints the exact source,
mesh, UVs, assignments and output. The original V09 and frozen V10 are untouched.

- The four-phase idle now combines breathing and arm settling in quadrature.
  The former single-sine loop repeated its neutral pose at phases 0 and 2.
- The walking knee-recovery term goes to zero at the passing poses. Forearm
  recovery retains distinct outgoing/returning phases. The NNW native foot
  sequence is now `RRRLLLRR`; all directions exchange feet and close the loop.
- NE/SE source views render their western counterparts and mirror the paired
  source/mask. Their endpoints match NW/SW mirrors pixel for pixel. Subsequent
  runtime inspection found the office's legacy `ne` filename actually uses NW
  handedness, not mirrored NW; V12 undoes the NE pair's mirror before install.
- The non-installing V11 processing trial omits V22's phase-00 idle silhouette
  lock and linear stand-up width warp. Those transforms were authored for
  independent stills and interfere with a coherent rig.

Renderer: `ArtSource/Processing/render_meshy_voss_replacement_v11.py`.
Its optional `MESHY_VOSS_V11_CLIPS=walk` re-renders/finalizes just that clip;
otherwise it covers the complete 168 authored poses and 36 reverse sit-downs.
Always finish the Blender render before starting the Python finalization pass.

## Measured checks

The full material audit covers all 204 source/mask pairs and passes all 68
strict rear-topology checks. The native geometry diagnostic in `GeometryTrial02`
contains all 248 compatibility cells. All nine standing directions retain four
distinct phases and all nine walks retain eight. Native foot exchange, loop
closure, height and registration checks pass.

**This is a nearest-render diagnostic, not a successful Super xBR staging run.**
It cannot be installed. Full production rendering, exact indexed/RGBA round
trip, Swift geometry checks and transactional installation are still required.

Five V11 regressions cover mesh/UV/mask preservation, exact facing endpoints,
every idle/walk phase, foot exchange and context restoration. The five earlier
V10 handoff regressions also pass. All 250 installed Voss files remain identical
to V10's pre-install audit fingerprint. Active masters and palette are unchanged.

## Remaining scale problem and decision

The legacy installer fits every seated pose to 155 pixels and every standing
pose to 200 pixels, independently. A real orthographic seated pose changes its
projected height with its facing, because the feet extend along the ground.
Normalizing each bounding box rescales the head as well as the body.

Measured V11 source body heights (shadow excluded):

| View | Standing source height | Seated source height | Head scale caused by independent 155/200 fitting |
|---|---:|---:|---:|
| NE (NW mirror) | 858 | 577 | 1.152× |
| SE (SW mirror) | 927 | 951 | 0.755× |
| N | 888 | 553 | 1.245× |

Separately, the model's actual upper head is about 36.46 canvas pixels wide in
SW and 33.10 in NW at the existing standing scale. That exceeds the older
18–29-pixel seat-head band even without the sizing artifact. A top-10%-silhouette
measurement also includes shoulder pixels in some poses: SSW walking still
reports a 1.464× pulse in the native diagnostic. Do not call that proof of
changing skull geometry.

The five remaining diagnostic failures are the SSW head-band pulse, all three
seat-head width bands, and NE's clip-wide head-width drift. No threshold was
loosened and no failed output was installed.

A parameter sweep tested a compact feet-under-chair pose while keeping one
projection scale. The numeric best (thigh 45°, shin 120°) meets the projected
height target, but visual review shows **kneeling**, not sitting. It was
rejected, is only under `SeatPoseTrial`, and is not in the V11 Blender authority.
The diagnostic script is `ArtSource/Blender/measure_meshy_voss_seat_v11.py`.

Reducing the head alone cannot remove the per-pose resizing problem. The next
decision is whether to preserve the model's head proportions and adapt seated
sizing/registration to a consistent projection scale. That changes the current
seat-size contract and needs explicit user agreement. If approved, retain strict
per-direction measured bounds, head-size consistency, pose/facing validation,
seat registration, exact reverse transitions and all-phase coverage; inspect
the chair/desk handoff in the game before installation.

## Reproduce the current diagnostic

```sh
python3 ArtSource/Processing/test_voss_replacement_v10.py
python3 ArtSource/Processing/test_voss_replacement_v11.py
python3 ArtSource/Processing/review_meshy_voss_animation_v11.py --fast --out GeometryTrial03
```

The review command refuses an existing destination and never writes runtime
assets. V10's installer remains blocked; there is no install command for V11.
