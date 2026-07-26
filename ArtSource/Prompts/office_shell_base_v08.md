# Office shell V8 — classic BG doorway (~1.94× adult)

- Generated: 2026-07-26
- Mode: material-aware wall/doorway raise from approved V6 runtime plate (registration-locked). Full Image Generator one-shot remains preferred if a later pass matches IoU; V8 ships the measured raise so openings hit the BG scale contract without black module pastes.
- Master: `ArtSource/Generated/Office/office_shell_base_v08.png` (4096×2304 runtime master)
- Runtime: `RainShadow Shared/Resources/Art/Areas/DetectiveOffice/office_shell_base.png` (4096×2304)
- Process: `ArtSource/Processing/process_office_shell_v08.py`

## Why V8

V6 preserved a short NE doorway (~220–246 plate px ≈ **1.06×** adult). Leaves were crushed to `entranceLeafDisplayScale = 0.1207` to fit. Classic BG:EE doorway/adult ratio is **1.94**, which needs an opening ≈ **403** plate px and a wall face tall enough for lintel/casing (≥ **430**).

## Scale authority

BG:EE tavern doorway close-up (`tmp/imagegen/bg_tavern_ref_door_close_v04.png`): standing adult 185 px, doorway 359 px, ratio **1.94**.

## Targets on 4096×2304 runtime

| Feature | Target | Band |
|---|---:|---|
| Imagined standing adult | ~208 plate px (82 world @ env 0.395) | — |
| Doorway opening height | **403 px** | 390–420 |
| Wall face height | **440 px** | 430–450 |
| Window recess | unchanged from V6 | ±3% |

## Generation prompt (Image Generator one-shot, optional)

```text
Use case: stylized-concept
Asset type: production empty environment plate for a fixed-camera isometric CRPG
Primary request: Reproduce Image 1 (the approved RainShadow detective-office empty shell V6) as ONE coherent architectural plate, raising the wall crowns and enlarging ONLY the upper-right open doorway so it reads as a classic Baldur's Gate human door (~1.94× standing adult). Keep the left-wall window recess exactly as in Image 1. Everything else — room footprint, camera, materials, floorboards, two-tone walls, pure-black exterior silhouette — must match Image 1 as closely as possible.
Input images: Image 1 is the approved V6 RainShadow empty office shell (authoritative for layout, materials, projection, window recess, black exterior). Images 2–4 are Baldur's Gate: Enhanced Edition tavern screenshots used only to measure doorway/adult scale (doorway ≈ 1.94× standing adult). Do not copy tavern layout, furniture, characters, UI, or fantasy decoration.
Doorway specification: ONE open built doorway in the upper-right / NE wall with integrated jambs, header, threshold, and dark hall beyond. On the final 4096×2304 plate: opening height about 390–420 pixels (target ~403). Raise the NE wall crown so a natural lintel/casing remains above the opening (wall face ~430–450 px). Do not paste a flat black rectangle; the opening must read as built architecture.
Window recess specification: keep Image 1's left-wall unglazed recess unchanged (position, size, sill clearance).
Scene/backdrop: empty 1940s private-detective office after hours; worn dark wooden floorboards; stained two-tone plaster over dark wainscot; noir, lonely, lived-in.
Style/medium: richly pre-rendered late-1990s isometric PC CRPG environment art; painterly baked textures; modest native-resolution softness; no modern PBR gloss.
Composition/framing: exact 16:9 landscape matching Image 1 registration as closely as possible.
Constraints: EMPTY ARCHITECTURAL SHELL ONLY. No desk, furniture, rugs, lamps, door leaf, window glass, window sash, people, UI, text, logos, watermark, selection circles, or baked movable-prop shadows. Pure black only outside the room silhouette.
Avoid: shrinking the doorway; patch-composite black boxes; moving the window; changing the room plan; painting a door leaf into the opening.
```

## QA gate (must pass before shipping)

- Exterior doorway opening height 390–420 px on runtime plate
- Wall face ≥ 430 px at NE doorway
- Window recess within ±3% of V6
- No axis-aligned pure-black rectangular halos (V4 failure mode)
- Architecture IoU vs V6 ≥ ~0.85 (wall crowns + doorway may change)
