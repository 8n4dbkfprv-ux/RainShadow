# RainShadow UI chrome V03 (BG-noir)

Date: 2026-07-27  
Generator: Cursor built-in Image Generator  
References: supplied Baldur's Gate UI screenshots (layout/weight/bevel hierarchy only).  
Materials: original RainShadow film-noir — do not copy franchise frames, icons, or ornament.

## Shared material language (lock)

- Blue-black rain-slicked gunmetal plates with deep bevels and weathered pits
- Smoked leather inlays, polished black marble / dark mahogany accents
- Muted oxblood recesses, tiny aged-brass pins and Art Deco geometric corner filigree
- Late-1990s pre-rendered CRPG UI readability (thick frames, recessed wells, metallic icon bevels)
- High-contrast monochrome icons with soft white metal highlights
- Flat chroma-green `#00FF00` background wherever alpha is needed
- **No baked interface copy, letters, numbers, or readable stamps**

## Style-lock composite

`ui_style_lock_v03` — single sheet showing three corners for approval:

1. Left rail fragment with 3 stacked beveled icon wells + sample metallic icon
2. Inventory outer-frame corner with thick ornate bevel + empty dark well
3. Dialogue plaque corner with thick frame, portrait well notch, side mid-edge tab

Approve this before mass regeneration.

## Asset families

### HUD

| ID | Canvas | Notes |
|---|---|---|
| `hud_left_rail_plate_v03` | 256×2048 | Tall left rail; 12 transparent button wells stacked |
| `hud_right_rail_plate_v03` | 320×2048 | Tall right rail; portrait well + 3 utility wells |
| `hud_action_icons_sheet_v03` | sheet 3×4 | menu, map, journal, inventory, character, leads, contacts, settings, rest, help, hide-ui, clock — noir subjects |
| `hud_party_icons_sheet_v03` | sheet 3×1 | search, lantern, select-party |
| `hud_portrait_frame_v03` | 1086×1448 | Transparent center portrait bezel |

### Dialogue

| ID | Canvas | Notes |
|---|---|---|
| `dialogue_outer_frame_overlay_v05` | 1720×730 | Low wide blackened-steel / smoked-leather plaque; compact portrait window TL; transparent live-content well; **no** painted scrollbar channel |
| `dialogue_command_button_plate_v04` | 512×128 | Empty rain-scratched noir END/CONTINUE plate with live-label leather face |
| `dialogue_scroll_components_v03` | 2×2 sheet | up, down, track, thumb (oxblood/amber diamond thumb) |

### Inventory

| ID | Canvas | Notes |
|---|---|---|
| `inventory_outer_frame_overlay_v03` | 1960×1080 | Full BG hierarchy plate; transparent wells; no labels |
| `inventory_slot_silhouettes_sheet_v03` | 4×2 | hat, coat, hands, feet, ring, weapon, item, bag |

### Journal / Map / Common

| ID | Canvas | Notes |
|---|---|---|
| `journal_casebook_plate_v03` | 1400×1600 | Open noir case ledger; tab wells; newsprint pages |
| `journal_row_marker_v03` | 64×64 | Small bullet / raven mark |
| `map_chrome_top_bar_v03` | 1920×96 | Title well + toggle wells + world-map button plate |
| `ui_close_box_noir_v03` | 128×128 | Shared overlay close |

## Generation order

1. Style-lock composite  
2. HUD rails + icons + portrait frame  
3. Dialogue frame + command + scrollbar  
4. Inventory frame + silhouettes  
5. Journal + close + map top bar  
