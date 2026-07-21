# Character pre-rendered 3D V3 style lock

Generated 2026-07-21 with the built-in Image Generator in reference/edit mode.

## Direction

RainShadow's gameplay actors use the classic pre-rendered video-game production chain: a deliberately simple 3D character model is rigged and rendered offline into directional 2D frames. V3 corrects the overly realistic V2 finish by requiring:

- authentic late-1990s isometric PC **video game** character rendering;
- a very modest polygon budget and visibly faceted silhouette/volume changes;
- low-resolution hand-painted diffuse maps, broad baked light, restrained AO, and limited muted color ramps;
- simplified faces, hair, fingers, shoes, and accessories designed to survive a roughly 100-pixel-tall final sprite;
- ordinary realistic proportions rather than toy or oversized pixel-sprite anatomy;
- no modern PBR, photoreal skin/hair, painterly concept-art finish, cel shading, comic outline, or hand-authored pixel art.

The generator masters use a flat `#00ff00` chroma field with no floor or shadow. `process_pre_rendered_characters_v3.py` removes the key, reduces each figure in premultiplied-alpha space to a 100-pixel native body, limits it to 96 colors without dithering, enlarges it 2× with nearest sampling onto a 512×512 registered frame, and writes all 55 runtime cells. SpriteKit displays the 512px frame at 256 points with nearest filtering, resolving the intended small native raster while preserving the existing 100-world-unit scale and doubled ground pivot.

## Shared prompt contract

Use case: style-transfer
Asset type: directional gameplay sprite or animation sheet for a late-1990s fixed-camera isometric PC role-playing video game
Primary request: Re-render every supplied pose as the same simple low-polygon 3D video game model, animated in 3D and rendered offline into 2D sprites. Preserve the exact identity, costume, direction, pose progression, grid order, camera, baseline, and layout from the input sheet.
Style/medium: authentic 1997-1999 pre-rendered isometric VIDEO GAME sprite; very modest polygon budget; blocky/faceted mesh; low-resolution diffuse texture maps; broad baked light; restrained ambient occlusion; limited muted color ramps; simplified face, hair, hands, shoes, and accessories; intentionally designed to read at about 100 pixels tall; not polished modern character art.
Composition/framing: orthographic 2:1 dimetric camera looking down about 35 degrees; strict equal-cell layout; generous gutters; every figure fully separated and uncropped.
Scene/backdrop: perfectly flat uniform solid `#00ff00` chroma-key field.
Constraints: exactly the requested figure count; one consistent character throughout; no floor plane, cast/contact shadow, scenery, extra props, weapons, labels, grid lines, boxes, text, logos, or watermark; do not use `#00ff00` in a character.
Avoid: photorealism; realistic concept art; modern PBR; pore-level skin; individual hair strands; glossy materials; painterly rendering; cel shading; comic outlines; cute/toy proportions; oversized head, hands, or shoes; hand-drawn pixel art.

## Character locks

- **Elias Vale:** receding dark hair, short dark beard, broad weary middle-aged face, compact sturdy build, charcoal trench coat, cream shirt, loosened dark-red tie, brown trousers, brown shoes; no hat or weapon.
- **Vivian Hart:** adult mid-century appearance, small burgundy hat, dark brown waved bob, worried face, charcoal raincoat, burgundy skirt suit, cream blouse, brown handbag in her anatomical left hand, sensible dark heels.

## Sheet-specific layout contracts

- Elias standing idle: five figures in one row — South, Southwest, West, Northwest, North.
- Elias walk: strict 4-column × 5-row sheet; four alternating contact/pass phases per row; row order South, Southwest, West, Northwest, North.
- Elias seated idle: four figures in one row; southeast desk-facing pose; complete sleeves, forearms, and hands on one implied tabletop plane; no desk or chair drawn.
- Elias stand-up: strict 4-column × 3-row sheet, read left-to-right then top-to-bottom; seated, lean, weight transfer, rise, planted southeast idle.
- Vivian arrival: five figures in one row — contact, pass, opposite contact, inverse pass, planted southwest idle; handbag side fixed.
- Vivian departure: four figures in one row — contact, pass, opposite contact, inverse pass; rear three-quarter northeast; handbag side fixed.

## Generator outputs

| Asset | Built-in output | Retained master |
|---|---|---|
| Elias key | `exec-9ddaaa9b-ad07-4d8b-97ed-4683d702afa1.png` | `Detective/PreRendered3DV3/det_key_se_chroma_v03.png` |
| Elias standing idle | `exec-dd634143-e67e-4a45-bcb8-756b3f8b06f2.png` | `Detective/PreRendered3DV3/det_standing_idle_5dir_chroma_v03.png` |
| Elias walk | `exec-7f63947b-af8a-4ab6-9318-792522ddfce7.png` | `Detective/PreRendered3DV3/det_walk_5dir_4frame_chroma_v03.png` |
| Elias seated idle, corrected | `exec-208d51a8-0d9a-4ca2-b6a9-9d7fa42a627d.png` | `Detective/PreRendered3DV3/det_seated_idle_strip_chroma_v03.png` |
| Elias stand-up | `exec-8c908cde-fa06-438d-9c4a-1cf139cf0b9e.png` | `Detective/PreRendered3DV3/det_stand_up_sheet_chroma_v03.png` |
| Vivian key | `exec-abd63e86-4502-4c59-9c24-caa31bbe2e65.png` | `Client/PreRendered3DV3/vivian_key_sw_chroma_v03.png` |
| Vivian arrival | `exec-05185718-fb1f-4073-8417-c76b0f35caaa.png` | `Client/PreRendered3DV3/client_arrival_sw_strip_chroma_v03.png` |
| Vivian departure | `exec-11c7a7c0-b8d5-4ab7-91c3-4a5f1037aefe.png` | `Client/PreRendered3DV3/client_departure_ne_strip_chroma_v03.png` |

The seated correction was a `precise-object-edit` that removed only a detached vertical render artifact beside pose three and restored the uniform chroma field.
