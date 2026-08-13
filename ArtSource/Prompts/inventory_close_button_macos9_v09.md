# RainShadow Inventory close control + frame reserve V09

Date: 2026-08-13  
Generator: Codex built-in default Image Generator  
Use cases: `precise-object-edit`, `stylized-concept`

## Retained outputs

- Frame output: `exec-f4950e25-7a94-46fd-b74e-60427059bc04.png`
- Frame master: `ArtSource/Generated/UI/Inventory/inventory_outer_frame_v09_gen.png`
- Frame master SHA-256: `8b14d49249db2c33b7f81d52f55a2233bb4b1c22ad2460a42c85079d06220584`
- Close output: `exec-808b1e21-cf5a-4232-9e4c-4aaffbbfa6da.png`
- Close master: `ArtSource/Generated/UI/Common/inventory_close_box_macos9_noir_v09_gen.png`
- Close master SHA-256: `ea6e9b32ff8adbf9488cc1d6aae9de35410ce7a301f8cd46bfa0310544f526bd`

## Reference roles

- `inventory_outer_frame_v08_gen.png`: frame geometry, title plaque, groove rhythm, material, and chroma composition authority.
- User-supplied `classic-mac-os^1999^system-9-system-folder.png`: Classic Mac OS 9 close-box placement and shape grammar only.

## Frame reserve prompts

### Remove the baked control

Use case: precise-object-edit  
Asset type: production game UI chrome master for the RainShadow Inventory overlay  
Input images: Image 1 is the edit target and absolute authority for canvas, frame geometry, title plaque, grooves, material, lighting, color, and chroma field. Image 2 is Classic Mac OS 9 shape context only.  
Primary request: Remove only the complete beveled square close-button/close-seat construction at the far left of Image 1's title bar. Replace that square area seamlessly with the same uninterrupted horizontal title-bar grooves and surrounding charcoal gunmetal already present immediately to its right, so a separate live close control can later be composited over the grooves. There must be no button, square seat, recess, blank square patch, hole, icon, X, or special close geometry baked into the frame.  
Constraints: Change only the former close-square area. Keep every other pixel-level design feature visually invariant: exact straight-on 1960:1080 aspect, frame silhouette and proportions, outer border, thin side and bottom rails, top-bar height, number/thickness/spacing of horizontal grooves, centered blank title plaque, pitted noir gunmetal material, cool grayscale palette, bevel lighting, and perfectly flat #00FF00 interior chroma field. Continue the groove lines cleanly to the left inner edge with no seam or repeated texture artifact. No text, no controls, no utility boxes, no watermark. Do not alter or crop any other part of the frame.

### Add quiet breathing room

Use case: precise-object-edit  
Asset type: production game UI chrome master for the RainShadow Inventory overlay  
Primary request: Create one compact quiet groove-free reserve in the far-left portion of the top title bar for a separately composited close control. Fill it only with the same flat matte charcoal gunmetal base material as the title bar beneath the grooves. This is only empty visual breathing space: do not draw a button, close box, inset face, square outline, bevel, border, socket, recess, hole, X, icon, or raised plate. Stop the groove lines cleanly at the reserve edges and resume them cleanly after it.  
Final correction: Flatten the reserve into a completely unoutlined, unbeveled patch; remove any pale or dark edge, rectangular border, inset edge, recess, and corner treatment. Preserve the rest of the frame exactly.

## Standalone close-control prompt

Use case: stylized-concept  
Asset type: standalone interactive game UI close-box sprite for RainShadow Inventory  
Input images: Image 1 is the exact material, palette, bevel-lighting, groove scale, and title-bar context authority. Image 2 is Classic Mac OS 9 close-box shape grammar authority only.  
Primary request: Create exactly one compact standalone square close-box control that visually belongs on Image 1's striped title bar. It must own its entire silhouette so it can be composited over uninterrupted grooves with no painted seat beneath it. Use the Classic Mac OS 9 idea of a small square Platinum close box with no X glyph: a restrained thin outer square plate that masks the grooves beneath, one crisp upper-left light/lower-right dark bevel, and a simple inset dark square push face. Keep the construction shallow, slim, and readable at a final on-screen size of about 58×58 px. The outer rim must not dominate the button.  
Scene/backdrop: perfectly flat solid #00FF00 chroma-key background, uniform edge to edge with no shadows, gradients, texture, reflections, or floor plane.  
Style/medium: late-1990s pre-rendered CRPG bitmap UI, straight-on orthographic, original RainShadow noir interpretation rather than a literal copied control.  
Color palette: cool neutral charcoal, graphite, blackened nickel, and sparse rubbed pewter only.  
Constraints: no X, letters, icons, dots, traffic-light colors, warm metal, rounded modern corners, giant chunky border, double frame, title-bar stripes inside the button, cast shadow, glow, reflection, watermark, or second object.

## Processing and runtime contract

`ArtSource/Processing/process_ui_chrome_v05_inventory.py outer_v09 close_inventory_macos9_v09` produces:

- `ArtSource/Generated/UI/Inventory/inventory_outer_frame_v09_keyed.png`
- `RainShadow Shared/Resources/Art/UI/Inventory/inventory_outer_frame_v09.png` at 1960×1080
- `ArtSource/Generated/UI/Common/inventory_close_box_macos9_noir_v09_keyed.png`
- `RainShadow Shared/Resources/Art/UI/Common/inventory_close_box_macos9_noir_v09.png` at 128×128

