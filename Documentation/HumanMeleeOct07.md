# Human melee animation — October 7

Voss and Wharf Ladder opponents now play an authored 12-frame melee action in
16 directions. A readied Lantern shortsword uses its synchronized weapon layer;
unarmed Voss uses the same strike without a weapon. The current splint mail and
winged helmet have synchronized overlays and keep their own palette colors.
The lookout's existing switch to a sword at melee range now animates too.
Other melee crew carry the shortsword when combat starts.

The action runs at 15 fps: wind-up, hit at phase 6 (0.4 seconds), then recovery
through phase 11. Human attacks save their accepted result immediately, reveal
HP/log changes and knockouts at the hit marker, and lock input through recovery.
The clock respects tactical pause. Reload restores the accepted outcome without
replaying the action. Human barrel strikes use the same marker to launch the
existing physical fragments; their settled poses are saved before playback.
Bear attacks keep their existing clip and behavior. Female melee art is not
claimed or substituted with the male body.

## Additive artwork

`MeleeAttackAnimationSet` pins four new indexed bundles: `HumanMelee`,
`HumanMeleeSword`, `HumanMeleeMail`, and `HumanMeleeHelmet`. Each contains 192
registered frames. The existing VossCHMF, LilaSentinel, sword, armor, bow and
arrow bundles are unchanged. New resources are included in both app targets.

The live Blender MCP session imported a separate copy of the current equipment
source, `ArtSource/Blender/SplintMailCuppedOct04/Voss_SplintMail_Animations.blend`.
Geometry, UVs, armature structure, body proportions and weapon attachment were
preserved. The new action poses the arms with connected wrist joints, retains
the neutral hand/forearm relationship, and rolls the forearm to orient the
blade. All 12 wrist gaps measured below 0.000001 model units. Fingers close on
the existing hilt. The feet retain the resting ground pivot, and the per-facing resting shadows
come directly from the approved Voss bundle at the same world registration.

Local authoring files are under `ArtSource/Blender/MeleeOct07/` (the repository
intentionally ignores the local art pipeline):

- `Melee_Current_Before.blend`: incremental backup before posing.
- `Melee_Authored.blend`: accepted baked action, plus the pose source texts.
- `FinalRenders/`: neutral/ID body passes and three body-occluded gear passes.
- `render_plan.json`: all facings/phases, projection and hit marker.
- `pose_metrics.json`: per-pose wrist continuity measurements.
- `Review/`: indexed contact sheets and directional playback GIFs.

`ArtSource/Processing/package_human_melee.py` stages these renders. It reuses
the existing human material shade calibration and fixed studio brightness
transfer. Every layer uses the same 160-pixel canvas, (80,60) bottom-left pivot,
175.78125-unit display size and original human density. No pose is scaled to fit
its bounds. Body and gear preserve their separate palettes. Thin sword edges
use a 64/255 coverage cutoff; other layers use 128/255. This keeps side-on steel
visible on the native pixel grid without modifying its rig or mesh.

Blender's persistent render cache must be disabled when switching materials
or holdout visibility: stale geometry can appear as black cuts in the helmet.
Viewport mesh evaluation is disabled during batch rendering for performance;
render visibility remains controlled independently for each pass.

## Verification

`MeleeAttackTests` validates the pinned layer inventories, registered dimensions,
animated phases in every direction and unchanged approved locomotion bundles.
The existing appearance tests still reject unimplemented female attacks and
human hit/death clips.

The focused live harness is `RAINSHADOW_QA_MELEE_ONLY=1` alongside
`RAINSHADOW_QA_COMBAT=<output-directory>`. It exercises sword, armored, unarmed,
miss, knockout and enemy attacks through scene input, including pause, hit
markers, saved outcomes, input locking, recovery and reload. The existing
barrel harness also checks that destruction waits for the melee hit pose.

The installed blobs and the macOS/iOS build resources match these hashes:

