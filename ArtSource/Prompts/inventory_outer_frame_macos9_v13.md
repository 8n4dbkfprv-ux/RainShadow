# RainShadow Inventory Mac OS 9 geometry V13

Date: 2026-08-13  
Generator: Cursor built-in default Image Generator  
Use cases: `ui-mockup` (full window), title-bar crop, standalone close box

This pass copies **literal Platinum geometry** from high-resolution Mac OS 9 title-bar photographs and remaps **only the palette** to RainShadow noir. It is not an OS 9-inspired interpretation. V12 failed because its prompt asked for an original noir reading of the shape; do not reuse that language.

## Retained outputs

- Frame first pass (rejected: thick well / fat ridges / left plate): `inventory_outer_frame_v13a_gen.png`
- Frame master: `ArtSource/Generated/UI/Inventory/inventory_outer_frame_v13_gen.png` (V13b full window)
- Frame master SHA-256: `67a88ac21391f7220c28c4a1f2f88d86ad2f58318f837d0b6511482eb2b6f432`
- Title-bar crop study: `ArtSource/Generated/UI/Inventory/inventory_titlebar_v13_gen.png`
- Close first pass (rejected: heavy nested plate): `inventory_close_box_macos9_noir_v12a_gen.png`
- Close generated master: `ArtSource/Generated/UI/Common/inventory_close_box_macos9_noir_v12_gen.png`
- Close generated SHA-256: `2898748a3bc70177c940fa4298107b2ee25bf408cab7b453236021918a839a0d`
- Shipping close: cropped from the V13 title-bar widget so the live sprite matches the stamped-in box

## Reference roles (geometry authority)

1. Full Platinum title bar with close, six hairlines, title, Zoom, WindowShade.
2. Close-up of left side (close box + six hairline stripes + title).
3. About This Computer window for slim rails, sunken content well, and resize gripper.

Noir material only. Do not use V12 or the in-game Inventory screenshot as a shape reference.

## Frame prompt (literal geometry, noir palette)

Use case: ui-mockup  
Asset type: production game UI chrome master for the RainShadow Inventory overlay, version V13  
Input images: the high-resolution Mac OS 9 Platinum title-bar photographs are the geometry authority. Copy their construction. Recolor only.

Exact construction copied from the photographs:

- Thin title bar that **is the top of the window**, not a well inside a slab. 1px near-black outer outline. One slim bevel (light top/left, dark bottom/right). Title-bar height ≈ 6–10% of window height.
- Flat charcoal field with **exactly six** 1px-class dark hairline pinstripes, full width. Dark lines on a slightly lighter charcoal field (or the noir-readable inverse: thin light hairlines on charcoal). Not eight fat metallic ridges. Not a grille.
- Stripes interrupted **only** by: close box (left), empty title capsule (center), Zoom + WindowShade (right). No left parking plate. No huge dark plaque. No Apple logo. No baked INVENTORY text.
- Close box stamped into the stripe field: small square, 1px dark border, recessed inner square, no X. Height ≈ title-bar inner height minus 1px inset.
- Right: Zoom (inner square offset top-left) and WindowShade (two horizontal lines, thicker over thinner), same size/grammar, stamped into the stripes.
- Slim single-bevel side/bottom rails. Sunken content well (dark top/left, light bottom/right). Optional OS 9 resize gripper at bottom-right.
- Interior and exterior: solid `#00FF00` chroma green **or** flat black that the processor flood-keys.

Palette: charcoal, black, high-contrast light-gray bevels. No Platinum silver fill, no rainbow Apple, no text, no watermark.

Hard forbidden (V12 failures): thick double-ridge picture frame; ~135px inset title well; eight fat ridges; unstriped left parking plate; huge title plaque; missing Zoom/WindowShade; 64px nested picture-in-picture close on a reserve.

## Close-control prompt

Standalone OS 9 close box, noir only: two squares (1px outer outline + recessed inner square), inner face slightly lighter than the plate, no X, chroma-green surround. The shipping sprite is cropped from the V13 title bar so it matches the stamped widget.

## Processing and runtime contract

`ArtSource/Processing/process_ui_chrome_v05_inventory.py outer_v13` produces:

- `ArtSource/Generated/UI/Inventory/inventory_outer_frame_v13_keyed.png`
- `RainShadow Shared/Resources/Art/UI/Inventory/inventory_outer_frame_v13.png` at 1960×1080
- `ArtSource/Generated/UI/Common/inventory_close_box_macos9_noir_v12_keyed.png` (cropped from the title-bar close)
- `RainShadow Shared/Resources/Art/UI/Common/inventory_close_box_macos9_noir_v12.png` at 128×128

Black generator fill is flood-keyed from the canvas border and content centre so title-bar hairlines are not punched. Horizontal seam expansion in the stripe runs preserves square close/zoom/windowshade widgets.

Overlay: live `INVENTORY` label in the center capsule; close sprite at `(-930, 490)` displayed at 60×60 in the left stripe field (100×100 hit target unchanged). Zoom and WindowShade are decorative and baked into the frame. Journal/map keep the shared V04 control.
