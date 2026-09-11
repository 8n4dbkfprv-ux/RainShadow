# Sable Row V24 playable test

The Blender district is available inside the real macOS game through
`Play Sable Row.command`, or by launching a Debug build with
`RAINSHADOW_START_SCENE=sable_blender`. The launcher builds with optimization
enabled so large cross-district path searches run at production speed.

Click to walk, Shift-click to queue waypoints, use arrows/WASD to pan,
minus/equals to zoom, M for the area map, and N to switch day/night.
The separate `RainShadow.Save.SableBlenderV24` key holds playtest exploration.
Normal launches and the story ward retain their existing area and save.

## Content and authoring

- Authority: `ArtSource/Blender/SableRowDistrictV24/sable_row_district_v24.blend`.
- Live evaluated geometry export: `SableRowDistrictV24/game_export/scene_geometry.json`.
- Native day/night renders: 9408×7020 over 4288×3200 world units, approximately
  2.194 source pixels per world unit. Runtime pages are 2048-pixel crops, with
  smaller edge pages; gameplay art is never upscaled. The area-map thumbnail
  is a separate reduced image.
- The exported 1.8 m adult projects to 69.857 world units, within 1% of Voss's
  70.3125. Character scale and the camera/navigation projection are unchanged.
- Terrain: 268×267 cells at the engine's 16×12 spacing. The last row is partial
  because the authored world height is 3200; it is sealed at the image edge.
- Buildings use ground footprints, not projected roof silhouettes. Their
  impassable interiors carry continuous sidewall terrain (10), so the visible
  facade can clear fog before sight stops beyond the mass. The apartment door
  has a travel region mapped to a clear exterior approach, leading to Voss’s
  existing office suite through its `from.city` entrance.
- Visible low physical meshes, fences, cars, trees, crates and the corrected
  rubbish bin contribute collision. Raised fire escapes and awnings contribute
  cover without blocking the ground beneath them.
- Cover comes from projected evaluated faces, preserving gaps in the fire
  escapes. The exporter simplifies by 0.25 world units and triangulates holes
  for the existing polygon/stencil format. No navigation, tint, viewport or
  stencil algorithm is changed.

Voss’s apartment is connected to the existing office suite for this playtest.
Other interiors and adjacent wards remain unconnected: their old coordinates
do not match this street plan. N compares the
two paintings with the existing day/night actor grades; a spatial character
lightmap has not yet been authored for this district. This is a movement,
scale, camera, fog and cover playtest, not a completed story-area replacement.

## Rebuilding

Export evaluated geometry through the live Blender MCP connection and render
the V24 Day and Noir scenes at 100%, 32 Cycles samples. Preserve the camera and
record world coordinates using `world_to_camera_view` over the world size above.
`object_inventory.json` records the inspected meshes and bounds. Retired hidden
objects and Boolean cutters are excluded. The old `west_street` test point
(-22,-7 m) was outside the expanded camera; the current point is (-18,-7 m).

Then run:

```sh
/tmp/rainshadow-area-v02/bin/python ArtSource/Processing/export_sable_blender_area_v24.py
RAINSHADOW_SABLE_STAGE="$PWD/ArtSource/Blender/SableRowDistrictV24/game_export/staged" \
  swift test -c release --scratch-path /tmp/RainShadowSableV24 \
  --filter SableBlenderAreaValidation
/tmp/rainshadow-area-v02/bin/python ArtSource/Processing/install_sable_blender_playtest_v24.py
./Play\ Sable\ Row.command
```

The Python environment needs Pillow, numpy and Shapely 2.1. Installation checks
both native plates against the projection gate, packages cropped pages, safely
replaces only the test resources, and adds macOS target membership. The Swift
suite checks all 552 directed pairs among 24 approaches, walks 25 route legs
with `Movable`, checks obstacle witnesses and measures the full district's
stencil bake. Reports and native captures are kept under `game_export`.

Validated September 8, 2026: all five Swift checks passed (4.57 seconds in the
optimized build), including 552 directed routes and 25 complete walks. The
1430×1067 stencil with 23,135 polygons baked in 0.056 seconds. Native day/night
projection errors were 0.19°/0.25°. The optimized Debug macOS build succeeded;
all 46 test resources were verified against the actual application bundle.
`game_export/reviews/game_day.png` is a capture through the game's renderer,
showing Voss, the district, HUD and exploration fog. The interactive app was
then launched without capture mode and left running. CUA was unavailable, so
mouse/key interactions were not separately automated; movement was exercised
by the runtime suite above.

## Apartment fog correction

The first export surrounded each building with a thin index-10 wall rim and
filled its core with index 13. That core was derived from the ground footprint;
it was not an authored roof-pixel region. This made the sight ray leave the wall
run almost immediately, hiding the door's upper glass behind opaque fog.
Movement itself never consulted fog; clicking the painted door instead hit an
impassable building coordinate because no entrance region existed.

Audited against GemRB commit `1c45c1850d9b5d61a23b3a569499ef57543e2c3f`,
`gemrb/core/Map.cpp`, `ExploreMapChunk` lines 3058–3062:

```cpp
} else if (bool(type & PathMapFlags::SIDEWALL)) {
    sidewall = true;
} else if (sidewall) {
    block = true;
```

