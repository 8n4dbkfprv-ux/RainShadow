# Combat defeat presentation — October 8

A lethal/knockout hit now starts an eighteen-frame collapse at the action's existing impact marker. The actor falls backwards, settles on the ground, and holds the last pose. Surviving hits keep their existing recoil. Turn progression and aftermath wait for the collapse to finish; tactical pause freezes the animation. Damage and initiative rules are unchanged.

The six `HumanDefeat` bundles contain the body plus registered sword, mail, helmet, bow and arrow layers, each with 288 frames (18 poses × 16 directions). `DefeatAnimationSet` pins their payloads. These are additive assets: approved VossCHMF, LilaSentinel, normal attacks, stealth, reactions and Bear Form resources are unchanged.

`CharacterAppearanceNode` exposes the new human `.die` action through the existing equipment/palette and per-layer lighting/stencil path. `TacticalCombatDirector` creates one defeat presentation per actor, unregisters the defeated actor from navigation, hides health/selection decorations and competing poses, and samples a clamped terminal animation clock. Fatal melee, ranged, burning and explosion damage all enter the same impact handler. A fatal overflow out of Bear Form waits for the existing human reversion before collapsing.

An unfinished combat save already records the resolved knockout. Loading it displays the resting pose immediately; it does not replay damage, collapse, turn costs or loot. Enemy bodies remain visible after encounter cleanup for the lifetime of the loaded area, including subsequent dialogue and encounters. They are presentation nodes, not navigation blockers or loot containers; leaving and reloading a completed area does not persist them. Current Wharf Ladder encounters are nonlethal: a defeated Voss remains down through the loss narration, then recovers when that aftermath is acknowledged.

## Art authority

`ArtSource/Blender/DefeatOct08/Before_Defeat.blend` is the incremental backup. The source was cloned from the approved human knockback scene through live Blender MCP; mesh topology, proportions, UVs and materials were preserved. The first eight collapse poses use the established fall; the new continuation lowers the torso and head onto the ground and settles carried weapons. Front/side/perspective views were inspected during authoring.

`Defeat_Pose_Source.py`, `source_poses.json`, `pose_metrics.json`, `Defeat_Authored.blend`, `render_plan.json` and `render_mcp_source.py` record the new action and live-MCP render recipe. The maximum wrist discontinuity measured below 0.000001 m. `ArtSource/Processing/package_human_defeat.py` audits render masks, packages the body and all equipment layers with the existing 160 px canvas, (80,60) pivot and 175.78125 display size, and creates review GIFs/sheets. Run `--install` only after reviewing the staged output and updating the pinned hashes.

## Verification

`DefeatAnimationTests` checks the clamped clock, complete registered equipment in all directions, meaningful body movement and a nonempty final floor pose. The dedicated live QA mode is `RAINSHADOW_QA_DEFEAT_ONLY=1`, with output selected by `RAINSHADOW_QA_COMBAT`. It exercises enemy melee/arrow/blast knockouts, armoured player defeat, fatal burning, fatal Bear Form overflow, pause, combat cleanup, saved knockouts and aftermath recovery.

Validated October 8: 94 targeted Swift tests passed; macOS Debug and iOS Simulator Debug builds succeeded. The live macOS run passed 65 checks across sword, arrow, armoured player, burning, barrel blast and Bear Form defeat. Directional contact sheets, registered equipment previews and in-game settled poses were reviewed. All sixteen body directions have eighteen distinct frames; render-mask overlap was 100%. Reports and previews are in `output/defeat-oct08`.
