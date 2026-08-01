# Dialogue command button plate V04

Date: 2026-08-01  
Generator: Codex built-in default Image Generator  
Master: `dialogue_command_button_plate_v04q_gen.png`
Soft-matte source: `dialogue_command_button_plate_v04q_keyed.png`

## Intent

Empty CONTINUE / END DIALOGUE plate matching the revised dialogue frame: a reference-like 8.83:1 bar with blackened steel, rain scratches, a smoked-leather live-label face, thin cold highlights, shallow bevels, and almost-square corners. Runtime draws the label.

## Final generator prompt

```text
Use case: precise-object-edit
Asset type: production 2D game UI command-button plate for RainShadow.
Input images: Image 1 is the existing RainShadow plate edit target. Image 2 is a shape-and-proportion reference only; use its very wide, thin END DIALOGUE button silhouette and restrained outline without copying text, ornament, or franchise details. Image 3 is the revised RainShadow dialogue frame and authoritative material reference.
Primary request: Reshape the plate to approximately 8.25:1 or wider so it aligns with the low 2.95:1 dialogue panel. Make one long, shallow, front-facing rectangular command bar with straight rails, almost-square subtly softened corners, and a thin uniform perimeter. Remove the deep 4:1 proportions, clipped corner wings, projecting end caps, and thick multi-step border.
Style/materials: preserve RainShadow's aged blackened nickel, rain-scratched gunmetal, smoked-charcoal recessed face, fine cold-pewter hairline highlights, shallow top-left bevel lighting, and restrained practical 1940s construction.
Composition/framing: one isolated symmetric button, centered and fully visible with generous padding. Border occupies about 12–15% of the button height, leaving a calm empty center for a code-drawn label.
Background: perfectly flat uniform solid #00ff00 chroma-key outside the plate. No shadow, gradient, texture, reflection, floor plane, or lighting variation. Do not use #00ff00 in the plate.
Text: none; runtime draws the label.
Constraints: simple wide shallow silhouette; no notches, protrusions, icon, portrait, symbol, baked label, cast shadow, contact shadow, fantasy ornament, gold, jewel, watermark, or copied franchise detail.
```

## Runtime

The default generator source is chroma-keyed with the imagegen skill's border-sampled soft matte and despill helper, then trimmed, texture-preserving lifted, and stretched into:

`RainShadow Shared/Resources/Art/UI/Dialogue/dialogue_command_button_plate_v04.png` — 1024×116 RGBA.
