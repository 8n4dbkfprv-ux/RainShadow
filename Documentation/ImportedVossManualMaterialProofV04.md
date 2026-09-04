# Imported Voss manual materials — proof V04

## Authority

The user manually edited
`ArtSource/Generated/Characters/Detective/ImportedVossMaterialProofV03/meshy_voss_material_proof_v04.blend`.
Its SHA-256 is
`91954d9f4b91edcfe4bbd6d0a93338e268c4b44049e1087d98f4aa54a9837a66`.
This blend, rather than the V03 coordinate classifier, is the V04 material
authority. The source FBX, V02 retarget proof, V03 proof and installed runtime
were not modified.

`export_meshy_voss_manual_materials_v04.py` freezes every assignment as exact
rest-mesh polygon indices in `manual_material_authority.json`. The geometry hash
`3ed0c8bf3db9335649dda621a301766190f0aeb5cc0f23457226d7eedfdedf39`
pins those indices to the unchanged 5,149-vertex / 10,310-face mesh.

## Manual material inventory

| mask | material | faces |
|---:|---|---:|
| 1 | shoes | 855 |
| 2 | shirt | 224 |
| 3 | tie | 123 |
| 4 | skin | 1,277 |
| 5 | trousers | 3,315 |
| 6 | coat | 4,201 |
| 7 | hair | 315 |

All faces are assigned once, all seven categories are present and no hair face
shares an edge with a coat face. The hair selection comprises a 294-face main
cap plus small temple-side patches of 8, 6 and seven single faces. Those small
patches are on the head at local height 155.96–158.82 and are not visible as
detached islands in the seven idle renders. They remain an all-animation review
item rather than being silently discarded from the user's manual authority.

## Reproducibility

`apply_meshy_voss_manual_materials_v04.py` replays the frozen indices onto the
clean V02 rig and writes `meshy_voss_material_proof_v04_rebuilt.blend`. It
reconstructs all 10,310 assignments once and reproduces the authority's exact
face counts and geometry hash.

Seven rebuilt material-ID renders were compared with the authority renders.
Fourteen source files were inspected: categorical output is unchanged except
for three anti-aliased boundary pixels across the N and W raw masks. The SW
material labels used by the indexed proof are identical. Lit Eevee pixels vary
slightly between render sessions, as expected; material ownership does not.

## Native proof

The seven S/SW/W/WNW/NW/NNW/N idle diagnostics show a compact manual hair cap
with no hair on the clothing. The SW proof encodes successfully at exactly 64
body rows and 27 pixels wide. All seven materials and the fixed shadow survive:

| label | native pixels |
|---:|---:|
| shoes | 114 |
| shirt | 51 |
| tie | 24 |
| skin | 64 |
| trousers | 193 |
| coat | 540 |
| hair | 45 |
| shadow | 369 |

The active Voss gradient rows remain unchanged, and all 250 installed Voss
runtime files fingerprint identically before and after the proof.

## Full animation and native indexed audit

`render_meshy_voss_full_material_audit_v04.py` renders the complete V23 action
vocabulary from the manual authority into an isolated audit root: 168 authored
masters (36 idle, 72 walk, 24 seated-idle and 36 stand-up) plus 36 sit-down
masters copied as the exact reverse of stand-up. All 204 beauty masters have a
strict P-mode categorical material mask. No active master or runtime atlas is
used as an output.

`audit_meshy_voss_full_material_v04.py` carries all 168 authored poses through
the paired body/mask crunch and writes two complete 204-frame native indexed
inventories: one with the active Voss rows and one with rows re-fitted to V04
in CIE94. The current rows are `[138, 5, 247, 159, 138, 100, 1]`; the isolated
V04 fit is `[138, 5, 144, 159, 138, 23, 9]`. The latter is a review result only
and does not modify `ie_avatar.VOSS`.

