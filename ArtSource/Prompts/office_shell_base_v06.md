# Office shell V6 — smaller, higher window recess (doorway locked)

- Generated: 2026-07-23
- Mode: built-in Image Generator, full empty plate (NOT local module pastes)
- Master: `ArtSource/Generated/Office/office_shell_base_v06.png` (3840×2160; shipped from `office_shell_base_v06c` generator pass)
- Rejected: `office_shell_base_v06_rejected_deep_alcove.png`, `office_shell_base_v06_rejected_undersill_void.png`
- Runtime derivative: `RainShadow Shared/Resources/Art/Areas/DetectiveOffice/office_shell_base.png` (4096×2304)

## Why V6

V5's baked window recess came out ~153 px tall on the master (~163 runtime, glass ≈ 0.79× adult) and nearly square, sitting directly on the wainscot trim. On this room's short upper-wall band it dominates the west wall and the separate sash prop cannot fill it without reading oversized. V6 regenerates the plate with a smaller, portrait, raised window recess matched to the approved sash (~0.62× adult glass). The approved V5 doorway is preserved unchanged.

Hard rule carried over from V5: **no Python hole-punching or alpha_composite of recess/doorway modules into the plate.** One coherent generated plate only.

## Scale authority

BG:EE tavern doorway close-up (`tmp/imagegen/bg_tavern_ref_door_close_v04.png`): standing adult 185 px, doorway 359 px, ratio **1.94**. The window deliberately sits *below* the BG glass band (0.75–1.25× adult) because this room's visible wall band is short; the approved in-game size is ≈ 0.62× adult.

## Targets on 3840×2160 master

| Feature | Target | Band |
|---|---:|---|
| Imagined standing adult | 180 px | 170–190 |
| Doorway opening height | unchanged from Image 1 (~375 px) | ±3% of Image 1 |
| Window glass recess height | **125 px** | 110–140 |
| Window recess aspect | portrait, width ≈ 0.8 × height | 0.7–0.9 |
| Sill clearance above wainscot trim | **~40 px** | 30–50 |

## Generation prompt

```text
Use case: stylized-concept
Asset type: production empty environment plate for a fixed-camera isometric CRPG
Primary request: Reproduce Image 1 (the approved RainShadow detective-office empty shell) as ONE coherent architectural plate, changing ONLY the window recess on the left wall: make it smaller, portrait-proportioned, and higher on the wall. Everything else — room footprint, camera, materials, floorboards, two-tone walls, the open doorway upper-right, and the pure-black exterior silhouette — must match Image 1 as closely as possible.
Input images: Image 1 is the approved V5 RainShadow empty office shell (authoritative for layout, materials, projection, doorway, black exterior).
Window recess specification: ONE unglazed built window recess on the left wall, left of centre. On the final 3840×2160 plate: glass recess height about 110–140 pixels (target ~125), portrait proportions with width about 0.8× the height, and the sill raised so roughly 30–50 pixels of continuous plaster show between the sill and the wainscot trim below. The recess must be built architecture with natural dimetric jamb depth following the left wall's angle — visible inner jambs, lintel and sloped sill — not a flat pasted rectangle. No glass, no sash, no frame prop; the wooden window itself is a separate sprite.
Doorway specification: keep the open doorway in the upper-right wall exactly as in Image 1 — same position, same size (within a few percent), same integrated jambs and dark hall beyond. Do not redesign it.
Scene/backdrop: empty 1940s private-detective office after hours; worn dark wooden floorboards; stained two-tone plaster over dark wainscot; noir, lonely, lived-in.
Style/medium: richly pre-rendered late-1990s isometric PC CRPG environment art; painterly baked textures; modest native-resolution softness; no modern PBR gloss.
Composition/framing: exact 16:9 landscape matching Image 1 registration as closely as possible. An imagined standing adult is about 170–190 pixels tall on the plate.
Lighting/mood: dim cool ambient from the window recess, subdued amber practical residue, deep but readable shadows.
Constraints: EMPTY ARCHITECTURAL SHELL ONLY. No desk, furniture, rugs, lamps, door leaf, window glass, window sash, people, UI, text, logos, watermark, selection circles, or baked movable-prop shadows. Pure black only outside the room silhouette. Openings are built architecture only. Do not paste inset tiles or leave hard axis-aligned pure-black rectangles inside walls.
Avoid: enlarging the window; square or landscape window proportions; window resting on the wainscot trim; patch-composite look; black rectangular halos; moving or resizing the doorway; changing the room plan.
```

## QA gate (must pass before shipping)

- Window glass recess height 110–140 px on master, portrait aspect 0.7–0.9, sill 30–50 px above trim
- Doorway opening height within ±3% of V5's (~375 px master)
- No axis-aligned pure-black rectangles inside the wall mass
- Architecture IoU vs V5 ≥ ~0.9 (only the window area may change)
- Visual: continuous plaster into the jambs; recess reads as wall architecture
