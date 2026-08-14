# RainShadow Inventory Mac OS 9 geometry V16

Date: 2026-08-14  
Generator: Cursor built-in default Image Generator, then a rectangular title-gap lock and nested-square close stamp

V15 kept the ~4% Platinum strip but its close box still read as a cropped title-bar fragment rather than OS 9's nested-square go-away box. This pass re-asks the default Image Generator with the user's high-res Platinum photographs as geometry authority. V16a–c thickened the bar again (~6–7%). Object-editing the shipped V15 strip produced V16d: a 37px / 3.6% noir title bar with stamped-in close/Zoom/WindowShade. A dedicated nested-square close sprite (V15c) is keyed and stamped into that strip so the live control matches the baked widget.

## Retained outputs

- Frame first pass (rejected: ~71px / 7.3% bar): `inventory_outer_frame_v16a_gen.png`
- Frame second pass (rejected: ~61px / 6.1% bar): `inventory_outer_frame_v16b_gen.png`
- Frame third pass (rejected: ~69px / 6.8% bar): `inventory_outer_frame_v16c_gen.png`
- Frame master: `inventory_outer_frame_v16d_gen.png` (37px / 3.6% strip)
- Title-bar crop studies: `inventory_titlebar_v16a_gen.png`, `inventory_titlebar_v16b_gen.png`
- Close first/second passes (rejected: extra bevel layers / dithered face): `inventory_close_box_macos9_noir_v15a_gen.png`, `inventory_close_box_macos9_noir_v15b_gen.png`
- Close master: `inventory_close_box_macos9_noir_v15c_gen.png` (two nested squares, inset bevel, flat face, chroma green)
- Frame master SHA-256: `d4c752f52bcd604673607bbd5b9bf997b8cea7819abab5a9c7c9ed4f63f5ee0e`
- Shipping frame SHA-256: `a4108d104a17510efff83bb2414e931e7136dea06c0840ca18e240736f15daf9`
- Close generated SHA-256: `d5b3a45d6787a48c7c7acd9541bbe1d71cd211aa607b4ff2de24450b50f205fc`
- Shipping close SHA-256: `7ac2b8f392a6272fdec055fad8647eb071f8767771bf6920a3c533f3e5fd12a7`

## Literal Platinum geometry (do not interpret)

Copied from the high-res OS 9 photographs; noir palette only.

- Title bar **is the top of the window**. 1px near-black outer outline + one thin bevel. Height ≈ 4% of window height = **39px on the 1960×1080 canvas**. Not a well inside a slab.
- Flat charcoal field with **exactly six** 1px dark hairline pinstripes, packed to fill the inner bar. Full width except widget/title interruptions. No left parking plate.
- Title gap: snug **unstriped rectangular interruption** of the six hairlines. Slightly lighter than the stripe field. A few pixels of padding around the live label. **No rounded capsule. No extra border/plaque.** Leave the gap blank — do not bake INVENTORY, no Apple logo. Gap width 240px for Copperplate-Bold 36 "INVENTORY".
- Close box stamped INTO the stripe field: **two nested squares**. Outer 1px near-black outline; recessed inset (darker top/left, lighter bottom/right); smaller flat charcoal face. No X. Height ≈ inner title-bar height minus 1px gutter = **30px**. Not Zoom's offset inner square.
- Right: Zoom = nested squares with inner square offset toward **top-left**; WindowShade = two horizontal bars, thicker over thinner. Same size/grammar as close, stamped into stripes.
- Side/bottom rails: slim **single** bevel. Sunken content well.

## Frame prompt (generator, V16a–V16d)

Use case: ui-mockup / object-edit  
Input images: high-resolution Mac OS 9 Platinum title-bar photographs are the geometry authority. V15 noir frame is palette and proportion reference only.

Exact construction:

- Thin title bar that **is the top of the window**. 1px near-black outer outline. One slim bevel. Title-bar height = 4% of window height (37–43px on 1080).
- Flat charcoal field with exactly six 1px-class dark hairline pinstripes.
- Stripes interrupted only by: close box (left), empty rectangular title gap (center), Zoom + WindowShade (right). No pill. No parking plate. No baked INVENTORY. No Apple logo.
- Close: two nested squares, inset bevel, flat face, no X.
- Slim single-bevel side/bottom rails. Interior: solid black.

Hard forbidden: ~101px / ~8% title bar; rounded bordered title capsule; three-layer picture-frame close; Zoom inner square offset bottom-right; chiseled double-ridge rails; left parking plate.

## Close-control prompt

Standalone OS 9 close box, noir only: two nested squares (1px outer outline + recessed inset well + flat inner face), no X, chroma-green surround. The shipping sprite is this generated control, stamped into the V16 title bar so the live overlay matches the baked widget.

## Processing and runtime contract

`ArtSource/Processing/process_ui_chrome_v05_inventory.py outer_v16` reads `inventory_outer_frame_v16d_gen.png`, uniform-scales to 1080 tall (square widgets), expands stripe runs to 1960, paints a 240px slightly-lighter rectangular unstriped gap, flood-keys the black well, keys `inventory_close_box_macos9_noir_v15c_gen.png`, stamps that nested-square close into the left stripe field, and writes:

- `ArtSource/Generated/UI/Inventory/inventory_outer_frame_v16_{gen,keyed}.png`
- `RainShadow Shared/Resources/Art/UI/Inventory/inventory_outer_frame_v16.png` at 1960×1080
- `ArtSource/Generated/UI/Common/inventory_close_box_macos9_noir_v15_keyed.png`
- `RainShadow Shared/Resources/Art/UI/Common/inventory_close_box_macos9_noir_v15.png` at 128×128

Overlay: live `INVENTORY` label centered in the title gap (`titleY` 520, `verticalAlignmentMode = .center`). Close sprite at `(-957, 520)` displayed at 20×20 in the left stripe field with Platinum padding (8px unstriped field from the inner rail and before the hairlines; 100×100 hit target unchanged). Zoom and WindowShade share the same inset, 5px gap, and 8px stripe gutter. Journal/map keep the shared V04 control.