The frame owns only the flat reserve. The Inventory-specific close sprite owns every visible edge and displays at 60×60, centered at `(-899, 469)`, while the existing 100×100 transparent hit target remains unchanged. Journal and map overlays retain the shared V04/44 control.

## Runtime QA

- Capture: `ArtSource/Generated/UI/Inventory/inventory_frame_v09_close_runtime_qa.png` (800×632 macOS window).
- The flat reserve is visible around one standalone close control; no nested/baked second square remains.
- Clicking the visible button center and the right edge of the larger live target both dismiss Inventory.
- macOS and iOS simulator Debug builds pass, both bundles contain the V09 frame and close PNG, and the SwiftPM suite passes 560 tests.

## V10–V11 runtime correction

Subsequent user review identified two remaining readings: the center reserve still looked like a bordered plaque, and the far-left frame space still appeared button-like. The built-in default Image Generator produced:

- `exec-5d901fc9-28e1-4b2c-be7b-5d0e520570ac.png` (SHA-256 `a294b4ed0d06173d04583e801d761942213b907c4481330e79cd9dd7de33d563`): flat center stripe interruption, with no plaque or outline.
- `exec-61a4a84e-f976-4333-828c-f5571eb89214.png` (SHA-256 `ee516f0621c3d6d383b4869dc6f0314f9947c77c99830571286e0f2335f80663`): new standalone single-bevel Inventory close control.

The final `inventory_outer_frame_v11_gen.png` is a deterministic composite of the V09 frame-only reserve and the corrected generated center gap. This avoids generative geometry drift while retaining generated design content: the far-left end is a compact seamless unstriped bar segment with no baked square, and the center title is likewise only an interruption in the stripe lines. Runtime ships `inventory_outer_frame_v11` plus the separate `inventory_close_box_macos9_noir_v10` at 64×64. Capture: `ArtSource/Generated/UI/Inventory/inventory_frame_v11_runtime_qa.png`.

### Exact retained V10 center-gap prompt

Use case: precise-object-edit  
Asset type: production game UI chrome master for the RainShadow Inventory overlay, version V10  
Input images: Image 1 is the exact edit target and absolute authority for the outer frame, title-bar height, left close reserve, groove rhythm, noir material, lighting, palette, canvas, and chroma well. Image 2 is Classic Mac OS 9 title-bar layout context only.  
Primary request: Fix only the CENTER title area of Image 1. Remove the entire bordered, beveled, squarish center title plaque. Replace it with a simple quiet gap in the horizontal stripes for live code-rendered text. The horizontal grooves must end cleanly before a centered text gap and resume cleanly after it. Inside the gap there must be only the same completely flat matte charcoal title-bar base surface that lies beneath the grooves.  
Critical geometry: The center gap should be a clean horizontal text reserve approximately 410 pixels wide at a final 1960×1080 canvas, centered on the window. It is not a box or object. It must have no visible top, bottom, left, or right boundary and no corner shape. The underlying outermost window-frame rails at the very top and the title bar's lower separator remain continuous across the whole window; only the internal horizontal groove lines are interrupted for the text.  
Hard invariance: Preserve the left close-button reserve exactly as Image 1, including its flat unoutlined quiet surface and placement. Preserve every other pixel-level feature: 1960×1080 aspect, frame silhouette, straight outer borders, thin side/bottom rails, top-bar height, groove count/thickness/spacing outside the center gap, pitted cool noir gunmetal, bevel lighting, and flat #00FF00 interior. No text, no title plaque, no rectangle, no outline, no bevel around the text gap, no socket, no utility control, no close button, no X, no watermark, no crop, and no changes outside the former center plaque.

### Exact retained V10 close-control prompt

Use case: stylized-concept  
Asset type: replacement standalone interactive close-box sprite for the RainShadow Inventory V10 title bar  
Input images: Image 1 is the exact V10 title-bar material, palette, scale, lighting, and placement context authority. Image 2 is Classic Mac OS 9 close-box grammar authority only.  
Primary request: Create exactly one unmistakably new, very simple Classic Mac-style square close control for the flat far-left reserve in Image 1. The complete control must be standalone and own its whole silhouette. Use ONLY this shallow construction: one thin square outer edge with a narrow pale pewter highlight on the top and left; one narrow near-black shadow edge on the bottom and right; and one large completely flat charcoal center face. The center face should occupy about 75 percent of the control's width. No X or glyph. It must read as a restrained flat 1999 Platinum button translated into noir, not as a miniature ornate picture frame.  
Scene/backdrop: perfectly flat solid #00FF00 chroma-key background, uniform edge to edge with no shadow, gradient, texture, reflection, or floor plane.  
Style/medium: late-1990s pre-rendered CRPG bitmap UI, straight-on orthographic, crisp and readable at a final on-screen size of 64 by 64 pixels.  
Color/material: cool neutral graphite and blackened nickel with only one sparse rubbed-pewter top/left highlight; subtle fine pitting matching Image 1.  
Composition: exactly one centered square control, perfectly front-facing, about 45 percent of the image width, generous chroma padding, complete unclipped silhouette.  
Hard constraints: exactly one visible bevel layer. No second rim, no inner bevel, no nested square border, no socket, no surrounding plate, no double frame, no title-bar stripes inside it, no rounded corners, no X, letters, symbols, dots, colored traffic lights, brass, warm hue, cast shadow, glow, reflection, watermark, or second object. Do not use green inside the control.
