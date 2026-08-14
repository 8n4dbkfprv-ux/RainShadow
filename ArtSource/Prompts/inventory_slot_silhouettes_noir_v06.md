# RainShadow inventory slot silhouettes V06 (BG:EE empty-slot language × noir weapons)

Date: 2026-08-14  
Generator: Cursor built-in Image Generator  
Layout reference: Baldur's Gate: EE default/Enhanced inventory empty-slot *roles* and readability only (helmet / armor / gauntlets / amulet / cloak / belt / boots / ring / off-hand / quick weapon).  
Material reference: `ArtSource/Generated/UI/StyleLock/ui_style_lock_v03.png` and shipped HUD gunmetal.  
Supersedes: `inventory_slot_silhouettes_sheet_v05` cell set (adds cloak, belt; splits holster vs revolver).

## Hard rules

- Original RainShadow film-noir line art — **do not** copy franchise frames, STONHELM/STONBOOT BAMs, fantasy swords, shields, quivers, fonts, or watermarks.
- Flat chroma-green `#00FF00` outside every silhouette and between cells.
- **No baked interface copy**, letters, numbers, stamps, or readable glyphs.
- Faint dark-gray **line-art** silhouettes only (BG empty-slot language): thin noir gunmetal stroke, no filled photo icon, no bevelled slot frame, no drop shadow.
- Cool neutral grayscale only — no warm leather brown, gold, parchment, or purple glow.
- Each cell must stay readable when displayed at ~72×72 game points.

## Sheet layout

Canvas: single orthographic sheet, **4 columns × 3 rows** equal cells on solid chroma green.

| Row | Col 1 | Col 2 | Col 3 | Col 4 |
|---|---|---|---|---|
| 1 | fedora (head) | trench coat (torso armor) | gloves (gauntlets) | pocket charm (amulet) |
| 2 | cloak / cape | belt / girdle | lace-up shoes (boots) | signet ring |
| 3 | **shoulder holster** (off-hand) | **service revolver** (quick weapon) | generic pocket item | investigator satchel |

### Cell notes

1. **Fedora** — soft brimmed hat outline, three-quarter front, no face.
2. **Trench coat** — belted overcoat silhouette, lapels readable, empty (no figure).
3. **Gloves** — pair of gloves or cupped hands outline (one gauntlet slot for both hands).
4. **Charm** — small pendant / pocket watch / amulet on a short chain.
5. **Cloak** — hanging cape / trench cape outline (distinct from the coat cell).
6. **Belt** — horizontal buckle belt / girdle outline.
7. **Shoes** — pair of lace-up oxfords / detective shoes, top-down or slight angle.
8. **Ring** — single signet ring outline.
9. **Holster** — shoulder / underarm holster outline (noir off-hand; **not** a kite shield).
10. **Revolver** — Webley-style service revolver side profile (noir quick-weapon empty; **not** a sword or bow).
11. **Item** — small generic casework prop (matchbook / flask / notebook block) for quick-item empties.
12. **Satchel** — investigator messenger bag / case bag outline.

## Runtime IDs (after slice)

| Sheet index | Runtime name |
|---|---|
| 0 | `inventory_slot_silhouette_hat_v06` |
| 1 | `inventory_slot_silhouette_coat_v06` |
| 2 | `inventory_slot_silhouette_hands_v06` |
| 3 | `inventory_slot_silhouette_item_v06` (charm) — also used as charm/amulet empty |
| 4 | `inventory_slot_silhouette_cloak_v06` |
| 5 | `inventory_slot_silhouette_belt_v06` |
| 6 | `inventory_slot_silhouette_feet_v06` |
| 7 | `inventory_slot_silhouette_ring_v06` |
| 8 | `inventory_slot_silhouette_holster_v06` |
| 9 | `inventory_slot_silhouette_weapon_v06` |
| 10 | `inventory_slot_silhouette_item_generic_v06` |
| 11 | `inventory_slot_silhouette_bag_v06` |

Processing maps charm (cell 3) to the amulet/CHARM empty and cell 10 to generic quick-item empties. Prefer stable public IDs:

- `inventory_slot_silhouette_hat_v06`
- `inventory_slot_silhouette_coat_v06`
- `inventory_slot_silhouette_hands_v06`
- `inventory_slot_silhouette_charm_v06` (from cell 3)
- `inventory_slot_silhouette_cloak_v06`
- `inventory_slot_silhouette_belt_v06`
- `inventory_slot_silhouette_feet_v06`
- `inventory_slot_silhouette_ring_v06`
- `inventory_slot_silhouette_holster_v06`
- `inventory_slot_silhouette_weapon_v06`
- `inventory_slot_silhouette_item_v06` (from cell 10)
- `inventory_slot_silhouette_bag_v06`

Each fitted to 256×256 RGBA after chroma key + grayscale lock.

## Generation prompt (paste)

Use case: ui-mockup / orthographic icon sheet.

Flat chroma-green `#00FF00` background. One 4×3 grid of equal cells. Each cell contains only a faint dark-gray line-art silhouette for a late-1990s CRPG empty inventory slot, cool noir gunmetal stroke, no fill photo, no frame, no text, no numbers, no gold, no fantasy heraldry. Row 1 left to right: soft-brim fedora; belted trench coat; gloves; pocket charm on a chain. Row 2: hanging cloak; buckle belt; lace-up shoes; signet ring. Row 3: shoulder holster; service revolver side profile; small generic pocket item; investigator satchel. Shapes must stay readable at 72 pixels. Original film-noir detective props only — no swords, shields, helmets with horns, or copied franchise icons.

## Processing

`ArtSource/Processing/process_ui_chrome_v05_inventory.py silhouettes_v06` chroma-keys, force-grayscale, slices 4×3, writes:

- `ArtSource/Generated/UI/Inventory/inventory_slot_silhouette_*_v06.png`
- `RainShadow Shared/Resources/Art/UI/Inventory/inventory_slot_silhouette_*_v06.png`
