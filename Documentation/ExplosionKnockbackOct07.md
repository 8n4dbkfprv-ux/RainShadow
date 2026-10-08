# Explosion knockback — October 7

Explosions now combine a deterministic impulse/friction trajectory with authored
human stumble and fall/recovery clips. These replace the previous 0.35-second
cubic slide and generic hit flinch on displaced human survivors.

## Movement and collision

`ExplosionKnockbackMotion` uses an initial speed of 320 unprojected world units
per second and ground deceleration of 640 units/s². In open space it travels the
existing 80-unit maximum and stops after 0.5 seconds. Its position is the
closed-form solution `v₀t − ½at²`, clamped to the already-certified endpoint.
A shorter endpoint represents inelastic contact with an obstacle or occupied
space; the initial speed stays unchanged and contact occurs earlier. There is
no overshoot, bounce through walls, accumulated frame-rate error or new
world-geometry clearance test. The existing raster remains the only collision
authority. Projected y remains scaled by 0.75 and presented positions integral.

The combat model still resolves damage and reserves/saves each survivor's final
position before presentation. This is a constrained physical shove, not a
runtime ragdoll simulation. Saving/loading never reapplies the impulse or damage.

## Animation

- Ordinary pushes: 16-frame backward stumble with alternating foot recovery;
  0.8 seconds at 20 fps.
- Stronger pushes: 24-frame seated fall and rise; 1.2 seconds at 20 fps. Selected
  within 65% of blast radius, or when more than one blast hits the survivor,
  provided at least 32 units of cleared travel remain.
- Less than 12 units of clearance: existing heavy flinch; avoids playing a long
  backward step when a wall or another actor prevents the shove.

The human faces into the blast for the backward reaction, then turns through
the shortest facing arc over the last six planted poses back to the existing
actor's facing. Gameplay facing/sight cones do not change as a visual side
effect. Reaction proxies follow the actual displaced actor each tick, with the
existing equipment, palette colours, ground shadow, lighting and wall stencil.
Tactical pause freezes the motion and poses together. The turn stays locked
until recovery finishes. Chain explosions choose one reaction per survivor.

These falls are cosmetic recovery; no extra prone status, action charge or
damage is introduced. Knocked-out actors now use the collapse and held ground pose
documented in `CombatDefeatOct08.md`.
Bear form retains its own hit clip while using the new displacement trajectory.

## Art authority

The live Blender MCP scene is `Human_Knockback_Oct07`. The incremental
`ArtSource/Blender/KnockbackOct07/Knockback_Before.blend` preserves the source;
`Knockback_Authored.blend` preserves the first authored pass;
`Knockback_Final.blend` contains the accepted actions with corrected weapon
clearance during the fall. The companion
`Knockback_Pose_Source.py`, `pose_metrics.json`, `render_plan.json` and
`render_mcp_source.py` record authoring and production. Use the live Blender
MCP connection to render; the recipe is not a standalone Blender launcher.

Geometry, proportions, UVs and materials are preserved. Explicit leg solving
keeps knees above ground during the deep fall; cloth panel bones follow those
solved poses. The approved base rig/assets and their original reaction source
file remain intact. Wrist separation stayed below 0.0000003 Blender units;
minimum knee height across the two clips was 0.0875 units. The final fall
keeps the bow at least 0.051 and the arrow at least 0.070 units above the ground
(`weapon_clearance.json`). `render_fall_clearance_mcp.py` rerenders that bounded
correction across every fall direction and matching equipment pass.

`ArtSource/Processing/package_human_knockback.py` packages six additive indexed
bundles: `HumanKnockback`, `HumanKnockbackSword`, `HumanKnockbackMail`,
`HumanKnockbackHelmet`, `HumanKnockbackBow`, `HumanKnockbackArrow`. Each contains
640 frames (40 poses × 16 facings), registered to the existing 160×160 canvas,
(80,60) pivot and 175.78125 display size. `CombatReactionAnimationSet` pins the
reviewed payloads. Existing hit, dodge, locomotion and attack bundles stay
byte-for-byte unchanged.

## Verification

All 81 combat/core tests passed. New tests cover frictional deceleration, early
wall contact with unchanged initial impulse, projected distance, frame-rate
independence, exact endpoints, recovery timing, facing wraparound and complete
pinned equipment frames. The prior raster wall/actor/map-edge push checks
remain unchanged and pass.

Both macOS and iOS Simulator builds passed. All six installed hashes match the
reviewed staged bundles and each built app's resources. Neutral/material mask
coverage matches at IoU 1.0 across all 640 frames. Old runtime avatar bundles
are unchanged. Live dedicated knockback QA passed 45 checks, covering player
and NPC stumble/fall, armor, shared impact clock, pause, saved endpoints,
recovery and reload without replay.

Preview: `output/explosion-knockback-preview.gif`. Dedicated live report and
captures: `output/knockback-qa-final`.

The barrel regression passed 48 checks (chains, debris, spill ignition,
enemy barrel choice and player knockback). Ordinary hit/dodge regression passed
65 checks. Final live total: 158 checks. Reports:
`output/knockback-barrels-qa` and `output/knockback-reactions-regression`.
