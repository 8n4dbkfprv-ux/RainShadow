# Imported Voss replacement manual masks — V09

## Outcome

V09 freezes the user's manual material edits from
`meshy_voss_replacement_surface_v09.blend` as exact face indices, replays them
onto the clean V08 surface/rig authority, and regenerates the complete native
indexed animation set. It passes the full 204-frame categorical-mask audit,
but installation exposed a stricter runtime requirement: even one shirt/tie
index is forbidden in NW/NNW/N views. V09 remains isolated and uninstalled;
[V10](ImportedVossReplacementRuntimeV10.md) carries the measured 105-face
rear-collar correction and the installation record.

## Authority

The supplied manual blend is:

`ArtSource/Generated/Characters/Detective/ImportedVossReplacementSurfaceV08/meshy_voss_replacement_surface_v09.blend`

Its SHA-256 is
`2f7db5f8122ed81b3f52e270e83d84407284353430369c0fba293bb665952c8c`.
The manual assignment SHA-256 is
`66a528856ede9a54de003410c5fb7661852410e98f9636ee7cbd981d9e46fa64`.

`export_meshy_voss_replacement_manual_v09.py` validates that the material slots
remain in IE order, geometry/topology and UVs match V08, all vertices remain
weighted, and the four retargeted actions are present. It then freezes every
face index into `manual_material_authority_v09.json`.

To avoid accepting accidental shader, rig or viewport edits, only those face
assignments are replayed. `apply_meshy_voss_replacement_manual_v09.py` starts
from the exact clean V08 blend, detaches the mesh data, writes the categorical
face layer through BMesh, retains V08's masked-value surface nodes and actions,
and writes:

`ArtSource/Generated/Characters/Detective/ImportedVossReplacementSurfaceV09/meshy_voss_replacement_surface_v09_authority.blend`

Its SHA-256 is
`57a8aefb978eaecf4db8c850c2887c1627f594084bcc780be5d4108eff0fe25b`.
A fresh Blender reload reproduces the exact manual assignment hash.

## Manual changes

V09 changes 5,706 of 62,375 faces relative to V08. Most changes refine the
coat/trouser boundary:

| transition | faces |
|---|---:|
| trousers -> coat | 3,969 |
| coat -> trousers | 1,498 |
| tie -> coat | 158 |
| hair -> skin | 34 |
| skin -> hair | 30 |
| shirt -> coat | 9 |
| coat -> hair | 6 |
| coat -> skin | 1 |
| shirt -> tie | 1 |

Final face counts are:

| material | faces |
|---|---:|
| shoes | 7,174 |
| shirt | 470 |
| tie | 201 |
| skin | 1,983 |
| trousers | 18,025 |
| coat | 32,072 |
| hair | 2,450 |

The twelve-direction proof shows the revised boundary consistently in all nine
standing and all three seated directions. All seven material regions still
survive the 64-row indexed reduction, the front shirt/tie aperture remains
visible, and both sampled and complete pure-rear checks pass.

## Full audit

V09 contains 168 authored master/mask pairs and 36 sit-down pairs derived as
exact stand-up reversals. The audit proves:

- all 204 masks are complete categorical P-mode images;
- all 204 active-row and 204 fitted-preview indexed frames round-trip exactly;
- all eight walk phases remain distinct in all nine directions;
- all twelve stand-up phases remain distinct in all three directions;
- standing idle resolves to three-four native planes and seated idle to five;
- raw-render and final-mask rear failures are both zero;
- all 250 installed Voss files remain byte-for-byte unchanged.

The complete CIE94 fit remains `[138, 248, 144, 159, 138, 100, 22]`, review
only. At matching SW orientation the active-row body remains 26 pixels wide,
with 36.55% of pixels in deep shades 9-11; CHMC4 measures 26 pixels and 34.12%.

Review outputs are under
`ArtSource/Generated/Characters/Detective/ImportedVossReplacementSurfaceV09/`:

- `material_mask_direction_review.png`
- `native_v05_replacement_bg_comparison.png`
- `FullAnimationAudit/native_idle_walk_review.png`
- `FullAnimationAudit/native_seat_chain_review.png`
- `FullAnimationAudit/depth_cue_comparison.png`
- `FullAnimationAudit/full_animation_audit.json`
- `manual_material_authority_v09.json`
- `manual_material_replay_v09.json`

There is intentionally no install command in this proof. A runtime replacement
must transactionally move the atlas payload, raw indexed bundle, exact masks
and chosen gradient rows together.
