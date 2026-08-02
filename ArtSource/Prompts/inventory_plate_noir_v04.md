# RainShadow inventory plate V04 (BG structure × noir materials)

Date: 2026-08-02  
Generator: Cursor built-in Image Generator  
Layout reference: supplied Baldur's Gate EE Classic inventory screenshot (structure, slot roles, badge geometry, bag/ground hierarchy only).  
Material reference: `ArtSource/Generated/UI/StyleLock/ui_style_lock_v03.png` and shipped HUD/dialogue gunmetal.  
Runtime layout contract: `InventoryOverlay.Metrics` on a 1960×1080 canvas (center origin).

## Hard rules

- Original RainShadow film-noir materials — **do not** copy franchise frames, claw ornaments, fantasy icons, fonts, or watermarks.
- Flat chroma-green `#00FF00` wherever alpha is needed.
- **No baked interface copy**, letters, numbers, stamps, or readable glyphs.
- Late-1990s pre-rendered CRPG readability: thick frames, deep recessed wells, metallic bevels, high-contrast silhouettes.
- Wells must stay near-black / empty so processing can punch them transparent.

## Shared material language (lock)

- Blue-black rain-slicked gunmetal plates with deep bevels and weathered pits
- Smoked leather inlays, polished black marble / dark mahogany accents
- Muted oxblood recesses, tiny aged-brass pins, restrained Art Deco corner geometry
- Cool grayscale chrome with soft white-metal highlights (upper-left light)
- No purple glow, no parchment warmth, no fantasy stone claws

## Asset family

| ID | Canvas | Notes |
|---|---|---|
| `inventory_outer_frame_overlay_v04` | 1960×1080 | Full BG hierarchy plate; transparent / punchable wells; no labels |
| `inventory_slot_silhouettes_sheet_v04` | 4×2 sheet | hat, coat, hands, feet, ring, weapon, item, bag — BG-faithful line silhouettes in noir metal |
| `inventory_stat_badges_sheet_v04` | 2×2 sheet | defence (shield), vitality (spiked circle), resolve (sunburst), damage (plain ring) — transparent centers |
| `inventory_slot_frame_v04` | 256×256 | One reusable recessed square slot frame; empty dark well; no icon |

## Plate structure (`inventory_outer_frame_overlay_v04`)

Paint one complete 16:9 inventory chrome plate matching BG EE Classic **regions**, retargeted to RainShadow noir and the Metrics wells below. Leave wells empty (near-black). Do **not** include the BG left character/nav rail.

### Regions (image space, top-left origin fractions of 1960×1080)

Approximate Metrics → image mapping (y_img = 540 − y_sk, x_img = 980 + x_sk):

1. **Outer frame** — thick ornate bevelled border around the full canvas; Art Deco pins at corners; no claw protrusions.
2. **Close well** — small square near top-left (~x 0.02–0.06, y 0.01–0.08).
3. **Title rail** — centered top band for live "INVENTORY" text (~y 0.02–0.08); empty dark face.
4. **Identity band** — wide horizontal well under title for name / profession (~x 0.10–0.88, y 0.08–0.14).
5. **Loadout column (left)** — panel ~x 0.08–0.30, y 0.16–0.64 with three horizontal slot rows (quick weapons 4, quick items 3, coat pockets 3). Section header bars empty (no text).
6. **Paperdoll chamber (center)** — large vertical well ~x 0.36–0.50, y 0.18–0.58 for the detective paperdoll; surround with equipment slot wells:
   - Top row of 5 small square wells above the chamber
   - One well on each side mid-height
   - Bottom row of 3 small wells under the chamber
7. **Stats column (right)** — panel ~x 0.66–0.92, y 0.16–0.64 with four stacked rows: circular/spiked badge well on the left + long text plate well on the right. Badge wells empty centers; do not bake numbers.
8. **Mid strip** — paused/status area left, wide item-description well center, coin well right (~y 0.66–0.74).
9. **Case bag band (bottom-left/center)** — satchel art well on the far left + 8×2 bag slot grid (~x 0.18–0.72, y 0.76–0.96).
10. **Nearby / ground (bottom-right)** — header well + 6 slot wells with small prev/next arrow wells on sides (~x 0.74–0.96, y 0.76–0.96).

### Explicit non-goals for the plate

- No character, item icons, silhouettes, coins, or satchel baked into the plate (those are separate sprites).
- No left party/nav icon rail.
- No fantasy stone texture — use noir gunmetal / leather / marble only.

## Silhouette sheet (`inventory_slot_silhouettes_sheet_v04`)

4×2 grid on chroma green. Each cell: faint dark-gray **line-art** silhouette only (BG empty-slot language), noir metal stroke, no filled photo icon, no frame, no text.

Row 1: fedora · trench coat · gloves/hands · shoes  
Row 2: signet ring · revolver/holster · pocket charm/amulet · investigator satchel

Keep shapes readable at 72px: simple classic outlines matching the reference slot roles.

## Stat badge sheet (`inventory_stat_badges_sheet_v04`)

2×2 grid on chroma green. Painted circular badge **frames** with transparent / chroma centers for live numbers:

1. Defence — shield silhouette frame  
2. Vitality — spiked / notched circular frame  
3. Resolve — sunburst / star circular frame  
4. Damage — plain circular metal ring  

No numbers, letters, or franchise heraldry.

## Slot frame (`inventory_slot_frame_v04`)

Single square recessed inventory slot: smoked-leather well, worn gunmetal bevel, tiny brass pins, empty interior, chroma outside. Straight-on orthographic, no icon.

## Generation order

1. Approve material match against `ui_style_lock_v03`  
2. Full plate `inventory_outer_frame_overlay_v04`  
3. Silhouette sheet  
4. Stat badge sheet  
5. Slot frame refresh  

## Processing

`ArtSource/Processing/process_ui_chrome_v04_inventory.py` chroma-keys, punches dark wells, splits sheets, and writes:

- `ArtSource/Generated/UI/Inventory/...`
- `RainShadow Shared/Resources/Art/UI/Inventory/...`
