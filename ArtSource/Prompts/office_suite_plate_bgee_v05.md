# Office suite plate — BG:EE orthographic camera (V5)

- Generated: 2026-08-15
- Mode: Cursor Image Generator
- Supersedes: `office_suite_plate_bgee_v04.md` (retired 2:1 dimetric / ~30° elevation wording)
- Projection lock: `Documentation/InfinityEngineGroundProjection.md` /
  `ArtSource/Processing/ie_projection.py`
- Process after regen: re-fit `office_room_plan.py` axes to slopes ±0.75, then
  `process_office_suite_plate_cramped_v01.py` / suite architecture rebuild

## Intent

Regenerate the empty detective-office suite under the true Baldur's Gate: EE
orthographic camera (elevation asin(0.75) ≈ 48.59°, ground axes 36.87°) so area
art matches the already-shipped 16×12 SearchMap and 0.75 locomotion foreshorten.
Architecture stays empty; modular props and actors keep body scale.

## Generation prompt (V5)

```text
Empty 16:9 isometric CRPG environment plate. Original 1940s noir detective suite, EMPTY architecture only. CRITICAL CAMERA: Baldur's Gate: EE orthographic projection — elevation asin(0.75) ≈ 48.59°, azimuth 45°, ground axes at 36.87° from horizontal (slopes ±0.75), height foreshortening ≈ 0.661, verticals perfectly vertical, no vanishing point, no horizon; a circle on the ground is a 16:12 ellipse. Pull back substantially farther and higher than a close dollhouse interior so the complete suite footprint sits smaller in the frame with generous pure-black void around the silhouette. Walkable floor should feel deep: roughly ten imagined adult body-heights from camera-near cutaway to rear wall. Wall height, window recess, and door openings must read SMALL relative to the floor diamond — doorway about two imagined adult heights, window glass about one adult height. Layout: private office left with high left-wall window recess; short partition with open doorway; compact waiting nook right with upper-right exterior doorway into darkness; open camera-near cutaway edges (no front wall). Materials: worn dark floorboards, stained nicotine plaster over dark olive wainscot, cracked plaster, scuffed trim. Lighting: cool rain-blue from window, subdued amber residue only — no bright orange doorway fire glow. Style: late-1990s pre-rendered Infinity Engine–era painterly CRPG, soft native raster, no PBR, no furniture, no people, no door leaves, no UI, no text, no fog. Pure black outside silhouette only. Do not use retired 2:1 dimetric / ~30° elevation.
```

Reference images: current suite plate (materials / layout craft) +
`Documentation/InfinityEngineGroundProjection.png` (camera geometry only — do not copy).

## After the master lands

1. Re-fit `REAR`, `AXIS_NW`, `AXIS_NE` in `office_room_plan.py` (slopes must be ±0.75).
2. Re-measure `WALL_FACE_H` / doorway under height foreshortening 0.6614.
3. Rebuild suite plate, partition, lettered door, prop registrations.
4. Re-emit `OfficeNavigationLayout.swift` and flood-fill reachability (`path`, not `route`).
