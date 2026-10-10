# Dash activation — October 10

Dash previously granted extra movement instantly with no dedicated animation.
It now plays a 0.9-second stationary preparation and release, accompanied by
short pale wind wisps. Movement remains a separate command. Enemy Dash queues
its already-selected approach until activation finishes.

The subsequent running-cycle addition is recorded in `DashRunningOct10.md`.
It changes movement playback after this activation while retaining this gesture.

## Reference

Visually inspected the released-game [NPC Dash Party footage](https://www.youtube.com/shorts/dVZIEahve7I),
especially 00:06.3–07.5: a brief in-place activation with pale wisps around the
actor, followed by movement. The blue electrical effects elsewhere in the shot
are not Dash and were not used as a reference. The footage is small and edited;
it supports the activation/then-movement structure and wind-like effect, not an
exact reconstruction of joint angles or a definitive engine timing measurement.

An older [How to Dash tutorial](https://www.youtube.com/watch?v=lW22lqFe5W0)
was also inspected but visibly identifies itself as Early Access, so it is not
the authority for the released-game presentation.

Our original pose interpretation bends the knees, braces the torso and draws
the arms into a short running preparation before settling to rest. It is not
an extracted BG3 animation or a replacement of the approved locomotion cycle.

## Runtime

`DashAnimationSet` owns additive `HumanDash`, `HumanDashSword`, `HumanDashMail`,
`HumanDashHelmet` and `HumanDashBow` bundles: 12 poses in 16 directions with the
existing 160×160 canvas, (80,60) pivot, fixed density and independent palettes.
The nocked arrow is omitted during the gesture. Armor and weapon layers share
the same poses, camera and ground registration as the body.

`TacticalCombatDirector.activateDash` validates artwork, accepts and checkpoints
the existing rule once, and owns presentation until recovery finishes. Input
cannot interrupt the gesture, spend another action, or start movement early.
The actor's simulation position is unchanged by the gesture. Save/load retains
the accepted extra movement without replaying the animation or granting it twice.
Hidden characters return to their concealed stance; Dash itself does not reveal
them. Bear form uses the wind effect on its existing body, without human poses.

`DashVisual` samples all its wisps from the pose's elapsed time. Tactical pause,
inventory and the Examine panel freeze both together. No independent SpriteKit
actions, emitter clock, movement-rate changes or navigation changes are used.

## Local authoring

`ArtSource/Blender/DashOct10/` holds the incremental scene backup, original pose
recipe, baked action, render plan, neutral/ID/equipment passes, metrics, staged
bundles and review sheets. The recipe was executed through the live Blender MCP
connection on an appended copy of the existing character scene. The original
world scene and approved character/armor geometry were preserved.

`ArtSource/Processing/package_human_dash.py` validates and packages all facings;
`--install` adds only the five new names, unlinking destinations before copying.
These local pipeline files follow the repository's existing ignored-art policy.

## Verification

- Generated 1,152 render passes and installed five 192-frame indexed layers.
  All 16 facings have 11 distinct body images and identical first/last images
  across every layer. Neutral/material-mask overlap is 1.0. Maximum baked wrist
  separation is below 0.000001 Blender units; planted feet stay at z=0.13.
- Reviewed sword, bow and armored pose sheets and native combat captures.
- 26 focused Swift tests pass across Dash animation, Dash rules, enemy tactics
  and shared character appearance. Approved VossCHMF/LilaSentinel payload
  validation remains intact.
- macOS and iOS Simulator Debug builds pass. All five generated payload hashes
  match the installed resources inside both built applications.
- Native combat run passes 112 checks, including unarmed, sword, armor, bow,
  armored bow, concealed and bear Dash; action/input gating; pause and inventory;
  in-flight save/reload; transient cleanup; and real enemy Dash followed by its
  queued movement and turn completion. Results: `output/dash-animation-oct10/`.
- Native movement-preview run passes 33 checks, including button activation,
  exact allowance, duplicate-click rejection and accepting ground movement after
  recovery. Results: `output/dash-movement-oct10/`.

For a manual check, launch `Play Combat.command`, enter combat and press G or
click Dash with an action available. Watch the stationary preparation and wisps,
then click ground to spend the enlarged movement allowance. The same activation
supports the readied sword/bow and equipped mail/helmet. Bear form receives the
wisps on its own existing body.
