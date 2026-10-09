# Distinct bow animations — October 9

The normal Ranged Attack keeps its planted draw and release. Pinning Shot lowers
Voss into an asymmetric brace, with the arrow aimed low. Ranged Sneak Attack now
has a crouched anticipation, takeoff, tucked airborne shot, landing compression
and recovery. Both unarmored Voss and the equipped mail/helmet use these poses.

## Animation authority

`ArtSource/Blender/BowDistinctOct09/author_motion.py` runs through the live Blender
MCP connection. It appends the approved normal and pinning scenes from
`ArmoredBowOct09/ArmoredBow_Authored.blend`, samples their evaluated upper-body and
weapon poses, and bakes the new pelvis and leg motion. The wrist, bow and arrow
relationships are retained. Mesh geometry, weights, rest skeleton, UVs, head and
body proportions are unchanged.

`Before_BowDistinct.blend` preserves the complete pre-edit scene.
`BowDistinct_Authored.blend` is the saved result. The recipe yields between poses
and disables mesh evaluation during bone baking: evaluating the detailed helmet
bevel after every bone update made the initial synchronous bake unresponsive.
Per-clip source snapshots, progress and metrics remain beside the scene.

Pinning retains 18 phases at 15 fps, with release at phase 10. Sneak Attack uses
24 continuous phases at 15 fps, reaches its apex at phase 11, releases at phase
12, and completes recovery at phase 23. There is no held airborne frame.
The registered floor shadow stays on the ground while the rendered body rises.
Projectile origins use the last nocked arrow-tip position from the new poses,
including the jump root's 4 cm descent from phase 11 to the release at phase 12.
The existing combat clock controls animation, projectile flight and tactical pause.
The source arrow root's visibility is explicitly keyed on its mesh descendants:
Blender does not inherit an empty's render visibility through parenting. The
crop gate caught an extra arrow on the north-facing airborne release before
installation; the affected release/recovery passes were rerendered after this
correction. The separately animated projectile takes over at the release marker.

Shooting ownership uses the accepted strike's combat actor ID. The player bow
proxy's visual definition is named `voss`, while combat identifies the player as
`detective.voss`; comparing those left the crouched stealth actor visible below
the jumping bow actor. Live QA now checks the combat identity for each special
shot and verifies that both underlying bodies are hidden during the jump.

`render_mcp_source.py` produces neutral, material-ID, mail and helmet passes in
16 facings. Body and weapons act as holdouts for the equipment passes. Camera
projection, world density and the 160×160 registered canvas remain fixed.
Evaluated meshes are cached across camera directions for each pose and pass.

`ArtSource/Processing/package_distinct_bow.py` creates `HumanPinningShot` (288
frames), `HumanSneakShot` (384), and the combined `HumanBowMail`/`HumanBowHelmet`
bundles (960 each). Ordinary-shot equipment frames are copied byte-for-byte from
the previous bundles; `WharfLookoutShot`, `VossCHMF`, base equipment, melee stealth
and Lila remain unchanged. `--install` backs up and replaces only those four
bundles. `--install-staged` validates and copies the reviewed stage without
regenerating it. Runtime authorities pin their resulting payload hashes.

`preview_distinct_bow.py` makes a side-by-side GIF from the actual indexed frames,
with both outfits and all three actions at their runtime speed. The preview lives
in `output/distinct-bow-oct09/`; all-direction contact sheets live in the local
art workspace's `Review/` folder.

## Validation

The packager measures neutral/ID mask agreement, visible airborne clearance in
every facing, and unchanged ordinary-shot equipment. Core tests validate all
frame inventories, payload hashes, registration, airborne body/floor-shadow
separation, release timing and outfit replacement during a stealth frame.

The live ammunition QA runs the special shots with either
`RAINSHADOW_QA_ARMORED_BOW=1` or `RAINSHADOW_QA_BOW_MOTION=1`, alongside
`RAINSHADOW_QA_AMMUNITION_ONLY=1` and `RAINSHADOW_QA_COMBAT=<output directory>`.
It checks the jumping pose, nocked arrow before release, airborne projectile
origin, pause behavior, recovery and existing ammunition interactions. The
armored mode additionally samples all 3,840 poses across full armor, mail only,
helmet only and unarmored outfits.

Validated October 9: all 2,688 initial render passes and the 832 release-visibility
repair passes completed without renderer errors. Final neutral/ID mask agreement
is 100%; the packaged airborne clearance is 21–29 native pixels across all 16
facings. Pinning lowers the drawn silhouette by 9–17 pixels. Its bow remains
0.190 m above the floor at the reviewed release pose. The ordinary-shot equipment
planes remain byte-identical.

All 34 core tests across the six bow, ammunition, appearance, armor, weapon-motion
and stealth suites pass. Both macOS and iOS simulator builds succeed with the
installed resources.

Final live macOS combat QA passes 59 armored checks and 46 unarmored checks.
Reports and captures are in `output/distinct-bow-armored-final-oct09/` and
`output/distinct-bow-unarmored-final-oct09/`. Both runs verify the airborne frame,
nocked-arrow release marker, raised projectile origin, tactical pause, normal
ammunition behavior, hidden underlying bodies and recovery to the equipped
exploration actor. The armored
run also loads all 3,840 frame/outfit combinations. The final comparison preview
is `output/distinct-bow-oct09/bow-actions-final.gif`.

Installed payload hashes:

| Bundle | SHA-256 |
| --- | --- |
| `HumanPinningShot` | `6f385292e5d0343be7dc940be3da7c5fc676642ef5ea00dfed353de77b80ffbe` |
| `HumanSneakShot` | `49b583a67d2fea34c9d2b354d975170b53f56a9a2619f999b774d775c07b0674` |
| `HumanBowMail` | `aaca9275a2903b1975904b2031dd12cefb71f711cba73b4d2638d4b96cf1cf6f` |
| `HumanBowHelmet` | `f957cc80ae17f1cd6572dc34adb3b642f1cf98ba4215744638917feb626efb72` |
