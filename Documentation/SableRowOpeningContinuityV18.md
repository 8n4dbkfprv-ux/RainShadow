# Sable Row / OpeningExterior continuity — V18

V18 adapts Voss’s district apartment to the existing opening façade. The district and proposed opening shots are rendered from the same Blender geometry and materials. This is staged art, not a runtime installation.

## Reference and adaptation

Reference: `ArtSource/Generated/Exterior/NativeDetailV02/masters/ext_apartment_base_hd_v02.png` and its preview. The reference supplies the four-storey street façade, narrow sash windows, front iron fire escape, low entrance canopy, dark masonry and worn plaster, and a warm upper-floor office window.

The district retains its established 12 m street wing and courtyard. Its front uses seven window bays rather than reproducing the wider painted building exactly. The rear courtyard wing remains three storeys; the street wing gains a fourth floor, with its roof, chimneys and skylight raised together. This is a continuity adaptation to the existing lot, not an exact tracing of the opening painting.

## Implemented

- Rebuilt the front wall around recessed door and window apertures. Glazing and timber frames sit inside the reveals; each new mesh has UV coordinates.
- Four rows of narrow sash windows with thin dark stone lintels and sills, blinds behind glass and selected warm interiors.
- Three front fire-escape landings with open grating, stair openings, two stair flights, guards, brackets and a lower ladder. The original courtyard escape remains.
- Lowered the entrance to one threshold step, replaced the high stoop and canopy, and removed the obsolete foundation strip across the doorway.
- Applied apartment-specific darker brick and trim materials, preserving neighbouring building materials.
- Added Image Generator plaster texture on irregular strips between window bays.
- Authored an opening continuity camera in the same file. A restrained night-only reflected-sky light keeps the façade readable.

## Assets and authority

`ArtSource/Blender/SableRowDistrictV18/sable_row_district_v18.blend` is the saved result. `before_apartment.blend` preserves the prior scene. Ordered live MCP operations are recorded in `live_apartment_operations.json`; they are a change record, not a standalone build script.

The district master camera and world extent remain unchanged. The opening camera is a separate cinematic view, not a gameplay plate camera. Opening images are 3072 × 1728. District masters retain 9408 × 7020 native resolution.

The identifiable office window is at Blender world `(-12.35, -1.34, 11.23)`. `reviews/opening_day_anchor.json` and `opening_noir_anchor.json` record its projected image coordinates. The existing runtime opening pan uses an anchor fitted to the old painting; it must be fitted and verified against this new shot before installation. No Swift, cutscene, navigation, search-map, cover or runtime texture files were changed for V18.

On the 3072 × 1728 opening renders, the window projects to approximately `(1484, 590)` from the top-left, or `(1484, 1138)` from the bottom-left. This is a proposed shot anchor, not a change to the existing runtime `(1650, 1000)` target.

## Generated texture

Tool mode: built-in Image Generator, new texture generation, no image reference. Saved project texture: `ArtSource/Blender/SableRowDistrictV18/textures/aged_lime_plaster.png`. Actual output is 1254 × 1254; the prompt requested 2048 × 2048. Edge tiling was requested but not assumed as a verified property; visible use is bounded façade patches.

Prompt:

> Use case: photorealistic-natural. Asset type: flat seamless diffuse color texture for Blender, square 2048x2048. A close orthographic scan of severely aged warm grey-beige lime plaster on a 1930s American urban tenement, exposed in an early-1950s noir setting. Fine cracks, irregular flaking, darker gritty substrate visible in scattered worn patches, subtle long vertical water streaks and soot, dusty matte surface. Mostly intact plaster 65 percent, worn areas 35 percent. No bricks, no windows, no architecture, no text, no lighting gradients or cast shadows. Neutral even illumination, high surface detail at realistic scale. Tileable on all edges; no obvious central motif. This will be used in selected vertical facade strips among separate dark brick material.

## Review

Open `ArtSource/Blender/SableRowDistrictV18/reviews/comparison.html` for the original opening reference, the proposed shared-model opening, and the district views. Projection measurement and geometry checks are saved beside that review. These checks do not validate runtime navigation or cover exports; those remain integration work before installation.

Final district projection results: daylight worst deviation 0.19°, noir 0.25°, both within the existing 1.5° gate. All 27 window aperture centres and the doorway centre are clear of the authored front masonry. Day and noir opening anchor records agree. Both native masters and both opening shots were visually reviewed.

Follow-up design question: front metal fire escapes suit this older urban building; [NYC Municipal Archives](https://www.archives.nyc/blog/2018/8/3/hinm65gv0uas2stfukwp28qh1rulmu) documents their nineteenth-century development. The V18 lower ladder is shown extended beside the doorway. Showing it raised when unused is a recommended further refinement to make the entrance less crowded; it has not been applied in these renders.
