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


## Bear action bar and Goading Roar — October 8

Bear Form now replaces the human weapon/stealth controls with Claw Attack [5],
Goading Roar [6], Human Form [4], Defend, Extinguish, End Turn and Yield.
Weapon shortcuts are blocked while transformed. Human controls and equipped
appearance return after voluntary reversion, duration expiry or loss of bear
endurance. Existing transformation costs, duration and equipment ownership are
unchanged. This supersedes the earlier first-version scope note about no roar.

Claw Attack uses the existing authored 12-frame swipe at 15 fps. The accepted
hit/miss saves immediately, but damage and the target reaction are revealed at
frame 6 (0.4 seconds). Input stays locked until the 0.8-second recovery ends;
misses use the existing dodge. Target selection can be cancelled without cost.

Goading Roar costs one standard action and has one use per transformation. It
affects conscious, non-hidden rivals within 240 world units (30 feet) with a
clear line through the shared navigation raster. No eligible targets means no
cost or use spent. It deals no damage and has no saving throw in RainShadow's
current rules. Goaded expires at the end of each victim's next turn; reversion
immediately releases everyone. The enemy AI focuses on the bear, foregoing
barrel attacks, shove tactics and emergency extinguishing while goaded. This
is RainShadow's adaptation, not a full BG3/D&D Wild Shape implementation.

The optional `roarSpent` and `goadedBy` checkpoint fields preserve old saves.
Accepted effects are saved before playback, so loading mid-roar resumes the
resolved conditions without replaying the sound, damage or animation.

The new `BearGuardianRoar` bundle is additive: 24 poses across 16 directions,
20 fps, with a 0.45-second impact. Anticipation lowers the shoulders, then the
neck/head rise with a jaw/ear pulse and recover to the same rest pose. All four
paws use the existing planted-target solver. The original mesh, skin weights,
rig structure, materials and base 832-frame payload are unchanged. The roar
uses the same fitted palette, camera, source density and ground pivot. Its
first/last bone matrices match exactly; packaging reuses the first endpoint
render to remove a Cycles sampling difference in the last frame.

At impact, an original synthesized rumble, three expanding ground waves and
human flinches provide the reaction. Audio, waves and all animation clocks
follow tactical pause and clean up on completion. Prone targets stay grounded.

Art authority: `ArtSource/Blender/BearAbilitiesOct08/Bear_Roar_Animated.blend`,
with `Before_BearAbilities.blend`, `author_roar.py`, `render_roar.py`,
`render-plan.json`, `endpoint-validation.json` and `stage-validation.json`.
Authored, inspected and rendered through live Blender MCP. Package with
`ArtSource/Processing/package_bear_roar.py`. The original bear and approved
VossCHMF/LilaSentinel resources remain pinned to their prior payloads.

Validation: **77 tests across eight suites** passed, including bear abilities,
combat actions, Trip Attack, Sneak Attack, weapon techniques, burning, barrels
and reactions. **58 live macOS checks** passed with
`RAINSHADOW_QA_BEAR_ABILITIES_ONLY=1`. These cover transformation/controls,
roar and claw timing, hit/miss reactions, pause/audio, save/reload, enemy focus,
condition expiry, spent use, equipment restoration, voluntary reversion,
endurance depletion and duration expiry.

macOS Debug and iOS Simulator Debug builds succeeded, and both installed roar
blobs match the pinned hash. iOS is compile-verified, not interactively played.
All 384 render jobs completed without errors. The first/last rest bone matrices
match exactly, every direction has at least 10 distinct indexed poses, and the
new bundle retains the original bear's palette and ground pivot. Live action-bar,
roar, swipe, miss and human-return captures were visually reviewed.

Report: `output/bear-abilities-oct08/report.json`.
Preview: `output/bear-abilities-oct08/bear-abilities-preview.gif`.


## October 8 — revised claw animation

Claw now crouches and transfers weight onto planted hind paws, rears up with
both front paws raised, draws the striking paw wide, sweeps diagonally down
and across, then lands and compresses before returning to all fours. The
24-frame action plays at 20 fps; damage and target reactions occur at phase 12
(0.60 seconds), and input remains locked until the 1.20-second recovery ends.
Misses retain their dodge timing and tactical pause freezes the whole action.
The barrel-breaking playback also uses the new clip and frame rate.

`BearGuardianClaw` contains 384 indexed frames across all 16 facings, with
SHA-256 `29c31ef6b19545d2f000290f2c06268e6e044dd46c186ca2deeb48e20e8e50e1`.
It uses the approved bear palette, camera scale and ground pivot. The original
832-frame bear package and the separate roar package are unchanged. Runtime
frame selection routes bear attacks to the new additive package; validation
still checks the original package against its original 12-frame swipe.

Authored and visually reviewed through live Blender MCP, using pose changes
only: mesh, skin weights, materials and bone structure are unchanged. Source:
`ArtSource/Blender/BearClawOct08/author_claw.py` and
`Bear_Claw_Animated.blend`; incremental backup: `Before_Claw.blend`.
`render_claw.py` renders the family, and
`ArtSource/Processing/package_bear_claw.py` produces the indexed bundle.
`pose-validation.json` records identical first/last bone matrices and hind-paw
anchor drift below 0.000001 model units. All 384 renders completed, and package
validation confirms unclipped sprites and at least 20 unique poses per facing.

Validation: 78 tests across eight combat suites passed. macOS Debug and iOS
Simulator Debug builds succeeded; both bundled payload hashes match the
runtime pin. The live macOS bear-abilities playtest passed 62 checks, including
rear-up pause, contact reactions for hits/misses, and input locking through
landing. Reviewed the rendered front/side/three-quarter key poses and live
combat captures. iOS was build-verified only.

Report: `output/bear-claw-oct08/report.json`.
Preview: `output/bear-claw-oct08/claw-preview.gif`.

## October 8 — form-aware portrait and inventory

Bear Form now replaces Voss's party portrait and inventory figure with renders
of the existing bear model. The party health readout uses bear endurance;
inventory shows endurance, stored human health, bear defence, movement, attack
bonus, claw damage and turns remaining. The existing Claws, Goading Roar and
Human Form action bar remains the combat control surface. RainShadow retains
its authored eight-endurance, three-turn balance; these are not BG3 stat values.

Equipment remains stored, is dimmed in inventory, and cannot be equipped,
removed or moved between equipment slots while transformed. Bag inspection and
organisation remain available. Manual dismissal, endurance depletion and
duration expiry restore the human portrait, equipped figure and human readouts.
`BearFormReadout` uses `presentedCombat`, preserving animation-impact timing.

The opaque leather party rail previously covered its portrait. Portrait content
now draws above that background, with the health label above the portrait.

Art was rendered and visually reviewed through live Blender MCP from a private
copy of `Bear_Claw_Animated.blend`, using camera/render changes only. Meshes,
materials, weights and armature structure remain unchanged. Reproduction source:
`ArtSource/Blender/BearUIOct08/render_ui.py`; saved scene: `Bear_UI.blend`.
Installed art: `bear_paperdoll_guardian.png` and `bear_portrait_guardian.png` in
`Resources/Art/UI/Inventory`, included in both app targets.

Validation: 79 tests across five core suites passed. macOS Debug and iOS
Simulator Debug builds succeeded. The live macOS bear playtest passed 110
checks, including form UI on save/reload, merged equipment refusal, portrait
layering and all three reversion paths. Bear/human inventory and portrait
captures were visually reviewed. iOS was compile-verified only.
Report and captures: `output/bear-ui-oct08/`.
