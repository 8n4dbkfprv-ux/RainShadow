# Sable Row V14 — service street and working yards

7 September 2026. Addresses the central street/plot ambiguity identified in the V13 review. The work was performed through live Blender MCP, using an incremental V14 backup before geometry edits and daylight renders between the paving and yard-detail passes. The previous V13 file remains available.

## Layout changes

The edited district section now has a seven-metre central service lane, running between x=22–29 and y=12–27.5 in the authored Blender plan. A four-metre access branch behind the workshop joins it to the established street on the west. The broad central asphalt space is bounded by public paving and working yards rather than remaining an undefined apron.

- Rebuilt the south block's pavement outline with a deliberate opening for the service lane.
- Added nominal 1.5-metre public pavement strips along the lane and behind/beside the workshop. Local posts and crossing slopes are not included in this nominal-width measurement.
- Gave the workshop a distinct concrete working yard with metal railings, a five-metre side entrance and a sliding gate parked along the fence.
- Enlarged Marine Electrical's forecourt, joined its plot to the surrounding public paving and added a separate front pedestrian route outside the loading-yard railing. Its driveway crossing is four metres wide.
- Replaced full kerbs at the two vehicle entries with sloping apron crossings and tapered adjoining pavement corners.
- Removed obsolete kerb fragments from the old paving islands and connected the new kerb runs.
- Distinguished the warehouse loading apron from the public route and moved four crates, in two two-high stacks, from the access road to the annex forecourt. All 220 crate components, including labels and fasteners, moved together.

Building dimensions and transforms are unchanged. The workshop, warehouse and Marine Electrical retain their existing recessed doors. The original diner entrance, actor assets, projection camera and V13 noir lighting treatment are retained. Existing generated paving, metal and wood textures were reused; this layout change did not require new generated images.

## Inspection and verification

The daylight paving pilot was reviewed before adding boundaries. The refined daylight view was then reviewed with railings, crate relocation and driveway crossings in place. `layout_validation.json` records the actual bounds of nine added buildings plus the workshop and checks the authored lane/selected public paving rectangles against them. The tested rectangles have no building-footprint intersections. The four relocated crates account for 220 component objects. A review caught that the initial inward-folded gate leaves narrowed the approach around the workshop; they were replaced with a sliding panel parked parallel to the fence, retaining a measured 3.2-metre approach beside the workshop wall.

These are staged-art authoring checks. The four-metre branch is narrow service access; no passing provision, traffic regulation, vehicle swept path or turning simulation is certified. The seven-metre central lane gives more manoeuvring space, but this is not a heavy-truck engineering plan. Runtime search maps, navigation, cover and actor lighting were not modified or validated.

## Files

- `ArtSource/Blender/SableRowDistrictV14/sable_row_district_v14.blend`: packed scene with day, baseline night and noir scenes.
- `staged/sable_district_noir.png`: full 9408×7020 noir master.
- `reviews/street_layout_refined.png`: 3292×2457 daylight layout preview.
- `reviews/service_street_detail.png`: native-camera daylight detail of the edited corridor.
- `reviews/street_plan.svg`: schematic explaining public paving, access and private yards.
- `reviews/comparison.html`: current views, previous V13 views, detail and plan.
- `street_layout_changes.json`, `layout_validation.json`, `live_street_layout_v14.json`: authoring changes, measured checks and live operation record.

The daylight overview is a review preview, not an installation master. The district remains staged art rather than a replaced game area.

## Final render verification

The gate-corrected daylight overview and native corridor detail were visually reviewed, followed by the final 9408×7020, 64-sample Cycles noir master. The projection gate passed: daylight +36.74°/−36.68° (worst 0.19°); noir +36.67°/−36.65° (worst 0.22°), against the ±36.87° target and 1.5° tolerance. All local comparison links resolve. `manifest_v14.json` records SHA-256 hashes of the review and source artifacts.
