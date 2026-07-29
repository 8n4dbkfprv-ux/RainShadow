# Office entrance leaf V10.5 — purpose-built fallen state

- Generated: 2026-07-29
- Mode: built-in Image Generator
- Identity reference: `ArtSource/Generated/Office/Props/office_door_leaf_ig_v104_chroma.png`
- Perspective reference: `tmp/door_v103_fallen_architecture_final.png`
- Chroma master: `ArtSource/Generated/Office/Props/office_door_leaf_fallen_ig_v105_chroma.png`
- RGBA master: `ArtSource/Generated/Office/Props/office_door_leaf_fallen_rgba_v105.png`
- Runtime derivative: `RainShadow Shared/Resources/Art/Props/Office/office_door_leaf_fallen.png`

## Final prompt

```text
Use case: precise-object-edit
Asset type: isolated production game prop for the landed/fallen state in a late-1990s pre-rendered isometric noir CRPG
Input images: Image 1 is the exact door identity, material, panel layout, knob, and lettering reference. Image 2 is the exact game-camera and floor-plane perspective reference; use it only to understand the required viewing angle and the current billboard problem.
Primary request: Render the same H. Voss detective-office door as a heavy real wooden door leaf that has just torn free from its frame and is lying flat on the office floor, viewed from the same elevated isometric camera as Image 2. It must unmistakably read as a constructed door, not a billboard, signboard, poster, framed picture, or flat card.
Subject: a complete dark near-black walnut 1940s office door leaf, fallen face-up. Preserve the frosted upper glass panel, dark wood lower recessed panel, small aged-brass knob, and battered noir materials from Image 1. Make the physical construction especially legible in the foreshortened floor pose: thick perimeter stiles and rails; strongly recessed lower panel; visible bottom rail; a 4–5 cm thick dark latch edge and bottom edge; subtle bevels; chipped wood; two torn hinge mortises with screw holes along the hinge edge; tiny splinters at the failed hinge points. Keep the door intact overall, not shattered.
Text (verbatim): "H. VOSS" above "PRIVATE INVESTIGATOR". Preserve exact spelling, two-line hierarchy, centered placement, and simple dark period lettering on the frosted glass.
Style/medium: richly painted late-1990s isometric PC CRPG prop, non-photorealistic pre-rendered look matching Image 2, crisp silhouette at game scale, restrained painterly texture.
Composition/framing: one isolated complete fallen door centered diagonally on a 1536x1024 landscape canvas, hinge side toward upper right and latch/knob side toward lower left. Strong floor-plane foreshortening matching Image 2. Generous padding around every edge. Do not include the room itself.
Scene/backdrop: perfectly flat uniform solid #00ff00 chroma-key background for removal. No floor plane, shadow, gradient, texture, reflections, or lighting variation in the background.
Lighting/mood: dim rain-soaked 1940s office light; restrained cool ambient light and a faint warm rim; no orange glow.
Constraints: preserve the same door identity and darkness. Show convincing thickness along the near/latch and bottom edges. The outer silhouette must be a perspective trapezoid, not a plain screen-aligned rectangle. No wall, door frame, jamb, threshold, room, furniture, character, UI, cast shadow, contact shadow, watermark, extra sign, or extra text. Keep the door fully separated from the green background with crisp edges. Do not use #00ff00 anywhere in the subject.
Avoid: billboard, advertising board, shop sign, poster, picture frame, freestanding panel, paper-thin slab, glowing amber glass, bright orange wood, large shiny hardware, misspelled text, cropped corners, upright door.
```

## Runtime treatment

- The existing upright leaf and projective fall animation remain unchanged
  until impact.
- At landing, SpriteKit swaps to this purpose-built floor-perspective texture
  and hides the old generic edge extrusion.
- The generated artwork owns the visible stiles, rails, recessed panel, knob,
  bottom/latch thickness, and damaged hinge edge.
