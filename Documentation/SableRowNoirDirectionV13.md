# Sable Row V13 — plot correction and noir direction

7 September 2026. Built from the packed V12 texture-finish scene through Blender MCP. V12 remains saved as the previous version. V13 includes the corrected plot, the existing day/night lighting scenes and a separate noir scene. The camera, building sizes and district extent are retained.

## Plot decision

Plots need not all have equal widths or depths. The specific defect was a paved edge almost coincident with the freight annex's side wall. The rear of the port block also ended two metres before the adjacent residential block.

Expanded `V12 Port pavement` from 22×19 to 24×21 model metres. Its world bounds are now x=9–33 and y=27.5–48.5. The street frontage remains at y=27.5. The annex's side wall remains at x=31, leaving a nominal two-metre walkway to the outer kerb; plinth and kerb thickness reduce the clear surface slightly. The rear boundary now aligns with the neighbouring block at y=48.5. Moved the side kerb and added the front return and rear edging. No building was stretched or moved.

`plot_correction.json` records the original dimensions, new bounds and changed kerbs. `reviews/annex_plot_fixed.png` is a native-camera crop under the original day lighting. The supplied screenshot is retained beside it as the before reference.

## Why the original image felt weakly noir

My visual assessment: the previous lighting treated most roofs, walls and roads similarly. The regular frontages, broad open asphalt and even pools of illumination gave the district an orderly model-like appearance. Surface detail alone did not establish a strong focal point or a sense of concealment.

The useful cinematographic references are shaped darkness, isolated light, reflections and uncertain spaces. The [BFI discussion of early noir](https://www.bfi.org.uk/sight-and-sound/features/how-french-birthed-film-noir) describes rain-soaked exteriors, strong patterns of light and shadow, and reflective surfaces. Those are references for this art direction, not a requirement that every noir scene occur at night.

## Implemented lighting study

- A more directional cool key and narrow sun-source angle produce legible diagonal shadows from architecture and poles.
- Warmer, stronger street-level pools and diner spill establish local destinations. The diner remains the main warm focal point.
- A scene-local asphalt material adds irregular wet/dry roughness and a restrained reflective coat over the existing generated asphalt texture.
- A soft courtyard bounce lifts the floor and fire escape enough to inspect the area without removing the broader shadow structure.
- Original day/night lights and asphalt remain available in separate scenes. The noir scene owns its light objects, world, road material and compositor group.

The first preview left the courtyard excessively dark. A second visual pass corrected that before the final render. This is a color noir treatment with cool ambient light and warm practical light. No new Image Generator assets were needed for the lighting study.

## Recommended next art pass

1. Give the industrial side a clearer harbor identity: a distant dock/crane silhouette, a service gate and a distinct loading lane would make the warehouses belong to a working port.
2. Add a few specific story locations: a lone lit upstairs office, a partially shuttered bar entrance and a handcart left in a service alley. Each should be placed deliberately around a usable approach rather than spread evenly across the map.
3. Break up the repeated shop-front rhythm with distinct signs, awnings, repaired masonry and a few empty or shuttered windows. Keep the diner and detective's entrance visually dominant.

These are further composition suggestions, not features claimed as implemented in V13. Lighting improves the mood, but it does not by itself supply narrative activity, richer architecture or port scenery.

## Delivery scope

`ArtSource/Blender/SableRowDistrictV13/sable_row_district_v13.blend` contains the packed scene. `staged/sable_district_noir.png` is the 9408×7020 noir render. `reviews/day_plot_overview.png` is a 3292×2457 daylight review preview, not an installation master. `reviews/comparison.html` includes the noir view, the previous V12 night render, the daylight preview and the plot before/after.

`live_art_direction_v13.json` records the live operations; `noir_direction.json` records camera and light settings. This is staged area art. Runtime navigation, cover, actor lighting and integration are not changed or validated by this visual study.

## Final verification

The 9408×7020 noir master completed at 64 Cycles samples and was visually reviewed against the refined study. The daylight plot overview also completed and was reviewed. The noir master passes `qa_plate_projection.py`: axes +36.67° and −36.65°, worst deviation 0.22° against the 1.5° BG:EE tolerance. Review local links were checked; a SHA-256 manifest records the delivered files.
