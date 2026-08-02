# RainShadow inventory modular chrome V05 (BG structure × noir materials)

Date: 2026-08-02  
Generator: Cursor built-in Image Generator  
Layout reference: supplied Baldur's Gate EE Classic inventory screenshot (structure, slot roles, badge geometry, bag/ground hierarchy only).  
Material reference: `ArtSource/Generated/UI/StyleLock/ui_style_lock_v03.png` and shipped HUD/dialogue gunmetal.  
Runtime layout contract: `InventoryOverlay.Metrics` on a 1960×1080 canvas (center origin).  
Architecture: **fully modular** — each master is a separate composable sprite. Do **not** bake a single full-screen region plate.

## Hard rules

- Original RainShadow film-noir materials — **do not** copy franchise frames, claw ornaments, fantasy icons, fonts, or watermarks.
- Flat chroma-green `#00FF00` wherever alpha is needed (outside each piece and inside punched wells).
- **No baked interface copy**, letters, numbers, stamps, or readable glyphs.
- Late-1990s pre-rendered CRPG readability: thick frames, deep recessed wells, metallic bevels, high-contrast silhouettes.
- Wells / empty seats must stay near-black or chroma so processing can keep them transparent or empty.
- Each asset ships alone — no neighboring sections painted into the same master except intentional sheets.

## Shared material language (lock) — match shipped HUD / dialogue

**Primary material authority:** runtime `hud_left_rail_plate_v03` and `dialogue_outer_frame_overlay_v10`.
Inventory chrome must read as the same family when placed next to those assets.

- Cool neutral grayscale only — hammered / pitted gunmetal, rain-scratched blackened nickel
- Flat matte faces with coarse mottling (not warm brown leather, not carved wood, not marble veins)
- Bright worn-silver bevel highlights on upper-left edges; soft dark recesses lower-right
- Squircle / rounded-rect wells matching HUD rail button seats (double-bevel stamped metal)
- Tiny fastener dots allowed; **no** large brass ornaments, gold fins, oxblood pinstripes, or mahogany
- Force cool grayscale in processing (`force_grayscale`) — reject warm brown / sepia masters
- No purple glow, no parchment warmth, no fantasy stone claws
- **Outer frame:** straight uniform rails + stepped/notched corners (dialogue family). **No** half-circle fans, scalloped crests, or sunburst ornaments on the inventory frame (those belong only on the HUD rail caps)

## Asset family

| ID | Canvas | Notes |
|---|---|---|
| `inventory_outer_frame_v05` | 1960×1080 | Border-only ornate frame; fully transparent / chroma interior |
| `inventory_section_loadout_v05` | 520×560 | Left column backplate: 3 empty header bars + slot-row recesses |
| `inventory_section_paperdoll_v05` | 420×520 | Center chamber frame only; empty interior for paperdoll sprite |
| `inventory_section_stats_v05` | 500×560 | Right column: 4 badge seats + long text-plate wells |
| `inventory_section_mid_v05` | 1800×120 | Mid strip: paused well / description well / coin well |
| `inventory_section_bag_v05` | 1100×220 | Bag band: satchel seat + 8×2 empty slot-well grid |
| `inventory_section_nearby_v05` | 520×220 | Nearby band: header well + 6 slot wells + left/right arrow seats |
| `inventory_slot_frame_v05` | 256×256 | One reusable recessed square slot; empty dark leather well |
| `inventory_slot_silhouettes_sheet_v05` | 4×2 sheet | fedora, coat, gloves, shoes, ring, holster/weapon, charm, satchel |
| `inventory_stat_badges_sheet_v05` | 2×2 sheet | defence shield, vitality spiked, resolve sunburst, damage ring |
| `inventory_selection_frame_v05` | 256×256 | Painted selection highlight rim (cool amber-metal), transparent center |
| `inventory_page_arrow_sheet_v05` | 2×1 sheet | Prev / next painted metal chevron marks |
| `inventory_case_bag_v05` | 512×512 | Investigator satchel prop |
| `inventory_coin_stack_v05` | 512×512 | Worn coin stack / scatter |

## Region geometry (1960×1080 image space, top-left origin)

Approximate Metrics → image mapping (`y_img = 540 − y_sk`, `x_img = 980 + x_sk`):

1. **Outer frame** — thick bevelled border around the full canvas; Art Deco pins at corners; interior 100% chroma.
2. **Close seat (V06)** — shallow recess on the TL **title rail** for `ui_close_box_macos9_noir_v04` (no floating interior well). See `inventory_outer_frame_macos_close_v06.md`.
3. **Loadout section** — placed ~x 0.04–0.30, y 0.16–0.64; three stacked bands (4 / 3 / 3 slot seats).
4. **Paperdoll chamber** — centered vertically in primary band ~x 0.36–0.56; empty interior.
5. **Equipment slots** — runtime places 10 reusable `inventory_slot_frame_v05` + silhouettes around the chamber (BG geometry: 5 top, 2 sides, 3 bottom).
6. **Stats section** — ~x 0.68–0.94, y 0.16–0.64; four stacked rows.
7. **Mid strip** — ~y 0.66–0.74 full width with three wells.
8. **Bag / nearby** — bottom band ~y 0.76–0.96.

### Explicit non-goals

- No character, item icons, or silhouettes baked into section plates.
- No left party/nav icon rail.
- No single monolithic plate that paints all regions together.

## Silhouette sheet (`inventory_slot_silhouettes_sheet_v05`)

4×2 grid on chroma green. Each cell: faint dark-gray **line-art** silhouette only (BG empty-slot language), noir metal stroke, no filled photo icon, no frame, no text.

Row 1: fedora · trench coat · gloves/hands · shoes  
Row 2: signet ring · revolver/holster · pocket charm/amulet · investigator satchel

Keep shapes readable at 72px.

## Stat badge sheet (`inventory_stat_badges_sheet_v05`)

2×2 grid on chroma green. Painted circular / shield badge **frames** with transparent / chroma centers for live numbers:

1. Defence — shield silhouette frame  
2. Vitality — spiked / notched circular frame  
3. Resolve — sunburst / star circular frame  
4. Damage — plain circular metal ring  

No numbers, letters, or franchise heraldry.

## Selection frame (`inventory_selection_frame_v05`)

Square rim only: thin cool amber / worn-brass highlight bevel suggesting selection, fully transparent center and exterior chroma. Orthographic, matches slot outer size.

## Page arrow sheet (`inventory_page_arrow_sheet_v05`)

2×1 on chroma: left chevron, right chevron. Solid filled noir metal marks, no text, no circular button body required (runtime hits are separate).

## Slot frame (`inventory_slot_frame_v05`)

Single square recessed inventory slot: smoked-leather well, worn gunmetal bevel, tiny brass pins, empty interior, chroma outside. Straight-on orthographic, no icon.

## Generation order

1. Approve material match against `ui_style_lock_v03`  
2. Outer frame  
3. Section plates (loadout, paperdoll, stats, mid, bag, nearby)  
4. Slot frame + selection frame  
5. Silhouette sheet + stat badge sheet + arrow sheet  
6. Case bag + coin stack  

## Processing

`ArtSource/Processing/process_ui_chrome_v05_inventory.py` chroma-keys, force-grayscale, punches intentional wells where needed, splits sheets, and writes:

- `ArtSource/Generated/UI/Inventory/...`
- `RainShadow Shared/Resources/Art/UI/Inventory/...`
