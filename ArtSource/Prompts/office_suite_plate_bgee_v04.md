# Office suite plate — BG:EE mid-band camera (V4)

- Generated: 2026-08-06
- Mode: Cursor Image Generator with BG:EE screenshot + cramped V3 suite as scale/material references
- Masters:
  - `ArtSource/Generated/Office/office_suite_plate_cramped_v04.png` (from `office_suite_plate_bgee_v04b.png`)
  - Alternate closer pass: `office_suite_plate_bgee_v04.png`
- Shipped: `RainShadow Shared/Resources/Art/Areas/DetectiveOffice/office_suite_plate.png` via
  `process_office_suite_plate_cramped_v01.py --scale 0.60`
- Runtime camera: rendered adult body at **9%** of visible height (`DefaultPlayZoom`);
  shell mapped at `ENVIRONMENT_SCALE = 0.395` (nav-authored). Plate fill is ~0.90 of
  the mid-band camera — a thin black void past the plate edge is intentional.

## Intent

Pull the playable office framing to the BG:EE playfield mid-band after fixing the
logical-82 vs rendered-90.6 density mismatch. Architecture stays empty; modular
props and actors keep body scale.

## Generation prompt (v04b — shipped source)

```text
Empty 16:9 isometric CRPG environment plate. Original 1940s noir detective suite, EMPTY architecture only. CRITICAL CAMERA: pull back substantially farther and higher than a close dollhouse interior — fixed near-orthographic 2:1 dimetric view matching Baldur's Gate Enhanced Edition area-view human scale. The complete suite footprint must sit smaller in the frame with generous pure-black void around the silhouette. Walkable floor should feel deep: roughly ten imagined adult body-heights from camera-near cutaway to rear wall. Wall height, window recess, and door openings must read SMALL relative to the floor diamond — doorway about two imagined adult heights, window glass about one adult height. Layout: private office left with high left-wall window recess; short partition with open doorway; compact waiting nook right with upper-right exterior doorway into darkness; open camera-near cutaway edges (no front wall). Materials: worn dark floorboards, stained nicotine plaster over dark olive wainscot, cracked plaster, scuffed trim. Lighting: cool rain-blue from window, subdued amber residue only — no bright orange doorway fire glow. Style: late-1990s pre-rendered Infinity Engine–era painterly CRPG, soft native raster, no PBR, no furniture, no people, no door leaves, no UI, no text, no fog. Pure black outside silhouette only.
```

Reference images: cramped suite V3 (materials / layout craft) + supplied BG:EE screenshot (camera elevation / human scale only — do not copy).
