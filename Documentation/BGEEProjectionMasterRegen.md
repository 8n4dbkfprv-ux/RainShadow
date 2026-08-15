# Area master regeneration — BG:EE projection

Pipeline math, docs, grayboxes, UI rings, and `OfficeNavigationLayout.swift`
already speak the Baldur's Gate: EE camera
(`ArtSource/Processing/ie_projection.py`). Painted masters still need Image
Generator passes under the new locks.

## Office suite (V5)

1. Generate empty suite plate with
   [`ArtSource/Prompts/office_suite_plate_bgee_v05.md`](../ArtSource/Prompts/office_suite_plate_bgee_v05.md).
2. Re-fit `REAR` / axis **lengths** in `office_room_plan.py` against the new
   shoes (slopes must stay ±0.75). Re-measure `WALL_FACE_H` / doorway under
   height foreshortening ≈ 0.6614.
3. Rebuild suite plate, partition, lettered door, prop registrations
   (`process_office_suite_plate_*`, `process_office_partition_plate_v01.py`,
   `process_office_door_lettered_v01.py`).
4. `python3 ArtSource/Processing/office_layout_plan.py` must print
   `ALL CHECKS PASS: True`, then `--write`.
5. Flood-fill the runtime SearchMap (`path`, never `route`).

## City districts (V3)

1. Generate each district against
   [`ArtSource/Prompts/city_perspective_lock_v03.md`](../ArtSource/Prompts/city_perspective_lock_v03.md).
2. `python3 ArtSource/Processing/process_city_districts_v02.py`
3. `measure_city_door_apertures.py` + `qa_city_door_registration.py`
4. Re-derive street-side portal approaches (~120–150 units out from
   `nearestWalkablePoint`, unrounded) in `CityDistrictCatalog.swift`.
5. Flood-fill every spawn.

## Characters (follow-up)

See [`ArtSource/Prompts/character_camera_lock_bgee_v01.md`](../ArtSource/Prompts/character_camera_lock_bgee_v01.md).
Install only in the AGENTS.md order after masters land.

## Already done in-repo

- `ie_projection.py` shared constants + helpers
- Docs / prompt locks (city V3, office suite V5, character lock)
- Layout planner half-steps 64/48, diamond 128×96
- Room-plan axis slopes ±0.75
- Graybox / prop / UI ring generators on shared projection
- Procedural zone props + selection rings regenerated
- `OfficeNavigationLayout.swift` re-emitted; planner `ALL CHECKS PASS: True`
