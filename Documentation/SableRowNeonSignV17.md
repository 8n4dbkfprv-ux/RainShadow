# ROOMS neon sign — V17

8 September 2026. Live Blender MCP refinement of the existing projecting ROOMS sign. The oxblood backing, wall brackets and position are retained. V16 remains available on disk; V17 includes a before-edit blend.

The original five font objects were replaced with matching flat painted strokes and physical single-line tubes. Tubes have a 10 mm radius and stand approximately 50 mm ahead of the backing. Small porcelain supports, sleeved returns, an edge supply cable and a rear transformer housing complete the visible installation. Letter shapes are authored paths rather than glowing solid text.

Separate tube objects/materials are linked to day and night scenes. Day emission is 0.18; nighttime values vary slightly from 5.0 to 5.5 to produce steady, mildly uneven illumination. Two nighttime-only spill lights use 2 W each and a 0.5 m soft radius. Initial 9 W spill lights produced two obvious hot spots in the close-up; these were reduced after visual inspection. Glow is rendered with emissive geometry and local lighting, without a whole-frame bloom filter or flicker animation.

The pawnshop remains painted. No district lighting, other buildings, roads, actor assets, projection camera or runtime resources are changed. Existing materials are reused; no new image-generated textures were needed.

Saved source: `ArtSource/Blender/SableRowDistrictV17/sable_row_district_v17.blend`. Exact operation logs and `neon_record.json` are adjacent. Native masters are staged area art, not installed game resources.

Final close-ups were visually reviewed after spill reduction, followed by the district overview. Native masters are 9408 × 7020, Cycles 32 samples. Projection QA passes: daylight +36.69° / −36.68° (worst 0.19°); noir +36.67° / −36.65° (worst 0.22°). All review links resolve.
