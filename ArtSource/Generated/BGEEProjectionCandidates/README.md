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

Office candidate `office_suite_plate_bgee_v05_candidate.png` is **installed**
by `ArtSource/Processing/install_office_bgee_v05.py` (3.81° on the 4096×2304
letterboxed plate). `ie_projection.ACTIVE` is `BGEE`.

Install city districts with `ArtSource/Processing/install_city_districts_bgee_v03.py`.
Do not run `process_city_districts_v02.main()`.
