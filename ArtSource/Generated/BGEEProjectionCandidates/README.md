# BG:EE city V3 masters

Accepted 2026-08-15. Installed grounds after `fit_to_aspect` to 2048×1152:

| District | Worst delta | Verdict |
|---|---|---|
| Riverside | 0.79° | PASS |
| Sable Row | 2.04° | PASS |
| Lila Street | 2.15° | PASS |
| Wharf Ladder | 2.16° | PASS |
| Harborpoint PD | 2.97° | PASS |
| Civic Records | 3.90° | PASS |

Office V5 candidate `office_suite_plate_bgee_v05_candidate.png` is the on-lock
master. `install_office_bgee_v07.py` re-places it and compresses the plaster
band so the exterior door column is 73% door/wall (V5 was 54% — a warehouse
void above the lintel). Installed plate still grades inside 4°.
`ie_projection.ACTIVE` is `BGEE`.

Install city districts with `ArtSource/Processing/install_city_districts_bgee_v03.py`.
Do not run `process_city_districts_v02.main()`.
