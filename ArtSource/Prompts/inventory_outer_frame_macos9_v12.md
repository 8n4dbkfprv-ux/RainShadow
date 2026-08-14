# RainShadow Inventory Mac OS 9 geometry V12

Date: 2026-08-13  
Generator: Cursor built-in default Image Generator  
Use cases: `ui-mockup`, `precise-object-edit`, `stylized-concept`

## Retained outputs

- Frame first pass: `inventory_outer_frame_v12_gen.png` (assets cache; retained as `inventory_outer_frame_v12a_gen.png`)
- Frame master: `ArtSource/Generated/UI/Inventory/inventory_outer_frame_v12_gen.png` (V12b reserve edit)
- Frame master SHA-256: `128c062205ea550289d027c7959ff5ec2911cc256310f77d5ee103446db5707e`
- Close first pass: `inventory_close_box_macos9_noir_v11_gen.png` (assets cache; retained as `inventory_close_box_macos9_noir_v11a_gen.png`)
- Close master: `ArtSource/Generated/UI/Common/inventory_close_box_macos9_noir_v11_gen.png` (V11b square-within-square)
- Close master SHA-256: `930689059e2a05158d14a447d1ec2547778b23327cdcefc7e955c2b07510a5a2`

## Reference roles

- User-supplied Mac OS 9 About This Computer screenshot: Platinum window, title-bar, and close-box geometry authority only.
- `inventory_outer_frame_v11_gen.png`: RainShadow noir material, lighting, and chroma-composition authority only.

## Frame prompt

Use case: ui-mockup  
Asset type: production game UI chrome master for the RainShadow Inventory overlay, version V12  
Input images: Image 1 is Classic Mac OS 9 shape and title-bar grammar authority only; Image 2 is RainShadow noir material, lighting, and chroma-composition authority only.  
Primary request: Redesign the outer frame and title bar into an original RainShadow noir interpretation of the Classic Mac OS 9 Platinum window shape. Keep a straight-on landscape border-only master. Exact construction: one-pixel near-black outer outline; very slightly rounded outer corners; a raised beveled frame with a thin pale pewter highlight on the top and left and a thin near-black shadow on the bottom and right; slim uniform side and bottom rails; a distinct integrated top title bar about two to three times thicker than the side rails. Fill the title bar with dense crisp parallel horizontal pinstripes. Interrupt the pinstripes in the center with a flat unoutlined solid rectangular title reserve of the same matte charcoal title-bar base (no plaque, no bevel, no outline). At the far left, leave a compact quiet unstriped reserve for a separately composited close control; do not bake a button, seat, recess, socket, or X. Far-right title bar is only pinstripes — no zoom, collapse, or utility boxes.  
Scene/backdrop: The entire live interior opening and any exterior area beyond the frame must be perfectly flat solid `#00FF00` chroma green.  
Style/medium: late-1990s pre-rendered CRPG UI chrome, polished production bitmap, original design; Mac OS 9 proportions and line rhythm translated into RainShadow noir rather than copied literally.  
Color palette: cool neutral grayscale only — charcoal, graphite, blackened nickel, sparse rubbed pewter.  
Constraints: No text, no baked close button, no X, no scrollbar, no resize grip, no status strip, no panels, no character, no scenery, no watermark, no green in the metal, no warm hue.

## Frame reserve correction

Use case: precise-object-edit  
The first V12 pass baked a square close seat into the far-left title bar. The retained master is the V12b edit: remove that complete baked square and replace it with a compact unoutlined, unbeveled unstriped charcoal reserve. Preserve every other pixel-level feature of the V12 frame.

## Close-control prompt

Use case: stylized-concept  
Asset type: standalone interactive close-box sprite for RainShadow Inventory V12  
Input images: Image 1 is Classic Mac OS 9 close-box geometry authority only; Image 2 is RainShadow noir title-bar material authority only.  
Primary request: Create exactly one compact square Classic Mac OS 9 close box translated into RainShadow noir. Geometry: a small perfect square; a thin near-black 1-pixel outer outline; a shallow raised outer plate with one pale pewter highlight on the top and left and one near-black shadow on the bottom and right; and a distinctly smaller recessed inner square occupying about 55 percent of the control width. No X or glyph. It is not a zoom box, not a raised inner block, and not a thick ornate picture frame.  
Scene/backdrop: perfectly flat solid `#00FF00` chroma-key background.  
Style/medium: late-1990s pre-rendered CRPG bitmap UI, straight-on orthographic, readable at 64×64.  
Hard constraints: only this shallow two-layer construction. No surrounding socket, no title-bar stripes inside the button, no rounded corners, no traffic-light colors, no brass, no warm hue, no cast shadow, no glow, no watermark, no green inside the control.

## Processing and runtime contract

`ArtSource/Processing/process_ui_chrome_v05_inventory.py outer_v12 close_inventory_macos9_v11` produces:

- `ArtSource/Generated/UI/Inventory/inventory_outer_frame_v12_keyed.png`
- `RainShadow Shared/Resources/Art/UI/Inventory/inventory_outer_frame_v12.png` at 1960×1080
- `ArtSource/Generated/UI/Common/inventory_close_box_macos9_noir_v11_keyed.png`
- `RainShadow Shared/Resources/Art/UI/Common/inventory_close_box_macos9_noir_v11.png` at 128×128

The frame owns only the flat left reserve and the flat center title gap. The Inventory-specific close sprite owns every visible edge and displays at 64×64, centered at `(-899, 469)`, while the existing 100×100 transparent hit target remains unchanged. Journal and map overlays retain the shared V04/44 control.
