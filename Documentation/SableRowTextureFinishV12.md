# Sable Row V12 — generated surface textures

7 September 2026. Texture finish of the staged district, following the period audit and recessed-door work. Edited the current scene through the live Blender MCP connection. The incremental backup is `ArtSource/Blender/SableRowDistrictV12/sable_row_district_v12_before_texture_finish.blend`.

## New Image Generator assets

Six separate, square material images were generated with the built-in Image Generator. Each is 1254×1254. Exact prompts and original output paths are in `ArtSource/Blender/SableRowDistrictV12/textures/finish_prompts.json`. These are surface maps applied to the actual Blender materials, not a paint-over of the rendered district.

| Asset | Applied to |
|---|---|
| `finish_concrete.png` | Sidewalk flags and paved yards; replaces the asphalt image previously reused as concrete grain while preserving authored slab joints. |
| `finish_limestone.png` | Pale masonry, sills, lintels, thresholds, steps and coping that share the limestone material. |
| `finish_enamel.png` | Bottle-green painted loading doors, garage panels and diner enamel surfaces. |
| `finish_canvas.png` | New separate cotton-canvas material for shop awnings, which previously shared the enamel shader. |
| `finish_bark.png` | Main courtyard plane tree and planted-yard tree trunks/branches. |
| `finish_soil.png` | Courtyard tree bed and planted-yard earth. These previously inherited aged wood and bark respectively. |

Existing Image Generator timber, galvanized steel, worn painted iron and chrome images were also applied to remaining untextured materials. Timber grain follows the long axis of door panels, bench slats and crossarms, and runs vertically on poles and water-tank sides. Rope, ivy and blind hems were excluded from the wood reassignment. Existing freight crates/decks retain their earlier mapped timber. Existing generated brick, roof, window-frame, glass, road, lamp, hubcap and manhole maps remain in place.

## Treatment

The maps introduce restrained color variation and fine shader bump. Existing material colors and construction patterns remain underneath them. Timber uses a dedicated UV layer; other surfaces use world-space box mapping at controlled physical scales. No mesh displacement was used. The six new images and reused maps are packed into the Blender file.

The material choices follow the early-1950s American port-city setting: stone, cement, aged paint/enamel, cotton canvas, timber, iron, galvanized metal and chrome. These authored surfaces are not claims of a particular historic manufacturer's product. The historical object-family references remain in [the period audit](SableRowPeriodAuditV12.md).

Smooth materials such as opal lamp glass, ceramic crockery and laminate were not arbitrarily roughened. Small foliage, lettering and paper also retain their existing treatment.

## Change record and review

- `texture_finish_changes.json`: material treatments and selective object assignments.
- `live_texture_finish.json`: exact live editing operations, retained for reproducibility against the saved pre-finish backup.
- `reviews/before_finish_day.png`: previous complete day plate for comparison.
- `reviews/texture_finish_warehouse.png`: intermediate native-resolution material check.
- `reviews/texture_finish_courtyard.png`: tree, wood and metal material check.
- `reviews/comparison.html`: day/night, native-size inspection and before-finish comparison.

Geometry, camera projection, district extent and lighting are unchanged. This revision updates the staged Blender art; it does not install the larger area or regenerate gameplay search, cover or lighting maps.

## Final verification

Both 9408×7020 Cycles renders completed at 64 samples and were visually reviewed. Native-resolution checks covered courtyard masonry, tree/soil/bench, warehouse, shops/water tank, diner/car and street lamp details. `qa_plate_projection.py` passes both plates against the 1.5° BG:EE limit: day maximum deviation 0.22°, night 0.23°. The saved scene has 7,972 objects in each lighting scene; the six new images are packed and all 12 new texture treatments are connected. Review links were checked and the SHA-256 delivery manifest refreshed.