All eight walk phases remain distinct in every one of the nine authored
directions. All twelve stand-up phases remain distinct in all three seated
directions and the rise is monotonic from about 50 to 64 native body rows. The
deliberately tiny standing breath resolves to two or three native index planes.
The seated breath is sub-pixel at this craft and resolves to one native plane
in all three directions; the seated pose itself and both transition directions
remain present.

The production camera/material gate passes silhouette width, shadow, canvas,
material coverage and source value range. Its only failure is the deliberately
strict pure-rear shirt/tie limit: eight seated-idle and two stand-up raw renders
show `0.1004–0.1008%` at the rear collar against a `0.1000%` maximum. Snapping
the categorical plane to the beauty silhouette removes enough boundary pixels
that all final masks pass, but the raw-render failure is retained in the audit
rather than waived. V04 is therefore not yet marked runtime-candidate-ready.

## Why the BG figure still reads as more three-dimensional

The perception is measurable and is not mainly caused by indexing. The
equal-height review shows that V04 already has the softer read before palette
encoding. Across the 108 standing and walk masters, V04 uses ramp shades
`4 / 6 / 10` at p5/p50/p95; the 135-frame BG reference uses `3 / 6 / 10`.
V04 therefore lacks BG's brightest small highlight band.

The matching CHMC4 southwest frame exposes the stronger difference. Its mean
same-material neighbour change is about `0.98` shade steps, versus `0.71` for
V04 with the current rows, and about 34% of its body pixels occupy shades 9–11
versus 7% for this V04 frame. BG is separating adjacent sculpted planes with
both harder light breaks and deeper local shadow. V04 uses a bare Diffuse BSDF,
a smooth cloth-heavy coat and no specular term. Re-fitting the rows raises the
full-set deep-shadow fraction and correctly re-centres tie, coat and hair, but
cannot create a highlight or plane break absent from the render.

The next art experiment should therefore be a restrained, hard specular term
on skin, hair and selected coat/lapel planes, paired with a small fill reduction
and a fresh CIE94 row fit. It should be reviewed as an isolated A/B before any
runtime install; merely increasing global contrast would crush the dark brown
wardrobe without adding the missing geometric cue.

Review outputs:

- `FullAnimationAudit/native_idle_walk_review.png`
- `FullAnimationAudit/native_seat_chain_review.png`
- `FullAnimationAudit/depth_cue_comparison.png`
- `FullAnimationAudit/rear_trim_diagnostic.png`
- `FullAnimationAudit/full_animation_audit.json`

All 250 installed Voss runtime files fingerprint identically before and after
the full audit.

## Scope boundary

V04 is a reproducible manual material authority with complete all-phase and
native-indexed review. It remains an isolated proof: the active character
masters, active gradient rows and installed runtime are unchanged. The raw rear
collar threshold and the measured diffuse-only depth gap are the two remaining
art decisions before a transactional runtime candidate should be built.

## Reproduce

```sh
/Applications/Blender.app/Contents/MacOS/Blender --background \
  ArtSource/Generated/Characters/Detective/ImportedVossMaterialProofV03/meshy_voss_material_proof_v04.blend \
  --python-exit-code 1 \
  --python ArtSource/Blender/export_meshy_voss_manual_materials_v04.py

/Applications/Blender.app/Contents/MacOS/Blender --background \
  ArtSource/Generated/Characters/Detective/ImportedVossRiggedProofV02/meshy_voss_retarget_proof_v02.blend \
  --python-exit-code 1 \
  --python ArtSource/Blender/apply_meshy_voss_manual_materials_v04.py

/Applications/Blender.app/Contents/MacOS/Blender --background \
  ArtSource/Generated/Characters/Detective/ImportedVossMaterialProofV03/meshy_voss_material_proof_v04.blend \
  --python ArtSource/Processing/render_meshy_voss_full_material_audit_v04.py \
  --python-exit-code 1

python3 ArtSource/Processing/render_meshy_voss_full_material_audit_v04.py
python3 ArtSource/Processing/audit_meshy_voss_full_material_v04.py
```
