# Sable Row — Infinity Engine outdoor redo (v01)

Pilot ward only. The other five Act I districts stay on modular facades until a
later pass.

## Contract

| Piece | Behaviour |
|---|---|
| Day plate | `city_sable_row_day_v01` — one pre-rendered 8192×6144 painting |
| Night | `city_sable_row_night_placeholder_v01` via `nightPlateTextureName` (Extended Night swap, not a blue multiply). Full night art deferred. |
| Roofs | Painted into the plate; search map keeps type **13** |
| Closed street doors | Painted into the plate (no `city_door_*` overlays). ARE door + region polygon for click / Tab outline. Fog-only shroud outdoors (`outdoorDoorShroud`). |
| Open door | Clears the door stamp → LOS through the opening. No indoor room flood. |
| Cover | `wallPolygons` on each lattice diamond (`AreaCoverAuthoring`) |
| Rain | `RainSystem` overlay at reduced density; default actor grade is `cityDay` |

## Bake

```bash
python3 ArtSource/Processing/bake_sable_row_ie_outdoor_v01.py
```

### Portal.office stamp

The f266886b human-scale portal take was unseated: the IG crop was ~80×
sharper than the soft plate neighbourhood and read as a lit rectangle on
Voss's stoop. Restore + rebake:

```bash
python3 ArtSource/Processing/unseat_sable_row_portal_office_v01.py
```

## Xcode

1. Open `RainShadow.xcodeproj` on macOS.
2. Run with `RAINSHADOW_START_SCENE=city` (optional `RAINSHADOW_START_DISTRICT=sable_row`).
3. Tab toggles door / travel outlines. Walk to Voss's stoop (`portal.office`) to exercise open + travel.
4. Suite: `swift test --scratch-path /tmp/RainShadowSwiftPM --filter SableRowIEOutdoor`

## Deferred

- Full Extended Night painting (placeholder only)
- Remaining five wards
- Night-scheduled ambient playback tied to the plate swap
