# Sable Row lot roofs v01

- Generated: 2026-08-16
- Mode: procedural BG:EE roof deck from the SE terrace hip-slate
- Intent: One continuous lot volume. Street facades stay; the diamond
  interior is roof, not a 3/4 courtyard of extra houses.

`lots_v01/` is the facade authority. `fill_sable_lot_roofs.py` keeps the
near street wall (and the far roof crown) and stamps SE-terrace slate
onto the courtyard plus the far rank's camera-facing wall.

```bash
python3 ArtSource/Processing/fill_sable_lot_roofs.py
python3 ArtSource/Processing/qa_sable_area_bake.py
python3 ArtSource/Processing/compose_city_district_preview.py sable_row
```

Catalog feet and world sizes stay on the v01 crop boxes. Do not tidy them.
