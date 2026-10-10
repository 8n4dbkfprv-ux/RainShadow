# Shove — October 8

Select **Shove · bonus**, then click a nearby standing rival. Hovering shows the chance, push path and landing ring; invalid attempts show a red ring and a reason. Selecting Shove again cancels it. A valid attempt consumes one shove bonus action for this actor's turn, even when resisted, without consuming the TemplePlus-derived standard/move budget. This addition does not rewrite existing Hide costs or introduce a shared general-purpose bonus-action economy.

The skill roll is d20 + Athletics against 10 + the target's higher Athletics/Acrobatics. Hiding grants advantage and attempting a shove reveals the participants. There are no automatic critical successes/failures. A willing ally needs no roll. Shove deals no direct damage. These behaviors are inspired by [BG3's Shove](https://bg3.wiki/wiki/Shove); this is a RainShadow adaptation, not an imported Larian implementation.

`ShoveProfile` supplies authored strength, skills and weight separately from attack accuracy. Optional profile/turn-use fields preserve old saves. Default Voss is Strength 14, Athletics +4, Acrobatics +2, 80 kg; ordinary crew are 12/+3/+2/80 kg, lookouts 10/+1/+4/75 kg. Current Bear Form weighs 350 kg and cannot be shoved by the current humans; initiating Shove requires human form. Eligibility uses strength × 12 against target kilograms. RainShadow's distance curve is clamped to 24–80 world units (roughly 1–3 m); strength increases it and target weight decreases it.

The existing search raster certifies the straight push and clips it at walls, characters, barrels and area boundaries. A wholly blocked shove is rejected without spending randomness or the action. The maximum-distance parameter only bounds the existing RainShadow knockback query; navigation ports and their algorithms are untouched. These level-ground maps have no authored chasms or fall-damage surfaces, so Shove does not invent ledge deaths. Explosion knockback keeps its previous default distance and physics.

The model accepts the roll and landing atomically before the animation and checkpoints that result. The pusher visually steps into palm contact and recovers to its unchanged game position; the shared melee reach includes both actors’ footprints. The visible target stays at its start until the open palm reaches the impact marker. A successful shove triggers the existing decelerating impulse and the complete 24-frame fall/get-up reaction; a resisted shove uses a bracing hit reaction. Tactical pause freezes both bodies and the impulse. Turns remain locked until the target has finished standing up, including after the physical push and pusher animation have ended. This cosmetic fall never applies Prone or consumes movement. Loading an in-flight save restores the final position and spent shove without replaying it.

The lookout tries Shove when an adjacent target can be pushed beyond melee reach, a normal attack remains, and the success chance is at least 25%. It then uses its bow on success or its existing close-range behavior on resistance. Melee enemies retain their existing attack policy.

## Animation authority

`ArtSource/Blender/ShoveOct08/Before_Shove.blend` preserves the starting scene. A copy of the approved human rig was posed through live Blender MCP; no mesh, body-proportion, rig-topology or material changes were made. `Shove_Pose_Source.py`, `rest_pose.json`, `pose_metrics.json` and `Shove_Authored.blend` record the accepted action. The maximum measured wrist gap is below 0.000001 m. The character steps and leans into an open left palm while carrying the weapon in the right hand; loose ammunition is stowed during the shove.

`render_mcp_source.py` renders the baked action through the live instance. `ArtSource/Processing/package_human_shove.py` audits masks and creates five registered indexed layers: body, sword, bow, mail and helmet. Each contains twelve poses in sixteen directions (192 frames). `ShoveAnimationSet` pins their hashes, 160-pixel canvas, (80,60) pivot and existing palette contract. All facings have nine distinct body poses and matching first/last neutral poses. Approved VossCHMF, LilaSentinel, and prior attack/death payloads are unchanged.

## Verification

`ShoveTests` covers model costs, successful and resisted rolls, invalid and heavy targets, hidden advantage, save compatibility, independent standard actions, raster collision/occupancy restoration and the full animation inventory. `RAINSHADOW_QA_SHOVE_ONLY=1` enables the live macOS scenarios, using an isolated save key and the directory supplied by `RAINSHADOW_QA_COMBAT`. Outputs are in `output/shove-oct08`.

Validated October 8: 102 targeted combat tests pass; macOS Debug and iOS Simulator Debug builds pass. The final live run passes 84 checks across sword, armor, bow, resistance, hidden advantage, enemy shove-then-shoot and invalid range. Pause, costs, landing, save/reload, control layering and cancellation are covered. Final in-game contact and preview screenshots were visually reviewed; the report is `output/shove-oct08-final/report.json`.

Fall/get-up follow-up: successful shoves now select the existing full fall clip in all sixteen directions. Resisted attempts keep their bracing reaction. Verified with 15 focused core tests, successful macOS/iOS builds, and 114 live checks. The live checks capture ground and get-up phases, confirm that the completed push remains busy through recovery, freeze the grounded pose on pause, verify no extra condition or movement charge, and confirm a return to standing before the lookout shoots. Report and previews: `output/shove-fall-oct08`.

## October 10 pacing

The pusher now takes 1.10 seconds rather than 0.67 seconds. Source phases 0–3
span 0.40 seconds of preparation, phases 3–6 keep the authored 18 fps forward
push, and the remaining phases recover over 0.53 seconds. Palm contact is at
0.511 seconds (phase 5). This is an authored RainShadow timing adjustment, not
a measured BG3 animation duration.

The director already derives its approach, reaction trigger and return from
the same impact/duration markers, so the target stays still until the retimed
palm contact. Successful and resisted pushes share the clock, including enemy
shoves and every equipment layer. Target fall/get-up and displacement physics
remain unchanged. Payload hashes, rules and save outcomes are unchanged.

Validated with 17 core tests across shove, reaction and knockback suites, macOS
and iOS Simulator Debug builds, and 120 live checks covering armor, sword, bow,
resistance, hidden advantage, enemy shove-then-shoot, pause and save/reload.
Live report and screenshots: `output/shove-pacing-oct10-final/report.json`.
The old live fixture now explicitly assigns its bow enemy the archer role;
otherwise its inherited bruiser role correctly chooses a different action.
