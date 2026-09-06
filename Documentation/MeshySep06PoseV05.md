# Meshy V05 pose correction

V05 is installed in all five runtime atlases and the indexed bundle. The four
targeted Swift checks pass against both staging and the installed files.

V05 revises the approved V04 character's poses and coat skinning. It preserves
the approved material palette, directional lighting, embedded cast shadow,
58-row body craft and 163.125 compatibility display size. Navigation, camera
and blitter code are unchanged.

## Corrections

- The lower coat follows the knees instead of projecting forward as a rigid
  flap when seated. Only 459 coat vertices below rest height 0.72 m have weight
  transferred from upper leg to lower leg, using a smooth falloff down the hem.
- Seated hands have a defined resting position. During rising and sitting they
  follow an outward clearance path instead of cutting through the coat.
- The walking passing poses are distinct: the right ankle lifts 9 cm at frame
  2 and the left at frame 6. The other foot stays planted. Arm poses use a
  restrained opposing swing with enough clearance from the coat.
- One WNW walking frame needed more than the historical four reduction passes
  to converge to 58 body rows. This candidate allows eight; the native pixel
  and nearest-neighbor rendering approach is unchanged.

## Reproduction and evidence

`ArtSource/Blender/repair_meshy_sep06_pose_v05.py` reproduces the edits from the
hash-pinned V04 `.blend` plus `MeshySep06PoseV05/pose_patch.json`. Use its
`apply_patch()` and `queue_render()` functions through the live Blender MCP
connection. The mask material is explicitly reconstructed and retained with a
fake user so saving and reopening cannot lose the ID-render dependency.

`reproduction_audit.json` confirms that vertex positions, topology and UVs are
unchanged. `final_source_pose_audit.json` measures 156 quarter-frame samples
across walking, seated idle, standing and sitting: neither hand intersects the
coat torso/skirt. Connected cuff/sleeve seams are excluded from this check.
Standing/seated transition endpoints and reversed poses are exact. Source loop
endpoint discrepancies are below 0.000001 m. Both passing feet clear the floor
by approximately 0.09 m while the opposite sole stays within 0.0001 m of it.

Stage with `python3 ArtSource/Processing/stage_meshy_sep06_pose_v05.py`.
The resulting source set has 204 beauty/mask pairs; staging contains 248 cells,
including 24 empty arm overlays, and the indexed bundle. The Swift native-pixel
check now reads `RAINSHADOW_VOSS_ATLAS_ROOT` so it validates the actual candidate
rather than the old, fixed V04 directory. A separate test checks every exact
transition endpoint and every reversed transition frame.

The preview GIFs decode the staged indexed bytes. `game_seated.png` is a capture
from the existing isolated macOS build with the candidate bundle substituted.
The office chair/seat-anchor mismatch remains room authoring work.

## Remaining diagnostics

This revision does **not** make the complete historical asset suite green.
The body-only screen-half planted-foot heuristic still flags S, NW and N.
Direct source measurements establish alternating forward feet and distinct
swing clearance, but do not establish that every native view satisfies that
silhouette heuristic. Its threshold is unchanged.

Two NW walking cells retain one shirt-index pixel each at the collar. Ray
inspection locates these on the collar at about 1.42 m, not on the hands or
coat hem. They have not been recolored to conceal a failing test. The stricter
rear-garment test remains failing; the rear skin-share check passes.

The SE mirrored shadow convention inherited from V04 also remains unchanged.

## Installation

`install_meshy_sep06_pose_v05.py` verifies a hash-bound review receipt and the
source pose audit, preserves all five installed atlases and the indexed bundle
in `RuntimeBackupBeforeV05`, installs them together and verifies every copied
file. `install_receipt.json` records the exact installed hashes and remaining
diagnostics. The master selector and palette selector must move together.
