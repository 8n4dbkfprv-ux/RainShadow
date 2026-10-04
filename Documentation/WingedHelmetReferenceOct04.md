# Winged helmet — reference proportions, October 4

This revision supersedes `WingedHelmetRearOct03` after the user's comparison
showed that adding rear details had not sufficiently matched the reference's
proportions and surface construction. Reproducible live Blender MCP recipes,
source backups and reference images are in
`ArtSource/Blender/WingedHelmetReferenceOct04/`.

## Changes

- Increase brow-band height from 41 to 60 mm while retaining its lower edge at
  the established forehead position. The dome and spike move upward by 19 mm.
- Enlarge and round the band and rear crown rivets; broaden the central strip.
- Replace the stretched lower mail hoops with consistently spaced, alternating
  tilted rings, distributed by surface arc length. Increase wire thickness.
- Reduce lateral mail flare from its previous coefficient of 68 to 32 mm.
  Retain the rearward allowance required by the raised armor collar. The
  reference depicts an empty helmet; a completely vertical hanging curtain
  cannot occupy the collar's space on this character without intersection.
- Broaden and curve the flight feathers. Use three overlapping covert rows on
  each face, extending farther across the wing. Keep the curved holder visible
  along their roots. There are 18 shared flights and 57 coverts on each face,
  or 132 physical feathers per wing, with 75 represented per face.
- Give the helmet a darker forged shell, brighter bands and satin silver
  feathers. Fine procedural steel variation supplements the existing material
  detail. These materials belong to the helmet only.

The head, body proportions, armor, sword, rig and original actions are protected.
The helmet's brow position, mail-to-collar clearance and body registration remain
anchored to the previously reviewed V8 sources.

## Reproduction and review

Open `Before_Reference_Revision.blend` in live Blender MCP. Run the core and
wing construction recipes, then assembly and transfer. The generated masters
are `Voss_WingedHelmet_Paperdoll.blend` and `Voss_WingedHelmet_Animations.blend`.
The core and wings can be inspected separately in their incremental review
files. Temporary rendering states must not overwrite these masters.

The review recipe now includes both a straight rear view and a rear three-quarter
view. Source geometry is 250,326 vertices, 492,553 edges, 246,605 faces and
491,896 triangles, before bevel evaluation. All components are closed.

`package_winged_helmet_reference_oct04.py` stages 336 independent renders as
1,200 indexed idle/walk frames, plus the paperdoll and inventory icon. The
compatible body is the user's selected latest armored Voss from
`SwordMaterialsV8Oct01`. The current September 28 runtime is not replaced.

Gameplay export groups directions by pose and skips redundant action/frame
assignments to reduce repeated geometry evaluation. Camera projection, sampling,
frame keys and source registration remain unchanged. Saved detailed sources
retain bevels; gameplay renders omit their subpixel bevels as in October 3.
