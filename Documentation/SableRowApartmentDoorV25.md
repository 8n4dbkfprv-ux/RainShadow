# Sable Row apartment door V25

The V24 Blender district now has an interactive door-state variant at
`ArtSource/Blender/SableRowDoorV25/sable_apartment_door_v25.blend`.
The original V24 Blender source is retained. The Sable Row playtest uses the matching V25 paintings and geometry.

## Door controls

In either V24 Day or V24 Night baseline scene, frame **1** is closed and
frame **2** is open. `V25 | apartment door hinge` rotates the ten existing
door components together: stiles, rails, lower panel, glass, glazing bars
and handle. The hinge is at `(-14.64, -1.14, 0.36)` and opens 90 degrees
inward. These are two background states, not a runtime animation sequence.

The old building core filled the space directly behind the leaf. A reversible
Boolean on `V18 | street wing core` creates an entrance recess between
x `[-14.64, -13.36]`, y `[-1.16, 0.65]`, z `[0.35, 2.90]`. A dark rear
lining sits beyond the opened leaf. The old glass backing is visible only
in the closed state. The surrounding facade, frame and threshold are retained.

The initial game-camera renders showed almost no state difference: the awning
and fire escape hid the leaf. With user approval, all 35 parts of the V21
awning assembly were shortened together from approximately 1.35 m projection
to 0.405 m. Its width and roof pitch are retained; its own brackets, seams and
edges follow the same transform. The fire escape and master camera are unchanged.
`awning_adjustment.json` records the exact transform and original object matrices.
The lower leaf is now visible, although the upper doorway remains partly
obscured by the fire escape. This is retained architectural occlusion.

## Render package

The `export` directory contains native 9408×7020 closed day/night paintings
and 1024×1024 registered closed/open patches. All use the existing camera and
4288×3200 world extent, with no image enlargement. Patches cover pixel rectangle
`(640,2432)–(1664,3456)` measured from the top-left; this is aligned to 64-pixel
tiles. `apartment_door.json` records world placement, tile cells and file hashes.

`ArtSource/Processing/package_sable_apartment_door_v25.py` packages and checks
the renders produced through live Blender MCP. It does not operate Blender or
install resources. Full paintings use frame 1 with render borders disabled;
open patches use frame 2 and a cropped render border at the rectangle above.
The border fractions add 0.001 pixel before division to avoid Blender's
floating-point border truncation producing a 1023-pixel crop.

Inspection renders use a separate front camera to verify the leaf and cavity.
They are not game artwork. The four-panel comparison uses native game-camera
crops. Initial diagnostic images and incremental Blender copies remain in
the study directory for comparison.

## Runtime integration

The first click on the closed apartment door approaches and opens it, then
leaves Voss outside. A second click on the open doorway walks to the outer
doorstep `(501,1803)` and travels to the apartment. The closed leaf offers the interaction cursor. Once open, its moved leaf
retains its own interaction cursor and can be clicked to close it. The separate
entrance opening offers the travel cursor without a door highlight. Stop and replacement floor clicks cancel
pending orders. The
outer doorstep is deliberate: the deeper recess does not admit the current
actor's conservative search-map clearance. No navigation port is changed.
Returning from the apartment starts the exterior door open.

`AreaDoor.backgroundTiles` registers the 1024-square open patch in the
background, below actors. Closed tiles are baked into the matching V25 full
painting. Extended Night selects the night patch while retaining door state.
State-specific door wall polygons are selected alongside the search-cell stamp;
the existing per-pixel stencil is rebaked on a door change. The revised awning,
recess and vestibule are in the static geometry export. The closed glazed leaf
blocks movement through thirteen conservatively intersected cells but permits
sight. Open/closed door geometry is excluded from static cover.

This follows pinned GemRB `1c45c185`'s `core/Scriptable/Door.cpp`:
`ToggleTiles` assigns `overlay->tiles[tile].tileIndex = (ieByte) state;` and
`DoorTrigger::SetState` selects walls using `wp->SetDisabled(!isOpen)` for open
walls and `wp->SetDisabled(isOpen)` for closed walls, then calls
`map->ResetStencilViewport()`. RainShadow reuses its existing search-map and
stencil ports; the scene adapter sequences the door action and travel region.

