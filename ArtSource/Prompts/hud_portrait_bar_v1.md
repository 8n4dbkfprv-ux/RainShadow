# RainShadow portrait bar V1

Date: 2026-07-19  
Generator: built-in Image Generator  
Generated source: `exec-7e52d738-3ef9-47cb-aad4-ce4f6b57bf50.png`

## Reference roles

- Baldur's Gate portrait-rail screenshot: proportion and information-hierarchy reference only.
- `dialogue_outer_frame_overlay_v02.png`: RainShadow material and rendering-style reference.
- `inventory_outer_frame_overlay_v01.png`: RainShadow material and rendering-style reference.
- `dialogue_portrait_elias_vale_v01.png`: unchanged runtime portrait; not regenerated.

## Final prompt

```text
Use case: stylized-concept
Asset type: game UI portrait bezel overlay for a late-1990s pre-rendered noir CRPG
Primary request: Create one original tall rectangular character-portrait bezel for RainShadow. Use Image 1 only for the compact tall portrait-cell proportions and readable inset hierarchy. Use Images 2 and 3 as the exact material and rendering style reference: rain-worn blue-black gunmetal, oxblood leather corner insets, tiny aged brass rivets, subtle engraved Art Deco geometry, sober detective-noir craftsmanship.
Composition/framing: one centered portrait bezel, straight-on orthographic UI asset, outer aspect ratio about 3:4, a large simple rectangular open window occupying roughly 82% of the width and 78% of the height, with a slightly heavier lower nameplate-like sill but no text.
Scene/backdrop: perfectly flat solid #00ff00 chroma-key background; the entire portrait window must also be the identical flat #00ff00 so both exterior and opening can be removed.
Style/medium: polished hand-painted raster game UI, late-1990s pre-rendered CRPG readability, crisp at small size, original RainShadow design.
Lighting/mood: restrained cool steel highlights, tiny warm brass accents, high local edge contrast, no glow.
Color palette: blue-black charcoal metal, muted oxblood leather, aged brass; do not use green anywhere in the bezel.
Constraints: bezel only; bilateral symmetry; front view; clean complete silhouette; generous padding; no character; no health; no letters; no numerals; no icons; no logo; no watermark. Background and inner window must be perfectly uniform #00ff00 with no shadows, gradients, texture, reflections, floor plane, or lighting variation. No cast shadow, contact shadow, or reflection.
Avoid: fantasy runes, skulls, bright gold, emerald accents, ornate gothic spikes, thick bulky frame, extra panels, multiple frames.
```

## Processing and runtime contract

- The 1086×1448 chroma source is retained at `Generated/UI/HUD/hud_portrait_frame_chroma_v01.png`.
- `remove_chroma_key.py` sampled `#03f904`, produced an alpha PNG, and retained 7,570 partially transparent edge pixels.
- Runtime asset: `Resources/Art/UI/HUD/hud_portrait_frame_v01.png`.
- SpriteKit owns the full-height rail, portrait crop, health text, text shadow, health-state tint, screen-edge anchoring, and fallback geometry.
- The rail uses the actual viewport size so it spans the screen independently of the office camera zoom.
