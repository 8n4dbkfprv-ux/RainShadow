# Stealth animations — October 7

Hide now lowers human combatants into a crouch over eight frames, then loops a six-frame breathing idle. Hidden movement uses a separate twelve-frame sneaking gait sampled by distance travelled. Playback moves at half the normal human walking rate, with the original movement profile restored on completion. The combat movement allowance and the GemRB navigation port are unchanged.

Melee Sneak Attack uses an eighteen-frame jump and downward stab, with contact on descent at frame 9 (0.6 s). The October 7 jump revision replaces the initial six-centimetre bob with a 0.52 m jump lift, tucked feet at the apex, and a compressed landing. The ground shadow stays planted and the actor's navigation root is unchanged. Ranged Sneak Attack uses a distinct crouched eighteen-frame bow draw with an additional 0.25 s aiming hold, release at frame 10, and a muzzle position measured from that pose. Explicit misses retain the same attack preparation. Automatic Sneak Attack damage uses these clips for ordinary attacks; named weapon techniques retain their own animation.

Hide transitions, idle breathing, walk cycles, attack poses, projectiles and hit markers follow the paused combat clock. Hidden state restores directly to crouched idle after loading. Revealing, being hit, changing form and ending combat release the hidden-body presentation. Existing detection, advantage, damage and save rules are unchanged.

## Art authority

The actions were authored and rendered through the live Blender MCP connection in cloned scenes, preserving the approved body geometry, material layout and weapon rig. Front and side poses were inspected. The arm solvers preserve connected wrists; the measured maximum wrist gap is below 0.000001 m. Bent legs lower the pelvis rather than scaling the character.

- `ArtSource/Blender/StealthOct07/Stealth_Pose_Source.py` and `Stealth_Authored.blend`: Hide, crouched idle, walk and stab.
- `ArtSource/Blender/StealthOct07/Bow/Stealth_Bow_Pose_Source.py`, `source_poses.json` and `Stealth_Bow_Authored.blend`: lowered original bow draw, preserving hand/string alignment.
- Each directory's `render_mcp_source.py` is the repeatable live-MCP render recipe.
- `ArtSource/Processing/package_human_stealth.py`: mask validation, palette conversion, registered body/gear bundles, review sheets and installation. Run with the Pillow/numpy environment; `--install` installs only the seven new payloads.
- `ArtSource/Blender/StealthOct07/Review`: all-facing frame sheets and animated previews.

`StealthAnimationSet` pins the new payloads: HumanStealth plus sword, mail, helmet, bow and arrow layers (704 frames each), and HumanSneakShot (288 frames). The existing VossCHMF, LilaSentinel, normal bow and technique payloads are untouched. The bow attack uses the existing integrated bow-body presentation, with its existing equipment limitations; crouched idle, movement and melee support the separate equipped armour and weapon layers.

The design takes inspiration from the jump/downward stab described in [Larian's community discussion](https://forums.larian.com/ubbthreads.php?Number=838505&ubb=showflat); it is original animation, not imported BG3 animation data.

## Verification

`StealthAnimationTests` checks all seven payload hashes, all sixteen facings, distinct body motion, rest/crouch endpoints, hold/release timing and animation selection for misses and automatic bonuses. `RAINSHADOW_QA_SNEAK_ONLY=1` exercises Hide, hidden travel, both attacks, pauses, armour, save/reload and visibility detection in the macOS app. Screenshots and reports are written to the `RAINSHADOW_QA_COMBAT` output directory.

Validated result: 91 targeted core tests passed; macOS and iOS Simulator builds succeeded; 57 live macOS checks passed. Report and captured poses: `output/stealth-oct07-verified/`. The initial live test incorrectly paired the ranged fixture with armour; it was corrected to the existing supported unarmoured bow loadout and the complete suite rerun successfully.

## Jump revision

The first version did not read as a jump. `JumpRevision/Stealth_Jump_Authored.blend` and the updated `Stealth_Pose_Source.py` now author a deeper anticipation, clear takeoff, an airborne apex at phase 7, descending stab at phase 9, landing at phase 11 and recovery. Both feet gain 0.64 m at the apex including the tuck. Only the interior melee Sneak Attack body, sword, mail and helmet frames are replaced; Hide, crouched idle, sneaking walk, ranged Sneak Attack and both attack endpoints remain byte-identical.

`package_stealth_jump_revision.py` verifies that scope against the previous stage and produces before/after previews. Bow and ammunition overlays are excluded from this shortsword-only move; the separate bow attack and its bundles remain unchanged. The new body clears its initial foot position by 16–21 sprite pixels across all sixteen directions, excluding the grounded shadow. The new regression checks measure the body separately from shadow index 1. The wrist continuity measurement stays below 0.000001 m.

The wider 3.6 m render framing at 372 px prevents clipping the raised weapon. Packaging retains the existing world density, 160 px registered canvas, pivot and display size; it does not shrink the actor.

Jump revision validation: all 92 targeted combat tests passed, macOS and iOS Simulator builds succeeded, and 34 live checks passed using `RAINSHADOW_QA_SNEAK_ONLY=1 RAINSHADOW_QA_SNEAK_JUMP_ONLY=1`. The airborne frame was captured and visually inspected in `output/stealth-jump-revision/live/melee-sneak-airborne.png`. Before/after animation: `output/stealth-jump-revision/jump-before-after.gif`.
