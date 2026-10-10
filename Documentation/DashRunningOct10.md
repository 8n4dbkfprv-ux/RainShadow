# Dash running gait — October 10

Dash now changes subsequent movement in the same turn to a dedicated running
cycle. Its existing activation gesture still plays first. Ordinary walking,
including VossCHMF and BearGuardian's approved walk payloads, is unchanged.

## Presentation and rules

A new optional `CombatBudget.dashed` field records the accepted Dash. It survives
partial moves and save/load and resets with the next turn's budget. Old saves
without this field load with ordinary walking. Distance allowance and action
costs are unchanged; the flag only selects presentation.

Human running uses a forward lean, bent knees, longer strides, alternating arms
and readied sword/bow handling. Independent mail and helmet layers share the body
poses and registration. Bear running uses a diagonal trot with longer paw sweeps,
lifted swing paws and a small body rise/fall. Each has 16 poses in 16 facings.

The combat director plays certified routes through the existing integral
`Movable` stepping path used by combat enemies. A smooth rate envelope increases
from 0.55 to 1.65 of the normal movement profile, then decreases near arrival.
Pose phase comes from actual projected distance travelled, not elapsed time.
The stride conversion uses the authored support sweep and fixed sprite density:
0.70 / 0.45 metres per human cycle; 0.65 / 0.46 per bear cycle. Human footstep
contacts reuse the existing sound/cadence gate. A 0.12-second recovery blends
back to the standing body. Short moves spend most of their time accelerating
and stopping instead of reaching full running speed.

Pause, inventory and Examine stop both movement and pose progression. Input stays
locked through recovery. Enemy Dash starts its selected route after activation.
Stealth's existing movement slowdown and observation rules remain in force.
Burning effects follow the visible running body. Accepted movement is checkpointed
once; reload retains its endpoint, spent allowance and Dash flag without replay.

No navigation, pathfinding, projection, shader or viewport port was modified.

## Art authority

Live Blender MCP appended independent copies of the existing human and bear
production scenes. Only new action poses were authored; geometry, rig topology,
materials, UVs and existing animation bundles were preserved. The original
`Wharf_Ladder_Day` scene was restored after rendering.

`ArtSource/Blender/RunOct10/` contains the human backup, bootstrap, solver/pose
recipes, baked `Human_Run_Animated.blend`, render plan and passes, indexed staging,
review sheets/GIFs and validation. Its `Bear/` folder contains the equivalent
bear files, including `Bear_Run_Animated.blend`. These local source artifacts
follow the repository's ignored-art policy. Packaging lives in
`ArtSource/Processing/package_human_run.py` and `package_bear_run.py`.

`RunAnimationSet` pins the six additive runtime bundles: HumanRun, HumanRunSword,
HumanRunMail, HumanRunHelmet, HumanRunBow and BearGuardianRun. The body and gear
retain their existing palette families, canvas, density and ground pivots.

The human pose loop closes exactly, with foot-target error below 0.0000001
Blender units and wrist separation below 0.0000005. The bear loop also closes
exactly, with paw-target error below 0.0000002. Human neutral/ID mask overlap is
1.0. Every bear facing has 16 distinct poses; all human facings are checked too.

## Verification

- 39 focused Swift tests pass, covering the new assets and gait, legacy budget
  decoding, Dash persistence, faster integral stepping to the same endpoint,
  normal movement profiles, existing enemy tactics and character appearance.
- macOS and iOS Simulator Debug builds pass.
- Native combat passes 183 checks across unarmed, sword, armor, bow, armored bow,
  concealed and bear setups, plus actual enemy Dash. This covers distance-driven
  poses, ground endpoints, unchanged route charges, recovery cleanup, pause,
  inventory and saved Dash state. Results: `output/run-animation-oct10/`.
- Movement-preview/action-bar regression passes 33 checks.
  Results: `output/run-movement-oct10/`.

Launch `Play Combat.command`, enter combat, press G, wait for Dash activation,
then click ground. Movement for the rest of that turn uses the new gait; the
next turn returns to the ordinary walk unless Dash is used again.
