# RainShadow detective-office area map V3

Date: 2026-07-30  
Generator: layout-locked composite (not freehand Image Generator)

## Correction brief

V2 was locked to the July 19 single-room modular interior. The playable office
is now a cramped two-room suite. Freehand Image Generator restyles of the suite
drifted too far from the shipped modular props (invented parquet, wrong chair
models, extra cabinets). V3 is therefore **layout-locked**:

1. `compose_office_redesign_preview.py` composites the shipping suite plate +
   runtime props (skipping retired washbasin) + desk clutter.
2. The composite is framed on a black void as `office_runtime_clean_v03.png`.
3. A light map mood pass (vignette, warm desk / cool window grade, slight
   contrast) produces `map_detective_office_v03.png` without moving pixels.

The Baldur's Gate area-map screenshot remains a functional/presentation
reference only (cutaway readability, black void, localized light). It is not
used as a content source for V3.

## Reference roles

- `ArtSource/References/UI/Map/office_runtime_clean_v03.png`: structural source
  of truth (composed from shipping plate + `office_layout_plan` props).
- `ArtSource/Generated/UI/Map/map_detective_office_v03_from_layout.png`: mood
  pass retained beside the shipped plate.
- Rejected freehand attempts retained as
  `map_detective_office_v03_rejected_freehand.png` /
  `map_detective_office_v03b_ai_restyle.png`.

## Rebuild

```bash
python3 ArtSource/Processing/compose_office_redesign_preview.py
# then re-frame onto black void + mood pass into map_detective_office_v03.png
```

## Runtime contract

- Source/runtime image: 1847×1040 opaque sRGB PNG.
- Retained source: `ArtSource/Generated/UI/Map/map_detective_office_v03.png`.
- Runtime asset: `RainShadow Shared/Resources/Art/UI/Map/map_detective_office_v03.png`.
- SpriteKit owns UI, labels, notes, and the live 2:1 current-position ring.
- POIs use cramped-suite authored anchors (window/radiator, desk, waiting, exit).
- Overlay `mapSize` preserves 1847:1040; `worldBounds` maps the suite silhouette.
