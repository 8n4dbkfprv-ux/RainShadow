# RainShadow BG2-style container-transfer panel V02

Date: 2026-08-14  
Generator: Codex built-in Image Generator  
Generator output: `exec-46815aa6-8efe-4b64-aa2f-cc365e1ea7bb.png`  
Runtime ID: `hud_loot_container_panel_v02`  
Runtime contract: 1600×320 RGBA, 5:1 aspect ratio

## Reference routing

- User-supplied Baldur's Gate II container screenshot — composition and interaction hierarchy only.
- `hud_loot_container_panel_v01.png` — prior RainShadow material reference and superseded composition.
- `hud_left_rail_plate_v03.png` — primary material, bevel, and wear authority.
- `dialogue_outer_frame_overlay_v07.png` — open-field frame-weight authority.

The BG2 image controls only the broad source→carrier→purse hierarchy of this backing. The backing bitmap reproduces no franchise art, stonework, red-gem control, typography, icon, or exact frame silhouette; the separate live Take All control has its own versioned prompt and provenance.

## Final generation prompt

Create one original RainShadow container-transfer HUD backing as a strict 5:1 horizontal rectangle on perfectly flat `#00FF00` chroma. Use the shipped RainShadow rain-darkened pitted gunmetal, smoked-black leather, worn silver upper-left bevel highlights, charcoal lower-right shadows, restrained rivets, and subtle 1940s film-noir industrial wear. Paint one thin continuous outer frame around one uninterrupted deep-black recessed field. Leave it open and quiet for code-owned zones laid left-to-right: dynamic source identity and bulk action, a 3×2 source grid, the selected character's case bag and capacity, a 2×2 carried-inventory viewport with row controls, and a narrow party-purse display. Use negative space only; paint no internal dividers or wells. Straight-on orthographic view, crisp transparent-ready clipped corners, generous green padding. No text, numerals, currency, icons, coins, bags, furniture, slots, grids, buttons, arrows, close glyphs, characters, fantasy motifs, franchise ornamentation, logos, signatures, watermarks, scenery, cast shadows, or green variation.

## Processing

1. Copy the generator result to `ArtSource/Generated/UI/HUD/hud_loot_container_panel_v02_gen.png`.
2. Remove chroma with the installed ImageGen helper into `hud_loot_container_panel_v02_keyed_full.png`.
3. Run `ArtSource/Processing/process_ui_loot_panel_v02.py` to crop, resample, add transparent corner sentinels, validate alpha/chroma, and write:
   - `ArtSource/Generated/UI/HUD/hud_loot_container_panel_v02_keyed.png`
   - `RainShadow Shared/Resources/Art/UI/HUD/hud_loot_container_panel_v02.png`

Code owns every icon, slot, label, value, paging control, hover/press state, and hit target.
