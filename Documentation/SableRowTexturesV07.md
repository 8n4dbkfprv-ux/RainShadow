# Sable Row V07 — generated surface textures

The user requested image-generator texture detail while preserving the existing
geometry, using Baldur’s Gate AR0100 as the surface-density reference. The
setting remains an early-1950s American port city. AR0100 was not sampled or
copied into any material; its supplied image informed the desired level of
visual detail.

Six square 1254×1254 masters were generated with the built-in image_gen tool,
then copied into the project’s V07 textures directory. The complete exact
prompts and original output paths are in
[texture_prompts.json](../ArtSource/Blender/SableRowStudyV07/texture_prompts.json).

| Map | Applied use |
|---|---|
| asphalt.png | Mineral aggregate and fine surface wear on asphalt; restrained grain on existing paving materials |
| roof.png | Worn tar/felt, mineral dressing and fine weathering on flat roofs and repair patches |
| lamp.png | Chipped enamel and fine casting pits on lamp ironwork |
| window.png | Roughness variation on windows and slight transmitted-brightness variation on lit apartment panes |
| hubcap.png | Registered circular texture on all eight existing sedan hubcaps |
| manhole.png | Registered cast pattern across the existing lid and raised ribs |

These are artistic colour/grime maps, not measured scan-derived PBR textures.
Colour variation also supplies restrained bump shading, so no displacement
changes the silhouettes. The window map does not replace the transparent
storefront with an opaque painting. The existing manhole rib geometry remains.

Maps were applied through live Blender MCP in bounded steps with native-view
render checks. A first pass lost the finest street grain to filtering; the
final pass increases coverage and tightens its tonal range. Broad authored
puddles, patches, paving joints and roof forms remain. Fine details naturally
become less visible when the whole area is fitted into a small preview.

The final image maps are packed inside
[sable_noir_court_v07.blend](../ArtSource/Blender/SableRowStudyV07/sable_noir_court_v07.blend)
and also available as separate PNG files. Exact live material operations are
recorded in `live_texture_stages.json`.

## Geometry and inherited validation

`geometry_integrity.json` records identical SHA-256 values before and after
for visible mesh vertices, face topology and world matrices. Materials and UVs
are intentionally excluded from that comparison. No geometry, camera, character,
navigation algorithm or runtime renderer was changed.

The V06 geometry/search/height/cover bundle was copied byte-for-byte, including
its existing validation reports. Its five tests, 132 approach pairs, 12 walks
and 99.615% cover agreement remain inherited results, not a claimed fresh test
run. V07 regenerates beauty plates and their projection checks.

This remains a staged exterior courtyard study, not a full installed ward.

[Before/after review](../ArtSource/Blender/SableRowStudyV07/reviews/comparison.html)
