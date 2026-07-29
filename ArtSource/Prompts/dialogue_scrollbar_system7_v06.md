# Dialogue scrollbar System 7 V06 (RainShadow noir textures)

Date: 2026-07-29  
Generator: Cursor built-in Image Generator (button faces, box, gray area) +
processor-stamped pixel-exact System 7 arrow glyphs

## Intent

Replace the Mac OS 9 Platinum scrollbar suite (V05). Platinum used solid filled
triangles, a proportional scroll box with grip ridges, and a plain recessed track.
System 7 uses different control grammar: outlined arrowheads with a rectangular
stem ("handle"), a fixed square scroll box, and a dithered gray area.

## Control grammar (non-negotiable)

- One arrow at each end of the bar (classic arrangement, not Smart Scrolling doubles)
- Every part is a **crisp rectangle**: no rounded corners, no drop shadows, no glow
- **Flat matte faces.** Lighting lives in the 1px bevel, not in a gradient pillow
- Bevel: light top/left, dark bottom/right (raised); reversed for the recessed gray area
- Outer 1px near-black outline on every part so parts read as one assembled control
- Arrow glyphs are **outlined arrowheads with a rectangular stem** (dark rim, light fill)
  — never Platinum solid black triangles, never stemless triangles
- System 7's stem is longer than the stubby 1984 Mac OS handle
- Grayscale only. Cold gunmetal, no brass, no parchment, no colour accent
- Scroll box is a **fixed square** the size of the arrow boxes (no proportional sizing)
- Gray area is a **50% dither**; when content fits it goes **solid** and the box hides
- No hover tint (System 7 predates hover feedback); press swaps to pressed arrow art

## Parts

1. `dialogue_scroll_up_v06` — 96x96 square button, raised bevel, outlined up arrow + handle
2. `dialogue_scroll_down_v06` — 96x96, matching, outlined down arrow + handle
3. `dialogue_scroll_up_pressed_v06` / `dialogue_scroll_down_pressed_v06` — inverted press
4. `dialogue_scroll_box_v06` — 96x96 fixed square scroll box, plain face, no grip ridges
5. `dialogue_scroll_area_v06` — 30x1024 pixel-exact dither tile (cropped, never stretched)
6. `dialogue_scroll_area_solid_v06` — 30x1024 solid disabled gray area

## Why the arrows are stamped, not generated

Image Generator keeps painting Platinum solid triangles. The authentic System 7 glyph
is an outlined arrowhead with a stem; `stamp_system7_arrow()` draws it from a native
1× bitmap and nearest-neighbour scales it onto the blank button face so up/down stay
identical and the handle length cannot drift.

## Why the gray area ships pixel-exact

Same failure mode as the old grip ridges: a painted stipple scaled to the 30pt column
merges the two gunmetal values into grey mush. `pixel_exact_dither()` rebuilds a 2pt
checker on a 30×1024 canvas; runtime crops with `SKTexture(rect:in:)` instead of
stretching.

## Flush assembly

Buttons abut the gray area with no gap. Arrow boxes carry outline on all four sides;
the gray-area tile carries left/right outlines only so joints stay a single hairline.

## Geometry (code)

Fixed square scroll box: side = `min(trackWidth, trackHeight)`. Arrow step = one line;
gray-area page = viewport − one line.

## Source

`dialogue_scrollbar_assembled_system7_v06_gen.png` — style-lock reference  
`dialogue_scroll_components_system7_v06_gen.png` — blank raised/pressed faces (2×2)  
`dialogue_scroll_box_system7_v06_gen.png` — plain square scroll box  
`dialogue_scroll_area_system7_v06_gen.png` — dither + solid side-by-side  
Processor: `process_ui_chrome_v03.py` → `process_dialogue_scrollbar_system7_v06`

## Runtime wiring

- `DialogueScrollbarNode` loads the V06 suite (V05 fallbacks); crops gray area; swaps
  pressed arrow textures; no hover tint; no grip; no nine-slice
- `DialogueScrollbarGeometry` fixed-square `thumbLayout`, `arrowStep` / `pageStep`
- Shipped 2026-07-29; verified via `preview_scrollbar_v06.py` at 30pt column width
