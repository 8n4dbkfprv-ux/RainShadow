# RainShadow Inventory Platinum frame V08

Date: 2026-08-13  
Generator: Codex built-in default Image Generator  
Use case: `ui-mockup`  
Generator output: `exec-6bc4c2d8-3323-4e74-915a-33299074c51e.png`  
Retained master: `ArtSource/Generated/UI/Inventory/inventory_outer_frame_v08_gen.png`  
Master SHA-256: `540e84248d339fd54017804a5363a92fcddcb774d9e589aa3d9bbd7f26f6d346`

## Reference roles

- `inventory_outer_frame_v07_gen.png`: edit target and border-only/chroma composition authority.
- User-supplied `classic-mac-os^1999^system-9-system-folder.png`: Classic Mac OS 9 shape and title-bar grammar authority only.
- `hud_left_rail_plate_v03_gen.png`: RainShadow noir material and wear authority only.
- `dialogue_outer_frame_overlay_v08b_gen.png`: RainShadow bevel, lighting, and rendering authority only.

## Production prompt

Use case: ui-mockup  
Asset type: production game UI chrome master for the RainShadow Inventory overlay  
Input images: Image 1 is the edit target and exact border-only/chroma-master composition authority; Image 2 is Classic Mac OS 9 shape and title-bar grammar authority only; Images 3 and 4 are RainShadow noir material, lighting, wear, and rendering authorities only.  
Primary request: Redesign only the outer frame and title bar of Image 1 into an original RainShadow noir interpretation of the Classic Mac OS 9 Platinum window shape shown in Image 2. Keep a straight-on landscape border-only master in an exact 1960:1080 aspect ratio. The frame must have a square orthographic silhouette, restrained stepped double-line Platinum-style border geometry, very slim side and bottom rails, compact square corners, and a distinct integrated top title bar approximately twice the thickness of the side rails. Across the top title bar, render dense crisp parallel horizontal grooves/stripes on the left and right, interrupted by a centered empty quiet title reserve about 420 px wide for live code-rendered text. At the far left of the title bar, make one empty shallow recessed square seat sized for a separate 44 px close control, centered approximately 46 px from the left edge and 42 px from the top edge. Do not bake the close control itself.  
Scene/backdrop: The entire live interior opening must be one perfectly flat solid `#00FF00` chroma green for local alpha removal. Any exterior area beyond the frame must also be exactly the same flat `#00FF00`.  
Style/medium: late-1990s pre-rendered CRPG UI chrome, polished production bitmap, original design; Mac OS 9 proportions and line rhythm translated into RainShadow noir rather than copied literally.  
Lighting/mood: restrained upper-left worn-metal highlights, near-black lower-right seams, moody film-noir legibility.  
Color palette: cool neutral grayscale only—charcoal, graphite, blackened nickel, sparse rubbed pewter. No warm hue.  
Materials/textures: the same coarse cloudy hammered/pitted gunmetal and crisp narrow pewter bevels as Images 3 and 4; keep the horizontal title grooves readable and the center title reserve visually quiet.  
Text: none. The live title will be rendered by code later.  
Constraints: Change only the outer frame/title bar. Preserve a huge unobstructed rectangular interior well. No panels, items, character, labels, iconography, or scenery. No perspective. No cast shadow or glow crossing the chroma area. No baked close button and no X. No status strip, scrollbar, resize handle, right-side window controls, or utility boxes. No green anywhere in the metal. No watermark.  
Avoid: picture-frame mitres dominating the silhouette; bulky L-shaped corners; fantasy filigree; fan, scallop, crest, or sunburst ornaments; rivet clutter; brass, gold, brown, sepia, leather, oxblood, purple; bright white silver; glossy modern gradients; modern macOS traffic-light controls.

## Processing and runtime

`ArtSource/Processing/process_ui_chrome_v05_inventory.py outer_v08` chroma-keys and cool-grayscale normalizes the master, then resizes it directly to 1960×1080 without horizontal seam expansion so the two groove banks and centered title reserve retain their authored proportions. It writes:

- `ArtSource/Generated/UI/Inventory/inventory_outer_frame_v08_keyed.png`
- `RainShadow Shared/Resources/Art/UI/Inventory/inventory_outer_frame_v08.png`

`InventoryOverlay` keeps `INVENTORY` and the close control live. The close control is centered at `(-899, 469)` on the 1960×1080 SpriteKit canvas, and the identity line moves to y `390` beneath the deeper title bar.

## Runtime QA

- Capture: `ArtSource/Generated/UI/Inventory/inventory_frame_v08_runtime_qa.png` (800×632 macOS window).
- The live title remains centered within the blank plaque, the identity line clears the title bar, and the modular Inventory panels remain unobstructed.
- Clicking the far-left close artwork dismisses the Inventory, confirming the visible recess and 100×100 live hit target are aligned.
- macOS and iOS Debug builds pass; the SwiftPM suite passes 560 tests.
