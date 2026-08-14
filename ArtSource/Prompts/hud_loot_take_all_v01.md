# RainShadow Take All control V01

Date: 2026-08-14  
Generator: Codex built-in Image Generator  
Generator output: `exec-601337a9-2297-4516-8aad-9936a5d52cb1.png`  
Runtime ID: `hud_loot_take_all_v01`  
Runtime contract: 256×256 RGBA

## Reference routing

- `hud_party_select_v03.png` and `hud_action_inventory_v03.png` — compact painted-control authority.
- `inventory_coin_stack_v05.png` — RainShadow coin material authority.
- `ui_close_box_macos9_noir_v04.png` — small-control bevel authority.

The BG2 screenshot establishes the need for a bulk-transfer control only. Its red diamond/gem artwork is not a visual reference and is not reproduced.

## Final generation prompt

Create one original square RainShadow button meaning "take all from this open container." Use a concise mixed-contents pictogram: a worn silver coin, an old brass key/tag, and a folded case document descending together into a shallow open noir evidence tray, with one restrained downward motion cue. It must read at 32–44 pixels without text. Render it in late-1990s pre-rendered PC-game style using cool pitted gunmetal, smoked black, worn silver, and a tiny brass accent inside a compact square bevel. Center it with generous padding on perfectly flat `#00FF00` chroma. No text, numerals, currency symbols, red diamond, gemstone, fantasy rune, hand, character, bag, franchise ornamentation, logo, signature, watermark, scenery, shadow, or background variation.

## Processing

1. Copy the generator result to `ArtSource/Generated/UI/HUD/hud_loot_take_all_v01_gen.png`.
2. Remove chroma with the installed ImageGen helper into `hud_loot_take_all_v01_keyed_full.png`.
3. At generation time, `ArtSource/Processing/process_ui_loot_panel_v02.py` wrote the exact keyed/runtime pair. Its active asset table has since advanced to V03; the retained V01 files are the historical output of that earlier configuration.

The button action and accessibility-sized hit target remain code-owned.