- `HumanMelee`: `42d01719486b6af5639270e8c197984375568abad8cf2415d2ec38969ab9646d`
- `HumanMeleeSword`: `8b8a0b56c1e046889114756074fc1d6ee46d692008c4535888712f3b82e4f5d9`
- `HumanMeleeMail`: `50ca546fd80d455736f68d3986dd2c9142338ead322c6259dfcce9db2e076bf0`
- `HumanMeleeHelmet`: `2ce11b105795e3e0ab35ed0edc0d44a9a1d1907811a1014511150deb081b9558`

Final verification: **56 core tests, 70 live melee checks and 42 live barrel
checks passed.** macOS Debug and iOS Simulator Debug builds pass. Built payloads
match all four installed hashes on both platforms. iOS was compiled, not played.
Live reports and captures are in `output/melee-combat-qa` and
`output/melee-barrel-qa`; the animation preview is
`output/melee-animation-preview.gif`.

## Sword swing trail

Sword attacks now draw a short pale blade trail during the cut. `SwordSwingPath`
stores blade-base and blade-tip positions sampled from the accepted Blender
action (`ArtSource/Blender/MeleeOct07/blade_trail_poses.json`). It projects those
positions with the same camera and density as the melee sprites in all sixteen
facings. The leading edge stays on the displayed animation frame; interpolation
only fills the path behind it.

`MeleeSwingTrail` shows phases 4–7, retains up to 2.2 frames of tapered history,
then fades over 0.12 seconds. Its cached texture is an independent `IEAvatarNode`
behind the body and equipment, using the existing actor lighting and per-layer
wall stencil in both rendering paths. No renderer or shader behavior changes.
The combat presentation clock controls the trail and its fade, so pausing freezes
both. Recovery detaches the layer. Sword misses also sweep; unarmed attacks do
not. The same presentation serves player and enemy sword attacks.

Trail verification: all **3 melee core tests and 103 live checks pass**, including
pause, impact visibility, equipment selection, fading and removal. macOS Debug
and iOS Simulator Debug builds pass; iOS was compiled, not played. In-game impact
captures and the armor close-up were visually inspected. Report and captures:
`output/swing-combat-qa/`.

## Situational weapon techniques

The combat bar adds four techniques for players and enemies. Select a button
or its number, then select a rival. The same button, Escape or clear-targeting
input cancels without spending an action. The description shows the tradeoff
before targeting; spent techniques stay visible. Buttons reflow on narrow views.

| Key | Technique | Rule |
| --- | --- | --- |
| 6 | Power strike | Sword, standard action; −3 to the attack roll, +3 damage on hit. |
| 7 | Feinting cut | Sword, standard action; half damage, minimum 1 on hit; weakens the survivor for −3 accuracy through the end of their next turn. |
| 8 | Aimed shot | Bow, full-round action before any movement; +4 to the attack roll, normal damage, no movement left. |
| 9 | Pinning shot | Bow, standard action; half damage, minimum 1 on hit; halves the survivor's movement allowance through the end of their next turn. |

Each technique has one use per actor per encounter, consumed even on a miss.
Invalid targets, blocked lines, wrong equipment, insufficient actions and Bear
Form reject without consuming the use, budget or random state. Ordinary attacks
remain available on later turns. Sword techniques require the readied sword;
the existing player bow animation still requires unarmored human form. Techniques
target combatants, while Fire arrow [5] retains barrel ignition and chain blasts.

Enemy selection uses current hit chance, target health, distance and existing
conditions. Power strike is reserved for healthy targets with a high hit chance;
feinting cut weakens a surviving threat. Aimed shot helps against difficult
targets when the whole turn remains, while pinning shot slows a healthy target
within closing distance. Enemies avoid repeating an existing condition and use
ordinary damage for likely finishing blows. Safe barrel opportunities retain
priority. Approach and firing-position budgets now account for Slowed using the
existing SearchMap-based navigation adapter.

