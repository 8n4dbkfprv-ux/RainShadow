# Equipment fit and material refinement — October 1

The subsequent [hand repair](VossHandRepairOct01.md) retains this equipment
design and grip, and supersedes its production sources with corrected body
weights and matching holdouts. The hashes and unchanged-body checks below
record the earlier V2 installation; use the hand-repair packager for current
runtime installation.

The V2 equipment source lives in
`ArtSource/Blender/LanternEquipmentOct01V2/Voss_Equipment_Animations.blend`
and `Voss_Equipment_Paperdoll.blend`. These self-contained files supersede the
first sword/armor authoring files for the current equipment appearance.

## Fit and grip

The splint-mail skirt no longer ends in a continuous flared hoop. Eight
separate leather-backed tassets, each with three steel splints and two rivets,
replace that lower section. Their lower edge is at model z=0.935 rather than
0.825; the maximum x radius is 0.222. Small side gaps allow the silhouette to
read as armor panels instead of a solid ring. The upper torso geometry and
its existing weights are retained. The final mail mesh has 6,183 vertices and
4,736 faces, down from 8,700 vertices and 6,816 faces.

The sword remains a separate mesh parented to `hand.R`. Its attachment is
translated into the palm and rotated across the curled grip. The exact
original and final transforms are in `grip_registration.json`; close-up
renders record the front, outside and palm-side views. Neither the hand mesh
nor the existing body animation is edited to accommodate the equipment.

## Materials

The built-in Image Generator supplied worn steel and dark leather base-color
textures. `Textures/prompts.json` records the full prompts and tool. The PNGs
are stored beside the sources and packed into both Blender files. Rest-mesh
UV coordinates make the surface detail follow the armor during animation.

Steel uses restrained texture variation, high metallic response, broad rough
reflections and a shallow bump. Leather uses a darker grain with higher
roughness. The texture contribution was reduced after a first render looked
too coarse; the final treatment keeps metal readable at inventory size.
The sword's original steel, brass and leather materials and its isolated
inventory icon are retained.

## Reproduction and review

`render_via_live_mcp.txt` is executed through the connected Blender instance
with the V2 animation file open. It renders each item separately with the
unchanged body as a holdout: 336 source views per item, 1,008 total. The live
render recipe records progress and can resume existing completed images.
When revising an item, remove only that item's stale V2 render outputs before
resuming. Do not mix images from different grip or mesh revisions.

`python3 ArtSource/Processing/package_lantern_equipment_v2.py stage` validates
the renders and writes 3,600 registered idle/walk frames. The existing body
crop reducer, idle holds, native canvas, palette support and layer ordering
are reused. Review `paperdoll_equipped_final.png`, the grip close-ups, and the
`equipped_idle_all_directions.png` / `equipped_walk_all_directions.png` sheets
before running the same command with `install`. The installer preserves the
previous runtime equipment in `output/lantern-equipment-v2/originals`.

The current VossCHMF body blob must retain SHA-256
`6afc892de2acf11ece673b4d32d3c7d4d20b490e790514dd37c7bc411d58d372`.
No item rules, grants, save schema, navigation, lighting or actor registration
change. Equipment remains authored for standing and walking only.

Validation results and final live captures are recorded in
`output/lantern-equipment-v2`.

Final verification passed: 97 Swift tests across eight suites, macOS Debug
and iOS Simulator Debug builds, and all 33 live desktop equipment checks.
Both built applications match all three installed equipment bundles and all
seven checked inventory PNGs, comparing decoded pixels for iOS-optimized
PNGs. No iOS device execution was performed.

`model_preservation.json` compares the equipment source's body mesh, topology,
UVs, material indices, skin weights, vertex groups and rest bones against the
canonical September 30 source; all comparisons are equal. The shipped body
blob hash also remains unchanged. Final inventory and walking captures are
`output/lantern-equipment-v2/live/inventory_equipped.png` and
`walking_equipped.png`.
