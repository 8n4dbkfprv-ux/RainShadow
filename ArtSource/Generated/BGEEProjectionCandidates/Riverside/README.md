# Riverside V3 masters (BG:EE camera)

Accepted 2026-08-15 after `qa_plate_projection.py` on the installed 2048×1152
ground: **+36.28 / −37.66, worst 0.79°**.

| File | Role |
|---|---|
| `city_riverside_ground_v03.png` | Clean play underlay (16:9 request; generator emitted 3:2) |
| `city_riverside_ground_v03_4x3.png` | Alternate 4:3 pass (also on-lock, worse 3.66°) |
| `city_building_*_v03.png` | Landmark solos on `#00FF00` |
| `city_door_*_v03.png` | Separate leaves on `#00FF00` |

Install with `ArtSource/Processing/install_riverside_bgee_v03.py`. Do not run
`process_city_districts_v02.main()` — that walks every district.
