# Human Dash run refinement — October 11

The October 10 run lifted the recovering foot by roughly 26 cm, kept the pelvis
low, and held a nearly constant torso lean. This made the first strides read as
high knees and the body look rigid. The new human action lowers the recovery
arc to a measured 13.9 cm, raises the support posture slightly and halves the
vertical pelvis excursion (5 cm to 2.4 cm). Feet travel on narrower tracks with
a 60 cm support sweep instead of 70 cm.

The action now includes opposing pelvis/chest rotation, a small weight shift,
closer elbows, delayed arm swing, ankle roll at contact and toe-off, and light
tunic follow-through. Head counter-rotation keeps the gaze steadier. These are
pose changes only: meshes, proportions, materials and rig topology are preserved.
The body and all four equipment layers are rendered from the same action in all
16 directions. The approved ordinary walks, Dash activation, bear run and wind
effect remain as they were.

`CombatRunMotion.stride` converts the new 0.60 / 0.45 metre cycle through the
existing fixed sprite density. Pose progression still follows actual ground
travel, so changing the art does not introduce foot sliding by retaining the
old, longer stride. Movement allowance, navigation, speed envelope and recovery
timing are unchanged.

## Local production authority

The live Blender MCP appended the existing run scene into an independent
`Human_Run_Oct11` scene and saved `Before_Run_Revision.blend` before edits.
Bounded pose changes were reviewed from front/side views and comparison sheets
before the full render. `ArtSource/Blender/RunOct11/` holds the retained pose
recipe, bootstrap, solvers, `Human_Run_Animated.blend`, render recipe and plan,
1,536 passes, indexed staging and review sheets/GIFs. These follow the existing
ignored-art policy. The new baked action is `HumanRunRefined_run`.

`ArtSource/Processing/package_human_run.py --source-dir
ArtSource/Blender/RunOct11` stages this revision; the original default remains
`RunOct10` for reproducibility. Add `--install` only after reviewing the stage.
`RunAnimationSet` pins the five installed human payloads.

Pose validation measures maximum foot-target error below 0.0000002 Blender
units and wrist separation below 0.0000005. The sampled loop's maximum bone
matrix difference is 0.0000013 (floating-point roundoff); its foot targets
close exactly.

Re-evaluating all 17 keyed samples after baking (including the closing sample)
keeps foot-target error below 0.0000003 and wrist separation below 0.0000007.
The neutral and material-ID renders overlap exactly in every frame; all 16
facings contain 16 distinct body poses, with complete matching gear layers.

## Verification

- 39 focused Swift tests pass across run/Dash assets, budgets, character
  appearances, ordinary movement profiles and enemy tactics. The tests also
  validate the unchanged VossCHMF, LilaSentinel and BearGuardian authorities.
- macOS Debug and iOS Simulator Debug builds pass.
- Native Dash/run combat QA passes 190 checks across unarmed, sword, armored,
  bow, armored bow, concealed and bear setups, plus enemy Dash. This verifies
  distance-driven frames, endpoints, pause/inventory, recovery and save behavior.
  Results: `output/dash-run-refinement-oct11/native/report.json`.
- Side-by-side preview GIFs: `output/dash-run-refinement-oct11/comparison-*.gif`.
- Blender's original `Scene` was restored after rendering and review.
