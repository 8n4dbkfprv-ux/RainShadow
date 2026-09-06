# Sable Row Blender section V02

6 September 2026. Refines V01's Voss entrance, courtyard, diner and intersection,
then stages terrain and cover from the actual Blender geometry. This is a
validated **section**, not a replacement for the entire 5120×3840 Sable Row ward.

## Review files

All assets are in `ArtSource/Blender/SableRowStudyV02/`:

- `sable_noir_court_v02.blend`: editable daytime and nighttime scenes with 3,411
  objects in the day scene, the original scene preserved, and the masonry image
  packed into the file. Day and night share geometry and camera.
- `staged/sable_court_day.png` and `staged/sable_court_night.png`: native
  6144×4608 Cycles renders. No image enlargement supplies their source detail.
- `sable_court_walk_review.mp4`: 37.73-second SpriteKit review, 1280×960, with
  current native Voss frames, the actual movement trace and the shipped stencil
  shader. Playback skips every other recorded step and is labeled 2×.
- `staged/sable_court.area.json`, `.sr.png`, `.ht.png`: decoded and exercised by
  the real area/navigation code, without installing an experimental catalog entry.
- `scene_geometry.json`: evaluated meshes, ground footprints, camera transform
  and named positions exported through the live Blender MCP connection.
- `staged/runtime_walks.json`, `stencil_report.json`, `cover_comparison.json`,
  `export_report.json`, `validation_points.json`: measured evidence.
- `texture_prompts.json`: exact prompt and built-in ImageGen provenance.
  `textures/russet_brick_albedo.png` is the generated texture used by Blender.
- `live_refinement_stages.json`: retained authoring batches. The `.blend` is the
  authority; these batches require V01's live construction namespace.

## Visual changes

The apartment uses textured weathered masonry at measured brick scale. Asphalt
has fine aggregate rather than broad cloudy coloring. Paving and courtyard
setts have restrained variation, with localized concrete replacements, road
repairs, gutter dampness, kerb weeds and litter. Roofs now have repairs, a wired
skylight and diner extraction duct. Windows have varied roller shades and two
courtyard planters. Foliage uses lobed leaf geometry instead of square cards.
The courtyard has ivy and an enamel street plate.

The gate was widened from 1.45 m between masonry piers to 2.45 m. This is an
authored geometry change, not a relaxation of search-map clearance.

This is a more detailed and less uniform section. It is not an assertion that
its procedural architecture equals the surface richness of a finished BioWare
background. Roofs, trim and period sedans still have a simpler treatment.

## Export contract and results

The modeled section is 2816×2112 world units. At 6144×4608 it carries 2.1818
source pixels per world unit. A 1.8 m adult projects to 69.85 world units,
within 0.67% of the current 70.3125-unit detective. The 2.38 m Voss door leaf is
1.322× an adult. Both final plates pass `qa_plate_projection.py` with worst
error **0.18°** against the ±36.87° ground axes.

Ground footprints are projected onto a shared reference plane at z=0.10 m.
The height raster accounts for street/pavement/court offsets using the runtime's
128-centered, ±6-unit convention. The stoop is an obstacle; the street approach
is where an exterior interaction would be issued. The height map does not
pretend to make the staircase or multiple floors navigable.

The 176×176 terrain raster is conservative: any positive-area footprint overlap
blocks a cell. Buildings use sidewall terrain 10, with roof terrain 13 confined
to the interior of their physical footprints. Low obstructions use 8. Roof
pixels are not incorrectly stamped over walkable streets behind a building.
The section boundary is closed and contains no invented district travel links.

The cover export uses evaluated mesh faces, unions their projected silhouettes,
retains holes and triangulates polygons with holes. Its 0.25-world-unit
simplification is below one source pixel. The exported area contains 7,602
cover polygons, including fine foliage and wires. `AreaWallStencil.bake`
produced a **1408×1056** mask in **0.77 seconds**, under its existing 2048 cap.
The fine foliage makes this a higher polygon count than a typical ward; a whole
ward must be measured independently before extending this representation.

Validation uses the actual `AreaCatalogLoader`, `AreaSearchMapLoader`,
`NavigationMap`, `PathFinder`, `Movable`, `AreaHeightMap` and `AreaWallStencil`:

- All **132 directed pairs** among 12 approach/route anchors reach their exact
  requested cells with the current detective clearance.
- All **12 recorded movement journeys** arrive and keep every emitted position
  on walkable terrain.
- The apartment, diner, tree bed and parked car witnesses are solid.
- Front-of-wall/open-street witnesses stay clear; the behind-wall witness gets
  the correct dither channels. An asymmetric triangle preserves its orientation.
- Native Voss frame export for review passes and leaves character resources intact.

One initial movement failure exposed a fractional waypoint at x=1295.99516:
the authoring check saw cell 80, while `Movable` rounded to x=1296 in cell 81.
The exporter now writes integral engine positions before testing. It does not
silently relocate blocked targets; all positions are validated after conversion.

An independent Workbench silhouette render at four samples per axis agrees
with the real Swift stencil at **99.485% intersection-over-union**. There are
zero mismatches more than three mask pixels from the reference boundary.
A first single-sample reference missed entire subpixel leaves; a dedicated
asymmetric-face check confirmed the runtime orientation was correct. Increasing
the reference sampling resolved that measurement error without changing the
runtime or loosening the gate.

## Reproducing the stage and review

The converter requires Python with Pillow, numpy and Shapely 2.1. The session
used an isolated environment at `/tmp/rainshadow-area-v02`.

```sh
python ArtSource/Processing/export_sable_blender_area_v02.py
RAINSHADOW_SABLE_STAGE="$PWD/ArtSource/Blender/SableRowStudyV02/staged" \
  swift test --scratch-path /tmp/RainShadowSableV02 --filter SableBlenderAreaValidation
python ArtSource/Processing/qa_sable_blender_cover_v02.py
swift ArtSource/Processing/preview_sable_blender_v02.swift
```

The tests are opt-in through `RAINSHADOW_SABLE_STAGE`, so an absent local art
study does not fail the ordinary suite. Blender renders are generated through
the live scene; the converter does not launch Blender or regenerate geometry.

## Installation boundary

No shipped area, game engine behavior or character asset was changed. The
SpriteKit video is an isolated QA scene using the recorded real movement and
shader; it is not a full-game playthrough. It uses a fixed daylight actor tint,
and does not validate rain, fog exploration, dialogue, interior travel or night
actor lighting. The staged section has no authored travel/door state records.

Replacing the whole ward still requires extending the design to its district
connections and interactive buildings, authoring those records, matching actor
lighting to both plates, and reviewing the full game. The section exports and
their current navigation/cover measurements are concrete inputs to that work;
they should not be installed over the much larger existing ward as-is.
