# RainShadow full-width inventory case-bag backing V06

Date: 2026-08-14  
Generator: Codex built-in Image Generator  
Generator output: `exec-894cc588-8e90-4d5c-8a99-e0a6154cc43f.png`  
Runtime ID: `inventory_section_bag_v06`  
Runtime contract: 1680×190 RGBA

## Reference routing

- `inventory_section_bag_v05.png` — prior bag-band role and registration reference only.
- `hud_left_rail_plate_v03.png` — primary material, bevel, and wear authority.
- `dialogue_outer_frame_overlay_v07.png` — inset-well and late-1990s rendered-chrome authority.

References control material language only. Do not copy franchise art, typography, ornament, or layout.

## Final generation prompt

Create one original RainShadow inventory UI asset: an extremely wide, shallow full-width case-bag backing on a perfectly flat uniform chroma-green `#00FF00` background, designed for an exact 1680×190 runtime canvas. Match the supplied RainShadow HUD, dialogue, and prior bag references: cool rain-darkened pitted gunmetal, smoked-black leather recesses, worn silver upper-left bevels, charcoal lower-right shadows, tiny restrained rivets, and subtle 1940s film-noir industrial wear. Build a narrow recessed satchel/status well at the far left and one long uninterrupted recessed contents well across the remaining width. The contents well must be calm, empty, and wide enough for one code-laid row of sixteen independent item slots. Use a straight-on orthographic UI view, crisp late-1990s pre-rendered PC-game chrome, thin horizontal rails, restrained stepped corners, transparent-ready exterior silhouette, and transparent-ready outer corners. No text, letters, numerals, labels, weight values, icons, satchel, items, slots, grid divisions, arrows, buttons, characters, fantasy motifs, franchise ornamentation, logos, signatures, watermarks, scenery, shadows outside the backing, gradients in the green background, or baked interactive contents.

## Processing

1. Copy the generator result to `ArtSource/Generated/UI/Inventory/inventory_section_bag_v06_gen.png`.
2. Remove chroma locally into `inventory_section_bag_v06_keyed_full.png`.
3. Run `ArtSource/Processing/process_ui_loot_chrome_v01.py` to crop, resample, add transparent corner sentinels, validate chroma/alpha, and write:
   - `ArtSource/Generated/UI/Inventory/inventory_section_bag_v06_keyed.png`
   - `RainShadow Shared/Resources/Art/UI/Inventory/inventory_section_bag_v06.png`

Code owns the satchel icon, weight copy, all sixteen slot frames, item icons, selection state, and hit targets.
