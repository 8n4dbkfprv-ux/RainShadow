# Imported Voss replacement model — V08

## Outcome

V08 replaces the earlier imported Voss proof geometry with the user's second
rigged Meshy FBX, retargets the existing Voss animation set, authors complete
seven-region IE material masks, and preserves selected texture depth inside
those regions. The result passes the complete 168-authored / 36-exact-reverse
native indexed audit and is runtime-candidate-ready.

The candidate remains isolated. No runtime atlas, active master, or active
gradient row was installed or changed.

## Source and retarget

The source is:

`/Users/laurensvanoorschot/Downloads/Meshy_AI_Character_output-2.fbx`

Its SHA-256 is
`14638649cd06045799ef32ba642d649f400d881afe0d1da45ff5c4442e84fe3a`.
The FBX contains a 31,198-vertex / 62,375-triangle character mesh, one packed
2048x2048 base-colour texture, one UV set, and a 24-bone Meshy rig. All 31,198
vertices are weighted and the per-vertex weight sums remain normalised.

`build_meshy_voss_replacement_v06.py` imports the exact FBX, discards the
unrelated cube, retargets the existing Voss idle, walk, seated-idle and stand-up
actions, fits the same 1.82-unit standing body height, and grounds every keyed
pose. It writes:

`ArtSource/Generated/Characters/Detective/ImportedVossReplacementV06/meshy_voss_replacement_retarget_v06.blend`

The V06 blend SHA-256 is
`37789d784b16d114b5008960d57fe4c43081ee91b8fe664a921a76282cde31b1`.
The packed source texture is retained as a diagnostic and exported beside the
blend. It is not used as an unrestricted runtime colour source.

## Categorical material regions

The FBX has a single material. `analyse_meshy_voss_replacement_v06.py` samples
its packed texture through the mesh UVs and records rest-space geometry and
bone weights per face. `author_meshy_voss_replacement_materials_v07.py` uses
those measurements to assign every face to exactly one of the seven IE avatar
regions:

| IE region | faces |
|---|---:|
| shoes | 7,174 |
| shirt | 480 |
| tie | 358 |
| skin | 1,978 |
| trousers | 20,496 |
| coat | 29,441 |
| hair | 2,448 |

There are no unassigned faces, overlapping material labels, interpolated mask
values, or index-0 holes inside the body.

The source texture wraps a small portion of the front collar around the rear.
`diagnose_meshy_voss_replacement_rear_trim_v07.py` evaluates stable face IDs in
front, rear, seated and stand-up poses. The V07 builder moves exactly 48
measured rear-visible shirt faces to coat. Those faces account for only 1.74%
of front shirt pixels; both raw and final masks subsequently have zero strict
rear-view failures.

The categorical authority is:

`ArtSource/Generated/Characters/Detective/ImportedVossReplacementMaterialV07/meshy_voss_replacement_material_v07.blend`

Its SHA-256 is
`014b24344ab1354e43a9ced4018dee29d715df9eecd2ec9f0b091850d8296e5e`.

## Masked texture depth

A flat material proof discarded the model's painted lapel folds, face planes,
and hair gradient at 64 rows. V08 keeps the V07 categorical assignments but
allows the packed texture to contribute grayscale value and restrained bump
only inside each assigned material. Source hue never reaches the output, so
the seven IE ranges remain the sole colour and recolour authority.

Each region is centred on its measured source value. A local +/-0.12 sRGB
window maps to a 0.30-2.40 value multiplier; conversion to scene-linear occurs
before configuring the shader thresholds. Bump strength is 0.10 for skin,
0.22 for hair and 0.25 elsewhere, with distance 0.04. This deliberately strong
master response is reduced by the 512-to-64-row indexed craft.

The final isolated blend is:

`ArtSource/Generated/Characters/Detective/ImportedVossReplacementSurfaceV08/meshy_voss_replacement_surface_v08.blend`

Its SHA-256 is
`91fdd9580801ff4989eee09cd49d695f1bf840077458ea1a0aa300a5fcd2d479`.
The geometry SHA-256 remains
`8e464aabe02d69c83c140fe052993ca98aa507057dd8ac0713b83822c8d38476`
through V07 and V08; surface authoring changes neither geometry nor face
material assignments.

## Baldur's Gate comparison

The comparison uses CHMC4G12 cycle 20, frame 193, matching the SW standing
direction. All figures are shown at equal body height and the candidate is
judged after the same 64-row indexed reduction used by production.

| measurement | previous V05 fitted | V08 active | V08 fitted preview | BG CHMC4 |
|---|---:|---:|---:|---:|
| body width | 27 px | 26 px | 26 px | 26 px |
| body rows | 64 | 64 | 64 | 61 |
| width / height | 0.422 | 0.406 | 0.406 | 0.426 |
| deep-shadow fraction, shades 9-11 | 10.50% | 36.44% | 37.42% | 34.12% |
| mean same-material neighbour shade change | 0.815 | 0.618 | 0.626 | 0.981 |

The replacement is materially closer in geometry: a narrower torso, stronger
shoulder/chest silhouette, swept rather than round hair mass, and an angular
projecting nose. Its SW body width exactly matches the reference. V08 also
restores a BG-like proportion of deep shadow. CHMC4 still has more abrupt local
contrast because its armour creates hard plate edges that a cloth detective
costume does not; that is a costume/geometry difference rather than a failed
mask or lost colour gradient.

The complete CIE94 fit is `[138, 248, 144, 159, 138, 100, 22]`. This is review
output only. In particular, hair row 22 retains the source hair value gradient
inside the categorical hair mask. The installed Voss rows remain unchanged.

## Full animation audit

`render_meshy_voss_replacement_v07.py` renders all 168 authored masters and
finalises 36 sit-down frames as exact stand-up reversals. The general isolated
audit then proves:

- all 204 beauty/mask pairs are present and categorical;
- all 204 active-row and 204 fitted-preview outputs make a P-mode indexed round
  trip;
- every standing body converges to the 64 +/- 1-row production contract;
- all eight walk phases remain distinct in all nine directions;
- all twelve stand-up phases remain distinct in all three directions;
- standing idle resolves to three-four native planes and seated idle to five;
- raw-render and final-mask rear failures are both zero;
- all 250 installed Voss files hash identically before and after the audit.

Review outputs are under
`ArtSource/Generated/Characters/Detective/ImportedVossReplacementSurfaceV08/`:

- `native_v05_replacement_bg_comparison.png`
- `material_mask_direction_review.png`
- `FullAnimationAudit/native_idle_walk_review.png`
- `FullAnimationAudit/native_seat_chain_review.png`
- `FullAnimationAudit/depth_cue_comparison.png`
- `FullAnimationAudit/full_animation_audit.json`

There is intentionally no install command in this proof. Runtime replacement
requires a separate explicit decision and a transactional installer so the
atlas payload, raw indexed bundle, masks and gradient rows cannot drift apart.
