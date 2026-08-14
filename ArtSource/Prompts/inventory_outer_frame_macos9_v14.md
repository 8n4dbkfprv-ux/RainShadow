# RainShadow Inventory Mac OS 9 geometry V14

Date: 2026-08-13  
Generator: Cursor built-in default Image Generator, then a deterministic Platinum geometry lock

This pass copies **literal Platinum geometry** from high-resolution Mac OS 9 title-bar photographs and remaps **only the palette** to RainShadow noir. It is not an OS 9-inspired interpretation.

V13 still had two mismatches versus the photographs: the title gap was a bordered pill, and the title bar was ~101px of 1080 (~9%) instead of OS 9's ~20–22px on a ~572px window (~4%). Generator object-edits of V13 (V14a, V14b, title-bar crop) kept emitting a capsule and a fat bar. V14 therefore keeps V14b's noir window body and **locks** the title strip to measured Platinum proportions.

## Retained outputs

- Frame first pass (rejected: still a pill / ~80px bar): `inventory_outer_frame_v14a_gen.png`
- Frame second pass (rejected: still a plaque / ~68px bar on 1024): `inventory_outer_frame_v14b_gen.png`
- Title-bar crop study (rejected: still a bordered gap): `inventory_titlebar_v14_gen.png`
- Frame master: `ArtSource/Generated/UI/Inventory/inventory_outer_frame_v14_gen.png` (geometry-locked 1960×1080)
- Frame master SHA-256: `d05a25abc6990ac4a40826cdf1424b7d8d9960803fd285485e100d45cffbd71c`
- Shipping close: cropped from the V14 title-bar widget so the live sprite matches the stamped-in box
- Close SHA-256: `05ced8109cb3046853dd77146636e18c786b8a598509445e730765816fc7abb9`

## Literal Platinum geometry (do not interpret)

Copied from the high-res OS 9 photographs; noir palette only.

- Title bar **is the top of the window**. 1px near-black outer outline + one thin bevel. Height ≈ 4% of window height = **43px on the 1960×1080 canvas** (OS 9: ~20–22px on ~572px). Not a well inside a slab. Not ~101px.
- Flat charcoal field with **exactly six** 1px dark hairline pinstripes, packed to fill the inner bar. Full width except widget/title interruptions. No left parking plate.
- Title gap: snug **unstriped rectangular interruption** of the six hairlines. Same field color as the bar. A few pixels of padding around the live label. **No rounded capsule. No extra border/plaque.** Leave the gap blank — do not bake INVENTORY, no Apple logo. Gap width 240px for Copperplate-Bold 36 "INVENTORY" (~216px) + 12px pad/side.
- Close box stamped INTO the stripe field: small square, dark outer, inner bevel, **diagonal gradient face** (darker top-left → lighter bottom-right). Height ≈ inner title-bar height minus 1px = **38px**. Not nested squares (that is Zoom).
- Right: Zoom = nested squares with inner square offset toward **top-left**; WindowShade = two thick horizontal bars. Same size/grammar as close, stamped into stripes.
- Side/bottom rails: slim **single** bevel, not a chiseled double ridge. Sunken content well. Optional OS 9 resize gripper at bottom-right.

## Frame prompt (generator, V14a/V14b)

Use case: ui-mockup / object-edit of the V13 noir window  
Input images: high-resolution Mac OS 9 Platinum title-bar photographs are the geometry authority. The V13/V14b noir frame is palette and window-body authority only.

Exact construction copied from the photographs (the generator did not emit this; the processor locks it):

- Thin title bar that **is the top of the window**. 1px near-black outer outline. One slim bevel. Title-bar height = 4% of window height (40–45px on 1080).
- Flat charcoal field with exactly six 1px-class dark hairline pinstripes.
- Stripes interrupted only by: close box (left), empty rectangular title gap (center), Zoom + WindowShade (right). No pill. No parking plate. No baked INVENTORY. No Apple logo.
- Close: diagonal-gradient face, not nested squares.
- Slim single-bevel side/bottom rails. Interior: solid black.

Hard forbidden (V13/V14a/V14b failures): ~101px / ~8% title bar; rounded bordered title capsule; nested-square close; Zoom inner square offset bottom-right; chiseled double-ridge rails; left parking plate.

## Processing and runtime contract

`ArtSource/Processing/process_ui_chrome_v05_inventory.py outer_v14` reads `inventory_outer_frame_v14b_gen.png`, locks the title strip, flood-keys the black well, and writes:

- `ArtSource/Generated/UI/Inventory/inventory_outer_frame_v14_{gen,keyed}.png`
- `RainShadow Shared/Resources/Art/UI/Inventory/inventory_outer_frame_v14.png` at 1960×1080
- `ArtSource/Generated/UI/Common/inventory_close_box_macos9_noir_v13_keyed.png` (cropped from the title-bar close)
- `RainShadow Shared/Resources/Art/UI/Common/inventory_close_box_macos9_noir_v13.png` at 128×128

Overlay: live `INVENTORY` label centered in the title gap (`titleY` 517, `verticalAlignmentMode = .center`). Close sprite at `(-951, 517)` displayed at 38×38 in the left stripe field (100×100 hit target unchanged). Zoom and WindowShade are decorative and baked into the frame. Journal/map keep the shared V04 control.
