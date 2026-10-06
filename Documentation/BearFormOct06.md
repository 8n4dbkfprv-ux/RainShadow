# Bear Form — October 6, 2026

Bear Form is a playable magical ability for Voss in the existing Wharf Ladder
turn-based encounters. It uses the TemplePlus standard-action budget already
ported to RainShadow. Its balance rules are authored for RainShadow, not a
complete D&D Wild Shape implementation.

## Playing

Open `Play Bear Form.command`. It builds the macOS app, starts at the shipping
office entrance and uses the separate persistent `RainShadow.Save.BearForm.Oct06`
save. Open the door and choose a dialogue response to enter the encounter.
The ability is also available in normal play through these encounters.

- Press **4** or click **Bear Form** on your turn. Activation costs one standard
  action and requires enough free ground for the bear. A rejected activation
  spends neither the action nor the encounter's use.
- The bear gains **8 temporary endurance**, defence **14**, attack bonus **+6**
  and claw damage **5–8**. These nonlethal encounters keep their existing outcome
  contract. Equipment remains owned and equipped but contributes no bear stats
  or visible overlays. Bear movement is 30 feet per move.
- The form lasts for **three full player turns after the activation turn**.
  End Turn advances its duration. Pressing **4** while transformed voluntarily
  reverts for a standard action. Depletion of temporary endurance, expiry,
  yielding, or encounter completion also restores the human presentation.
- Temporary endurance absorbs damage first. Excess carries into Voss's normal
  HP; reversion does not heal him. The form is usable once per encounter,
  including across reloads. Inventory and normal stats are never rewritten.
- Ground clicks move; enemy clicks attack. **1** defends, **Enter** ends the
  turn, **3** yields, and **Space** pauses. Visible buttons support touch input.

## Asset authority and production

The user supplied `Meshy_AI_Grizzly_Guardian_1006160324_texture.fbx` with its
base-colour, normal, roughness and metallic textures. Inspection found one
UV-mapped mesh, 706,436 vertices and 1,412,900 triangles, with no skeleton,
weights, shape keys or animation. The original source was preserved.

Live Blender MCP was used to create a separate production scene. A reduced
copy retains 56,502 vertices and 113,032 triangles. The 21-bone quadruped rig has
normalized skin weights with at most four influences per vertex. Authored
clips include breathing/head motion, a four-beat walk with planted/swing paw
targets, a left claw swipe, hit reaction and reversion crouch.

Local authority: `ArtSource/Blender/BearFormOct06/Bear_Guardian_Animated.blend`.
Incremental surface, rigged and animated checkpoints are beside it. The file
contains the animation authoring text; the accepted mesh, weights, materials
and actions live in the `.blend`. `render-plan.json` records every camera and
pose job. `ArtSource/Processing/package_bear_form.py` encodes the renders and
does not launch Blender. As with other local art sources, `ArtSource/` remains
ignored by Git; preserve that directory when moving the authoring workspace.

The bake uses 16 explicit directions, elevation `asin(0.75)`, a fixed
orthographic scale of 3.6, and one projected ground pivot. Every pose renders
on a 256-square transparent canvas and reduces to a 128-square native plane.
The display canvas is 180 world units. There is no per-pose size fitting.

832 indexed frames: idle 12, walk 12, attack 12, hit 6 and revert 10 per
direction, played at 15 fps. The palette rows were fitted with the existing
CIE94 pipeline and encoded using `bgee-mixed-v1`. All frames are nonempty,
within the canvas, and have valid indices and per-frame hashes. Each clip
contains at least four distinct frames in every direction.

`BearAnimationSet` pins the installed blob hash. `CharacterBodyCode.bearGuardian`
loads it through the shared appearance system and rejects human equipment.
The installed bundle lives under `Resources/Art/IE/Avatars/BearGuardian` and is
included in both app targets. VossCHMF and LilaSentinel are unchanged.

## Runtime boundaries

The human actor remains the navigation/camera identity. While transformed,
the bear is its visible presentation. Certified bear routes play through the
existing integral `Movable` and synchronize the hidden controller's position.
The form uses `personal_space = 5`, a 48-unit proximity radius, and the existing
SearchMap/PathFinder clearance queries. Human and other-actor map profiles are
unchanged. No geometry check or ported navigation behavior was added.

The transformation presentation now lasts 1.6 seconds. Gathering mist and
spiralling gold-green motes accompany registered strips of the outgoing
body/equipment textures rising and fading. The form switches under peak
coverage at 0.68 seconds, then fades in while the bear's authored reversion
crouch plays backward. A ground ripple, outward dust and a low impact cue
land at 1.02 seconds; the remaining particles dissipate before input unlocks.
Reversion uses the forward crouch and a quieter inward swirl.

`BearTransformationEffect` has 65 deterministic sprites plus temporary silhouette
strips. Coloured radial/cloud/ring textures are baked once in memory and use the
existing native compositor's direct sprite path. No generated image assets,
custom actor shaders, or emitter warm-up are needed. The actor's terrain lift
remains owned by the existing height map. The approved human animation and
bear payloads are unchanged; this is a choreographed conceal/reveal rather
than a new anatomical morph or a new human casting animation.

An original synthesized breath/impact/creature rumble uses one `AVAudioPlayer`.
Its clock follows the combat clock, including pause and slow-frame correction,
and cleanup stops it. A brief 1.8-world-unit impact shake is applied after the
ordinary city camera update and bounded by the existing viewport clamp. It
never changes the stored free-camera target and is disabled by Reduce Motion.
There is no render-port or navigation-port arithmetic change.

The optional checkpoint field stores remaining turns, temporary endurance and
whether the activation turn is still current. Keeping its spent state after
reversion prevents reload exploits. Older checkpoints omit the field and
decode normally. Accepted actions save their outcome before visual playback;
reloading during a transition resumes the accepted form without replaying it.

## Verification

Core checks: `BearFormTests`, `TacticalCombatTests`, `CharacterAppearanceTests`,
`WharfLadderStoryTests`, and `SaveStoreTests`. The live macOS harness remains
`RAINSHADOW_QA_COMBAT=<output directory>` and uses a disposable save.
It now exercises Bear Form through scene input, including transformation,
particle pause, movement, claw playback, form restoration and save/resume.

Final verification on October 6: **46 tests across five suites passed**;
**41 live macOS checks passed** in `output/bear-form-qa-final/report.json`.
The latter includes voluntary reversion, expiry and yielding restoring human
appearance and clearance, alongside all four authored encounter outcomes.
The transformation, walk, claw, reversion and compact-window captures were
reviewed. macOS Debug and iOS Simulator Debug builds passed; both built bear
blobs match the validated source byte-for-byte. iOS was compiled, not played
on a simulator or physical device.

The first live pass exposed expensive searches for occupied approach goals
around the larger body. `CombatNavigation` now rejects goals without raster
clearance before searching, uses a wider melee approach around the bear, and
tries nearby candidates until it finds a certified route. This changes the
combat adapter's enemy policy; the GemRB pathfinder remains untouched.

This first version is scoped to combat. It does not add exploration shapeshift,
roar/charge actions, or bear inventory portraits.

## Transformation presentation follow-up

The upgraded presentation passed **46 core tests** and **46 live macOS checks**
in `output/bear-transformation-qa-final/report.json`. The new checks cover audio
pause, reversed crouch emergence, restored opacity and terrain registration,
particle/audio cleanup, and absence of a leftover reversion camera offset.
Gather, reveal, impact and settle captures were visually reviewed. macOS Debug
and iOS Simulator Debug builds passed; iOS remains compile-verified only.
