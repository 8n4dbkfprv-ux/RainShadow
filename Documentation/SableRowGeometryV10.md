# Sable Row geometry repairs V10

The courtyard wall intersected the ground-floor window and its planter at x=1.8, y=8.3. V10 keeps the high north wall from y=4.65 to 7.15 and adds a low continuation from y=7.15 to 8.50, with a top at z=0.80. The planter starts at z=0.88, giving 0.08 m clearance. This preserves the courtyard boundary while exposing the window and planter.

A full-height street lamp was centred on the apartment's x=5.0 façade at y=11.6, embedding half of the fixture in the building. Its four V04 mesh components, two hidden legacy components and both scene-specific light sources were removed. Other street and entrance lights remain.

The V09 textures, camera, buildings, window assembly, cars and diner are retained. The packed Blender deliverable is `ArtSource/Blender/SableRowStudyV10/sable_noir_court_v10.blend`; live MCP operations are recorded in `live_geometry_operations.json` alongside it.

Validation: inspected the original viewport and native crop after repair; measured wall/planter clearance in `geometry_validation.json`; final day/night plates use 6144×4608 Cycles rendering with 64 samples. Projection reports are under `reviews/`. The close-up precedes a final UV-coordinate refresh; final plates include that refresh.

This is a staged art repair, not a runtime installation. V09 navigation, height and cover exports were deliberately not copied into V10 because geometry changed. Their former validation receipts must not be used to install this revision. Runtime export/validation is a separate integration step; no runtime code changed here.
