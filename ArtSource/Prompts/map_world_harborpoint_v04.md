# Harborpoint world map V4 — BG:EE Classic regional parchment

## Intent

Ship a **sparse regional travel map** for Harborpoint that matches the Baldur's
Gate EE Classic World Map look from the playable reference (warm amber open
parchment, soft coast, discrete location stamps drawn by the engine). Replace
the dense city-plan plates (V2/V3).

## Style lock

- Source recording: `Screen Recording 2026-08-05 at 11.37.22 AM.mov` (BG:EE Classic World Map).
- Staged stills: `ArtSource/Generated/UI/Map/_refs/bg_ee_worldmap_*.png`.

## Geography (Harborpoint)

| Region | Treatment |
|---|---|
| West | Thin blue-gray ocean band + soft brown-ink shoreline |
| Southwest | Simple river mouth / channel on parchment |
| Interior | Open empty warm golden-amber land — **no** rooftops, streets, or grid |
| Landmarks | **None baked** — six district stamps + labels are runtime sprites |
| Text / UI | None (no cartouche, compass, TRAVEL, place names) |

3×3 ward grid (north → south, west → east):

```
[locked]        Civic Records     [locked]
Wharf Ladder    Sable Row         Lila's Street
Riverside       Harborpoint PD    [locked]
```

Marker centres on the 1536×1024 plate (process + layout):

| District | (x, y) |
|---|---|
| civic_records | 768, 142 |
| wharf_ladder | 256, 483 |
| sable_row | 768, 483 |
| lila_street | 1280, 483 |
| riverside | 256, 824 |
| harborpoint_pd | 768, 738 |

## Imagine prompt (winning pass)

> Keep the same warm golden-amber parchment texture, soft brown ink lines, and open empty land with no buildings or labels. Shift the geography so the open landmass fills most of the plate and all travel-marker zones stay on warm paper: only a thinner blue-gray ocean band along the far left edge, and a simple river channel entering lower-left then running gently across the lower third without covering the center or mid-left. Remove any water from the middle and right of the map. No compass, cartouche, text, rooftops, streets, or stamps. Flat top-down Infinity Engine regional travel-map style, parchment edge-to-edge.

Prior candidates: pure gen peninsula (too much water under west markers), BG-crop restyle (black frame), emptied city outline (too schematic). Land-expanded edit of the best pure-gen base won.

## Deliverables

| Path | Role |
|---|---|
| `ArtSource/Generated/UI/Map/map_world_harborpoint_v04_base.png` | Clean 1536×1024 parchment |
| `ArtSource/Generated/UI/Map/map_world_harborpoint_v04.png` | Same (no baked ink) |
| `RainShadow Shared/Resources/Art/UI/Map/map_world_harborpoint_v04.png` | Runtime plate |
| `process_world_map_markers_v01.py` | Marker key/hover + install clean plate |

## Runtime contract

- Texture: `map_world_harborpoint_v04` (`WorldMapOverlay.Metrics.textureName`).
- District stamps always visible (normal color); oxblood + 1.12× scale on hover.
- Engine owns labels, party ring, fog/locked cells, TRAVEL chrome.
