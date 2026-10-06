# Wharf Ladder lookout bow — October 6

The second gate opponent is a lookout with the Elven Court bow and arrow.
He holds a clear firing position, seeks a reachable firing lane when blocked,
and switches to the existing shortsword when engaged within melee reach.
This is RainShadow enemy policy above the existing TemplePlus action-budget
adaptation. It changes none of the GemRB navigation or rendering ports.

## Animation authority

The additive `WharfLookoutShot` bundle contains 18 frames in each of 16
directions. It uses the Rustic Warrior body and its existing material shade
calibration, projection and native density. VossCHMF and LilaSentinel remain
unchanged. The shot is supported for the unarmored male body equipped with
exactly the Elven Court bow and arrow; other bodies/equipment do not acquire
this clip implicitly.

The live Blender authoring package is
`ArtSource/Blender/WharfLookoutOct06/Wharf_Lookout_Bow_Shot.blend`.
It contains an isolated scene, baked body/bow/arrow actions and the pose source
as `WharfLookout_Pose_Source.py`. Incremental copies preserve the initial pose,
the shoulder correction and the pre-wrist correction. The source bow, arrow
and approved character packages were not overwritten.

The bow is in the right hand, with the left hand drawing the string. The
corrected elbow uses a common hinge plane for both arm segments; the left
hand follows the forearm's neutral relative orientation through the entire
clip. The earlier independent hand rotation pinched the wrist at roughly
95 degrees. The corrected pose audit measures approximately 9.04 degrees
throughout, with wrist joint separation below 0.000001 model units. Front,
side, wrist close-up and lowering views are retained in the authoring folder.

`ArtSource/Processing/package_wharf_lookout.py` encodes the rendered material
IDs and neutral shading into the existing mixed indexed palette. The composite
uses a 160-pixel canvas with the original human world density; it does not
resize the body to fit each pose. A fixed material-by-material brightness
transfer, fitted from the 16 resting directions against the original human
renders, compensates for the brighter equipment studio before the existing
shade curves are applied. The transfer is recorded in `neutral_transfer.json`
and remains constant across all frames. The combined bow uses the body's metal and
leather palette rows. Independent weapon palette customization during shooting
is outside this first clip's scope.

## Action and projectile

- The shot costs one standard action, with the existing attack roll and
  nonlethal damage rules. Rejected shots consume neither budget nor RNG.
- Range is 640 world units (80 combat feet), beyond the existing 105-unit
  melee reach, and requires a clear raster sightline.
- The clip plays at 15 fps. Phase 10 (two-thirds of a second) releases the
  arrow. The projectile starts at the projected authored arrow tip and reaches
  the target in 0.22–0.65 seconds, depending on distance.
- The accepted outcome is saved before animation. HP, log feedback, bear-form
  depletion and hit presentation become visible at impact. Reload resumes at
  the saved outcome without repeating the attack.
- Player pause freezes pose and flight together. The combat turn stays locked
  until both impact and recovery finish; cleanup removes the projectile.

NPC ammunition is implicit. This does not add a player bow command, inventory
arrow consumption, cover bonuses, ranged opportunity attacks or retreat AI.
Old combat saves with no ranged-weapon field retain their prior melee actors.

Use `Play Combat.command` to enter the playable Wharf Ladder encounter.

## Verification

The final export contains all 288 frames, with no clipped source edges or
missing material masks. Two raised-bow frames needed extra source-camera margin;
their encoding uses the recorded camera size and retains identical world density.
The installed blob is pinned to
`254550ed657112f5a126ccbe6aa73fa2834772755a77153b040af19332e6f6fd`.

**52 core tests and 53 live macOS checks passed.** The live report and draw,
flight and impact captures are in `output/bow-combat-qa`. Checks include paused
flight, damage timing, accepted-action saves and projectile cleanup alongside
the existing bear-form and encounter checks. Both macOS Debug and iOS Simulator
Debug builds passed; both built payloads match the installed hash. iOS was
compiled, not played on a simulator or physical device.

## Flaming arrow presentation

The lookout's arrow ignites during the final two draw frames. An orange halo,
yellow core, short flame trail and embers follow the existing projectile path.
`BowArrowFire` samples a fixed pool of 20 particles from the combat clock;
birth positions use the arrow's historical position so the trail follows the
flight path. The head goes out at impact and the remaining particles fade
within 0.14 seconds, before shot recovery permits the next turn. Pause freezes
all flame motion and fading, and shot cleanup removes the entire effect.

This is a visual fire effect. Attack rolls, damage, ammunition and saved combat
rules are unchanged; it does not apply an additional burn status.

macOS Debug and iOS Simulator Debug builds pass. All **56 live macOS checks**
pass in `output/fire-arrow-qa/report.json`, including visible fire, paused
particles and effect cleanup. The in-flight capture was visually reviewed.
