# RainShadow slim inventory frame V07

Date: 2026-08-08  
Generator: Codex built-in Image Generator  
Edit target: `inventory_outer_frame_v06_gen.png`  
Close reference: `ui_close_box_macos9_noir_v04_gen.png`

## Intent

Replace the heavy V06 inventory border with a restrained noir rail that gives
the content more air and makes the Classic Mac OS 9 close box feel like part of
the title-bar construction.

## Production prompt

Redesign only the border frame from the edit target so it is substantially
thinner, lighter, and more elegant while remaining unmistakably RainShadow
noir. Keep a straight-on 1960×1080 composition with symmetric rails. Target a
58–64 px visual rail on the runtime canvas: one worn charcoal-gunmetal band,
crisp narrow pewter bevels, a hairline inner rule, and compact mitred corners.
Remove the bulky L-shaped corner blocks and stacked title bar.

Carve one empty, shallow 52 px square seat into the top-left rail. Center it at
approximately x = -743 in SpriteKit canvas coordinates and center it vertically
within the rail. The existing `ui_close_box_macos9_noir_v04` art must sit inside
the seat without an X glyph or a baked button. Keep the live well and exterior
perfectly flat `#00FF00` chroma green. No copy, symbols, panels, fan crests,
scallops, rivet clutter, bright silver, brass, traffic-light controls,
perspective, or shadows crossing the live well.

## Runtime

`ArtSource/Processing/process_ui_chrome_v05_inventory.py outer_v07` keys and
widens the master to the 1960×1080 canvas, writing:

- `ArtSource/Generated/UI/Inventory/inventory_outer_frame_v07_gen.png`
- `ArtSource/Generated/UI/Inventory/inventory_outer_frame_v07_keyed.png`
- `RainShadow Shared/Resources/Art/UI/Inventory/inventory_outer_frame_v07.png`

`InventoryOverlay` places the 44 px close control at `(-738, 498)`, aligned to
the generated socket after the master is fitted to the runtime canvas.
