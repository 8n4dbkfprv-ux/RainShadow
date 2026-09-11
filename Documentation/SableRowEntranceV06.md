# Sable Row entrance V06

The V05 corner door was effectively edge-on to the unchanged area camera.
It also lacked a separate full-height opening and complete door construction.
V06 replaces it with a front-facing recessed entrance beside the rounded corner.
The old corner is restored as continuous storefront glazing and lower panels.

The new assembly includes solid jambs and returns, a framed glazed leaf,
transom, lower enamel panel, hinges, pull, lock plate, stone threshold, rubber
entrance mat, painted OPEN plaque, and a canopy with a sheltered incandescent
light. Lower trim stops at the doorway. V05 remains preserved.

The update is an exterior art correction: the door is modeled closed, and no
interior transition or runtime door interaction is added. The area remains a
staged courtyard. Camera projection, characters and runtime code are unchanged.

Edits were made live through Blender MCP and checked in a native-resolution
crop before evaluated geometry, cover and final day/night renders were rebuilt.
The exact edit is recorded in `live_entrance_edit.json` beside the Blender file.

[Comparison](../ArtSource/Blender/SableRowStudyV06/reviews/comparison.html)

[Blender model](../ArtSource/Blender/SableRowStudyV06/sable_noir_court_v06.blend)

## Validation

All five staged validation tests pass (132 approach pairs and 12 runtime walks).
The independent cover comparison passes at 99.615% IoU, with no mismatch more
than three mask pixels from the reference edge. Final native 6144×4608 plates
pass the BG:EE projection gate: day 0.20°, night 0.25° maximum axis error.
Four SpriteKit review frames were regenerated.
