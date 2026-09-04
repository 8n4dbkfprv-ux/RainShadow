# Infinity Engine city-area architecture

Research checked 2026-08-27 against GemRB, the Infinity Engine Structures
Description Project (IESDP), and the installed BG:EE WED records for AR0400 and
AR0500.

## Literal outdoor dimensions now used

The installed AR0400/AR0500 WEDs are **80×60 background tiles**. At the WED/TIS
tile size of 64×64 pixels, that is a literal **5120×3840** area painting. Their
search maps are **320×320** cells; RainShadow therefore keeps GemRB's 16×12
world-unit search cell and uses the same 5120×3840 world extent.

The retired RainShadow size, 4096×3072 with a 256×256 search map, matched only
the 4:3 proportion. It was not the same dimensions.

A 2-pixel-per-world-unit monolith is 10240×7680 and roughly 300 MiB when decoded
as RGBA. RainShadow packages city art as a **5×5 page grid** of 1024×768 world
units per page, and the runtime pager keeps only the camera neighbourhood
resident. The current Sable Row V15 authority raises its density to 2.5 px/world
unit: one 12800×9600 painting cut into 2560×1920 pages. All 25 pages are
deterministic crops; no registered core, extension paintings, lot cards, or
building overlays survive in the visible result. Its day and night-placeholder
manifests alias those same crops until Extended Night is painted independently.

## What an exterior actually is

An Infinity Engine outdoor area is a pre-rendered background, not a scene made
from freely placed building sprites. The WED resource points at one or more TIS
tilesets; tiling is a storage/rendering detail for the continuous painting. WED
also carries wall polygons and door-specific open/closed tile and polygon data.
The ARE resource carries gameplay records such as actors, doors, entrances and
regions. An SR bitmap separately classifies pathfinding cells.

Sources:

- GemRB engine overview: <https://gemrb.org/Engine-overview.html>
- IESDP WED V1.3: <https://gibberlings3.github.io/iesdp/file_formats/ie_formats/wed_v1.3.htm>
- IESDP ARE V1.0: <https://gibberlings3.github.io/iesdp/file_formats/ie_formats/are_v1.htm>
- Near Infinity Area Viewer: <https://github-wiki-see.page/m/NearInfinityBrowser/NearInfinity/wiki/Documentation-Area-Viewer>

## Door and area-transition contract

The engine does not infer an interior from painted doorway pixels. A door and a
travel region are separate authored records. The door owns closed/open state,
impeded search cells, line-of-sight state and two use points; the travel region
names a destination area and a named entrance in that area. GemRB chooses the
nearer of the door's two approach points, changes door/search/LOS state, and the
area transition places the party at the destination entrance.

Accordingly, a doorway shape painted into a background is scenery unless the
area also authors an `AreaDoor`/travel-region pair. Every such authored city
door in RainShadow is enterable; decorative façade pixels do not advertise a
door cursor.

Reference implementation: GemRB `Door.cpp`:
<https://github.com/gemrb/gemrb/blob/master/gemrb/core/Scriptable/Door.cpp>

## RainShadow mapping

| Infinity Engine concept | RainShadow implementation |
|---|---|
| Continuous TIS/WED background | `<plate>.pages.json` + 25 `<plate>_page_c##_r##` textures, drawn as one 5120×3840 world |
| SR search bitmap | `city_<district>.sr.png` / `city_building_interior_v01.sr.png` |
| ARE door | `AreaDoor`: closed obstacle, sight flag, sounds and two exact approach points |
| ARE travel region | `AreaRegion(kind: .travel)` with `AreaTravel(destination:entrance:)` |
| Named destination entrance | `AreaEntrance`; exterior return points preserve the unrounded street approach |
| Door use | `CityDistrictScene` walks with `requiresExactDestination`, opens the registered door, then calls the router with the named entrance |

The Sable V6 payload is restored by
`ArtSource/Processing/superresolve_city_ie_monolith_v06.py`, cropped and
installed by `build_city_ie_monolith_v06.py`, and bound to its exact source and
tool hashes by `masters/sable_row.superres.json`. The shared street plan emits
the separate 320×320 search/light/height sidecars. Five landmark interiors
remain separate area records, so every return door still remembers the exact
exterior approach it came from. The earlier
`build_city_ie_80x60_pages_v01.py` extension-page path remains the authority for
wards not yet migrated to a full V6 monolith.

The paged runtime plate is the sole environmental painting. District area
records contain zero general props, so the retired large modular façades cannot
be drawn again over it. Interactive records—doors, regions, obstacles, ambients
and entrances—remain independent of the painting.

## Painted scale and acceptance gates

Infinity Engine actors, doors and scenery meet in the same rendered coordinate
system, so a plausible façade is not enough: its entrance has to agree with the
shipped actor. RainShadow uses the 70.3125-world-unit standing Voss sprite as the
adult witness. Exterior painted openings target 80.5 world units (1.145× adult)
and must stay within 1.05–1.35×. Ordinary V3 frontage bodies are 2.40–3.84×
adult; named landmarks are 3.66–6.81×. The review crop shows the actual shipped
sprite beside the opening and a yellow 1.15× target line.

Density is measured on source content, not inferred from the final canvas.
Ordinary frontage masters deliver 3.13 source px/world-unit, landmarks deliver
2.00, and the 256×384 separate door leaves deliver at least 3.48. Merely
upscaling a low-resolution whole-area painting to an 8K plate does not satisfy
this contract.

`qa_plate_density.py` reports stored and source density separately. Paged
plates take source density from `artMetrics.minimumTrueSourcePixelsPerWorldUnit`
or from the pre-enlargement `sourceSize` in a bound super-resolution provenance
file; standalone plates are bound in `qa_plate_density_sources.json`. Missing
or stale provenance fails the gate. Its play-scale diagnostic reads the current
native body height and world display contract from Swift (64 rows / 70.3125
world units at 100%; window resizing does not change pixel density),
and the opening exterior is also measured at its 1.08, 0.82 and 0.68 cutscene
camera multipliers. This prevents a Lanczos or neural enlargement from passing
by increasing only the delivered canvas dimensions.

Native-detail composites may bind a provenance JSON which declares
`minimumTrueSourcePixelsPerWorldUnit` independently of both a low-resolution
composition guide and the final runtime canvas. Every local source window must
be bound by path, dimensions, SHA-256, its retained `sourceRect` in native
pixels, and the `worldRect` those pixels cover. QA verifies the exact files,
derives density from each crop-to-world mapping, checks full-world coverage,
and rejects a declared density higher than the weakest retained source. A float
claim without those bound crops cannot pass. Runtime page dimensions are also
checked against the actual encoded files, not just their JSON declarations.
Opening layers additionally
declare the camera phases they cover, so a close arrival crop is graded at the
0.68 arrival scale without pretending it repairs the underlying wide shot.

Approved measurements in `DoorScale/apertures.json` are bound to the SHA-256 of
the exact installed plate or page manifest. Any repaint or re-encode therefore
invalidates the approval until the new crop is inspected. Sable V15's Voss
opening is measured from the encoded 25-page runtime image at `(2600, 325)`:
211 px / 84.4 world units, or 1.20× the standing adult.
