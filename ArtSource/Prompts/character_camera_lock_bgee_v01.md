# Character camera lock — BG:EE area projection

- Generated: 2026-08-15
- Intent: Re-render Voss and Lila masters so character sprites match the
  Baldur's Gate: EE orthographic area camera
  (`Documentation/InfinityEngineGroundProjection.md`).
- Status: **follow-up** — area pipeline and prompts land first; character
  masters are regenerated after the office and city plates are approved.

## Why this exists

Area art now uses elevation `asin(0.75)` ≈ 48.59° (ground axes 36.87°, height
foreshortening ≈ 0.661). Character masters previously locked to the retired
~30° / 2:1 dimetric camera will read flatter than the new plates. Re-render
anchors and clip masters at this camera before reinstalling atlases.

## Camera (must match areas)

| Parameter | Value |
|---|---|
| Elevation | `asin(0.75)` ≈ 48.59° |
| Azimuth | 45° plan (eight facing directions around the actor) |
| Height foreshortening | ≈ 0.6614 |
| Verticals | Stay vertical |
| Ground contact | 16:12 ellipse under the feet |

Paste into character Image Generator prompts:

```text
Orthographic Baldur's Gate: EE CRPG camera — elevation asin(0.75) ≈ 48.59°,
azimuth appropriate to the facing, height foreshortening ≈ 0.661, verticals
perfectly vertical, no perspective FOV, no vanishing point. Match the RainShadow
office suite plate camera. Ground contact reads as a 16:12 ellipse.
```

## Install sequence (after masters land)

Do **not** call `v11.main()` / `v12.main()`. Run the AGENTS.md order only:

```bash
cd ArtSource/Processing
python3 process_voss_desk_ne_v12.py
python3 -c "import process_pre_rendered_characters_v12 as v12, \
process_pre_rendered_characters_v3 as raster; \
from process_pre_rendered_characters_v7 import pixelize_figure_v7; \
raster.pixelize_figure = pixelize_figure_v7; v12.process_voss_desk_chain_se()"
RAINSHADOW_PRESERVE_WARDROBE=1 python3 install_voss_idle_walk_seated_match_v02.py
python3 -c "import process_pre_rendered_characters_v11 as v11, \
process_pre_rendered_characters_v3 as raster; \
from process_pre_rendered_characters_v7 import pixelize_figure_v7; \
raster.pixelize_figure = pixelize_figure_v7; v11.process_lila()"
python3 process_lila_departure_facing_fix_v01.py
python3 process_lila_departure_nw_v01.py
```

Validate every phase of every direction (not one representative cell). Gate on
`VossSeatScaleTests` and `VossWardrobeColorTests`. Hash-diff atlases against a
pre-change snapshot; never run the idle/walk installer alone without re-running
the desk chains first.
