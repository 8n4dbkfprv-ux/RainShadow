# Shipping-office roof terrace — October 11

The earlier freestanding timber loading platform is retired. The shipping office
now has a flat slate terrace, low stone parapets and a north-east-facing ladder
that starts directly on the street. Day and dusk plates use the existing city camera,
materials and lighting; the shipping entrance and interior are unchanged.

## October 12 architectural revision

The landing and its four steps are removed. The slim ladder extends down to the
cobbled street, with three additional rungs and iron shoes at its feet. The west
façade bay is dedicated to roof access; its two windows remain retired. The main
entrance and its animated door remain unchanged. The former timber and masonry
landings are retained only as hidden modelling history.

The ladder's outside width is 0.735 m (formerly approximately 1.41 m), with
65 × 90 mm rails and 70 × 50 mm rungs. The parapet opening is narrowed to 0.90 m
and iron fixings connect the ladder to the masonry. Its slope and upper endpoint
are retained; the lower endpoint is projected from the street at Blender
(-11.6, -5.295888889, 0). The landing and steps elevation surfaces are removed,
restoring their underlying street raster from the pre-terrace baseline. A separate
projected `climbTop` marks the last rung: presentation follows the longer rails for
5.6 seconds, then walks onto the safe roof endpoint for 0.8 seconds. Descent
reverses these segments. This fixes the previous sideways drift toward the inset
roof destination; the click area follows the same bent route. Combat movement
costs are unchanged, and descent now finishes at street height.

The revision is saved in `Shipping_Roof_Authored.blend`; the pre-edit incremental
copy is `Shipping_Before_Street_Ladder_Oct12.blend`. New components use the
`WL_Oct12` prefix in the shared day/dusk terrace collection. Retired components
are hidden in both viewport and render, preserving a reversible model history.

## Playing

Click the ladder to approach and climb; click it from the roof to descend. In
exploration and combat, hovering outlines the visible rails in gold and shows
`Climb up` or `Climb down`. Hold Tab on macOS, or toggle the lantern reveal
button on touch, to reveal the ladder without hovering. Cancel a selected combat
attack with Escape before clicking the ladder. Highlights clear over overlays,
during climbing, and when the pointer leaves. The outline is projected from the
Blender rail corners in `highlightOutline`; it also makes the upper handholds
clickable. This feedback is separate from the unchanged IE door/container port.

In combat the ladder costs 20 ft of movement, plus the walking approach, and keeps
the Action available. Use Dash explicitly if more movement is needed. The hover
panel reports movement cost and blocked exits. Bear form cannot use the ladder.
Climbing stows held weapons and uses a dedicated cycle for both unarmored and
armored Voss. Pause and inventory pause freeze traversal. Combat saves record
the accepted endpoint and spent movement atomically.

The roof is approximately 18 ft above the street. Ranged attack rolls receive
+2 at least 10 ft above the target or −2 at least 10 ft below. The preview and
resolver share the rule. Melee, shove and threatening reach cannot cross more
than 5 ft of vertical separation. Ladder departures offer opportunity attacks;
Disengage prevents them. Enemies can approach and use the ladder to seek useful
high ground or reach an opponent on another floor.

## Art and navigation authority

- `ArtSource/Blender/ShippingRoofOct11/Shipping_Roof_Authored.blend`: edited
  through the live Blender MCP, derived from the current Lamps Oct10 source.
- `geometry.json`: projected roof and ladder endpoints; also
  stored in the authored scene's `shipping_roof_geometry` property.
- `Human_Climb.blend`: separate baked character action. The approved VossCHMF,
  LilaSentinel and existing equipment bundles were not replaced.
- `Climb/render_climb.py`: live-MCP rendering recipe. `package_human_climb.py`
  encodes the additive indexed body/mail/helmet layers with approved palettes.
- `install_shipping_roof_oct11.py`: seats regional day/dusk renders, packages
  pages and patches 1,310 local roof search-map cells. It retains the original raster
  elsewhere and removes the retired platform's prop and obstacles.
- `ShippingRoofOct11/installation_receipt.json` and
  `navigation_installation_receipt.json` in the generated city directory are
  applied last by `restore_completed_city_areas.py`.

Normal walking still uses the unchanged GemRB pathfinder. A ladder is an explicit
transition between disconnected floors, never a walking path through a wall.
The combat projectile adapter allows elevated shots over this building's visible
front faces; doors, actors, chimney and unrelated walls remain blockers. Roof
actors stand above the building's ground-level cover mask. This is a painted
2.5D terrace: parapets stop movement; this change does not add roof-edge falls.

## Verification

Both day/dusk masters passed the projection gate. Pixels outside the regional
render are unchanged. macOS and iOS simulator builds passed. The native playtest
covers ascent, paused climbing, high-ground targeting and resolution, and descent:
`output/roof-oct11-final/report.json` (21 checks). 175 combat/navigation regression tests pass across 24 suites, plus 7 character runtime tests.

October 12 street-ladder verification: day/dusk projection errors are below 0.16°
and pixels outside the regional render remain identical. The art installer
preserved 259 protected resources. The navigation install restores the former
landing and steps to the baseline street raster and retains only the roof patch.
macOS and iOS simulator builds pass, as do 20 elevation/reachability tests. The
native playtest passes 23 checks, including street-level arrival, rail alignment,
pause, ascent, high-ground attacks and descent
(`output/street-ladder-oct12/report.json`). The reviewed daytime building image is
`output/street-ladder-oct12/building-review.png`.

Ladder feedback verification: macOS and iOS builds pass. The native combat test
also checks hover visibility, direction labels, clearing on pointer exit, Tab
reveal/release and unchanged ascent/descent. The composited-world screenshot is
`output/ladder-highlight-oct12-reviewed/street-ladder-approach.png`; capture waits
for the world renderer to redraw, because the HUD updates before that raster.
