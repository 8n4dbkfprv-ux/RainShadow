# Cupped shoulders and armor attachments — October 4

This revision follows `SplintMailRoundedOct04`. The user requested a more cupped
shoulder, a cleaner rear join, and visible attachment/overlap while retaining the
illustrated armor design. All modeling was performed through the live Blender
MCP connection.

## Changes

The outer shoulder plates turn down by up to 44 mm, wrapping the upper arm instead
of ending in an outward shelf. A bounded outward adjustment on the sword-side cup
retains clearance for the larger posed sleeve. The existing trim and rivets follow
the reshaped plate. Only the recorded shoulder components are changed here.

The identified upper backplate and its hardware tuck inward by up to 25 mm, with
a smooth transition down the back. This brings the upper plate closer to the
collar assembly. The helmet and its previously fitted rear collar are preserved.

`Splint_Shoulder_Fastenings` adds two short leather suspension tabs at the front
of the shoulder/collar joins, and two rear collar keepers. They use the existing
leather, polished-edge and fastener materials, with steel keepers and rivets. The
front tabs blend between existing chest and upper-arm weights; the rear tabs
follow the chest. No new bones or actions are introduced.

The original armor mesh retains 180,790 vertices, 362,152 edges, 181,780 faces and
360,744 triangles. 6,107 original vertices move. Its UVs and weights are unchanged.
The separate fastening mesh has 1,720 vertices, 3,424 edges, 1,744 faces and 3,360
triangles. Body, sleeves, head, helmet, sword, rest rig and nine original actions
are preserved.

## Sources and reproduction

All files are under `ArtSource/Blender/SplintMailCuppedOct04/`:

- `Before_Cupped_Revision.blend` retains the incoming live paperdoll.
- `Voss_SplintMail_Paperdoll.blend` is the revised detailed master.
- `Voss_SplintMail_Animations.blend` carries the same armor and fastenings on the
  existing animation source.

Open the backup in the live Blender instance. Run `cup_shoulders_via_live_mcp.txt`,
`tuck_backplate_via_live_mcp.txt`, and `build_fastenings_via_live_mcp.txt`, in that
order, using independent execution namespaces. Save the revised paperdoll before
running `transfer_via_live_mcp.txt`.

The fastening builder is a creation recipe, not an idempotent updater. Do not run
it again on a file which already contains `Splint_Shoulder_Fastenings`.

## Verification

`check_paperdoll_via_live_mcp.txt` verifies the paperdoll. `check_fit_via_live_mcp.txt`
checks all 21 distinct idle/walk poses; wait for its timer to finish before opening
another source. There are zero added or removed body intersection pairs relative
to the incoming armor, zero armor/helmet intersections, and zero fastening/body
or fastening/helmet intersections in the paperdoll and all tested poses. Existing
armor/body intersections elsewhere in the incoming asset remain; this does not
certify the entire historical outfit as intersection-free.

All 30 checks in `verify_via_live_mcp.txt` pass across the two masters. The original
armor coordinates outside the authorized shoulder/backplate components are also
included in the preservation hash. `preservation.json`, `paperdoll_fit.json`,
`animation_fit.json`, and `geometry_changes.json` retain the measurements.

`render_review_via_live_mcp.txt` renders identical before/after front, side,
three-quarter, rear three-quarter and close side views. It hides the new fasteners
for the before images. Reopen the saved master after rendering; do not save the
temporary camera/visibility state over it.

These are Blender source changes. Sprite layers have not been regenerated or
installed, and the runtime remains unchanged.
