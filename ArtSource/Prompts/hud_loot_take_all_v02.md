# RainShadow Take All arrow V02

Date: 2026-08-14  
Generator: Codex built-in Image Generator  
Generator output: `exec-86294e45-5820-4f14-a32b-9742868b3a32.png`  
Runtime ID: `hud_loot_take_all_v02`  
Runtime contract: 256×256 RGBA

## Reference routing

- `hud_loot_take_all_v01.png` — edit target and compact button-frame/material authority.
- `dialogue_scroll_down_v06.png` — differentiation reference only; V02 must not reuse its pale pixel-block treatment.

The control must remain content-neutral. A gun, document, key, or coin can all occupy the opened source, so the pictogram communicates only the downward bulk-transfer action. The BG2 screenshot establishes the action's position and role; its red diamond/gem artwork is not copied.

## Final generation prompt

Preserve V01's exact compact square gunmetal button silhouette, bevel, proportions, lighting, noir material, and padding. Remove the coin, key/tag, paper, tray, and prior arrow. Replace them with exactly one large, simple downward-pointing transfer arrow: a broad aged-brass stem and triangular point, optically centered, approximately 45% of the button width and 55% of its inner height, legible at 32–44 runtime pixels. Keep the exterior on perfectly flat `#00FF00` chroma. No contents, coin, currency, gun, weapon, key, paper, document, bag, box, tray, underline, extra chevrons, text, letters, numerals, logo, rune, gem, red diamond, watermark, scenery, cast shadow, contact shadow, or background variation. Do not use green inside the subject, and do not resemble the pale gray pixelated page-scroll arrow.

## Processing

1. Copy the built-in result to `ArtSource/Generated/UI/HUD/hud_loot_take_all_v02_gen.png`.
2. Remove chroma with the installed ImageGen helper into `hud_loot_take_all_v02_keyed_full.png`.
3. At generation time, `ArtSource/Processing/process_ui_loot_panel_v02.py` wrote the exact 256×256 keyed/runtime pair. Its active asset table has since advanced to V03; the retained V02 files are the historical output of that earlier configuration.

The button action, hover/press tint, and accessibility-sized hit target remain code-owned.
