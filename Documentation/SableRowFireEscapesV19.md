# Sable Row fire escapes — V19

V19 replaces the front and courtyard fire escapes with connected, inspectable assemblies and stores their drop ladders above pedestrian head height. It preserves the V18 apartment, materials, office window and district camera. The entrance canopy is narrowed slightly to clear the left front bracket.

## Construction changes

- Three landings on each escape, serving the upper floors at 3.7, 6.8 and 9.9 m.
- Channel frames, transverse joists, bearing grating and diagonal wall brackets. Wall plates, embedded rods, interior bearing plates and visible bolt heads represent the mounting connections.
- Parallel flat stair stringers with end connection plates; level open-bar treads seated on angle supports and vertical cleats. The former alternating flights occupied the same plane and would obstruct headroom near their meeting point. Parallel flights maintain about 2.90 m of conservative vertical clearance; the rear passage connects successive flights.
- The lowest landing has a complete grated floor. Upper landings have stair openings, end landing pads and a separate 0.70 m rear passage. The courtyard sill projection leaves approximately 0.41 m at the narrowest low-level point. Channels support the inside edges of the grating. Rails have full-height standards and bolted base plates back to the landing frames, including at the opening edges.
- Each drop ladder is shown stored 2.60 m above its pavement: bottom 2.81 m at the street and 2.84 m in the courtyard. It has 3.70 m long stiles, rungs, two C-guides, a holding catch, release lever and a gateway. The guide mouths face the rungs, allowing travel. The deployed range would be 0.21–3.91 m at the street and 0.24–3.94 m in the courtyard; the guides engage at both endpoints.
- Fixed ladders with gooseneck handholds connect the top balconies to the roof.
- The former courtyard steps, rails and solid platforms were retired. The new courtyard escape also reaches the fourth floor.

## Checks and limits

`reviews/geometry_checks.json` records the authored dimensions, flight slopes and checks. It verifies that anchor plates do not overlap active window/glazing/sill bounding boxes, front supports do not intersect the canopy, and both ladder positions remain engaged with the guides. Stored ladder ground clearance is 2.60 m. The front stair slope is about 46° and the courtyard slope about 42°.

This is a game-model geometry and mechanical-plausibility review. No material strength, masonry capacity, corrosion, live-load or structural certification analysis was performed. The model is not a construction drawing or a claim of code compliance.

The final geometry checks also compare actual paired stringer vertices to confirm a 3.10 m vertical offset with no change in plan position. There are 74 guard standards anchored into frames. The ladder deployment envelopes were checked against active scene meshes. A conflicting clothesline and its laundry were moved 0.80 m toward the rear courtyard wall, clearing the lowering path.

Construction reference: [NYC Department of Buildings, 1 RCNY §15-10](https://www.nyc.gov/assets/buildings/rules/1_RCNY_15-10.pdf), particularly its bracket, tread/stringer, guided drop-ladder and roof-access details. This later compilation is used to understand the construction of traditional metal fire escapes, not to assert a particular 1951 municipal code. [NYC Municipal Archives](https://www.archives.nyc/blog/2018/8/3/hinm65gv0uas2stfukwp28qh1rulmu) supplies the historical context.

## Deliverables

- `ArtSource/Blender/SableRowDistrictV19/sable_row_district_v19.blend`: edited scene.
- `before_fire_escape.blend`: incremental pre-edit copy.
- `live_fire_escape_operations.json`: ordered operations performed through live Blender MCP.
- `reviews/comparison.html`: close views, ladder detail, opening views and district comparison.
- `staged/`: day/noir district masters and updated opening renders from the same model.

Existing dark painted iron material is reused; no new image generation was needed for this geometry correction. The work is staged only. Runtime assets, navigation, cover, cutscene anchors and Swift code are unchanged.

Final visual QA: inspected the completed daylight close view, stored-ladder detail and day/noir district overviews. Both native district renders pass the BG:EE projection gate: daylight worst error 0.19°, noir 0.25°. Final assemblies are organised into separate front and courtyard collections; superseded V19 iteration objects were removed before saving.
