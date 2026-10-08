# Trip Attack — October 8

Trip Attack is a sword technique selected with the **Trip attack** combat button.
It spends a standard action and one use per encounter, including on a miss.
A successful hit deals half normal weapon damage (minimum 1), with any eligible
Sneak Attack bonus added separately, and knocks a surviving standing human Prone.
This is a RainShadow technique built on the existing TemplePlus action budget,
not a port of BG3's Battle Master class or superiority-die/save system.

Invalid range, line, weapon, friendly target, already-Prone target and Bear Form
reject without spending actions, uses or randomness. Misses dodge normally;
knockouts use defeat presentation instead of adding Prone. Shove cannot target
an already-Prone character. Ordinary Shove and explosion falls remain cosmetic.

Prone lasts through intervening turns. Nearby attacks gain advantage; attacks
beyond melee reach have disadvantage. These sources use the existing cancellation
rules, and a Prone actor cannot threaten a ranged attacker or qualify as an
adjacent Sneak Attack ally. Further hits and misses keep the grounded pose;
arrows aim at the lower body. A knockout on the ground goes to the resting defeat
pose instead of replaying a collapse from standing.

At the start of the victim's turn, the model removes Prone and spends half of
their effective movement speed (including Slowed) through the unchanged action
budget. This opens the first movement segment, leaves half of it, and preserves
the standard action. The actor can spend that action on further movement as
usual. The deduction is saved atomically, so reloading during recovery never
charges again or refunds it. Existing conditions still expire at turn end.

The director plays the dedicated HumanTripReaction fall through phase 12, holds
its braced ground pose without locking other turns, then resumes the get-up sequence
when the victim's turn starts. Input and AI wait until recovery ends. Pause
freezes both attack and recovery. Loading before the victim's turn restores the
held pose without replaying the strike or fall; loading after the start-of-turn
transaction restores standing with the movement cost already paid.

Enemy sword users prefer Trip Attack when a healthy standing target has an
adjacent conscious ally who can exploit the knockdown, after the existing
high-accuracy Power Strike choice. They keep ordinary damage for finishing blows
and never repeat Trip Attack against an already-Prone victim.

## Art

`ArtSource/Blender/TripOct08/Trip_Authored.blend` contains the independent 16-frame
low sword sweep, authored through the live Blender MCP connection on a private
copy of the approved human rig. The character lowers their weight, cuts across
at leg height and recovers to the exact starting pose. A bounded wrist flex
keeps the blade low; the hand/forearm joint remains connected. Meshes, proportions,
UVs, materials and the existing rig structure are preserved.

`Trip_Pose_Source.py`, `pose_bootstrap.json`, `pose_metrics.json`, `blade_paths.json`,
`render_plan.json` and `render_mcp_source.py` retain the authoring and production
inputs. The MCP render recipe generates neutral, material-ID, sword, mail and
helmet passes for all 16 directions. `package_human_trip.py` validates the masks,
registers the existing palette and contact shadow, and installs four additive
HumanTrip bundles. VossCHMF, LilaSentinel and existing attack payloads are unchanged.

TripAnimationSet pins all four payloads. Playback is 18 fps, with contact at
phase 8. The blade trail uses samples from the new action and its own texture
cache key. Matching body/sword/mail/helmet frames are presented together. A
hidden attacker still uses this low cut when Sneak Attack damage also applies.

## Verification

Core tests cover hits, misses, invalid-action atomicity, costs, intervening turns,
standing movement, Slowed interaction, save/reload, legacy conditions, advantage,
AI choices, timing, registered frames, rest endpoints and protected character
payloads. The live macOS harness runs with `RAINSHADOW_QA_TRIP_ONLY=1` and
`RAINSHADOW_QA_COMBAT=<output-directory>` and checks sword, armor, hidden attacks,
misses, enemy trips, pause, held poses, reload and recovery gating.

Final validation: **110 distinct core tests** passed (120 executions, including
a repeated Sneak Attack suite). **67 dedicated Trip Attack live checks** and
**114 Shove regression checks** passed. macOS Debug and iOS Simulator Debug
builds succeeded; both contain all four exact pinned Trip Attack payloads.
Neutral/material silhouette agreement is 1.0 for all 256 frames. Every facing
has 15 distinct body poses and identical first/last rest frames. Maximum wrist
separation is below 0.000001 model units. Front, side and rear sword/armor
reviews and in-game ground/recovery captures were visually inspected.

Reports: `output/trip-oct08/report.json` and
`output/trip-shove-regression/report.json`. Animation preview:
`output/trip-oct08/trip-preview.gif`. iOS was compiled, not interactively played.


## Dedicated target reaction — October 8 follow-up

Trip Attack now selects `CombatReactionKind.tripFall` and five independent
`HumanTripReaction*` bundles (body, sword, mail, helmet and bow). The 24-frame
reaction starts with the right knee buckling and the foot sweeping inward,
then drops the hips onto one side while the open left hand braces against the
floor. The right hand retains the weapon above the ground. The loose bow arrow
is visually stowed during the reaction so the left hand is free, then restored
with the standing equipment; inventory is unchanged.

The ground pose is held at phase 12. The remaining poses bring the feet back
under the body and push up to the exact starting stance on the victim's turn.
Playback remains 20 fps and existing Prone duration, movement cost, pause and
save semantics are unchanged. Cosmetic Shove and explosion falls continue to
use their original HumanKnockback artwork. Further hits or explosions against
a Prone target retain the braced pose while any accepted displacement still
moves its registered node.

Live Blender MCP authoring is retained in `ArtSource/Blender/TripReactionOct08/`:
`Before_TripReaction.blend`, `TripReaction_Authored.blend`,
`TripReaction_Pose_Source.py`, `bake_mcp_source.py`, `pose_bootstrap.json`,
`pose_metrics.json`, `render_plan.json` and `render_mcp_source.py`.
`package_human_trip_reaction.py` validates and packages the renders. The action
uses private copies of the existing rig/meshes; no topology, proportions, UVs,
materials or rig structure changed. Every wrist stays connected, and sampled
weapon vertices remain above the ground throughout the action.

Follow-up validation: **25 focused tests** passed across Trip Attack, reactions,
Shove and explosion motion. **83 live Trip Attack checks** passed, including
sword/bow targets, armor, hidden attacks, misses, pause, save/reload, a follow-up
strike against the grounded player, and input gating during recovery. macOS
Debug and iOS Simulator Debug builds succeeded with all five exact pinned
reaction payloads verified inside each app. iOS was compiled, not interactively
played. All 2,304 render passes completed; neutral/material silhouette agreement
is 1.0, with 23 distinct body poses per facing and identical rest endpoints.
Front, side and rear equipment reviews and live ground/recovery captures were
visually inspected.

Follow-up report: `output/trip-reaction-oct08/report.json`.
Preview: `output/trip-reaction-oct08/reaction-preview.gif`.

All **114 live Shove regression checks** also passed; its cosmetic fall
and immediate recovery are preserved. Report:
`output/trip-reaction-shove-regression/report.json`.
