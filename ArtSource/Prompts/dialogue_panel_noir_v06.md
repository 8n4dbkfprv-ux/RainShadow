# Dialogue panel noir V06 (reference-shape correction)

Date: 2026-08-01  
Generator: Codex built-in default Image Generator  
Frame master: `dialogue_outer_frame_overlay_v06_gen.png`  
Frame soft matte: `dialogue_outer_frame_overlay_v06_keyed.png`  
Command master: `dialogue_command_button_plate_v05_gen.png`  
Command soft matte: `dialogue_command_button_plate_v05_keyed.png`

## Intent

Use the supplied Baldur's Gate dialogue screenshot only for its sparse overall hierarchy:
a low wide rectangle, uniformly slim perimeter, compact detached upper-left portrait bezel,
large uninterrupted text well, and separate very shallow command bar. All visible artwork is
original RainShadow noir: rain-worn blackened nickel, smoked charcoal leather/Bakelite,
cold pewter highlights, restrained 1940s utility Art Deco miters, and tiny oxblood fasteners.

## Final frame shape-correction prompt

```text
Use case: precise-object-edit
Asset type: production 2D game UI dialogue-frame overlay.
Input images:
- Image 1: authoritative overall-shape and proportion reference only. Match its sparse, extremely low-wide hierarchy and compact detached portrait bezel; do not copy its fantasy ornament, text, portrait, scrollbar, button, or franchise details.
- Image 2: edit target. Preserve its original RainShadow noir materials, color palette, rain wear, cold highlights, and restrained Art Deco vocabulary.
Primary request: Correct only Image 2's overall silhouette and internal geometry so it follows Image 1 much more closely.
Required geometry changes:
1. Keep the trimmed outer plaque exactly about 2.95:1, perfectly rectangular, front-facing and level.
2. Make all four outer rails about 40% thinner. The bottom rail may be only 10% heavier than the top, not a broad footer.
3. Remove the center-bottom triple keystone, long raised bottom ledge, portrait tail, and all bulky projecting masses.
4. Detach the portrait bezel completely from the outer top and left rails. It must float inside the opening like Image 1, with uniform green space around it.
5. Make the portrait bezel compact and simple: its EMPTY GREEN interior hole about 7% of trimmed plaque width and 30% of plaque height, positioned about 2% from the left inner edge and 5% from the top inner edge. The bezel itself should be only a narrow rim around the hole.
6. Keep the main dialogue opening enormous, clean, uninterrupted, and solid #00ff00. Keep the right side visually blank for a code-drawn scrollbar.
7. Use near-square outer corners with tiny straight utility-Art-Deco miters only. Retain at most two small flush oxblood screws on the side rails.
Style/material invariants: preserve Image 2's aged blackened nickel, graphite, smoked charcoal, fine rain scratches, restrained cold pewter highlights, and hard-boiled 1940s noir tone.
Background and openings: perfectly flat uniform solid #00ff00 outside the frame, inside the main opening, and inside the portrait hole. No black fill, shadow, gradient, texture, reflection, fog, or lighting variation in the green areas.
Text: none.
Constraints: full frame visible with generous green padding; crisp isolated edges; no scrollbar; no command button; no cast or contact shadow.
Avoid: people, faces, portraits, letters, numbers, labels, icons, arrows, gems, fantasy ornament, medieval filigree, gold, brass-heavy steampunk, Gothic arches, bulky crown, large emblem, copied franchise detail, watermark.
```

## Final command shape-correction prompt

```text
Use case: precise-object-edit
Asset type: production 2D game UI command-button plate.
Input images:
- Image 1: authoritative overall-shape and proportion reference only. Match the END DIALOGUE control's very long, very shallow silhouette and minimal outline; do not reproduce its text or franchise ornament.
- Image 2: edit target. Preserve its original RainShadow noir materials, rain wear, cold highlights, and tiny oxblood accents.
Primary request: Change only Image 2's geometry so its trimmed button silhouette matches Image 1 much more closely.
Required geometry:
1. Make the button approximately 8.8:1 width-to-height after trimming—very long and shallow, not a tall plaque.
2. Reduce the border height by about 45%; keep a thin restrained double rim occupying only about 10% of total button height.
3. Remove the large vertical end towers and bulky stepped corner masses. Use nearly square, subtly softened corners with only tiny straight 1940s utility-Art-Deco miters.
4. Preserve a broad calm empty central face for a code-drawn label.
5. Keep exactly two tiny flush muted-oxblood dots, one near each end, but make them subordinate.
Style/material invariants: retain aged blackened nickel, smoked charcoal leather/Bakelite, graphite, cold pewter hairline highlights, shallow bevels, fine rain scratches, original hard-boiled noir character.
Background: perfectly flat uniform solid #00ff00 outside the plate, with generous padding; no shadow, gradient, texture, reflection, fog, or floor plane. Do not use #00ff00 in the plate.
Text: none.
Constraints: centered; perfectly front-facing; full silhouette visible; crisp isolated edges; no cast or contact shadow; no attached panel; no icon.
Avoid: letters, words, numbers, labels, arrows, fantasy ornament, gems, gold, bulky caps, watermark.
```

## Runtime outputs

- `RainShadow Shared/Resources/Art/UI/Dialogue/dialogue_outer_frame_overlay_v06.png` — 1720×583 RGBA.
- `RainShadow Shared/Resources/Art/UI/Dialogue/dialogue_command_button_plate_v05.png` — 1024×116 RGBA.

Both masters use the ImageGen skill's border-sampled soft matte and despill helper. The
processor trims the key field, clears transparent RGB, and fits each authored silhouette to
its runtime canvas. Code continues to own the black content plate, portraits, dialogue text,
responses, scrollbar, and command label.
