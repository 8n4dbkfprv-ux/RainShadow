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