`TacticalCombat` owns the rules and deterministic selection. Optional actor
fields preserve old checkpoints; spent uses and conditions are saved atomically
with damage. Status labels and combat logs reveal the accepted result at the
existing impact marker. The authored sword/bow clips and sword trail are reused;
pinning arrows land lower and both bow techniques use ordinary, unlit arrows.
TemplePlus action transitions and the GemRB navigation/rendering ports are
unchanged.

Core verification covers technique tradeoffs, natural rolls, failed-action
atomicity, costs, equipment, misses, condition expiry, save/reload, legacy
checkpoints and enemy choices, plus existing combat/bear/bow/barrel regressions.
Run the live controls and AI harness with `RAINSHADOW_QA_MANEUVERS_ONLY=1` and
`RAINSHADOW_QA_COMBAT=<output-directory>`. Captures and report live in
`output/weapon-techniques-qa/`.

Final technique verification: **59 core tests and 100 live checks passed**.
Both macOS Debug and iOS Simulator Debug builds pass. Standard and compact
targeting layouts and impact captures were visually reviewed; iOS was compiled,
not played.

## Distinct technique motion

Power Strike and Feinting Cut now use additive, authored body/sword/mail/helmet
layers in `HumanTechniques*`. Power Strike has 14 frames at 15 fps, with impact
at phase 8 and a higher wind-up. Feinting Cut has 13 frames at 18 fps: a false
start, return, then a lower cut, with impact at phase 8. Their blade trails use
separately sampled blade paths and remain aligned to the displayed frame.

Aimed Shot holds the approved fully drawn bow pose (phase 9) for an extra 0.4
seconds. Release, flight and recovery all follow that later marker. Pinning
Shot uses the separate `HumanPinningShot` clip: the approved bow action's upper
body, bow and arrow tilt together by up to 0.22 radians around the torso. Its
projectile origin is sampled from the lowered pose, and its destination remains
at leg height. Existing wrist/hand relationships and bow-string animation are
preserved; original character and equipment geometry is unchanged.

Surviving targets receive a brief, procedural recoil of their registered visual
layers around the foot pivot. Power Strike has a stronger, longer stagger.
These are cosmetic reactions, not movement or a new skeletal hit clip: the
combat/navigation position, selection ring and health label stay fixed. The
combat clock samples the reaction, freezes it on pause, clears it at recovery,
and keeps the turn locked until it settles. Misses and knockouts do not flinch.

Authoring lives in `ArtSource/Blender/TechniquesOct07/`: incremental backup,
separate melee and pinning `.blend` scenes, retained pose/render recipes,
`pose_metrics.json`, `blade_paths.json`, renders, review sheets and staged indexed
bundles. `package_weapon_techniques.py` validates and packages all 16 directions
with the established density, palette calibration, foot registration and resting
shadows. It installs only the new bundle names. `WeaponTechniqueAnimationSet`
pins the resulting hashes; `WeaponTechniqueMotion` owns presentation markers.

Blender rendering must evaluate the owning scene explicitly before every frame.
A render called with a different active scene can update the body while leaving
bone-parented equipment transforms stale. The corrected recipe switches to its
scene and updates its view layer. Geometry stays hidden from viewport evaluation
during batch renders, as in the original melee pipeline.

The remaining views use temporary evaluated-mesh caches for each pose, keeping
all armature, corrective-smooth and bevel results. The caches are discarded at
pose/material changes. A comparison against the uncached helmet pass measured
1.000 silhouette IoU and 0.35/255 mean absolute channel difference; the small
shading variation is from Cycles sampling. Rendering a bounded group of views
per timer callback also avoids repeating expensive Blender UI redraws. No
source mesh or modifier is removed or simplified.

Pinning's retained recipe sets transparent RGBA output explicitly. Its material
mask uses the same four coverage samples as the neutral pass, avoiding a
silhouette mismatch on the thin bow at the lower intermediate resolution.
The approved bow's procedural arrow visibility is baked into the new scene:
frames 11–16 hide the nocked arrow after release, then restore its resting
state. `Pinning_Authored_Final.blend` is the final authority. Packaging rejects
opaque backgrounds, clipped frames and mismatched neutral/material silhouettes.

