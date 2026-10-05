# Sword alignment, materials and walking grip — October 1 V8

`ArtSource/Blender/SwordMaterialsV8Oct01/User_Alignment_Snapshot.blend` preserves
the user's live sword placement before any work. `user_alignment.json` records
its exact bone-local transform and prior transform. `parent_pose_check.json`
confirms the same right-hand pose and rig transform. The user's sword-to-hand
attachment is retained in the paperdoll, idle and walking.

The walking correction closes the right fingers to the paperdoll grip and moves
the carrying arm forward/outward. `repair_walk_grip_via_live_mcp.txt` changes only
15 right-finger Euler tracks and two right-upper-arm channels in `Rustic_Walk_10`:
X +0.10 radians, Z -0.25 radians. The hand/wrist and forearm tracks are retained.
The blade follows the hand throughout the cycle. The earlier sword-only rotation
in `walking_alignment.json` was rejected and is not used by any final recipe.
`walking_clearance_audit.json` tests nine longitudinal blade rays against the
evaluated body and armor in each of ten walk poses, with no intersections.
This is a sampled clearance check; grip close-ups and all sixteen rendered
walking directions were also reviewed.

`model_preservation.json` verifies unchanged meshes, UVs, weights, rest bones,
non-walking actions and exact sword attachment. `unchanged_pose_audit.json` in
AnimationProduction verifies all 260 non-walking native source pairs remain
byte-identical and every registration box is retained. The shared body bundle
uses this carrying-hand pose during walking even when the sword is unequipped.
Idle and chair body frames and the body paperdoll remain unchanged.

Built-in Image Generator masters supply honed steel and worn brass. The grip
reuses the generated umber leather from armor V7. Exact prompts and texture
files are in `Textures/`, and all three maps are packed into the saved sources.
`materials_via_live_mcp.txt` adds materials and the sword's first UV map without
changing its 340 vertices or 206 faces. Steel and brass use metallic shading
with varied roughness; leather uses matte shading and shallow grain relief.
The existing edge bevel remains. The isolated icon has its own display camera
and lights; registered paperdoll/world lighting and cameras are retained.

Sources:

- `Voss_Sword_Paperdoll.blend`: exact user placement, textured sword and V7 armor.
- `Voss_Sword_Animations.blend`: matching equipment and corrected walk action.
- `AnimationProduction/Voss_Rustic_Animations.blend`: matching body source.

Live MCP recipes beside these sources reproduce material authoring, transfer,
walk repair, source verification, UI rendering and clearance checks. The transfer
recipe applies the walk repair once. The equipment render uses the same user
attachment for every pose: 336 sword source views and 160 new armor walk views;
V7's 176 armor idle views are retained. Each equipment bundle has 1,200 frames.

`package_sword_walk_body_v8.py` re-encodes walking with the original palette and
registration affine, sampling the full canvas to retain the outward carrying arm.
It copies all non-walking native pairs, then stages all 1,556 body frames.
Run `package_sword_materials_v8_oct01.py stage`, review the actual indexed
composites and paperdoll, write the hash-bound review receipt, then `install`.
The installer verifies source preservation, clearance, staged Swift validation,
source hashes and reviewed hashes. It replaces body/sword/armor bundles and the
sword UI images together, with rollback under
`output/sword-materials-v8-oct01/originals`. Helmet and other UI images are
hash-protected. The paperdoll source is the file for further user placement edits.

## Verification

Installed with a hash-bound review receipt. All 118 targeted Swift tests and
one staged-body validation test pass. macOS Debug, optimized macOS Debug (the
launcher setting) and iOS Simulator Debug builds pass. All four bundled character
layers and seven inventory images match installed resources in both apps.

The live desktop equipment run passed its first 21 loading, equip and portrait
checks but could not observe walking advance. The unchanged office-opening
transition also timed out. A subsequent CoreGraphics session check confirmed
`CGSSessionScreenIsLocked = 1`; desktop playback is therefore not verified in
this session. No gameplay or navigation logic was altered to bypass the failure.
Reports and captures are retained under `output/sword-materials-v8-oct01`.
