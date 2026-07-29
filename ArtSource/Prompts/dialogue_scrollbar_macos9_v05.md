# Dialogue scrollbar Mac OS 9 Classic V05 (RainShadow noir textures)

Date: 2026-07-29  
Generator: Cursor built-in Image Generator  

## Intent

Replace the V04 suite. V04 aimed at Mac OS 9 but drifted away from the actual
Platinum control grammar: the arrow buttons were thick pillowed picture frames with
*engraved* triangles, the track was woven leather inside an ornate rounded frame, and
the scroll box was an outline-less brushed slab. V05 paints the real thing — flat
faces, single-pixel bevels, solid glyphs, a plain recessed channel — in RainShadow's
cold gunmetal noir palette.

## Control grammar (non-negotiable)

- One arrow at each end of the bar (classic arrangement, not Smart Scrolling doubles)
- Every part is a **crisp rectangle**: no rounded corners, no drop shadows, no glow
- **Flat matte faces.** Lighting lives in the 1px bevel, not in a gradient pillow
- Bevel: light top/left, dark bottom/right (raised); reversed for the recessed track
- Outer 1px near-black outline on every part so parts read as one assembled control
- Arrow glyphs are **solid filled** dark triangles sitting on the face — never engraved
- Grayscale only. Cold gunmetal, no brass, no parchment, no colour accent

## Parts

1. `dialogue_scroll_up_v05` — 96x96 square button, raised bevel, solid up triangle
2. `dialogue_scroll_down_v05` — 96x96, matching, solid down triangle
3. `dialogue_scroll_track_v05` — 64x320 flat recessed channel tile, vertical nine-slice
4. `dialogue_scroll_thumb_v07` — 64x160 raised scroll box, plain face, vertical nine-slice
5. `dialogue_scroll_thumb_grip_v09` — 24x18 centred grip ridges, fixed-size overlay

## Why the grip stays a separate asset

Unchanged from V04. Baking the ridges into the thumb makes the nine-slice stretch them
with the proportional scroll box, and scaling painted ridges down to the ~20pt grip
merges each highlight into its shadow. The grip ships at its exact on-screen size and
is drawn 1:1 with `.nearest` filtering. As in Mac OS 9, the ridges are dropped when the
scroll box is too short to hold them.

## Flush assembly

Mac OS 9 scroll bars share borders: the arrow buttons abut the track with no gap, and
the scroll box fills the full track width. V05 drops the V04 runtime 3pt inter-part gap
and the 2pt thumb width inset (`DialogueScrollbarGeometry.thumbWidthInset`).

## Geometry (code)

Proportional thumb retained from V04: height scales with `viewport/content`, clamped to
`minimumThumbHeight`.

## Prompt language that worked

"flat matte face, single-pixel bevel, solid filled triangle, no engraving, no pillowing,
no fabric texture, machined gunmetal, film-noir cold grey, pure #00ff00 background".

## Source

`dialogue_scrollbar_assembled_macos9_v05_gen.png` — style-lock reference (whole bar)  
`dialogue_scroll_components_macos9_v05b_gen.png` (2x2: up, down, track, spare; hairline bevel pass)  
`dialogue_scroll_thumb_body_macos9_v05c_gen.png` — plain-faced scroll box (hairline bevel pass)  
`dialogue_scroll_thumb_grip_macos9_v07_gen.png` — grip ridge master  
Processor: `process_ui_chrome_v03.py` → `SCROLL_PARTS_V05`, `THUMB_BODY_V07`, `THUMB_GRIP_V09`

## Runtime wiring

- `DialogueScrollbarNode` loads `dialogue_scroll_{up,down,track}_v05`, `dialogue_scroll_thumb_v07`,
  `dialogue_scroll_thumb_grip_v09`; vertical-only `centerRect` (x=0, y=0.05, w=1, h=0.90)
- `DialogueScrollbarGeometry.chromeLayout` assembles flush buttons + track; `thumbWidthInset = 0`
- Shipped 2026-07-29; verified in-game on the dialogue panel at 30pt column width
