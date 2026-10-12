# Tabletop combat — October 12

Combat keeps the current turn-based rules. This implements the combat presentation
portion of GDD §§4.3.5, 5.6, 11, 12 and closes the pacing question in §15.

## Dice in the playable area

Blender resin dice are thrown directly onto the area ground, among the miniature
pieces. The supplied October 12 screenshot sets the scale: a d20 spans roughly
85% of a human miniature base, about two-thirds of the complete standing piece
in the projected view. `areaScale = 2.5` is 25% larger than the previous doubled
version; shadows and landing clearance scale with it. They are world nodes, so camera panning and zoom affect them naturally.
The existing 0.75 ground projection is retained. The presenter searches the
existing navigation raster for an open landing patch between the acting figure and its target;
the dice never enter actor occupancy or change navigation. Landing candidates
must fit inside the unobstructed viewport and visible fog cells. The search
falls back toward the player when the acting enemy is near a screen or fog edge. These are cosmetic throws with floor contact,
not a new simulation of collisions against every painted scenery object.

The local editable source is `ArtSource/Blender/tabletop_combat_dice_oct12.blend`,
made in the live Blender MCP connection. `Resources/Art/IE/Tabletop/Dice/meshes.json`
is the packaged authority on both platforms, with body triangles, raised numeral
triangles and numbered face normals/up vectors. d20/d6 and twice-numbered d3/d4
pieces cover current combat damage bands. Source coordinates and hashes are in
`Dice/provenance.json`. ArtSource remains local under the repository's ignore policy.
The generated prop atlas contributes the brass bezel only; there is no dice tray.

The October 12 material pass adds `Dice/resin-marble-v1.png`, generated with the
built-in Image Generator as a neutral pearly, smoky resin albedo. The same map
is tinted amber, green or oxblood in the runtime. Blender-authored face-planar
UVs avoid stretching on flat faces and carry through the bevels. The raised
numerals retain separate untextured ink materials. Geometry, normals, face
metadata and numeral meshes are unchanged; the JSON export adds only body UVs.
The textured source is `ArtSource/Blender/tabletop_combat_dice_textured_oct12.blend`
with the generated image packed inside. The original source is retained. Exact
prompt, generation method and asset path are in `Dice/resin-texture-v1.json`;
asset hashes are in `Dice/provenance.json`.

Texture QA uses `RAINSHADOW_QA_DICE_VISUAL_ONLY=1` with `RAINSHADOW_QA_DICE` to
capture all three paint variants, then a separate live combat run for area scale.

The cosmetic fixed-step throw uses gravity, spin, restitution and mesh support
height. A short guided settle puts the accepted face upward with its numeral
readable. The face reader checks the result, allows one cosmetic retry and then
settles explicitly. Ground shadows follow the throw. Amber, green and oxblood
resin all use light ivory numerals for readability; current Voss/enemy combat uses
amber/oxblood. Constant numeral lighting keeps their ink bright while tumbling.
SceneKit renders the Blender meshes into a transparent world sprite at up to
30 updates/second. Rendering is deferred outside SpriteKit's frame callback to
avoid nested Metal rendering. This should still be profiled on physical iPhones.

## Outcome and controls

`TacticalCombat` records the exact random values it already consumes. Attack
receipts include both advantage/disadvantage dice, the selected result, modifier
and defence. Damage receipts include weapon and sneak dice, modifiers, ward
absorption and applied damage. Initiative, shove and incidental hazard checks
write numeric results directly into the saved combat log without a visible throw.

The accepted action and next RNG state are checkpointed before the next rendered
frame. Dice have no access to combat mutation or its random generator. Damage
appears at the existing attack impact marker after the throw. Skip, Fast, pause,
log viewing, reload and a cocked visual cannot re-roll the accepted action.
Story-mode encounter resolution remains unchanged. A story-critical receipt type
is available for future authored checks; this adds no new story-critical scene.

Normal/Fast/Skip and independent dice mute persist in preferences. Skip throw
ends the current presentation immediately. Roll log pauses presentation and pages
through the retained 30 entries. Reduced Motion presents settled dice without
tumbling or the critical glint. Contact audio is a short synthesized resin/board
sound with an independent sample generator, played on cosmetic floor contacts.

## Miniatures and combat UI

Attacks, shoves, hit reactions, knockbacks and defeat move/tilt the complete rigid
miniature and base. The approved character bundles, palette swaps and navigation
remain intact. Initiative and the action portrait use brass roundels. Prone,
burning and ward conditions add brass chips beside the miniature base while
retaining text readouts. Existing ink-wash action cards remain in use.

New crew sculpts, terrain boards, a separately authored 55-degree camera and the
noncombat journal/dialogue/inventory/travel prop conversions remain separate art
and UI work. No claim is made that the full campaign encounter roster is authored.

## Verification

Run the combat core regressions with SwiftPM on macOS and build both app targets
using the commands in README. The debug macOS harness runs with
`RAINSHADOW_QA_DICE=<absolute-output-directory>` and writes `visual-report.json`,
`report.json`, painted-dice/miniature captures and the real Wharf Ladder throw.
It checks every authored face, pause, speed and skip. Run the live combat stage
independently with `RAINSHADOW_QA_COMBAT=<absolute-output-directory>` and
`RAINSHADOW_QA_DICE_INTEGRATION=1`; this checks world parenting, visible floor
placement, reference-matched size, accepted saves, deferred impacts and the next RNG state
after reload.

October 12 validation: both macOS and iOS Simulator Debug builds pass. The
combined SwiftPM selection passes 55 tests in eight suites, including 600 seeded
checks of the exact attack, advantage/disadvantage and sneak-damage draw sequence.
After the generated resin material pass, the SpriteKit mesh/pose/control harness
passes 66 checks, including complete texture coordinates for all four meshes.
The final real Wharf Ladder run passes 21 checks and
verifies world parenting, floor placement, checkpoint-before-display,
pause, skip and reload. The earlier ranged path also verifies arrow impact timing.
Mesh/control captures are in `output/combat-dice-world-oct12-final/` (including
`log-width-320.png`). The enlarged in-area throw is captured separately in
`output/combat-dice-reference-oct12/` as `combat-dice-visible.png` and
`combat-dice-paused.png`.
The textured material pass was rebuilt for both platforms and verified separately;
its three colour captures, Blender close-up and live combat captures are in
`output/combat-dice-textures-oct12/`. Both fresh runtime reports pass (66 visual
checks and 21 live combat checks). The mesh export was also compared with its
pre-texture contents: removing the new UV arrays leaves identical geometry,
normals, face metadata and numeral meshes.
Physical iPhone performance and audio listening remain device review work.
