# RainShadow Inventory Mac OS 9 geometry V15

Date: 2026-08-14  
Generator: Cursor built-in default Image Generator, then a rectangular title-gap lock

V14 was already installed (Python-locked 43px bar). This pass re-asks the Image Generator for the two remaining V13 mismatches: a bordered title pill, and a title bar that was still a thick well rather than OS 9's ~4% Platinum strip. V15a still emitted a ~67px bar. Object-edits of V14 produced V15b/V15c, the first generator frames whose title strip measures ~40px on 1024 (~3.9%). Residual 1px vertical strokes at the gap are painted out by the processor.

## Retained outputs

- Frame first pass (rejected: ~67px / 6.9% bar): `inventory_outer_frame_v15a_gen.png`
- Frame second pass (thin bar, residual gap stroke): `inventory_outer_frame_v15b_gen.png`
- Frame master: `inventory_outer_frame_v15c_gen.png` (thin bar; gap stroke locked in processing)
- Title-bar crop studies: `inventory_titlebar_v15a_gen.png`, `inventory_titlebar_v15b_gen.png`
- Frame master SHA-256: `5126bad36dc64e815d11e8049f96ce2e18b408099c250877165077e120e16ae6`
- Shipping close: cropped from the V15 title-bar widget so the live sprite matches the stamped-in box
- Close SHA-256: `761ffafbab3fb0d4c42c8d9b7fad9f2da61ec01a02facfdb9fdae40655ece431`

## Literal Platinum geometry (do not interpret)

Copied from the high-res OS 9 photographs; noir palette only.

- Title bar **is the top of the window**. 1px near-black outer outline + one thin bevel. Height ≈ 4% of window height = **43px on the 1960×1080 canvas**. Not a well inside a slab. Not ~101px.
- Flat charcoal field with **exactly six** 1px dark hairline pinstripes, packed to fill the inner bar. Full width except widget/title interruptions. No left parking plate.
- Title gap: snug **unstriped rectangular interruption** of the six hairlines. Slightly lighter than the stripe field. A few pixels of padding around the live label. **No rounded capsule. No extra border/plaque.** Leave the gap blank — do not bake INVENTORY, no Apple logo. Gap width 240px for Copperplate-Bold 36 "INVENTORY".
- Close box stamped INTO the stripe field: small square, dark outer, inner bevel, **diagonal gradient face** (darker top-left → lighter bottom-right). Height ≈ inner title-bar height. Not nested squares (that is Zoom).
- Right: Zoom = nested squares with inner square offset toward **top-left**; WindowShade = two horizontal bars, thicker over thinner. Same size/grammar as close, stamped into stripes.
- Side/bottom rails: slim **single** bevel. Sunken content well. Optional OS 9 resize gripper at bottom-right.

## Frame prompt (generator, V15a–V15c)

Use case: ui-mockup / object-edit  
Input images: high-resolution Mac OS 9 Platinum title-bar photographs are the geometry authority. V13/V14 noir frames are palette references only.

Exact construction:

- Thin title bar that **is the top of the window**. 1px near-black outer outline. One slim bevel. Title-bar height = 4% of window height (40–45px on 1080).
- Flat charcoal field with exactly six 1px-class dark hairline pinstripes.
- Stripes interrupted only by: close box (left), empty rectangular title gap (center), Zoom + WindowShade (right). No pill. No parking plate. No baked INVENTORY. No Apple logo.
- Close: diagonal-gradient face, not nested squares.
- Slim single-bevel side/bottom rails. Interior: solid black.

Hard forbidden: ~101px / ~8% title bar; rounded bordered title capsule; nested-square close; Zoom inner square offset bottom-right; chiseled double-ridge rails; left parking plate.

## Processing and runtime contract

`ArtSource/Processing/process_ui_chrome_v05_inventory.py outer_v15` reads `inventory_outer_frame_v15c_gen.png`, uniform-scales to 1080 tall (square widgets), expands stripe runs to 1960, paints a 240px slightly-lighter rectangular unstriped gap, flood-keys the black well, and writes:

- `ArtSource/Generated/UI/Inventory/inventory_outer_frame_v15_{gen,keyed}.png`
- `RainShadow Shared/Resources/Art/UI/Inventory/inventory_outer_frame_v15.png` at 1960×1080
- `ArtSource/Generated/UI/Common/inventory_close_box_macos9_noir_v14_keyed.png` (cropped from the title-bar close)
- `RainShadow Shared/Resources/Art/UI/Common/inventory_close_box_macos9_noir_v14.png` at 128×128

Overlay: live `INVENTORY` label centered in the title gap (`titleY` 518, `verticalAlignmentMode = .center`). Close sprite at `(-956, 518)` displayed at 30×30 in the left stripe field (100×100 hit target unchanged). Zoom and WindowShade are decorative and baked into the frame. Journal/map keep the shared V04 control.
