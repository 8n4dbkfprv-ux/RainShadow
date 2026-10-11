# Shipping-office roof terrace — October 11

The earlier freestanding timber loading platform is retired. The shipping office
now has a flat slate terrace, low stone parapets, an attached landing and a
north-east-facing ladder. Day and dusk plates use the existing city camera,
materials and lighting; the shipping entrance and interior are unchanged.

## Playing

Click the ladder to approach and climb; click it from the roof to descend. In
combat the ladder costs 20 ft of movement, plus the walking approach, and keeps
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
- `geometry.json`: projected roof, landing, steps and ladder endpoints; also
  stored in the authored scene's `shipping_roof_geometry` property.
- `Human_Climb.blend`: separate baked character action. The approved VossCHMF,
  LilaSentinel and existing equipment bundles were not replaced.
- `Climb/render_climb.py`: live-MCP rendering recipe. `package_human_climb.py`
  encodes the additive indexed body/mail/helmet layers with approved palettes.
- `install_shipping_roof_oct11.py`: seats regional day/dusk renders, packages
  pages and patches 1,512 local search-map cells. It retains the original raster
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
