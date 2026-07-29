# Dialogue scrollbar Mac OS 9 Classic V04 (RainShadow noir textures)

Date: 2026-07-29  
Generator: Cursor built-in Image Generator  

## Intent

Exact **Mac OS 9 Classic / Platinum scrollbar shapes and control grammar**, painted with RainShadow film-noir gunmetal textures (not light platinum fills).

## Parts

1. `dialogue_scroll_up_v04` — square up-arrow button; solid triangle glyph; classic raised TL / dark BR bevel  
2. `dialogue_scroll_down_v04` — square down-arrow button; matching  
3. `dialogue_scroll_track_v04` — recessed stippled track tile (vertical nine-slice)  
4. `dialogue_scroll_thumb_v06` — raised rectangular Platinum scroll box, plain face, classic bevel; vertical nine-slice  
5. `dialogue_scroll_thumb_grip_v08` — the five centered grip ridges as a separate 24×18 overlay

## Why the grip is a separate asset

Baking the ridges into the thumb meant the nine-slice stretched them with the
proportional scroll box, and scaling the painted 18px-per-ridge art down to the ~20pt
grip merged each highlight into its shadow — the ridges read as two or three smeared
grooves instead of five. The grip now ships at its exact on-screen size and is drawn
1:1 with `.nearest` filtering, so it matches the generated art. As in Mac OS 9, the
ridges are dropped entirely when the scroll box is too short to hold them.

## Geometry (code)

Mac OS 9 proportional thumb: height scales with `viewport/content`, clamped to a minimum. Square-only V03 thumb behavior is retired.

## Source

`dialogue_scroll_components_macos9_v04_gen.png` (2×2: up, down, track, draft thumb)  
`dialogue_scroll_thumb_macos9_v04c_gen.png` — Platinum-shaped scroll box with grip ridges, RainShadow gunmetal  
Processor: `process_ui_chrome_v03.py` → `SCROLL_PARTS_V04`
