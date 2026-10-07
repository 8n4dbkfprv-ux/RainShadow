# Human combat reactions — October 7

Human combatants now use additive skeletal hit and dodge clips. Each has 16
facings, with 8 hit frames and 10 dodge frames. The normal flinch lasts 0.4 s;
Power Strike holds the same motion over 0.64 s and adds a stronger cosmetic
lean. The dodge lasts 0.5 s and starts 0.15 s before the accepted sword/arrow
impact, reaching its evasive pose at impact. Immediate bear attacks use the
same target response at their existing immediate damage marker.

These are presentation clocks: accepted damage, RNG, action costs, conditions,
positions, navigation and checkpoint semantics are unchanged. Tactical pause
freezes both attack and reaction. Input stays locked through reaction recovery.
Knockout still uses the existing removal presentation; no death clip was added.
Bear form retains its existing authored hit clip; the new dodge art is human.

## Asset authority

Live Blender MCP scene `Human_Reactions_Oct07`, incremental source files:

- `ArtSource/Blender/ReactionsOct07/Reactions_Before.blend`
- `ArtSource/Blender/ReactionsOct07/Reactions_Authored.blend`
- `Reaction_Pose_Source.py`, `pose_metrics.json`, `render_plan.json`,
  `render_mcp_source.py` in that same directory.
- `ArtSource/Processing/package_human_reactions.py` packages the render output.

The poses use the approved male rig, minimal-rotation arm solving and planted
foot IK. Mesh proportions, UVs and materials are unchanged. The sword, bow,
held arrow, mail and helmet follow the same rig; gear is rendered separately
with body occlusion and uses the existing equipment palette rows. Body colours
come from the actor's existing appearance. The approved Voss resting contact
shadow is registered beneath each pose.

`CombatReactionAnimationSet` pins the six new indexed bundles: `HumanReactions`
and the `Sword`, `Mail`, `Helmet`, `Bow`, `Arrow` variants. Each has 288 frames,
160×160 source canvas, (80,60) bottom-left pivot and 175.78125 display size.
Both app targets package these resources. Approved locomotion and all previous
attack bundles remain unchanged by this addition.

## Runtime

`CharacterAppearanceNode.presentReaction` selects registered body/equipment
frames. `TacticalCombatDirector` owns transient reaction nodes so player Voss
and NPCs can react without disturbing their normal actor playback. Each proxy
inherits position, height offset, depth, lighting and per-layer wall stencils.
Badges/rings follow the visible node. Recovery restores the original body;
knockout hides an active proxy. Explosion knockback moves the original actor,
which the reaction proxy follows. No procedural displacement affects gameplay.

`CombatRecoil` supplies frame timing and the small supplementary impact lean.
Dodge markers in melee/bow presentations fire once before impact. Misses never
apply damage or a hit condition. Saving records only the accepted combat result;
reaction clocks are transient and cannot replay damage after loading.

## Verification

Staged mask coverage matched on all 288 poses (minimum neutral/ID IoU 1.0).
All layers have complete frame inventories, unclipped canvas borders and exact
rest endpoints. Wrist separation remained below 0.0000003 Blender units.
All 76 combat/core tests passed, including reaction timing and payload checks.

Both macOS and iOS Simulator builds passed; all six payload hashes in each app
match the reviewed stage. Live SpriteKit QA passed 65 reaction checks (player
and NPC, melee and bow, hit and miss) and 168 technique checks, including pause,
recovery, visibility, equipment and accepted save state. Barrel QA passed 43 checks, and the ordinary/unarmed/armored/miss/knockout
melee regression passed 103 checks. Explosion checks cover the reaction proxy following knockback and no duplicate visible body.
The old spill fixture placed its click beneath the expanded combat action bar;
its firing position now starts on the opposite side so the click reaches the
world. No production HUD or navigation behavior changed for that fixture.

Preview: `output/combat-reactions-preview.gif`. Live reports and captures:
`output/reactions-qa`, `output/reactions-techniques-qa`,
`output/reactions-barrels-qa-v2`, `output/reactions-melee-qa`.
