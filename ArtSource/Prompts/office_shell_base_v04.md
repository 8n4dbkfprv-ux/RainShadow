# Office shell V4 — unglazed window recess + BG-scale doorway

- Generated: 2026-07-23
- Mode: built-in Image Generator recess/doorway patches + `ArtSource/Processing/process_office_shell_v04.py` composite onto V3 (preserves room registration; full-plate regenerate drifted)
- Retained master: `ArtSource/Generated/Office/office_shell_base_v04.png` (3840×2160)
- Runtime derivative: `RainShadow Shared/Resources/Art/Areas/DetectiveOffice/office_shell_base.png` (4096×2304)
- Scale preview: `ArtSource/Generated/Office/office_scale_preview_v04.png`

## Scale measurements (locked)

From `tmp/imagegen/bg_tavern_ref_door_close_v04.png` (BG:EE tavern doorway close-up):

| Feature | Pixels | Notes |
|---|---:|---|
| Standing adult (sole → crown) | 185 | Green-selected character on checkered rug |
| Doorway opening height | 359 | Dark passage under lintel |
| Door / adult ratio | **1.94** | Matches RainShadow band 1.80–2.20 |

Production targets on the **3840×2160** master (adult reference 180 px):

| Feature | Target px | Band |
|---|---:|---|
| Standing adult (imagined) | 180 | 170–190 |
| Doorway opening height | **375** | 340–410 |
| Window glass opening height | **195** | 170–220 |

V3 defect: doorway opening measured ~520 px (~2.89× adult) — oversized vs BG reference.

## External sources (scale / architecture language only)

- User-supplied BG:EE tavern screenshots (wide / doorway close / fog-edge).
- [Beamdog UI-scale discussion](https://forums.beamdog.com/discussion/72885/scale-the-ui-without-resolution-change)
- [Beamdog Infinity Engine map-upscaling](https://forums.beamdog.com/discussion/73868/upscaling-infinity-engine-maps-with-ai)
- [Infinity Engine (Wikipedia)](https://en.wikipedia.org/wiki/Infinity_engine) — pre-rendered 2D plates with separate sprites
- [Infinity Engine area construction notes](https://gamedev.net/forums/topic/540048-infinity-engine-ie-baldurs-gate-graphics-style/)

Do not copy tavern layout, furniture, fantasy trim, UI, or characters.

## Generation prompt

```text
Use case: precise-object-edit
Asset type: production empty environment plate for a fixed-camera isometric CRPG
Primary request: Edit Image 1 (RainShadow detective office shell V3) in two places only: (A) remove the baked rain window glass and frame on the left/rear wall and leave a clean unglazed wall recess/opening sized for a later separate window prop; (B) rebuild the upper-right doorway opening to Baldur's Gate play-scale human-relative height. Keep the rest of the room architecture, floor, walls, black exterior silhouette, camera, and materials pixel-stable.
Input images: Image 1 is the edit target — the current V3 empty office shell. Images 2–4 are Baldur's Gate: Enhanced Edition tavern screenshots used only to measure camera language and human-relative doorway/window scale (doorway ≈ 1.94× standing adult). Do not reproduce their rooms, props, characters, UI, or fantasy decoration.
Scene/backdrop: empty 1940s private-detective office after hours; worn dark wooden floorboards; stained two-tone plaster; cool rain-adjacent light only as ambient architecture (no glass); one unglazed window recess left of centre; one open doorway upper-right leading into darkness.
Style/medium: richly pre-rendered late-1990s isometric PC CRPG environment art; painterly baked textures; modest native-resolution softness; no modern PBR gloss.
Composition/framing: exact 16:9 landscape plate matching Image 1 registration. On the final 3840×2160 plate an imagined standing adult is about 170–190 pixels tall; the doorway opening must be about 340–410 pixels tall (target ~375); the window glass recess about 170–220 pixels tall (target ~195). Shrink the oversized V3 doorway down into that band while preserving dimetric jamb thickness, threshold, and dark corridor beyond. Window recess stays left of centre; doorway stays right of centre.
Lighting/mood: dim cool ambient from the open recess, subdued amber practical residue, deep but readable shadows; noir, lonely, lived-in.
Constraints: EMPTY ARCHITECTURAL SHELL ONLY. No desk, furniture, rugs, lamps, door leaf, window glass, window frame, people, UI, text, logos, watermark, selection circles, or baked movable-prop shadows. The window and doorway are unglazed built openings only — movable glass/frame and door leaf will be composited separately. Pure black only outside the room silhouette. Preserve continuous floor under future props.
Avoid: leaving the old oversized doorway; baking a door leaf or window frame into the shell; copying Baldur's Gate content; tavern barrels or fantasy ornament; changing the overall room footprint; modern interior-render perspective.
```

## Intended runtime contract

- Generated master: 3840×2160.
- Runtime derivative: 4096×2304.
- Window and door leaf/frame are separate props registered to the new openings.
- Standing adult target remains 82 world units at shell scale 0.395.
