# Dialogue outer frame V05 (Baldur's Gate hierarchy × RainShadow noir)

Date: 2026-08-01  
Generator: Codex built-in default Image Generator  
Approved master: `dialogue_outer_frame_overlay_v05q_gen.png`
Soft-matte source: `dialogue_outer_frame_overlay_v05q_keyed.png`

## Intent

- Use only the reference dialogue's low, wide hierarchy: thin rugged perimeter, compact upper-left portrait, large uninterrupted live-text opening.
- Make the visible artwork original RainShadow noir: blackened nickel, rain-scratched gunmetal, smoked leather, cold pewter edge polish, and restrained 1940s utility Art Deco geometry.
- Keep both the portrait hole and main content well transparent; SpriteKit owns the portrait, speaker name, dialogue, choices, black backing plate, and scrollbars.
- No franchise ornament, fantasy jewelry, gold trim, magic gem, text, portrait, or baked control.

## Final generator prompt set

### Initial base generation (superseded geometry)

```text
Use case: ui-mockup
Asset type: production 2D game UI artwork — a single dialogue-panel frame overlay for RainShadow, initially processed to 1720×730 before the final shape correction.
Primary request: Create a brand-new original film-noir dialogue plaque. It should preserve the readable late-1990s isometric-RPG hierarchy of a low wide rectangular conversation panel with a compact portrait well at the upper left, while clearly belonging to a 1940s private-detective noir game. Do not copy any franchise-specific ornament or exact frame shape.
Input images:
- Image 1: layout-and-weight reference only. Use only the low wide proportion, thin rugged perimeter, compact upper-left portrait placement, and generous text well. Do not reproduce its ornament, jewel, scrollbar, portrait, text, or exact silhouette.
- Image 2: geometry/workflow reference for the current RainShadow overlay. Keep the entire frame visible with generous key-color padding and preserve the same basic portrait-well placement and broad uninterrupted content opening, but redesign all visible artwork.
- Image 3: authoritative RainShadow material-language reference. Match its cold monochrome blackened nickel, rain-scratched gunmetal, smoked charcoal leather, top-left bevel lighting, and restrained mid-century utility finish; simplify it substantially for dialogue readability.
Composition/framing: One perfectly front-facing orthographic UI frame, centered, full frame visible, landscape about 2.35:1 after trimming. A slim continuous perimeter, slightly weightier lower rail, compact inset portrait bezel at upper left (approximately x=3%, y=6%, width=11%, height=27% of the trimmed plaque), and an uninterrupted large dialogue opening extending to a clean right-side gutter. Subtle small stepped corner caps and two low-profile side fasteners are allowed. Keep the construction practical and symmetric except for the portrait bezel.
Lighting/mood: hard-boiled rainy-night noir, low-key top-left light, quiet menace, readable highlights at game scale.
Color palette: near-black, graphite, pewter highlights, charcoal leather, tiny muted oxblood enamel accents only; no bright color.
Materials/textures: aged blackened steel, fine rain scratches, worn smoked leather, slight edge polish, shallow machined bevels. Restrained 1940s Art Deco geometry, not fantasy ornament.
Background and openings: perfectly flat solid #00ff00 chroma-key everywhere outside the frame AND inside the large dialogue opening AND inside the portrait opening. No black fill in those empty openings. Uniform key color only, with no shadows, gradients, texture, reflections, floor plane, or lighting variation.
Text: none.
Constraints: frame must be fully isolated from the key color with crisp edges and generous padding; no #00ff00 anywhere in the frame. Main dialogue opening must remain visually empty and unobstructed. Portrait hole must be completely empty. Leave the right gutter free for code-drawn scrollbar controls. No baked buttons. No attached command plate.
Avoid: people, faces, portraits, letters, numbers, labels, icons, scrollbar controls, gems, magic, swords, shields, skulls, gargoyles, Celtic knots, medieval filigree, fantasy jewelry, gold trim, brass-heavy steampunk, ornate Gothic arches, bulky top crowns, large decorative emblems, copied franchise shapes, watermarks, cast shadows, contact shadows.
```

### Intermediate proportion refinement (superseded geometry)

```text
Use case: precise-object-edit
Asset type: production 2D game UI dialogue-frame overlay.
Input image: Image 1 is the edit target and must remain the same design.
Primary request: Make exactly two geometry refinements to the existing frame:
1. Reduce the upper-left portrait opening and its bezel height by about one third so the EMPTY GREEN portrait hole occupies approximately 11% of the trimmed frame width and 27% of the trimmed frame height. Keep its left edge around 3% and top edge around 6% of the trimmed frame. Keep the same width, material, bevel, and stepped lower-right join. The portrait bezel should be compact, close to square, and tucked at the top-left like the reference dialogue hierarchy.
2. Reduce the heavy bottom rail height by about 40%, while preserving its existing aged blackened-steel face, bevels, corner construction, and full width.
Keep everything else unchanged: same original noir design, same thin top and side rails, same two side fasteners, same uninterrupted main content opening, same cold gunmetal and smoked-leather material, same front-facing orthographic view, same full-frame visibility, and same padding.
Background and openings: replace all green with one perfectly uniform flat solid #00ff00. It must be exactly uniform everywhere outside the frame, inside the main dialogue opening, and inside the portrait opening, with no shadow, gradient, texture, reflections, or lighting variation.
Text: none.
Constraints: crisp isolated edges; no #00ff00 in the metal or leather. No new objects, ornament, labels, scrollbar controls, buttons, portraits, or symbols.
Avoid: changing the overall design, changing the aspect ratio, cropping any part of the frame, fantasy ornament, gold, watermarks.
```

## Processing and runtime

The default generator source is chroma-keyed with the imagegen skill's border-sampled soft matte and despill helper, then trimmed and stretched into:

`RainShadow Shared/Resources/Art/UI/Dialogue/dialogue_outer_frame_overlay_v05.png` — 1720×583 RGBA.

The reference-shape follow-up replaced the earlier 2.36:1 plaque with a 2.95:1 runtime silhouette: straight uniform rails, near-square corners, no heavy lower band, no projecting portrait housing, and a narrow vertical portrait bezel contained inside the outer rectangle. The shipped portrait hole measures approximately x=0.0331, y-from-top=0.1046, width=0.0709, height=0.3448. `DialoguePanelLayout` uses those measured fractions and center-crops square portrait art into the vertical aperture without face distortion.

## Final net shape prompt

```text
Use case: precise-object-edit
Asset type: production 2D game UI dialogue-frame overlay.
Preserve RainShadow's original noir materials: blackened nickel, rain-scratched gunmetal, smoked charcoal, cold pewter edge highlights, shallow top-left bevel lighting, and restrained practical 1940s construction.
Use the supplied Baldur's Gate dialogue only as a shape-and-proportion reference. Create a low, wide rectangular silhouette close to 3:1 with straight continuous rails, nearly square worn miters, uniformly slim top/bottom/side edges, two tiny mid-edge fasteners, and one large uninterrupted transparent dialogue opening. Remove the thick leather bottom band, pointed/chamfered peaks, and projecting portrait housing.
Place one thin vertical portrait bezel fully inside the upper-left of the continuous rectangle. It must not alter the outer silhouette or protrude into the content area. Leave the right side clear for code-drawn scrollbar controls.
All areas outside the frame, inside the main opening, and inside the portrait hole must be perfectly flat uniform #00ff00 for removal. No text, portrait, face, label, icon, scrollbar part, jewel, fantasy ornament, gold, copied franchise detail, watermark, shadow, or reflection.
```
