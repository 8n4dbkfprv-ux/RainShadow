# Dialogue outer frame V08 (complete sidebar-matched redo)

Date: 2026-08-01  
Generator: Cursor default Image Generator  
Frame master: `dialogue_outer_frame_overlay_v08b_gen.png` (shipped as `v08_gen`)  
Frame keyed/runtime: `dialogue_outer_frame_overlay_v08.png` — 1720×583 RGBA

## Intent

Keep the dialogue panel system (content plate, speaker, body, choices, scrollbar,
command bar) unchanged. Completely redo the outer frame artwork — not a
style-transfer edit of V07 — so the metal reads as cut from the same sheet as
`hud_left_rail_plate_v03`: coarse hammered gunmetal, bright silver bevels, deep
black recesses, stepped utility corners.

Follow-up corrections from review:

1. No Art Deco sunburst / half-circle caps on the top or bottom rails.
2. Clear rectangular transparent space in the portrait window, with a visible
   gap separating the detached portrait bezel from the outer top and left rails.

## Generator prompt (complete redo)

```text
Use case: ui-mockup
Asset type: production 2D game UI dialogue-frame overlay for RainShadow.
Input images:
- Image 1 (material board): sole material/palette/texture-scale/bevel authority from hud_left_rail_plate_v03.
- Image 2 (geometry board): low-wide dialogue plaque hierarchy only (~2.95:1, TL portrait bezel, huge content opening).
Primary request: Brand-new original dialogue outer frame from scratch (complete redo, not an edit of any prior dialogue frame). Metal must look cut from the same sidebar asset sheet: thick beveled rails, cloudy mottling, coarse pits, bright worn-silver edge highlights.
Composition: front-facing orthographic UI frame; continuous outer rectangle; compact detached upper-left portrait bezel with green gap from outer rails; enormous empty green main opening; clear right gutter; near-square stepped corners. No protruding sunburst/half-circle caps.
Background/openings: flat uniform #00FF00 outside the frame, in the main opening, and in the portrait hole.
Text: none.
Avoid: half circles, fans, sunbursts, red gems, gold, fantasy filigree, scrollbar, buttons, portraits, text, watermark.
```

## Deterministic finish

Chroma-key + soft edge contract → trim → stretch to 1720×583 → cold grayscale →
histogram-match to `hud_left_rail_plate_v03` → unsharp → hard-clear rectangular
portrait hole and remove residual corner ornaments protruding into the wells.

## Runtime

- `RainShadow Shared/Resources/Art/UI/Dialogue/dialogue_outer_frame_overlay_v08.png`
- Loader prefers v08, falls back through v07…v02.
- Portrait hole fractions (measured): L=146/1720, W=207/1720, T=86/583, H=169/583.
