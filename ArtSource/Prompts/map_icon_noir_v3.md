# RainShadow noir map icon V3

Date: 2026-07-19  
Generator: built-in Image Generator  
Generated source: `exec-ddeb86ba-c0af-463a-a16b-2c3b9bc72f6f.png`

## Input roles

- `map_icon_noir_v02.png`: edit target and authoritative compass geometry.
- `hud_portrait_frame_v01.png`: primary shipped HUD palette and material reference.
- `inventory_outer_frame_overlay_v01.png`: supporting shipped UI palette and material reference.
- `map-icon-v02-macos.png`: actual runtime scale and surrounding-interface reference.

## Final prompt

```text
Use case: style-transfer
Asset type: production game UI icon recolor
Input images: Image 1 is the edit target and authoritative geometry; Image 2 is the primary RainShadow HUD color/material reference; Image 3 is a supporting RainShadow frame palette reference; Image 4 shows the edit target at its actual in-game scale and surrounding UI context.
Primary request: Refinish only the color palette and surface treatment of the compass Map icon in Image 1 so it belongs naturally beside the shipped RainShadow UI in Images 2–4 and no longer appears brighter or more monochrome than the surrounding interface.
Color palette: make the outer frame and compass predominantly dark blue-black gunmetal and charcoal steel matching Images 2 and 3; use muted deep oxblood/burgundy only in small recessed accent panels or compass-point insets; use aged dark brass only for tiny pins and restrained engraved line accents; keep the central N a subdued warm gray/smoked pewter so it remains readable without approaching bright white. Preserve the deep black inner backing.
Lighting/mood: reduce the broad silver highlights and overall brightness; retain narrow cool edge catches, low-key noir chiaroscuro, and restrained local contrast that reads at 108×72 points. The finished icon should sit at the same value level and saturation as the portrait bezel in Image 4.
Materials/textures: rain-worn blue-black steel, pitted charcoal gunmetal, scuffed oxblood leather/enamel recesses, tiny oxidized brass fittings; match the tactile hand-painted rendering quality of Images 2 and 3.
Text (verbatim): "N"
Constraints: change only palette, material finish, and highlight intensity. Preserve Image 1's exact 3:2 landscape canvas, straight-on view, clipped outer silhouette, border thickness, centered eight-point compass geometry, Art Deco engraving layout, single uppercase N shape, scale, placement, spacing, and black background. Render the N exactly once. No new symbols or ornaments. No crop, rotation, perspective change, extra border, toolbar, surrounding interface, words, other letters, numbers, watermark, or logo.
Avoid: bright neutral silver, white-hot highlights, vivid red, orange, yellow gold, fantasy runes, gothic spikes, new decorative geometry, or major shape changes.
```

## Runtime contract

- Source master: `Generated/UI/Map/map_icon_noir_v03.png`, 1536×1024.
- Runtime derivative: `Resources/Art/UI/Map/map_icon_noir_v03.png`, 768×512.
- SpriteKit displays the texture linearly filtered at 108×72 points inside the existing 108×108 map-button hit target.
- Code retains hover scaling and a restrained highlight without altering the generated pixels.
