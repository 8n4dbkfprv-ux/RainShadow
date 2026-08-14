# RainShadow HUD loot-container panel V01

Date: 2026-08-14  
Generator: Codex built-in Image Generator  
Generator output: `exec-79a933ab-89ea-4c59-bf6c-1c42fbd5af98.png`  
Runtime ID: `hud_loot_container_panel_v01`  
Runtime contract: 1536×256 RGBA, 6:1 aspect ratio

## Reference routing

- `hud_left_rail_plate_v03.png` — primary material, bevel, and wear authority.
- `dialogue_outer_frame_overlay_v07.png` — panel-weight and inset-well authority.
- `hud_loot_toast_v01_keyed.png` — composition/style reference only. The existing toast candidate is preserved unchanged and is not integrated by this feature.

References control material language only. Do not copy franchise art, typography, ornament, or layout.

## Final generation prompt

Create one original RainShadow video-game HUD asset: a very wide horizontal loot-container panel backing on a perfectly flat uniform chroma-green `#00FF00` background. The painted object itself must be a strict 6:1 rectangle. Match the supplied RainShadow HUD and dialogue references: cool rain-darkened pitted gunmetal, smoked-black recessed leather, worn silver upper-left bevel highlights, charcoal lower-right shadows, tiny restrained rivets, and subtle 1940s film-noir industrial wear. Inside the frame, build one large continuous recessed contents well occupying about the left 76 percent and one smaller recessed wallet/status well occupying about the right 24 percent, separated by one slim metal divider. Leave both wells empty and visually quiet so code can overlay six coin slots, arrows, a close control, wallet value, and transient feedback. Use a straight-on orthographic UI view, crisp readable late-1990s pre-rendered PC-game chrome, balanced horizontal symmetry, transparent-ready exterior silhouette, and transparent-ready rounded or clipped outer corners. No text, letters, numerals, currency symbols, labels, icons, coins, objects, slots, buttons, arrows, close glyphs, characters, fantasy motifs, franchise ornamentation, logos, signatures, watermarks, scenery, shadows outside the panel, gradients in the green background, or baked interactive contents.

## Processing

1. Copy the generator result to `ArtSource/Generated/UI/HUD/hud_loot_container_panel_v01_gen.png`.
2. Remove chroma locally into `hud_loot_container_panel_v01_keyed_full.png`.
3. Run `ArtSource/Processing/process_ui_loot_chrome_v01.py` to crop, resample, add transparent corner sentinels, validate chroma/alpha, and write:
   - `ArtSource/Generated/UI/HUD/hud_loot_container_panel_v01_keyed.png`
   - `RainShadow Shared/Resources/Art/UI/HUD/hud_loot_container_panel_v01.png`

Code owns slot frames, coin icons, all labels and values, arrows, close control, hover/press feedback, hit targets, pagination, and transient `+amount` feedback.