Final animation verification: **64 core tests and 160 live checks passed**.
Both macOS Debug and iOS Simulator Debug builds pass, and both apps contain
the five exact approved payloads. The live checks cover all four moves for
player and enemy, pause, release/impact timing, visible recoil, neutral recovery,
and save/load. In-game captures are in `output/weapon-technique-motion-qa/`;
the combined animation preview is `output/weapon-technique-motion-preview.gif`.
iOS was compiled, not played.

| Technique bundle | SHA-256 |
|---|---|
| `HumanTechniques` | `36e2bfffb342fbc363ec7562cb9550a00f703fcb9a22ef48defdb850d2f26e96` |
| `HumanTechniquesSword` | `025842c2c0b42f2baf59b4e41b0eadc643037faa626e19e6864f0f1b763e1e65` |
| `HumanTechniquesMail` | `75a0a2c533046414efd33c3e4d8213f582f5ed1827441c680a40d6521b062f3a` |
| `HumanTechniquesHelmet` | `6716748cf6a36564ad5ea39b0446c71487bf0fab0b64db7ccededc2f98eeeb40` |
| `HumanPinningShot` | `313713687a53ebc2968667e2f3aa3bb055570f00d525232ba938d73e4ebb56dd` |

## Sword motion refinement — October 7

The normal cut, Power Strike and Feinting Cut were re-authored together after
review of their stiff, mostly vertical arm motion. The normal cut now crosses
from the weapon-side high guard into an opposite-side follow-through. Power
Strike uses a higher chamber, a brief load and stronger forward weight transfer.
Feinting Cut first threatens high, retracts into a low chamber and cuts across;
it no longer repeats the same wind-up backwards. The free hand stays near the
chest. Hip rotation leads the torso, with a small pelvis shift and knee flexion;
the existing foot IK keeps the soles planted. No actor/navigation displacement
is used to fake the weight shift.

The new arm solver rotates segments toward their goals without switching the
elbow's roll axis. Forearm pronation is bounded, the hand retains its neutral
relationship to the forearm, and all 39 authored poses have wrist gaps below
0.000001 model units. Exact resting-pose keys bookend every clip. Meshes, UVs,
body proportions, rig structure, gear attachment and material calibration are
unchanged. Armor and helmet are rendered with the same pose as the body.

The reviewed authority is `ArtSource/Blender/SwordRefinementOct07/`:
`Sword_Before.blend`, `Sword_Authored.blend`, `Sword_Pose_Source.py`, the retained
MCP render recipe, pose measurements, blade paths, all-direction reviews and
staged bundles. `package_sword_refinement.py` packages the eight revised
`HumanMelee*`/`HumanTechniques*` layers; `PreviousRuntime/` keeps their prior
installed versions. Approved VossCHMF/LilaSentinel, bow and Pinning Shot bundles
are preserved. The normal unarmed action shares the body motion as before.

Frame counts, playback rates and damage markers remain compatible with existing
combat and save behavior. The sword trail is re-sampled from the new actions,
starts only during the cut, and retains 1.3 frames of history instead of 2.2.
This keeps it close to the moving blade. Updated hashes in the runtime animation
sets are the current authority; earlier hash tables above document prior art.

Refinement validation: all 48 clip/direction inventories pass, with exact
neutral/material silhouette agreement (IoU 1.0). All 74 focused core tests
pass. macOS Debug and iOS Simulator Debug builds pass, and each contains all
eight pinned payloads. The normal-melee live harness passes 103 checks in
`output/sword-refinement-melee-qa/report.json`. Front/side/rear sprite sheets
and the armored in-game impact were visually reviewed. iOS was compiled,
not interactively played. Preview: `output/sword-refinement-preview.gif`.
The player/enemy technique harness also passes all 160 checks in
`output/sword-refinement-technique-qa/report.json` (263 live checks total).