The existing Swift sight port already matches this branch. The fix changes
the exported area, not `SearchMapVisibility`, the fog shader or pathfinding:
14,272 cells change from roof (13) to wall (10). The walkable/blocked raster is
identical before and after. Rays reveal the continuous wall run, then stop at
its far boundary. Distant streets remain unexplored.

The projected V22 door geometry now supplies `sable.apartment.entrance`, an
ARE-style info polygon with approach `(489,1794)`, corresponding to model
`(-14,-1.9 m)`. Clicking the door's elevated pixels selects that ground approach.
`GameControl::UpdateCursor` also gives objects precedence over terrain, so the
city scene now feeds its existing info-region lookup into the existing cursor
resolver. No change to the resolver or movement rules is required.

The regression checks the real glazing point `(519,1899)` from both the old
approach and the new one, its click-region mapping, the return route and the
unchanged impassability of the wall. The original raster fails this check.
The named `apartment_approach` entrance allows a repeatable actual-game capture
with `RAINSHADOW_START_ENTRANCE=apartment_approach`.

Verification: the new doorway test failed against the original export and
passed after the correction. All 58 selected fog/navigation tests passed,
including 552 directed district routes and 25 complete runtime walks. The
optimized macOS build succeeded. `game_export/reviews/fog_fix/game_after.png`
shows the entrance and lower facade revealed in the actual game, with Voss
standing on the authored approach. The playtest was reopened there.

Sources: [GemRB Map.cpp](https://github.com/gemrb/gemrb/blob/1c45c1850d9b5d61a23b3a569499ef57543e2c3f/gemrb/core/Map.cpp#L3029),
[GameControl.cpp](https://github.com/gemrb/gemrb/blob/1c45c1850d9b5d61a23b3a569499ef57543e2c3f/gemrb/core/GUI/GameControl.cpp#L1384),
[IESDP search-map reference](https://gibberlings3.github.io/iesdp/appendices/search.html).

## Apartment entry and return

Clicking the apartment’s painted doorway highlights its authored polygon and
offers the existing travel cursor. Touch uses the same region, briefly
highlights it, and the movement reticle marks its ground approach. Voss walks
within the existing engine operating distance before the office loads; there
is no confirmation dialog. This is an entrance/travel hotspot, without a
separately animated exterior door leaf.

The exterior record now names `office_suite` / `from.city`. In this Debug
playtest only, `SableBlenderPlaytest.office(from:)` copies the office record and
changes its exit to `sable_court` / `apartment_approach`. The story catalog and
normal save are unchanged. Playtest startup marks the office intro completed
in its own save so entry starts in free play and the exit can be tested.

The router now recognises the test district on return as well as initial
launch. The existing `MovementOrderQueue`, `PathFinder`, `Movable`, sight and
cover algorithms are unchanged. `CityHighlightOutlines` supplies ARE polygon
highlights for scenes that do not use the old ward portal catalog.

Engine basis: GemRB `GameControl::PerformSelectedAction` issues `UseExit` for
a travel region; `InfoPoint::Entered` checks arrival before travel. Physical
doors use `GameScript::ToggleDoor`, which calls `MoveNearerTo` until within
`MAX_OPERATING_DISTANCE`. That distinction is why this baked exterior uses a
travel region rather than pretending to have an animated door.

For a repeatable real-scene regression, launch the Debug macOS app with
`RAINSHADOW_START_SCENE=sable_blender` and `RAINSHADOW_QA_DOOR_TRAVEL` set to an
output directory. The harness uses a temporary save, dispatches mouse/touch
events through the actual scene handlers, exercises replacement and stop,
walks inside and back, and writes `report.json` plus native renderer captures.
The report’s `passed` field must be true.

The scene regression also found a stale callback in the actor-to-scene bridge:
`MovementOrderQueue` discarded a refused/same-cell route, but
`DetectiveActorNode.issueOrder` retained its old movement completion. The next
idle tick could run the old entrance callback. These outcomes now call
`cancelMovement()`, clearing that callback and the walking presentation.
The underlying search/movement algorithms are unchanged. Upstream evidence,
GemRB `Actor.cpp` at the pinned commit, lines 3781–3788:

```cpp
void Actor::CommandActor(Action* action, bool clearPath)
{
    ClearActions(); // stop what you were doing
    if (clearPath) {
        ClearPath(true);
    }
    AddAction(action); // now do this new thing
```

Named `from.city` office arrivals now start Voss standing; the opening’s default
seated start is preserved. The visual review caught the previous seated pose
being reused at the entrance despite the correct arrival coordinate.

Verification (September 8, 2026): 36 targeted Swift tests pass, including the
552 district routes, and the optimized Debug macOS build succeeds. All 16
real-scene checks pass: mouse cursor/highlight, touch flash, walk before
transition, rejected replacement/Stop/new floor cancellation, named arrival,
standing free play, return to the new pavement and immediate re-entry. Native
captures and the passing report are in `game_export/reviews/door_travel/`.
The application bundle’s exterior JSON matches the installed file byte for
byte. Touch events are exercised through the shared handlers in the macOS
harness; no physical iPad test was performed.
