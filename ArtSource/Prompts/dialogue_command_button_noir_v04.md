# Dialogue command button plate V04

Date: 2026-08-01  
Generator: Codex built-in default Image Generator  
Master: `dialogue_command_button_plate_v04_gen.png`  
Soft-matte source: `dialogue_command_button_plate_v04_keyed.png`

## Intent

Empty CONTINUE / END DIALOGUE plate matching the revised dialogue frame: blackened steel, rain scratches, a smoked-leather live-label face, thin cold highlights, shallow bevels, and clipped mid-century corners. Runtime draws the label.

## Final generator prompt

```text
Use case: ui-mockup
Asset type: production 2D game UI command-button plate, matching the supplied RainShadow dialogue frame.
Primary request: Create one original empty noir command plate for the live CONTINUE / END DIALOGUE control. Match Image 1's aged blackened-steel frame, fine rain scratches, smoked-leather inset, cold pewter edge highlights, shallow machined bevels, and restrained 1940s utility Art Deco construction. Use Image 2 only for the required slim wide button proportion and empty center; redesign all visible artwork to match Image 1.
Composition/framing: a single perfectly front-facing orthographic button plate, centered, fully visible, approximately 4:1 after trimming. Thin double gunmetal rim, very shallow bevel, subtly worn charcoal leather face, small stepped clipped corners. Quiet and practical, with enough empty face area for a code-drawn label. Symmetric.
Lighting/mood: low-key top-left noir lighting, readable edge highlights at game scale.
Color palette: near-black, graphite, pewter highlights, charcoal; at most two pinhead-sized muted oxblood enamel accents, but no bright color.
Background: perfectly flat solid #00ff00 chroma-key everywhere outside the plate, one uniform color with no shadow, gradient, texture, reflection, floor plane, or lighting variation. Do not use #00ff00 in the plate.
Text: none.
Constraints: no baked label, icon, portrait, or symbol; crisp isolated edges; generous padding; no cast shadow or contact shadow; no attached dialogue frame.
Avoid: letters, numbers, words, arrows, gems, fantasy jewelry, medieval ornament, gold, brass-heavy steampunk, bulky end caps, watermarks.
```

## Runtime

The default generator source is chroma-keyed with the imagegen skill's border-sampled soft matte and despill helper, then trimmed, texture-preserving lifted, and stretched into:

`RainShadow Shared/Resources/Art/UI/Dialogue/dialogue_command_button_plate_v04.png` — 512×128 RGBA.
