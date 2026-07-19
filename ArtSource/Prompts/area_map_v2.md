# RainShadow detective-office area map V2

Date: 2026-07-19  
Generator: built-in Image Generator (edit/reference mode)  
Generated source: `exec-94e7d426-5eb1-48c0-90bd-b7ffc3f82803.png`

## Correction brief

V1 was structurally anchored to an older flattened office composite and therefore
included props that are no longer present in the playable modular interior. V2
uses a clean capture of the assembled runtime scene as its layout authority. The
user-supplied Baldur's Gate screenshot is a functional marker reference only:
the runtime current-position glyph is now a thin green 2:1 ground ellipse rather
than a compass needle.

## Reference roles

- `ArtSource/References/UI/Map/office_runtime_clean_v02.png`: structural source of truth captured from the assembled runtime scene with actors, fog, dialogue, HUD, and debug counters hidden.
- `ArtSource/Generated/UI/Map/map_detective_office_v01.png`: style-only reference for RainShadow's painterly noir area-map treatment.
- The user-supplied Baldur's Gate screenshot informs only the functional ground-ring convention. No franchise artwork, UI chrome, symbols, or locations are reused.

## Exact final prompt

```text
Create a corrected wide area-map raster plate for the RainShadow game.

INPUT ROLES:
- Reference image 1 is the STRUCTURAL SOURCE OF TRUTH: an exact clean capture of the currently shipped playable detective-office interior. Preserve its room footprint, wall geometry, isometric camera, floor extent, openings, prop count, prop identity, and prop placement.
- Reference image 2 is STYLE ONLY: the first generated map plate. Preserve its cinematic noir presentation, hand-painted late-1990s isometric CRPG texture, warm sepia/brown floor and furniture, cool rainy blue window, restrained golden desk lamp, deep black surrounding void, subdued contrast, and vignetted map-readability.

EXACT REQUIRED CONTENT FROM REFERENCE 1:
- one small high window on the left wall with one radiator beneath it
- one central detective desk with its matching chair and only the existing desktop papers/files, mug, ashtray, black telephone, and brass desk lamp
- one four-drawer filing cabinet near the right doorway
- one open frosted-glass wooden door in the right doorway
- one coat rack just right of the door
- one worn visitor armchair in the lower-right floor area
- the same broad sparse floor and panoramic zig-zag wall footprint shown in reference 1

REMOVE/DO NOT INVENT:
- no people, player character, NPCs, markers, icons, rings, labels, letters, title text, UI frames, controls, cursor, phone home indicator, or debug text
- no extra side tables, boxes, wastebasket, rugs, books on the floor, paintings, bulletin board, wall poster, second chair, extra cabinets, extra windows, closed second door, or decorative clutter
- do not crop into a compact square room and do not rearrange the furniture

OUTPUT:
- a wide landscape map plate matching reference 1's approximate 2.17:1 aspect ratio
- the complete playable interior centered with generous pure-black unexplored void/margin around the footprint, suitable for a full-screen area-map overlay
- visually consistent with RainShadow's existing dark painterly noir art, not photorealistic and not modern 3D
- no text and no embedded navigation marker
```

## Runtime contract

- Source/runtime image: 1847×851 opaque sRGB PNG (aspect ratio preserved by SpriteKit).
- Retained source: `ArtSource/Generated/UI/Map/map_detective_office_v02.png`.
- Runtime asset: `RainShadow Shared/Resources/Art/UI/Map/map_detective_office_v02.png`.
- SpriteKit owns all UI, labels, notes, and the live green 2:1 current-position ring.

