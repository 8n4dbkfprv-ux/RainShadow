# Dialogue panel sidebar-material V07

Date: 2026-08-01  
Generator: Codex built-in default Image Generator  
Frame master: `dialogue_outer_frame_overlay_v07_gen.png`  
Frame locked-alpha derivative: `dialogue_outer_frame_overlay_v07_keyed.png`  
Command master: `dialogue_command_button_plate_v06_gen.png`  
Command locked-alpha derivative: `dialogue_command_button_plate_v06_keyed.png`

## Intent

Keep the user-approved V06/V05 reference-shaped geometry unchanged while correcting the
material mismatch against the shipped RainShadow sidebars. The sole material authority is
`hud_left_rail_plate_v03.png`: neutral cold grayscale, coarse mottled/hammered gunmetal,
visible pits and scuffs, bright rubbed-silver bevels, and deep black recessed seams.

## Final frame material-transfer prompt

```text
Use case: style-transfer
Asset type: production 2D game UI dialogue-frame texture revision.
Input images: Image 1 is the sole material, palette, texture-scale, bevel-lighting, and rendering-style authority. Image 2 is the edit target and sole geometry authority.
Primary request: visibly replace every exposed metal surface in Image 2 with the exact same coarse, cloudy, hammered and pitted grayscale gunmetal seen on Image 1. Match Image 1's chunky late-1990s pre-rendered CRPG texture scale, irregular pale-gray mottling, scratched pits, hard near-black recesses, and distinctly brighter worn-silver bevels. The result must immediately look cut from the same sidebar asset sheet, not like a subtle recolor of Image 2.
Critical material correction: completely remove Image 2's smooth black nickel, fine rain scratches, leather-like micrograin, looping etched marks, and delicate modern polish. On broad rail faces use large irregular cloudy blotches and coarse stippled pits like Image 1. Make outward-facing edge highlights approximately as bright and thick as Image 1's long vertical silver rails, while seams remain near black. Force cold neutral grayscale except for the two tiny muted oxblood fasteners.
Geometry invariants: keep Image 2's exact pixel silhouette, exact 1720:583 proportions, rail widths, miters, corner pieces, portrait bezel position and dimensions, two side fasteners, huge main opening, clear right gutter, front-facing view, padding, and alignment. Do not add, remove, thicken, thin, move, bend, crop, or redesign anything.
Background/openings: preserve true transparency exactly everywhere Image 2 is transparent, including the main opening, portrait opening, and exterior. No fill, shadow, glow, fog, reflection, or texture in transparent areas.
Text: none.
Constraints: change only RGB material/texture/lighting on existing opaque pixels; no new shapes or ornament.
Avoid: organic curls, engraved squiggles, leather, smooth nickel, fine uniform scratches, brown or warm tint, gold, brass, steampunk, fantasy filigree, tabs, crowns, fan motifs, extra screws, scrollbar, button, text, watermark.
```

## Final command material-transfer prompt

```text
Use case: style-transfer
Asset type: production 2D game UI command-button plate texture revision.
Input images: Image 1 is the sole material, palette, texture-scale, bevel-lighting, and rendering-style authority. Image 2 is the edit target and sole geometry authority.
Primary request: visibly replace every exposed surface in Image 2 with the exact same coarse, cloudy, hammered and pitted grayscale gunmetal seen on Image 1. Match Image 1's chunky late-1990s pre-rendered CRPG texture scale, irregular pale-gray mottling, scratched pits, hard near-black recesses, and distinctly brighter worn-silver bevels. It must immediately look fabricated from the same sidebar asset sheet, not like a subtle recolor.
Critical material correction: completely remove Image 2's leather-like looping/etched squiggle pattern, smooth black nickel, delicate grain, and organic scroll texture. The wide central face must instead be subdued dark hammered steel with broad irregular cloudy mottling and coarse stippled pits like Image 1, quiet enough for a live code-drawn label. Make the double rim's outward edge as bright and chunky as Image 1's long silver rails; keep recessed seams near black. Force cold neutral grayscale except for the two tiny muted oxblood fasteners.
Geometry invariants: keep Image 2's exact 1024:116, 8.8:1 silhouette, exact thin double rim, rail widths, square corners, wide central label face, fastener positions, front-facing view, padding, and alignment. Do not add, remove, thicken, thin, move, bend, crop, or redesign anything.
Background: preserve true transparency exactly everywhere Image 2 is transparent. No fill, checkerboard baked into pixels, shadow, glow, fog, reflection, or texture outside the plate.
Text: none.
Constraints: change only RGB material/texture/lighting on existing opaque pixels; no new shapes or ornament.
Avoid: organic curls, etched squiggles, leather, smooth nickel, fine uniform scratches, brown or warm tint, gold, brass, steampunk, fantasy filigree, tabs, crowns, extra screws, attached frame, icons, letters, text, watermark.
```

## Deterministic runtime finish

`process_dialogue_noir_v07()` resizes the generated repaint, restores the approved V06/V05
alpha arrays byte-for-byte, forces the HUD's neutral-cool grayscale, histogram-matches opaque
chrome to `hud_left_rail_plate_v03`, and applies a modest final-size unsharp pass. The command
face then receives high-frequency texture sampled from four shipped HUD button wells at the
HUD-to-command display-scale ratio, replacing the too-fine leather micrograin with the same
coarse mottling visible in the sidebars. Transparent RGB is cleared after every pass.

## Runtime outputs

- `RainShadow Shared/Resources/Art/UI/Dialogue/dialogue_outer_frame_overlay_v07.png` — 1720×583 RGBA.
- `RainShadow Shared/Resources/Art/UI/Dialogue/dialogue_command_button_plate_v06.png` — 1024×116 RGBA.

V06/V05 remain in the bundle as fallback art. Runtime layout fractions do not change because
the new assets reuse their alpha geometry exactly.
