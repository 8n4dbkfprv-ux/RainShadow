# Office shell V7 — continuous west wall (no window hole)

## Status

**Abandoned 2026-07-23.** Generator kept re-inserting a window recess; local plaster fills were rejected. Runtime restored to V6 (window recess remains in the shell). Revisit later if needed.


- Generated: 2026-07-23
- Mode: built-in Image Generator, full empty plate (NOT local module pastes)
- Master: `ArtSource/Generated/Office/office_shell_base_v07.png` (3840×2160)
- Runtime derivative: `RainShadow Shared/Resources/Art/Areas/DetectiveOffice/office_shell_base.png` (4096×2304)

## Why V7

V5/V6 baked an unglazed window recess into the shell so a separate sash could sit inside it. In practice the recess reads as a hard square hole, and fitting a dimetric sash into that hole causes clipping, gaps, and deformation. V7 removes the recess entirely: the west wall is continuous plaster/wainscot, and the window is a surface-mounted prop only.

Hard rule: **no Python hole-punching or alpha_composite of wall patches into the plate.** One coherent generated plate only.

## Scale authority

BG:EE tavern doorway close-up: standing adult 185 px, doorway 359 px, ratio **1.94**. Doorway must stay locked from Image 1 (V6).

## Targets on 3840×2160 master

| Feature | Target | Band |
|---|---:|---|
| Imagined standing adult | 180 px | 170–190 |
| Doorway opening height | unchanged from Image 1 | ±3% of Image 1 |
| Window recess / hole | **none** | continuous wall |

## Generation prompt

```text
Use case: stylized-concept
Asset type: production empty environment plate for a fixed-camera isometric CRPG
Primary request: Reproduce Image 1 (the approved RainShadow detective-office empty shell) as ONE coherent architectural plate, changing ONLY the left/west wall window area: completely REMOVE the unglazed window recess / square hole. Fill that region with continuous stained two-tone plaster and matching wainscot so the west wall is unbroken. Everything else — room footprint, camera, materials, floorboards, the open doorway upper-right, and the pure-black exterior silhouette — must match Image 1 as closely as possible.
Input images: Image 1 is the approved V6 RainShadow empty office shell (authoritative for layout, materials, projection, doorway, black exterior).
Window specification: NO window recess, NO hole, NO dark opening, NO jambs, NO sill cutout on the left wall. Continuous plaster where the recess used to be. The wooden window sash is a separate sprite placed later and must NOT be painted into this plate.
Doorway specification: keep the open doorway in the upper-right wall exactly as in Image 1 — same position, same size (within a few percent), same integrated jambs and dark hall beyond. Do not redesign it.
Scene/backdrop: empty 1940s private-detective office after hours; worn dark wooden floorboards; stained two-tone plaster over dark wainscot; noir, lonely, lived-in.
Style/medium: richly pre-rendered late-1990s isometric PC CRPG environment art; painterly baked textures; modest native-resolution softness; no modern PBR gloss.
Composition/framing: exact 16:9 landscape matching Image 1 registration as closely as possible. An imagined standing adult is about 170–190 pixels tall on the plate.
Lighting/mood: dim cool ambient, subdued amber practical residue, deep but readable shadows. Without the window hole, keep soft cool wash on the west wall rather than a bright void.
Constraints: EMPTY ARCHITECTURAL SHELL ONLY. No desk, furniture, rugs, lamps, door leaf, window glass, window sash, people, UI, text, logos, watermark, selection circles, or baked movable-prop shadows. Pure black only outside the room silhouette. Do not paste inset tiles or leave hard axis-aligned pure-black rectangles inside walls.
Avoid: any window hole or recess; patch-composite look; black rectangular halos; moving or resizing the doorway; changing the room plan; painting a window into the wall.
```

## QA gate (must pass before shipping)

- No window recess / dark rectangular opening on the west wall
- Doorway opening height within ±3% of V6
- No axis-aligned pure-black rectangles inside the wall mass
- Architecture IoU vs V6 ≥ ~0.9 (only the former window area may change)
- Visual: continuous plaster into the west wall; doorway unchanged