Reproduce with the live-Blender geometry export in `game_export`, then:

1. `export_sable_blender_area_v24.py --study ArtSource/Blender/SableRowDoorV25/game_export`
2. `stage_sable_apartment_door_v25.py`
3. Run `SableBlenderAreaValidationTests` with `RAINSHADOW_SABLE_STAGE` pointing
   at this variant's `game_export/staged` directory.
4. `install_sable_apartment_door_v25.py` (checks route/stencil reports and both
   projection grades before packaging native pages and open patches).
5. Build the macOS Debug app and run `SableDoorTravelQA` with
   `RAINSHADOW_START_SCENE=sable_blender` and `RAINSHADOW_QA_DOOR_TRAVEL` set to
   the review output directory.

The V24 installer retains its old default; use the V25 installer to preserve
this door. `Play Sable Row.command` builds and launches the installed variant.

## Verification

Both native master PNGs pass `qa_plate_projection.py`: worst ground-axis error
0.19° day and 0.21° night, against the unchanged 1.5° limit. Packaging verifies
9408×7020 masters, 1024×1024 patches and writes their SHA-256 hashes. The visible
door change exceeds 25 channel levels on 278 day pixels and 293 night pixels;
before shortening the awning, neither lighting state had any such pixels.
The original ten component matrices return to their closed values within
1e-5; `geometry_validation.json` records the measured error and unchanged camera.
Full/cropped closed daylight registration was also compared: mean maximum-channel
difference 0.758 levels, with no pixels differing by more than 25 levels.
Front closed/open inspection renders and the final native comparison were
visually reviewed. The source was reopened after Blender closed, the recorded
awning transforms were restored, and the completed V25 file was saved again.

Runtime verification (2026-09-11): all seven staged area tests pass, including
552 ordered route pairs and the three-step doorstep walk from the approach.
The rebuilt macOS Debug app passes all 31 real-scene checks: mouse/touch,
opening before travel, background registration, day/night switching, selected
cover, door-cell restoration, cancellation before/after opening, interior
arrival, return with the door open, and same-cell threshold re-entry.
`game_export/reviews/door_travel/report.json` records the checks and adjacent
PNGs capture the native renderer. Day/night open captures were visually checked.
The 48 existing catalog, door-registration, round-trip and stencil tests pass.
Both bundled open patches and page manifests hash-match the installed sources.

Two-click interaction verification (2026-09-11): the macOS Debug build passes
all 34 real-scene checks in `game_export/reviews/door_two_click/report.json`.
Opening leaves Voss stationary outside with no pending travel; the open doorway
accepts a separate entry click. Closed/open cursors, cancellation, reopening,
day/night artwork, return and threshold re-entry are covered.

## Separate open leaf and entrance targets

The open ARE outline is the convex hull of the ten door components' evaluated
projected `openFaces` in `game_export/door_geometry.json`. The stationary travel
region remains unchanged. `stage_sable_apartment_door_v25.py` emits this outline
and records separate interior hit witnesses in `door_hit_witnesses.json`.
`CityHighlightOutlines` supplies both rings to the existing stateful highlight
renderer. Scene hit-testing uses the same active ring and gives the door leaf
priority over travel, as GemRB `Door::HitTest` / `GameControl::UpdateCursor` do.
Clicking the open leaf approaches and closes it; clicking the clear opening
enters. Merely hovering the opening no longer paints the closed-door outline.
No highlight resolver, navigation or rendering port algorithms were changed.

Verification: 39 real-scene checks passed (`game_export/reviews/door_leaf/report.json`),
including separate leaf/opening hover, touch-to-close, no accidental travel on
close, and correct initial open outline after returning. The native open-leaf
highlight capture was visually reviewed. All 13 door-registration and Sable
travel regression tests passed, including the new distinct-target test; the
macOS Debug build succeeds.
