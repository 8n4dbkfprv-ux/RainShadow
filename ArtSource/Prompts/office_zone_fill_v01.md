# Office 3-zone fill props V1

- Generated: 2026-07-24
- Mode: built-in Image Generator + Python normalize
- Retained masters:
  - `ArtSource/Generated/Office/Props/office_zone_fill_sheet_a_chroma_v01.png`
  - `ArtSource/Generated/Office/Props/office_zone_fill_sheet_b_chroma_v01.png`
  - `ArtSource/Generated/Office/Props/office_zone_fill_sheet_c_chroma_v01.png`
  - `ArtSource/Generated/Office/Props/office_zone_light_overlays_v01.png`
- Shell / style refs: furniture core V2 + noir clutter V1 + desk phone / filing cabinet / visitor armchair / worn rug
- Supersedes: procedural Pillow placeholders from `generate_office_zone_props_v01.py`

## Runtime IDs

| Sheet | ID | Canvas |
|---|---|---:|
| A | `office_desk_typewriter` | 280×200 |
| A | `office_desk_notebook` | 160×120 |
| A | `office_safe` | 256×280 |
| A | `office_window_blinds` | 180×220 |
| B | `office_case_board` | 320×280 |
| B | `office_wall_city_map` | 280×240 |
| B | `office_framed_licence` | 160×180 |
| B | `office_wall_photos` | 220×160 |
| B | `office_umbrella_stand` | 160×220 |
| B | `office_newspaper` | 140×100 |
| C | `office_waiting_chair_a` | 220×280 |
| C | `office_waiting_chair_b` | 220×280 |
| C | `office_waiting_table` | 200×160 |
| C | `office_entrance_runner` | 768×384 |
| lights | `office_light_blind_stripes` | 1536×1024 |
| lights | `office_light_hallway` | 768×512 |
| derive | `office_waiting_ashtray` | from `office_desk_ashtray` |

## Processing

`ArtSource/Processing/process_office_zone_fill_v01.py`

## Acceptance

- Pre-rendered late-1990s CRPG materials matching existing office furniture.
- No legible text/brands; chroma keyed cleanly.
- Wall props readable but not sticker-flat against plaster.
- Waiting chairs clearly mismatched; runner reads as floor cloth.
