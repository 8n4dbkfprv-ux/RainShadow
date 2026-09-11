# Sable Row courtyard materials V09

V09 adds seven image-generated material masters to the V08 Blender courtyard study. The built-in Image Generator was used in generation mode, one call per material. Exact prompts and original generated paths are recorded in `ArtSource/Blender/SableRowStudyV09/textures/prompts_v09.json`. Project copies are packed into `sable_noir_court_v09.blend`.

| Master | Application |
| --- | --- |
| frame_v09.png | Weathered painted wood on 352 existing window-frame material slots; grain follows each member's long axis. |
| glass_v09.png | Rain/grime mask for apartment, car and diner glass; existing light and transparency shaders retained. |
| paint_v09.png | Gentle roughness and micro-bump variation on four blue/olive body meshes; authored enamel colors retained. |
| chrome_v09.png | Pitting and tarnish on 40 car chrome slots; existing generated hubcaps retained. |
| zinc_v09.png | Galvanized metal on five rubbish-can bodies and five lids. |
| stone_v09.png | Courtyard wall tops and pier coping, with shader joints on long wall tops. |
| brick_v09.png | Courtyard walls and piers, separate from building masonry. |

The old courtyard shader projected X+Y horizontally and Z vertically in object coordinates. Upward-facing faces sampled one brick row, stretching it over the wall top; separate object origins also offset the vertical courses. V09 gives these surfaces dedicated world-aligned UVs and assigns stone to top faces. Brick is mapped approximately 0.675 × 0.555 metres per tile based on the actual generated pattern (which did not reproduce the prompt's requested four-brick/eight-course layout exactly). The tile has some edge mismatch; it is a generated albedo, not a measured scan or a complete scanned PBR set. Roughness and shallow relief are derived in Blender.

The material pass preserves the early-1950s art direction. This is not a new archival audit. Older V08 lamp textures and V07 road, roof, wheel and manhole maps remain in use.

## Verification and scope

- Checked native-resolution wall and material crop renders, then final day/night plates at 6144 × 4608, Cycles 64 samples with denoising.
- Visible mesh vertices, topology and world transforms retain hash `7ba357bfbc7c6b137dda9d0fd4ef0904c83c7eb235a6a3018355842141589154`; UVs and material assignments intentionally differ.
- Projection results are saved in the review directory after rendering.
- The staged navigation, height and cover assets are inherited from V08/V06. Their earlier validation reports are inherited evidence, not fresh V09 runtime tests. No runtime installation or gameplay-code changes were performed.
- V08's fresh SpriteKit preview had failed in the restricted environment; this material pass does not claim a successful replacement runtime preview.

Review `ArtSource/Blender/SableRowStudyV09/reviews/comparison.html` for before/after plates and generated masters. `material_operations.json` records the live MCP operations; the packed Blender file is the editable scene deliverable.
