# Lantern Service Shortsword equipment — October 1

Current October 1 V8 source/install authority: [sword materials and walking grip](SwordMaterialsV8Oct01.md). V8 synchronizes armor/body walking frames to the corrected carrying hand while retaining V7 armor geometry/materials and the existing armor paperdoll/icon.

The current source is the later `LanternEquipmentOct01V2` revision, which seats
the grip inside the palm and preserves the existing separate-layer runtime.
Use the combined V2 packager for current art; the original source and checks
below are historical. See [equipment refinement](LanternEquipmentRefinementOct01.md).

The existing `lantern-shortsword` item now has its own inventory icon, an
equipped paperdoll layer, and synchronized standing/walking sprites. Move the
item from the bag to a ready-weapon slot to display it. Removing it clears both
presentations. Selection follows the existing `CharacterInventory.readiedWeapon`
rule; carrying the sword does not equip it.

## Art authority

`ArtSource/Blender/LanternServiceShortswordOct01/Voss_Lantern_Shortsword.blend`
is a self-contained working copy of the current Rustic animation source with
one separately modelled shortsword parented to `hand.R`. The sword has a steel
diamond-section blade, brass guard and pommel, and wrapped leather grip.
`Voss_Lantern_Paperdoll.blend` stores the inventory-only pose and a separate icon
scene. Both were authored and rendered through live Blender MCP.

The original Voss source, rig, body mesh, gameplay actions, 1,556-frame bundle
and inventory portrait remain unchanged. The new geometry is separate. No
historical character installer or navigation/render-port logic was changed.

`render_recipe.json` records the camera, source references, parent bone, body
crop, native registration and source hashes. `Renders` contains 336 unique
standing/walking views. Use the existing body's `render_plan.json` to set each
action/frame and camera azimuth in the weapon animation copy. Render the body
with a Cycles Holdout material in every material slot; retain the weapon's own
materials. This provides per-pixel torso/finger occlusion without baking the
weapon into the body. The paperdoll render uses the same holdout operation in
its saved pose; the icon scene renders the sword alone.

## Packaging and registration

`ArtSource/Processing/package_lantern_shortsword.py stage` produces the review
sheets and indexed bundle. `install` copies the reviewed bundle and two UI PNGs
into their dedicated resources. It never installs or modifies VossCHMF.

The weapon bundle is `VossLanternShortsword`, with 65 idle and 10 walking frames
in each of 16 directions: 1,200 records. Idle holds reuse precisely the body's
11-pose schedule. Each record uses the body's name, 128×128 canvas, (64,46)
y-up pivot and 140.625-unit display size. Reduction uses the **body's** original
crop rounding, so the sword is not independently fitted to its own bounds.
Some rear-left frames are empty because the body completely hides the sword;
these are valid frames, not missing resources. No additional shadow is baked.

The native weapon palette has independent steel, brass and leather ramps.
`DetectiveActorNode` applies the existing tint and wall-stencil path to the new
layer, with its own shader instance. The layer is a child of the body, sharing
root position, scale and elevation. It reads the body's current frame directly
and has no separate animation clock. Both the SpriteKit fallback and native
world compositor use the same indexed resource.

The paperdoll weapon retains its full 768×1088 render canvas. Its anchor maps
to the centre of the existing body crop `(136,69)-(589,1036)`. Fitting the
weapon separately would break the hand alignment. The existing body picture
and its 276-point maximum height stay intact.

Only standing and walking are authored for this change. The sword is hidden
during seated and chair-transition poses. Attack animations are not included.

## Verification

- 54 targeted Swift checks: equipment selection, every registered frame,
  idle holds, current Voss hashes, inventory rules and persistence.
- macOS Debug and iOS Simulator Debug builds.
- `RAINSHADOW_QA_WEAPON=<output directory>` runs the macOS live equipment review
  with an isolated save: equipped/unequipped inventory captures, immediate world
  changes, native payload and independent shader checks, and matching frame names
  during real walking. The report and captures live in
  `output/lantern-shortsword/live`.

Build/test logs are in `output/lantern-shortsword`. No iOS device execution was
performed.
