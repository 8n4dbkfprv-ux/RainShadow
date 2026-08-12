# City door leaves V1 — separate from building facades

- Generated: 2026-08-02
- Mode: built-in Image Generator
- Refs: `city_perspective_lock_v02.md`, parent `city_building_*` facade (material + dimetric angle), office door separation rule
- Intent: Ship closed outdoor door leaves as separate chroma props so modular buildings keep empty warm doorway apertures only (office shell pattern).
- Placement: leaves are **not** positioned by hand. Each facade's opening is measured once — centre and threshold in 512×640 canvas pixels — into `CityDistrictLayout.SourceDoorAperture`, and `CityDistrictLayout.doorLeaf(...)` derives the leaf's world `groundPoint` from its building. Re-measure with `ArtSource/Processing/measure_city_door_apertures.py` whenever a facade in the table below is regenerated; a leaf added here without an aperture fails `CityDoorRegistrationTests`.

## Runtime IDs

| Building | Primary leaf | Extra leaves |
|---|---|---|
| `city_building_voss_stoop` | `city_door_voss_stoop` | `city_door_voss_stoop_garage` (storefront bay doors) |
| `city_building_tenement` | `city_door_tenement` | |
| `city_building_storefront` | `city_door_storefront` | |
| `city_building_rowhouse` | `city_door_rowhouse` | |
| `city_building_shop` | `city_door_shop` | |
| `city_building_gatehouse` | `city_door_gatehouse` | |
| `city_building_shipping_office` | `city_door_shipping_office` | |
| `city_building_warehouse` | `city_door_warehouse` | |
| `city_building_boarding` | `city_door_boarding` | |
| `city_building_dock_shed` | `city_door_dock_shed` | |
| `city_building_lila_rooms` | `city_door_lila_rooms` | `city_door_lila_rooms_b` (paired entry) |
| `city_building_lila_neighbor` | `city_door_lila_neighbor` | |
| `city_building_lila_opposite` | `city_door_lila_opposite` | |
| `city_building_lila_alcove` | `city_door_lila_alcove` | |
| `city_building_pd_station` | `city_door_pd_station` | |
| `city_building_pd_annex` | `city_door_pd_annex` | |
| `city_building_pd_alley` | `city_door_pd_alley` | |
| `city_building_records_annex` | `city_door_records_annex` | |
| `city_building_records_wing` | `city_door_records_wing` | |
| `city_building_records_colonnade` | `city_door_records_colonnade` | |
| `city_building_iron_stairs` | `city_door_iron_stairs` | (only if facade has a painted leaf) |
| `city_building_river_watch` | `city_door_river_watch` | |

Doorless chunks (no leaf props): `pd_plaza_wall`, `records_plaza`, `rail_lamp`, `abutment`.

## Shared leaf prompt (solo)

```text
Use case: stylized-concept
Asset type: modular isometric outdoor door-leaf prop
Primary request: Create one closed rain-dark period door leaf in the exact fixed 2:1 dimetric camera of the RainShadow city building facade (already sheared to match the wall — not an upright front elevation). Match the wood/metal material, panel layout, warm upper-left lighting, and leaf proportions from the parent building reference. Single leaf only — no wall, no jamb, no stoop, no awning, no stairs.
Scene/backdrop: perfectly flat solid #00FF00 chroma-key background for local removal. Uniform color, no shadows, gradients, floor plane, or lighting variation on the background.
Style/medium: richly pre-rendered late-1990s isometric PC CRPG prop; painterly baked textures; match RainShadow office suite plate materials.
Composition/framing: centered leaf with generous green clearance; full leaf visible; crisp silhouette.
Constraints: do not use #00FF00 in the leaf; no cast shadow; no contact shadow; no person; no readable text or logos; no frame/wall; no watermark.
Avoid: upright billboard elevation; modern flush door; purple neon; franchise copies.
```

## Empty-aperture building edit (shared invariant)

```text
Use case: precise-object-edit
Asset type: modular isometric architecture sprite
Primary request: Edit only the painted door leaf/leaves on this city building. Remove every opaque door leaf so each doorway becomes an empty warm dark aperture with jamb, threshold, and interior spill preserved. Keep stoop stairs, awnings, brick, windows, fire escapes, lamps, and the full building silhouette unchanged. Door leaves will be separate sprites later.
Constraints: change only door leaf pixels; keep camera, scale, materials, and chroma/alpha surround; no people, text, UI, watermark.
Avoid: filling the opening with wall; baking a new leaf; moving windows or stoop.
```

## Processing

- Processor: `ArtSource/Processing/process_city_districts_v02.py` (door solos/sheets)
- Runtime: `RainShadow Shared/Resources/Art/Props/CityDistrict/V2/city_door_*.png`
- Masters: `ArtSource/Generated/CityDistrict/V2/**/city_door_*`
