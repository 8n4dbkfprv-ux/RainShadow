# Office door V9 — detective-relative shell and dimensions

- Generated: 2026-07-26
- Mode: built-in Image Generator for the frame finish; deterministic registered geometry for shell, opening, leaves, partition, and runtime scales
- Character authority: shipped `VossIdle.atlas/voss_standing_idle_s_00.png`
- Runtime shell: `RainShadow Shared/Resources/Art/Areas/DetectiveOffice/office_shell_base.png`
- Runtime suite: `RainShadow Shared/Resources/Art/Areas/DetectiveOffice/office_suite_plate.png`
- Runtime frame: `RainShadow Shared/Resources/Art/Props/Office/office_door_frame.png`
- QA: `ArtSource/Generated/Office/door_detective_reference_v09/`

## Detective reference

Voss's shipped standing silhouette is exactly 200 opaque pixels on a 512×512
texture, presented in a 232×232 SpriteKit node:

`200 / 512 × 232 = 90.625 world units = 229.430 shell-plate pixels`

The earlier 394px opening was checked against the legacy logical 82-unit
navigation body, so it was only 1.718× the detective actually drawn on screen.

## Final character-relative geometry

| Feature | Final |
|---|---:|
| Voss visible body | 229.430 plate px / 90.625 world |
| Clear door opening | 202.273×445 px |
| Opening / Voss height | 1.940× |
| Opening H/W | 2.200 |
| Wall face | 505 px |
| Exterior frame outer/open width | ~1.21 |
| Handle height | 0.575× Voss above threshold |

The shell owns only the registered wall aperture and a narrow recess shadow.
The independent frame sprite is the sole decorative jamb/header authority, so
the runtime no longer stacks a freestanding frame over a second baked casing.
The exterior leaf and frame are projected onto the north-east wall slope as
matching parallelograms; their asset-specific threshold anchors register the
closed and fallen-door states to the shell rather than crossing the floor.

## Built-in Image Generator prompt

```text
Use case: stylized-concept
Asset type: production game prop source for a fixed-camera 2:1 dimetric late-1990s CRPG
Primary request: Create one slim, complete 1940s private-detective-office wooden doorframe/casing with an empty clear opening, designed to surround the separate door leaf from Image 2. This is a new frame asset, not an edit of the references.
Input images: Image 1 is Harlan Voss, the shipped standing detective and the sole human scale reference; Image 2 is the approved separate office door leaf and is the material, finish, and clear-opening proportion reference; Image 3 is the existing doorframe and is the camera/projection reference only.
Scale relationship: the clear opening represents about 1.94 times Voss's visible standing body height and has height-to-clear-width ratio 2.20. Keep the casing slim: outer width no more than about 1.20 times the clear opening width. The generated source will be normalized to exact dimensions after generation.
Subject: a single dark, battered wood jamb-and-header ring with subtle inner stop/reveal and a very thin threshold; no wall, no door leaf, no glass, no character.
Style/medium: richly pre-rendered late-1990s isometric PC CRPG prop; painterly baked wood texture; modest period softness; match Image 2's dark walnut color, wear, and warm upper-left lighting.
Composition/framing: centered upright frame, full object visible with generous padding; same 2:1 dimetric/rear-wall perspective as Image 3; clean readable silhouette.
Scene/backdrop: perfectly flat solid #00ff00 chroma-key background for local removal.
Constraints: the background must be one uniform #00ff00 color with no shadows, gradients, texture, reflections, floor plane, or lighting variation. Keep the object fully separated with crisp edges. Do not use #00ff00 in the object. No cast shadow, contact shadow, reflection, door leaf, person, wall, floor, text, logo, watermark, hinges, knobs, furniture, or extra objects. Do not include the detective from Image 1. Do not include the lettering from Image 2.
Avoid: thick freestanding box frame; ornate Victorian carving; front-on modern product render; copied character; black background.
```

## Generated source and processing

- Chroma source: `ArtSource/Generated/Office/Props/office_door_frame_ig_v04_voss_reference_chroma.png`
- Alpha source: `ArtSource/Generated/Office/Props/office_door_frame_ig_v04_voss_reference_rgba.png`
- The built-in source was keyed with the image-generation skill's
  `remove_chroma_key.py` helper using border auto-key, soft matte, and despill.
- `process_office_door_lettered_v01.py` preserves the generated four-segment
  wood finish while normalizing the clear aperture and slim casing exactly.
- `office_door_frame_upright_master.png` retains that normalized finish for the
  partition bake; the exterior runtime copy is separately wall-projected.
- One invocation of `process_office_door_lettered_v01.py` now rebuilds the
  exterior leaf/frame, partition plate, shipping suite, internal leaf, and
  matching hover texture in dependency order. Project-local masters are
  preferred, and a repeated rebuild is byte-for-byte deterministic.

## QA gate

`verify_door_shell_fit.py` must pass all gates, including:

- shipped Voss texture/display contract
- exterior, internal, and baked-shell opening = 1.94× visible Voss
- shipping-suite exterior aperture and current partition bake
- opening H/W = 2.20
- leaf and frame aperture fit
- full projected frame-aperture silhouette against the sloped shell opening
- shared-anchor top/bottom coverage
- frame outer/open width ≤ 1.25
- detector-reference composite generated beside the actual Voss sprite
