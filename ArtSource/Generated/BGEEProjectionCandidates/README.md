# BG:EE city V3 masters + V4 density overlay

V3 grounds (1536×1024) were accepted 2026-08-15 on the camera lock. V4
(`city_*_ground_v04.png`) is the same master centre-cropped to 16:9 and given
a 16 px sett / 56 px flag overlay at `PLATE_SIZE` (4096×2304). Installed
grades after that overlay:

| District | Axes | Worst | Density | Verdict |
|---|---|---|---|---|
| Riverside | +35.96 / −37.11 | 0.91° | 2.00 | PASS |
| Wharf Ladder | +35.08 / −36.21 | 1.79° | 2.00 | PASS |
| Lila Street | +39.08 / −37.20 | 2.21° | 2.00 | PASS |
| Sable Row | +39.19 / −36.83 | 2.32° | 2.00 | PASS |
| Harborpoint PD | +34.07 / −33.73 | 3.14° | 2.00 | PASS |
| Civic Records | +32.98 / −32.95 | 3.92° | 2.00 | PASS |

Office V5 candidate `office_suite_plate_bgee_v05_candidate.png` is the on-lock
master. `install_office_bgee_v07.py` re-places it and compresses the plaster
band so the exterior door column is 73% door/wall (V5 was 54% — a warehouse
void above the lintel). Installed plate still grades inside 4°.
`ie_projection.ACTIVE` is `BGEE`.

Install city **grounds** with `install_city_grounds_density_v04.py`.
`install_city_districts_bgee_v03.py` still slices landmarks/doors and now
routes grounds through the same overlay. Do not run
`process_city_districts_v02.main()`. Do not Lanczos a 1536 master to
4096 — that passes `qa_plate_density.py` without adding stonework.
