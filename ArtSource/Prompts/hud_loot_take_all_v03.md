# BG2-style Loot Take All diamond V03

Date: 2026-08-14  
Generator: Codex built-in Image Generator  
Generator output: `exec-5de37d5a-f38a-47ab-babd-497f3f7b7732.png`  
Runtime ID: `hud_loot_take_all_v03`  
Runtime contract: 256×256 RGBA

## Reference routing

- `/Users/laurensvanoorschot/Desktop/Screenshot 2026-08-14 at 12.43.32 PM.png` — visual authority for the red diamond directly below the wooden source shelf.
- Installed BG:EE `UI.menu`, `WORLD_CONTAINER` — direct semantic authority for the matching Beamdog control: this `ROUNDBUT` instance invokes Take All. The same button art is reused elsewhere for Quick Loot, but that is not this panel action. The supplied screenshot remains the BG2/BGII:EE visual authority.
- RainShadow's V02 loot panel — runtime size, placement, hover/press treatment, and 44-point hit target remain unchanged.

The user explicitly requested the screenshot's Baldur's Gate diamond instead of RainShadow's brass arrow. This asset is a newly generated reconstruction based on the supplied crop, not an extraction of the shipped BAM pixels.

## Final generation prompt

Use case: background-extraction

Asset type: standalone 256×256 game UI control for RainShadow's BG2-style opened-container panel.

Input images: Image 1 is the user-supplied visual reference. Isolate/reconstruct only the small red diamond control directly below the wooden shelf at the far left of the panel.

Primary request: create a faithful standalone version of that exact control role and appearance: a compact square rotated 45 degrees, with a heavy near-black/burnished-iron outer rhombus frame, thin worn gray bevel highlights, and a saturated faceted crimson-red inset diamond. Preserve the late-1990s pre-rendered pixel-era proportions, angular silhouette, dark outline, red inner facets, upper-left highlight, and lower-right shadow. It should read like the control in Image 1, not a modern jewel.

Composition/framing: centered on a square canvas, upright diamond points exactly top/right/bottom/left, occupying about 72–78% of the canvas so it remains clear in a 34-point runtime seat; generous transparent-ready margin.

Scene/backdrop: perfectly flat uniform `#00FF00` chroma-key background for local removal; no shadow, gradient, texture, reflection, floor plane, or lighting variation outside the control.

Constraints: only the freestanding diamond control. No square button plate, no rectangular backing, no arrow, coin, gun, key, paper, tray, bag, text, lettering, numeral, logo, watermark, surrounding HUD panel, shelf, inventory cells, or currency. Keep the outer corners of the square canvas pure chroma. Do not use `#00FF00` anywhere in the diamond.

Avoid: glossy modern gem photography, round jewel, fantasy rune, extra ornament, red glow outside the metal frame, soft blurry silhouette.

## Processing

1. Copy the built-in output to `ArtSource/Generated/UI/HUD/hud_loot_take_all_v03_gen.png`.
2. Remove chroma with the installed ImageGen helper into `hud_loot_take_all_v03_keyed_full.png` using an auto-sampled border key, soft matte, and despill.
3. Run `ArtSource/Processing/process_ui_loot_panel_v02.py` to crop, resample, add transparent corner sentinels, validate alpha/chroma, and write:
   - `ArtSource/Generated/UI/HUD/hud_loot_take_all_v03_keyed.png`
   - `RainShadow Shared/Resources/Art/UI/HUD/hud_loot_take_all_v03.png`

Code continues to own the Take All action, hover/pressed tint, disabled state, and accessibility-sized hit target.
