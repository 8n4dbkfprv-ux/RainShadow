# Office shell V5 — one-shot BG-scale openings (no patch composites)

- Generated: 2026-07-23
- Mode: built-in Image Generator, full empty plate (NOT local module pastes)
- Retained master: `ArtSource/Generated/Office/office_shell_base_v05.png` (3840×2160)
- Runtime derivative: `RainShadow Shared/Resources/Art/Areas/DetectiveOffice/office_shell_base.png` (4096×2304)

## Why V5

V4 patch composites produced black rectangular artifacts around the window and doorway. V5 regenerates the entire empty shell as one coherent plate. **No Python hole-punching or alpha_composite of recess/doorway modules into the plate.**

## Scale authority

BG:EE tavern doorway close-up (`tmp/imagegen/bg_tavern_ref_door_close_v04.png`): standing adult 185 px, doorway 359 px, ratio **1.94**.

External notes (scale/architecture language only):

- [Beamdog UI-scale discussion](https://forums.beamdog.com/discussion/72885/scale-the-ui-without-resolution-change)
- [Beamdog Infinity Engine map-upscaling](https://forums.beamdog.com/discussion/73868/upscaling-infinity-engine-maps-with-ai)
- [Infinity Engine (Wikipedia)](https://en.wikipedia.org/wiki/Infinity_engine)
- [Infinity Engine area construction notes](https://gamedev.net/forums/topic/540048-infinity-engine-ie-baldurs-gate-graphics-style/)

## Targets on 3840×2160 master

| Feature | Target | Band |
|---|---:|---|
| Imagined standing adult | 180 px | 170–190 |
| Doorway opening height | **375 px** | 340–410 |
| Window glass recess height | **195 px** | 170–220 |

## Generation prompt

```text
Use case: stylized-concept
Asset type: production empty environment plate for a fixed-camera isometric CRPG
Primary request: Rebuild the RainShadow detective office as ONE coherent empty architectural plate. Keep Image 1's room footprint, camera, materials, two-tone walls, floorboards, and pure-black exterior silhouette, but integrate a correctly scaled unglazed window recess and open doorway as continuous built architecture—not as pasted rectangles, modules, or cutout tiles.
Input images: Image 1 is the clean V3 RainShadow empty office shell (authoritative for layout, materials, projection, black exterior). Images 2–4 are Baldur's Gate: Enhanced Edition tavern screenshots used only for human-relative doorway/window scale (doorway ≈ 1.94× standing adult). Do not copy tavern layout, furniture, characters, UI, or fantasy decoration.
Scene/backdrop: empty 1940s private-detective office after hours; worn dark wooden floorboards; stained two-tone plaster; one unglazed window recess left of centre; one open doorway upper-right leading into a dark hall. Wall surfaces around both openings must be continuous plaster/wainscot with natural dimetric jamb depth—no floating black boxes, no axis-aligned pure-black rectangles inside the wall mass above the lintel or around the window.
Style/medium: richly pre-rendered late-1990s isometric PC CRPG environment art; painterly baked textures; modest native-resolution softness; no modern PBR gloss.
Composition/framing: exact 16:9 landscape matching Image 1 registration as closely as possible. On the final 3840×2160 plate an imagined standing adult is about 170–190 pixels tall; doorway opening about 340–410 pixels tall (target ~375); window glass recess about 170–220 pixels tall (target ~195). Shrink oversized openings from Image 1 into those bands while keeping the same left-window / right-doorway functional arrangement and abundant walkable floor.
Lighting/mood: dim cool ambient from the open recess, subdued amber practical residue, deep but readable shadows; noir, lonely, lived-in.
Constraints: EMPTY ARCHITECTURAL SHELL ONLY. No desk, furniture, rugs, lamps, door leaf, window glass, window sash, people, UI, text, logos, watermark, selection circles, or baked movable-prop shadows. Openings are built architecture only; door leaf and window glass will be separate sprites later. Pure black only outside the room silhouette. Preserve continuous floor under future props. Do not paste inset tiles or leave hard rectangular black patches inside walls.
Avoid: patch-composite look; black rectangular halos; copied Baldur's Gate content; tavern barrels; modern 3D sheen; changing the overall room into a different plan.
```

## QA gate (must pass before shipping)

- No axis-aligned pure-black rectangles inside the wall mass
- Architecture IoU vs V3 ≥ ~0.85
- Measured doorway/window heights in band
- Visual: continuous wall into jambs; no V4-style black boxes
