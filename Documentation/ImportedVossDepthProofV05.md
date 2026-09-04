# Imported Voss depth and rear-collar proof — V05

## Outcome

V05 closes the two open V04 art issues without changing the character's
geometry, rig, camera, UVs, weights or actions:

- restrained material-specific Principled response and lower fill produce
  clearer highlights, plane breaks and local shadow at 64-row IE resolution;
- 19 measured side/rear collar faces move from shirt to coat, eliminating the
  pure-rear shirt/tie failure without erasing the front shirt aperture.

The proof passes the complete 168-authored / 36-exact-reverse native indexed
audit and is marked runtime-candidate-ready. It remains isolated: no runtime
atlas, active master or active gradient row was installed or changed.

## Authority and invariants

`build_meshy_voss_depth_proof_v05.py` reads the exact manual V04 authority:

`ArtSource/Generated/Characters/Detective/ImportedVossMaterialProofV03/meshy_voss_material_proof_v04.blend`

Its required SHA-256 is
`91954d9f4b91edcfe4bbd6d0a93338e268c4b44049e1087d98f4aa54a9837a66`.
The isolated output is:

`ArtSource/Generated/Characters/Detective/ImportedVossDepthProofV05/meshy_voss_depth_proof_v05.blend`

Its SHA-256 is
`4fdcf644023a44308e4a9e7a3d008c52952ba6c6d06dc22e20c2bab17c178fc4`.
The geometry hash remains
`3ed0c8bf3db9335649dda621a301766190f0aeb5cc0f23457226d7eedfdedf39`:
5,149 vertices, 10,310 faces and 24 bones.

The V04 blend was saved in Edit Mode. In Blender 5.2, direct polygon material
edits made against that imported mesh appeared in memory but a save restored
the old FBX material layer. The builder therefore switches to Object Mode,
detaches a copied mesh data block and writes the face layer through BMesh. A
fresh Blender reload proves the V05 counts and exact corrected indices persist.

## Rear-collar correction

`diagnose_meshy_voss_rear_collar_v04.py` freezes each evaluated pose before
rendering exact polygon-ID colours. This avoids the FBX armature evaluation
restoring its original material layer during a diagnostic frame change.

Across front idle and pure-rear idle, seated and stand-up samples, 19 shirt
faces own every exact rear shirt pixel. They account for 670 of 18,955 exact
front shirt pixels (3.53%), all on the side/collar wrap. V05 reassigns exactly
those frozen face IDs and no coordinate range:

| material | V04 faces | V05 faces |
|---|---:|---:|
| shirt | 224 | 205 |
| coat | 4,201 | 4,220 |

All other material counts are unchanged. In the complete audit, both the raw
render masks and final categorical masks have zero rear-trim failures. V04 had
ten raw failures just above the strict 0.1000% limit.

## Depth response

V04 used bare Diffuse BSDF materials. V05 retains each base colour but gives
the seven material regions restrained Principled roughness/specular values:

| material | roughness | specular IOR level |
|---|---:|---:|
| shoes | 0.38 | 0.30 |
| shirt | 0.68 | 0.10 |
| tie | 0.38 | 0.24 |
| skin | 0.43 | 0.24 |
| trousers | 0.76 | 0.07 |
| coat | 0.50 | 0.18 |
| hair | 0.34 | 0.30 |

IOR is 1.45 throughout. The key remains 3.70; fill changes from 0.85 to 0.55
and ambient from 0.095 to 0.060. This is a material/lighting A/B: geometry,
pose, camera and shadow construction remain fixed.

At native indexed resolution, the matching SW frame improves as follows:

| measurement | V04 active | V05 active | V04 fitted | V05 fitted | BG CHMC4 |
|---|---:|---:|---:|---:|---:|
| mean same-material neighbour shade change | 0.705 | 0.764 | 0.785 | 0.815 | 0.981 |
| deep-shadow fraction, shades 9–11 | 7.06% | 8.40% | 9.73% | 10.50% | 34.12% |
| distinct material/shade indices | 50 | 54 | 53 | 55 | 50 |

Across every standing and walk master, V05 moves the active p95 shade from 10
to 11, raises the deep-shadow fraction from 11.01% to 12.65%, and increases
used material/shade indices from 61 to 66. Median shade stays at 6: the result
adds local modelling rather than lifting or crushing the whole figure.

The complete CIE94 fit is `[138, 5, 144, 159, 138, 23, 240]`. In particular,
the hair fit moves off the active row 1 and preserves the newly rendered hair
value gradient. This fitted row set is review output only; the active Voss rows
remain `[138, 5, 247, 159, 138, 100, 1]`.

The BG reference still has stronger local separation, much of it carried by a
different costume silhouette and larger shoulder/chest planes. V05 deliberately
closes part of that gap without changing Voss's established anatomy or brown
identity and without turning the coat or hair glossy.

## Full animation audit

`render_meshy_voss_depth_proof_v05.py` renders all 168 authored masters and
finalises the 36 sit-down masters as exact stand-up reversals. All 204 beauty
masters have strict P-mode material masks. `audit_meshy_voss_full_depth_v05.py`
then carries the complete set through the paired body/mask crunch and writes
204 active-row plus 204 freshly fitted native indexed frames.

The audit proves:

- all 204 master/mask pairs are present and categorical;
- all eight walk phases are distinct in all nine directions;
- all twelve stand-up phases are distinct in all three directions;
- standing idle resolves to three–four native planes;
- seated idle resolves to five native planes in every direction;
- raw and final pure-rear trim failures are both zero;
- all 250 installed Voss files hash identically before and after the audit.

Review outputs are under
`ArtSource/Generated/Characters/Detective/ImportedVossDepthProofV05/`:

- `TuningProof/v05_native_depth_comparison.png`
- `FullAnimationAudit/native_idle_walk_review.png`
- `FullAnimationAudit/native_seat_chain_review.png`
- `FullAnimationAudit/depth_cue_comparison.png`
- `FullAnimationAudit/full_animation_audit.json`

## Reproduce

```sh
/Applications/Blender.app/Contents/MacOS/Blender --background \
  ArtSource/Generated/Characters/Detective/ImportedVossMaterialProofV03/meshy_voss_material_proof_v04.blend \
  --python ArtSource/Blender/diagnose_meshy_voss_rear_collar_v04.py \
  --python-exit-code 1

/Applications/Blender.app/Contents/MacOS/Blender --background \
  ArtSource/Generated/Characters/Detective/ImportedVossMaterialProofV03/meshy_voss_material_proof_v04.blend \
  --python ArtSource/Blender/build_meshy_voss_depth_proof_v05.py \
  --python-exit-code 1

/Applications/Blender.app/Contents/MacOS/Blender --background \
  ArtSource/Generated/Characters/Detective/ImportedVossDepthProofV05/meshy_voss_depth_proof_v05.blend \
  --python ArtSource/Processing/render_meshy_voss_depth_proof_v05.py \
  --python-exit-code 1

python3 ArtSource/Processing/render_meshy_voss_depth_proof_v05.py
python3 ArtSource/Processing/audit_meshy_voss_full_depth_v05.py
```

There is intentionally no install command in this proof. Runtime replacement
requires a separate explicit decision and a transactional installer.
