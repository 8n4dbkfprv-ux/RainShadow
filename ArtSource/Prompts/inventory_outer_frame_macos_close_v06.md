# RainShadow inventory outer frame V06 + Classic Mac OS 9 close box

Date: 2026-08-02  
Generator: Cursor built-in Image Generator  
Material authority: shipped `hud_left_rail_plate_v03`, `dialogue_outer_frame_overlay_v10`.  
Close-control grammar: Classic Mac OS 9 / Platinum square close box (same family as dialogue scrollbar Mac OS 9), painted in RainShadow cool gunmetal — **not** a modern red traffic-light.

## Hard rules

- Cool neutral grayscale pitted / hammered gunmetal only
- Flat chroma-green `#00FF00` wherever alpha is needed
- **No baked interface copy**, letters, numbers, or readable stamps
- Straight uniform rails + stepped/notched corners
- **No** half-circle fans, scalloped crests, or sunburst ornaments
- **No** floating interior close well in the live content area

## `inventory_outer_frame_v06` (1960×1080)

Border-only inventory chrome plate:

1. Thick multi-layer bevelled rectangular border; ENTIRE interior = chroma green `#00FF00`.
2. **Remove** any small square close well floating inside the live area.
3. **Modify the top-left title rail** so a Classic Mac OS close box can sit **on the metal**:
   - Shallow recessed square seat centered in the **top rail thickness**
   - Inset from the outer/left edge of the TL corner bracket
   - Seat must **not** cut into the live content well — it lives entirely on the rail face
   - Empty seat (near-black or chroma recess); no baked button art
4. Match HUD/dialogue cool gunmetal; worn-silver bevel highlights upper-left.

## `ui_close_box_macos9_noir_v04` (128×128)

Classic Mac OS 9 / Platinum close-box widget on chroma green:

- Square Platinum control silhouette with hairline bevels
- Flat matte face; subtle hollow-square / inset affordance (classic close-box grammar)
- Cool grayscale RainShadow gunmetal — same family as dialogue scroll buttons
- Straight-on orthographic; readable at 40–52pt
- No red traffic-light, no letters, no franchise ornaments

## Generation order

1. Outer frame V06  
2. Close box V04  

## Processing

`ArtSource/Processing/process_ui_chrome_v05_inventory.py` (outer v06 + close target) writes:

- `ArtSource/Generated/UI/Inventory/inventory_outer_frame_v06_*`
- `RainShadow Shared/Resources/Art/UI/Inventory/inventory_outer_frame_v06.png`
- `RainShadow Shared/Resources/Art/UI/Common/ui_close_box_macos9_noir_v04.png`
