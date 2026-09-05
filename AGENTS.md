# AGENTS

## Cursor Cloud specific instructions

RainShadow is an Apple-only Swift/SpriteKit game (iOS/iPadOS + macOS). The cloud
agent VM is **Linux**, which is fundamentally mismatched with this codebase for
building or running the app. Read this before assuming a task can be verified here.

### What cannot run on the Linux cloud VM
- The iOS/macOS app targets (`xcodebuild` + SpriteKit) require **macOS + Xcode**.
- The SwiftPM package `RainShadowCore` and the `RainShadowCoreTests` suite import
  `CoreGraphics`/`CoreText`/`ImageIO`, which do **not** exist on Linux. `swift build`
  compiles `RainShadowPersistence` (Foundation-only) but fails `RainShadowCore` with
  `no such module 'CoreGraphics'`. So the game logic and its tests can only be built
  and run on macOS. Do not attempt to add a Swift toolchain to the startup path — it
  cannot build this repo on Linux and just slows startup.
- Canonical build/test commands (macOS only) live in `README.md` under "Verification".
  There is no linter configured (no SwiftLint/SwiftFormat, no CI workflows).

### What can run on the Linux cloud VM
- The Python art pipeline under `ArtSource/Processing/` (Pillow + numpy) generates and
  composes the game's isometric art assets. This is the only end-to-end-runnable,
  repo-relevant workflow on Linux. Example:
  `python3 ArtSource/Processing/generate_office_suite_architecture_graybox.py`.
- These scripts use **absolute repo paths** and write outputs into both
  `ArtSource/Generated/...` (tracked) and `RainShadow Shared/Resources/Art/...`
  (untracked build assets). Running one mutates those files, so `git checkout`/
  `git clean` afterward if you are not intentionally committing regenerated binaries.
- `numpy` is preinstalled globally; `Pillow` is installed into the user site by the
  update script. Most `ArtSource/Processing/*.py` scripts need both.

## The navigation stack is a port, not a design — do not "improve" it

`RainShadow Shared/Gameplay/Navigation/` is a transliteration of GemRB `master`
at `1c45c185`. `PathFinder.swift`, `Movable.swift`, `Path.swift`,
`Orientation.swift`, `Geometry.swift`, `SearchMap.swift`, `SearchMapTerrain.swift`,
`SearchMapVisibility.swift`, `ActorOccupancy.swift`, `GroundCircle.swift` and
`IEColorCycle.swift` mirror named engine functions, and the comments say which.
(`GroundCircle.swift` is the ground-circle port — `Selectable::DrawCircle`,
`Actor::SetCircleSize`, `Actor::ShouldDrawCircle` — drawn by
`Gameplay/Actors/GroundCircleNode.swift`. Its `circleSize` of 2 is avatars.2da's
`CIRCLESIZE`, deliberately *not* `personal_space`; the two are different fields.)
`Documentation/ThirdPartyNotices.md` has the file-by-file map.

**The bar for changing behaviour in these files is a diff against GemRB, quoted.**
Not a plausible-sounding improvement, not a test that would be easier to write
the other way. Several things in here look like bugs and are not:

- `blockedInLineTile` steps diagonally a whole cell at a time and **skips the
  cells either side**. That is `GetBlockedInLineTile`, and line of sight is
  allowed to be coarse. Routing is not — `isWalkableTo` uses the navmap-space
  `blockedInLine` for exactly this reason. Do not "fix" the tile walk; do not
  point `isWalkableTo` back at it.
- `isVisibleLOS` tests `SIDEWALL` **only**, and walks the line to the end
  (`stopOnImpassable: false`). Adding `NO_SEE` back is not a tightening — it is
  not the engine's table, and index 0 already blocks sight by being solid.
- `adjustPositionNavmap` asks for a passable *cell*, not for clearance
  (`size = -1`). It is `BumpAway`'s helper. Asking for clearance flings a shoved
  actor across the room instead of a step aside.
- `calculateLinePath` reflects the facing once per wall **cell**, so a thick wall
  flips it back and forth. That is `GL_REBOUND` as written upstream, TODO and all.
- `Movable.doStep` assigns `step.orient` outright and never derives facing from
  velocity. There is no hysteresis band and there should not be one.
- Positions are integral because `normalizeDeltas` ceils each axis. Arrival is an
  exact `position == node.point` test and only works because of it. Do not
  introduce float positions or a tolerance.

Four things are deliberately **not** ported, and each has a reason recorded in
`Documentation/PathfindingSystem.md` under "Deliberately not ported": the async
`PathFinderScheduler`, `Actor::WalkTo`'s `ResetPathTries` (upstream can never
reach `MAX_PATH_TRIES`), `BumpBack`'s `IE_EA` gate, and `RandomWalk`'s
action-queue branches. Adding one of those back is a design decision, not
housekeeping.

Open questions the port left behind — including one licensing decision — are in
`Documentation/NavigationOpenQuestions.md`. Read it before deciding you have
found something new.

## The render path is a port too

`IEBlit.swift`, `IEBlitShader.swift` and the per-actor tint in
`DetectiveActorNode.applyBodyTint` / `ClientActorNode.applyBodyTint` are a
transliteration of GemRB's `core/Video/Pixels.h`, `core/Sprite2D.h`
(`enum BlitFlags`), `Game::ApplyGlobalTint` and `Map::DrawMap`'s per-actor tint.
**The same bar applies: a diff against GemRB, quoted.**
`Documentation/ThirdPartyNotices.md` has the file-by-file map.

Three things in here look wrong and are not:

- **Tinting by white is not identity.** `(255 * 255) >> 8` is 254, so
  `ShaderTint` darkens by one step per channel at full white. Upstream lives
  with it by gating the tint behind `COLOR_MOD` instead of ever passing white,
  and `ActorSceneLighting.globalTint` returns `nil` rather than white for the
  same reason. Rounding this to 255 disagrees with the engine on every
  flagged-but-untinted sprite.
- **Greyscale peaks at 189, not 255**, and is an unweighted average rather than
  Rec. 709 luma. The engine's grey is deliberately darker than a desaturate. A
  `CIFilter` saturation of zero is *not* a substitute and swapping one in is the
  obvious-looking change that silently stops matching.
- **The tint is a multiply, not a blend.** `colorBlendFactor` interpolates
  *toward* a colour, which brightens a dark pixel; `ShaderTint` can only darken.
  The `0.45 + 0.55 * footLight` curve this replaced was invented. Do not
  reintroduce a blend weight to recover the old, brighter image — re-tune
  `ActorSceneLighting`'s authored grade instead, and say so.

**Actor cover is a per-pixel stencil, not an alpha.** `AreaWallStencil` bakes
`Map::DrawStencil`'s four channels and `IEBlitShader`'s `STENCIL_DITHER` path
reads them per fragment, so only the pixels a wall actually overlaps are
dithered. `ActorCover` is now just the depth lift — that half was always right,
because upstream also draws the actor after the background and lets the stencil
put the wall back in front. Do not reintroduce a whole-sprite alpha.

Three things in the stencil that bite:

- **The mask is row-major y-up from the world's minimum corner**, like
  `AreaSearchMapLoader` and `AreaLightMap`. `CGBitmapContext` is not — it stores
  row 0 as the top — so `AreaWallStencil.rasterise` flips once. A flipped mask
  applies cover to the mirror image of the scenery and looks plausible in a
  symmetric room.
- **Blit shaders are per *layer*, not per actor.** The stencil lookup is composed
  from each sprite's own world rect, and an actor's layers differ in size and
  anchor. Sharing one instance points every layer at whichever wrote last.
- **Every uniform the program declares must be bound, samplers included.** Leave
  one unbound and SpriteKit falls back to default shading for the whole shader,
  which reads as "the tint stopped working" rather than as an error.
  `IEBlitShader.blankStencil` exists for exactly this.

**The stencil bake is per area and must stay cheap.** It rasterises each polygon
into its own bounding box, and `maximumMaskDimension` caps the mask at 2048 cells
on its longest edge. Both exist because the first version did neither: a full
world-sized buffer per polygon at one unit per cell took **119 s** on a ward and
produced a 78 MB texture, which shipped and hung area transitions.
`AreaWallStencilTests.aWardBakesSmallAndFast` guards it. Do not raise the cap or
go back to full-area passes without measuring a ward.

Note the office and a ward are not comparable: the office is 1617x910 with three
covering walls, a ward is 5120x3840 with 86. **Timing the office proves nothing.**

`RAINSHADOW_DEBUG_STENCIL=1` draws the baked mask over the area — the stencil has
no other in-app failure signal, since a mask that is offset or flipped still
renders, just onto the wrong pixels.

**The light maps are engine-space multipliers now, not a colour to mix in.**
`LM.BMP` multiplies: `c.r = (tint.r * c.r) >> 8`. A cell value of 0.12 means "12%
of the sprite survives here", which is a black silhouette — not "a dark blue
cast". `bake_area_lightmap.to_engine_space` is what puts the authored lighting in
that space, and `build_city_building_interior_v01.py` imports it rather than
defining its own. Do not re-author a map into the old 0.03–0.35 range, and do not
reintroduce a remap curve in the runtime to compensate for one: the previous
`0.45 + 0.55 * sample` curve existed for exactly that reason and it is why the
maps drifted out of engine space unnoticed.

**The GLSL is a second transliteration and `swift test` cannot reach it.**
`ArtSource/Processing/qa_ie_blit_shader.swift` renders through SpriteKit and
compares against the integer port; run it after touching either copy:

```sh
swift ArtSource/Processing/qa_ie_blit_shader.swift
```

`ActorSceneLighting.globalTint` is the one deliberate adaptation: upstream has no
blend weight because its global tint *is* a multiplier, and `bodyBlend` is folded
into the tint to keep the authored knob. That is recorded in the source.

## The viewport is a port too, and its asymmetry is upstream's

`RainShadow Shared/Gameplay/Navigation/CameraZoom.swift` (the zoom ladder) and
`AreaViewport.swift` (the clamp) are transliterations of GemRB's `GameControl` —
`zoomLevel` / `GetScalePercent` / `SetScalePercent` / `OnMouseWheelScroll`, and
`MoveViewportTo`'s clamp block. `Documentation/ThirdPartyNotices.md` has the
map. **The same bar applies: a diff against GemRB, quoted.**

`AreaViewport.clampedCenter` is the *only* place a camera position is bounded.
`BaseGameScene.clampedCameraPosition` supplies the live scale and nothing else.

Three things in it look wrong and are not:

- **The axes are not symmetric.** x overflows by 64 on both sides; y pads one
  side only. GemRB's `p.y < 0` pins the engine's map top flush with no give,
  while the far edge gets `+ padding`. Engine y is *down*, so engine-top is
  world `maxY`: here the viewport may drop 50 units below `minY` and may not
  rise one unit above `maxY`. Squaring the axes up is the obvious-looking change
  and disagrees with the engine on every area edge.
- **The over-large centring is not a centre.** `(mapsize.h - viewport.h) / 2 + padding`
  lands on `map.midY - 50`. Upstream biases it to keep the map clear of the
  message window; RainShadow has no message window, so `mwinh` is 0, but the
  `padding` is ported and kept. It moved the office's shipped default framing 50
  units when it landed — that was measured, decided, and is not a bug to correct.
- **The office clamps to the painted room, not the plate.** An Infinity Engine
  area is WED-covered edge to edge, so map size and painted extent are one thing
  upstream. The office plate is a 4096x2304 canvas with the painting inset and
  black baked around it, and `OfficeInteriorScale.paintedRoomBounds` is the half
  that means "the area". Pointing the clamp at `worldBounds` hands the camera the
  baked margin.

**There is no per-plate zoom ceiling and there must not be one again.** A
`CameraZoom.fitStep` used to narrow the band to what the plate could cover, so
the ceiling fell out of plate size and window aspect: the office could not zoom
out at all at 16:9 and started *below* 100% at 21:9, while a ward had the full
band. Black past the area edge is IE framing, not a defect, and refusing it is
what produced the indoor/outdoor split.

## The search map is the only clearance authority

`SearchMap` rasterises authored obstacles **conservatively**: a cell is solid
when a rectangle overlaps its footprint at all, not when it covers the cell
centre. Nothing tests world-space geometry on top of that any more — the
navigation stack is a literal GemRB port, and the engine asks the raster and
nothing else. Two consequences bite:

- **Solids fatten by up to a cell.** A corridor has to survive that, or it is not
  a corridor. A gap narrower than 16x12 is two solids touching, which is also
  what it looks like to a person. `AreaReachabilityTests` and
  `CityWorldExtentTests` catch one that does not; the fix is authoring, never
  re-adding a finer test downstream.
- **`bake_area_searchmap.py` does not own the city rasters.** The six
  `city_*.sr.png` files carry roof and world-map-exit terrain that baker cannot
  produce, and it does not reproduce them — running it on a city area silently
  flattens that terrain and breaks fog and sight. It owns `office_suite` and the
  interiors. Authored rectangles reach a painted raster at load instead, through
  `SearchMap`'s terrain initialiser, which unions them in without touching
  terrain a rectangle cannot express.

**Do not re-add a world-space geometry test.** `SearchMap.segmentCrossesObstacle`
and `discOverlapsObstacle` still exist for authoring and QA, and they are the
obvious thing to reach for the next time an actor clips something. Reaching for
them is the mistake: it puts clearance back in two places that can disagree, and
it hides the real fault, which is either a rectangle that needs authoring or a
line query pointed at the wrong space. `PathFinder` must not call either of them.

The tests that hold this down, and what each is really asserting:

| Test | Holds |
|---|---|
| `MovementIntegrationTests.theDetectiveWalksToEveryOfficeApproachWithoutClippingAnObstacle` | conservative rasterisation genuinely *replaced* the conjunct rather than the conjunct just being deleted |
| `LiteralPortTests.aDiagonalCannotSlipBetweenTwoCornerTouchingSolids` | `isWalkableTo` is on the navmap-space walk |
| `LiteralPortTests.aSolidThinnerThanACellStillClosesIt` | a sub-cell solid is in the raster at all |
| `LiteralPortTests.aSolidEndingOnACellBoundaryDoesNotClaimTheNextCell` | edge contact is not overlap, so walls do not eat a free column |
| `ActorFootprintTests.officeReachabilityIsWhatTheRasterSays` / `cityReachabilityIsWhatTheRasterSays` | the raster did not quietly move |
| `AreaReachabilityTests`, `CityWorldExtentTests` | no shipped area sealed |

If you change rasterisation, those baselines move. Re-derive them from a
measurement and say so in the commit — do not relax an assertion to match.

## Projection lock (area art)

`ArtSource/Processing/ie_projection.py` defines two cameras and selects one:
`BGEE` (the target — elevation asin(0.75), ground axes ±0.75, diamond 128×96,
16:12 ground ellipse) and `LEGACY_V2` (what the installed plates are). See
`Documentation/InfinityEngineGroundProjection.md`.

### The projection lives in the pixels

Do not switch the pipeline ahead of the art. Forcing the room-plan axes to
±0.75 while the painted plate is still legacy stretches the authored floor
diamond off the painting — the camera-near tip drops ~328 px on a 2304 px plate,
so camera-near props land in the black void — and the planner still prints
`ALL CHECKS PASS`, because it is self-consistent with a plate that does not
exist. `qa_ie_projection.py` now fails on exactly that mistake. Flip
`ACTIVE`, re-fit `office_room_plan`, and land the masters in one commit; the
order is in `Documentation/BGEEProjectionMasterRegen.md`.

After changing projection math, rebake and hash-diff generated outputs;
intended-inert edits must come back identical.

### Two generators do not reproduce their own committed output

Verify inertness against *the generator's output on `main`*, not against the
committed file, or you will attribute pre-existing staleness to your change.

- `office_layout_plan.py` rewrites `OfficeNavigationLayout.swift` with a
  727/784-line diff on `main` — the committed Swift predates the 0.60 suite plate.
- `generate_office_zone_props_v01.py` overwrites Image-Generator masters with
  procedural placeholders (`office_case_board.png`: 101 KB → 2 KB).
- `bake_area_lightmap.py` rewrites six city `.lm.png` and six `.ht.png` on
  `main`, and used to *invent* maps for five `interior_*` areas that have never
  shipped one — which silently opts them into lightmap tinting. It now skips an
  area with no shipped `.lm.png`. The `.ht.png` drift is untouched and still
  open. Only `office_suite` and `city_building_interior_v01` reproduce.

### Grade a plate, do not eyeball it

`qa_plate_projection.py` measures the ground axes actually baked into a plate,
so "matches the camera" is a number. Every new or regenerated area master must
pass it before install. Its 4.0° tolerance is **too loose to hold the lock** —
it was sized to separate the lock from the retired 26.57° camera. At 4° off,
a ground line drifts ~197 px across the office, a full adult's height, and the
runtime cannot absorb it because `verticalProjectionScale`, the 16×12 search map
and the 16:12 rings are all hard-locked at 0.75. Both office masters have landed
at 3.8°. `--shipped` now derives the city plate list from the area records'
`plateTextureName` / `nightPlateTextureName` rather than assuming
`city_<slug>_block_v02`, so a ward that changes plates cannot fall out of the
gate; `qa_plate_density.py` reads the same names. All ten shipped plates
currently pass `qa_plate_projection.py --shipped`
at ≤1.5° (worst 1.02° on the Sable Row day plate, whose warm grade softens the
kerb lines the estimator reads). All 72 surveyed
city lots are unique Image Generator paintings gated on their *seated*
content, harmonized to one anchor exposure and feather-seated into a shared
night-key street — status in `Documentation/BGEEProjectionMasterRegen.md`.

Calibrate before trusting it: a plain 3×3 Sobel aliases on hard lines and read a
true 36.87° grid as 45°. The shipped estimator uses a smoothed structure tensor
and is accurate to 0.13° on a synthetic lattice.

### The installers emit a measurement that nobody copies

`install_office_bgee_v05.py` measured the plate, wrote `REAR` / `AXIS_*` /
`WALL_FACE_H` into `ArtSource/Generated/Office/bgee_v05_metrics.json`, and left
a note saying to copy them into `office_room_plan.py`. That never happened, so
the shipped floor diamond has never been fitted to the art. V7 then re-emitted
the *room plan's* values as its own metrics, which makes the file read like
corroboration when it is an echo. Diff the metrics against `office_room_plan.py`
before trusting either — and note `fit_diamond` itself snaps the unit square to
the **clipped** paint edge and clamps `REAR` onto the wall crown, so the numbers
need re-deriving, not just copying. Details in
`Documentation/BGEEProjectionMasterRegen.md`.

The door aperture is also stored twice: `office_layout_plan.
SHIPPING_EXTERIOR_OPENING_SIZE` is independent of
`office_room_plan.BAKED_DOORWAY_*`, and the emitted Swift follows the
layout-plan copy.

### `--write` refuses silently if you redirect it

`office_layout_plan.py --write` prints `refusing to write: navigation checks
failed` and exits **0** when its checks fail. Pipe it to `/dev/null` and you
will spend the next hour measuring a stale `OfficeNavigationLayout.swift` and
attributing the result to whatever you just changed. Always read its tail, and
confirm the Swift actually moved before testing.

### The planner's validation grid is a 31×31 window, not the room

`Grid.walkable` bounds-checks `0 <= c < columns`, and `cell_point` anchors the
window so the painted room happens to sit in the `c >= 0, r >= 0` quadrant. Grow
the floor diamond and the west/near corners go to `c = -1, r = -1`, where every
cell reads unwalkable and the planner reports **0% open floor** — which looks
exactly like sealed geometry and is not. Offsetting the index origin is safe:
this grid is an offline mirror, and the emitted `authoredProjectionOrigin` /
`authoredTileSize` are `private` and unreferenced in Swift.

### Every plate gate is blind to composition

`qa_plate_projection.py`, `qa_plate_density.py` and `qa_area_door_scale.py` all
measure a **local** property — camera angle, art px per world unit, door height
against the actor. A perfectly tessellated wallpaper passes all three, and one
did: Sable Row shipped 12 lot masters stamped 85 times onto the `CityBlockGrid`
diamond lattice with every gate green.

`qa_plate_composition.py` measures the other axis, calibrated against real BG
areas decoded from a local BG:EE install (`extract_ie_reference.py`, `--baseline`
reproduces the numbers):

| | duplicate patches | lattice score |
|---|---|---|
| Baldur's Gate `AR0100`–`AR0800` | 0.0–2.1% | 0.28–0.53 |
| RainShadow wards (pre V5 layout) | **6–52%** | **0.88–0.99** |
| RainShadow after IE street plan | **0.0%** (unique-once) | **0.45–0.46** |

The lattice score is killed by `city_ie_street_plan.py` — irregular UV masses
off the 840/630 period, shared search maps, `CityStreetPlan.swift` obstacles.
Duplicate fraction with twelve unique-once lot masters is measured per rebuild;
if it still fails, the masters are a self-similar family and new V5 street-block
paintings are required (`city_ie_composition_v05.md`, first piece
`city_sable_row_block_v05.md`).

**Pad-tone art debt.** Mass interiors without a seated V5 piece are a flat
per-mass pad tone, not architecture. The wards look worse until those pieces
land. **Do not graybox-fill the pads** (`draw_blocks` / procedural placeholders
have burned this repo before). Minimum unique V5 pieces to fill a ward:
`ceil(frontage_wu / 650) + corners` ≈ **57** (see
`ArtSource/Generated/CityDistrict/V2/IECompositionV05/piece_seats.json`).
Seating contract is documented in `city_ie_composition_v05.md` — design only;
do not build a seater against art that does not exist.

Do not loosen composition thresholds. Do not wire the composition gate into a
build step expecting green until the V5 pieces are seated.

### A plate can be on the lock and still be too coarse

`qa_plate_projection.py` only answers "is this on the camera?". It cannot see a
plate painted at a lower resolution than the sprites standing on it.
`qa_plate_density.py` measures the other axis — **art pixels per world unit**,
fixed at install because a plate is drawn to a fixed world size:

| | px/unit | vs the actor | magnified at play zoom |
|---|---|---|---|
| Voss (512 px canvas over 180 units) | 2.84 | — | 1.28x |
| office suite plate | 2.53 | 0.89x | 1.43x |
| every `city_*_ground_v02` (V4) | **2.00** | 0.70x | 1.82x |

The V3 1536×1024 candidates were on the camera but too coarse: installers
used to upscale them to `PLATE_SIZE` (2048×1152) = 1.00 px/unit, true source
0.75, and play zoom magnified the real detail 4.2×. Streets read as oversized
stonework while every sprite on them was native.

`PLATE_SIZE` is now **(4096, 2304)**. Raising it alone would pass
`qa_plate_density.py` by adding empty pixels — the tool counts width, not
stonework. The generator caps at 1536, so V4 keeps the V3 macro (kerbs,
lighting, puddles) and paints a 16 px sett / 56 px flag overlay on the BG:EE
axes (`composite_city_ground_density_v04.py`, option 1 in
`city_ground_density_v04.md`). Install with
`install_city_grounds_density_v04.py`. The runtime needs no change:
`CityDistrictScene` draws the texture at `worldArtSize`.

A re-run of `install_city_districts_bgee_v03.py` or
`install_riverside_bgee_v03.py` now routes grounds through that overlay.
Do not `fit_to_aspect` a 1536 master straight to `PLATE_SIZE`.

### Never resize a plate across aspect ratios

Scaling x and y by different factors multiplies every ground slope by `sy/sx`.
Taking a 3:2 master straight to 2048×1152 shears 36.87° to 31.74° and nothing
reports an error. Use `process_city_districts_v02.fit_to_aspect`, which
centre-crops to the target aspect first and then scales uniformly.

### The family warp is applied in pixel coordinates — pair the families right

`generate_city_ward_rebuild_v01._warp_linear` applies the affine in *pixel*
space (y down), while the grader reports peaks y-up. `peak_neg` is therefore
the pixel-space *downhill* family. The wrong pairing is invisible on symmetric
families (the shear term cancels — every office master), but on asymmetric
takes it shears the wrong way: a +51.6°/−31.7° lot "corrected" to +14.2/−12.9
and looked like the generator could never hold the lock. With the pairing
fixed, the same takes land at ≤0.2°. Regression: the synthetic-lattice test in
this file's history — a +50/−30 lattice must come back at ±36.87.

### Grade what seating keeps, not the square the generator returned

Feathered seating (`_seat_alpha`) fades out each lot master's camera-near
ground — which is the jig-derived, most on-lock content in the frame. Gating
the full square let twelve individually-passing lots stack their building
residuals into a plate-level Δ2.2° FAIL (Harborpoint). Gate `_seated_preview`
(master × seat alpha over a flat street tone) instead; that is what actually
lands on the plate.

### `shutil.copy2` writes through hard links on install

Several installed plates were hard-linked across paths (`*_block_v02.png` ==
`*_ground_v02.png` == old `ArtSource/Generated/.../V2` outputs, one inode).
`copy2` truncates and rewrites the shared inode, so installing block then
streets left *both* names holding the streets-only plate — buildings silently
erased, and the QA failure pointed at the generator, not the copy. Use
`install_copy` (unlink first); check `ls -la` link counts before trusting an
installed binary.

## Character sprite pipeline — traps that cost real time

Read this before touching anything under `ArtSource/Processing/` that produces
character atlases. Every item below is a mistake that was actually made here.

### Current Voss authority — imported replacement V14

Voss runtime now uses `install_voss_replacement_v14.py`, the unchanged V11
replacement rig plus the user's V09 material edits and V10 rear-collar correction.
`voss_masters.ACTIVE_VERSION = "replacement_v14"` selects V11's full 204-pair
master set together with `ie_avatar.VOSS_REPLACEMENT_V14`'s fitted palette rows
(same seven rows as V13). V14 keeps V13's bounded native-plane relief, then
folds only the near-black tail of the skin and hair ramps so 64-row reduction
does not leave black holes on the face. It does not change geometry, UVs,
lighting, alpha or mask topology and adds no noise. Non-skin/hair native
indices stay byte-identical to V13. See
`Documentation/ImportedVossReplacementRuntimeV14.md`.

Seat chains use one source projection scale shared with their standing endpoint,
not a forced 155px seated body. Their source-bbox displacement supplies canvas
registration. Do not restore per-pose size fitting, head-width stretching or the
old seated-height gate for this model. V12's source-derived projection and
categorical hair-cap checks replace those; V22's historical gates stay intact.
V14 retains this V12 projection contract. The office's legacy `ne` filename is
NW-handed. Exact endpoints and all-frame
rear/colour/inventory checks remain mandatory.

Stage with `python3 ArtSource/Processing/install_voss_replacement_v14.py stage`;
review the exact bundle and run staged Swift tests before
`install --confirm-runtime-replace V14`. The installer requires a hash-bound
review receipt and preserves all five atlases plus the indexed bundle together.
V12, V13 and V22 are historical, explicitly pinned rebakes; running any of
those install commands replaces the current replacement with that version.

`IEIndexedSprite.load` must derive the bundled resource name from
`manifestFileName`; a literal `avatar-v01` silently bypassed bundled v02 and
loaded checkout art. The synthetic-bundle regression guards this.

The office's painted chair / seat-anchor mismatch predates V12 and remains room
authoring work. Do not compensate by scaling this actor or changing navigation.

### The masters are a Blender rig now — V23

`ArtSource/Blender/build_voss_v23.py` builds the figure, rig and four actions as
a *script*; `ArtSource/Blender/voss_v23.blend` is its output, not the source.
Edit the script. `Documentation/VossV23BlenderRigProduction.md` is the record.


#### Blender MCP workflow — inspect, change, verify visually

When working with Blender from Codex, use the configured **Blender MCP server**
against the currently running Blender instance. Prefer MCP operations over
creating and launching one-off standalone Blender Python scripts.

Before changing anything:

1. inspect the current scene and identify the relevant objects, meshes, armature,
   materials and actions;
2. capture a viewport image of the current state;
3. confirm that the intended target is not the head, body proportions, rig or
   another protected component unless the task explicitly requires changing it.

For interactive Blender work, prefer dedicated MCP operations for:

- scene and object inspection;
- selection and transforms;
- mesh/geometry inspection and bounded edits;
- material and texture inspection/changes;
- armature/action inspection;
- viewport capture and rendering;
- saving/exporting.

Use Blender-side arbitrary Python execution only when the MCP server has no
dedicated operation for the requested change. Do not create a standalone `.py`
file merely to perform an operation that the live MCP connection can do
directly. When Python is necessary, prefer direct Blender data access
(`bpy.data`, mesh data, BMesh, object properties) over context-sensitive
`bpy.ops` where practical; operators depend on selection, active object, mode
and editor context and are therefore easier to make brittle.

For visual modelling work, make small, reviewable changes:

1. capture the current viewport;
2. make one bounded change;
3. capture the viewport again;
4. visually compare the result with the previous state and the references;
5. continue only when the change is correct.

Do not make a long sequence of geometry, proportion, material or rig changes
without intermediate visual checks. Before destructive geometry or rig edits,
save an incremental `.blend` copy.

**V23 source-of-truth rule still wins:** MCP is an interaction and validation
layer, not a replacement for the scripted authority above. If an accepted V23
change must survive regeneration, encode the final change in
`ArtSource/Blender/build_voss_v23.py`, regenerate `voss_v23.blend`, and verify
that the regenerated result matches the accepted live Blender result. Do not
leave a permanent V23 fix only in the generated `.blend` file.

For diagnosis before simplifying or rebuilding character clothing, first report
vertex/edge/face/triangle counts per relevant mesh and capture front, side and
perspective views. Modify only the named clothing component unless the task
explicitly expands scope. Preserve the head, body proportions, UVs, rig and
other meshes unless the requested task requires changing them.

Two traps in it cost real time, and both are the same shape — a measurement
reading the wrong plane:

- **A gradient row and its masters are one unit.** `ie_avatar.VOSS.colors` picks
  one 12-shade `MPALETTE` row per material, and that row *is* the material's
  whole value range. Three of V22's seven rows cannot carry correctly lit art at
  all: `armor` (237) and `leather` (160) top out at luma 84 and 82, so a
  properly lit coat clamps to the *bright* end of its ramp, and `major` (198) is
  not monotonic — its shade 11 is brighter than its shade 5. They were a faithful
  fit to art that was three shade steps too dark. Re-fit with
  `fit_voss_v23_gradients.py` whenever the masters change, and score in **CIE94,
  not Euclidean RGB**: RGB is luma-dominated and reproduced a warm brown coat
  with a khaki, which came back olive with a grey face.
- **A baked shadow is not part of the body.** `native_rows = 64` is a contract
  about the figure. The shadow runs along the ground past the feet, so solving
  the convergence on the alpha bounding box fits body *plus* shadow into 64 rows
  and shrinks the registered body — which `standing_height [198, 202]` then
  reports as a scale error. `crunch._body_rows` reads mask indices 1-7. Every
  other gate that means "the body" has to do the same.

The shadow's mask label is spelled out in three modules that cannot import each
other (`voss_rig_spec` has to load inside Blender, which ships numpy but not
Pillow). `qa_ie_shadow.py` pins them together, the way `IEResampleTests` pins the
two resamplers. Do not add a fourth copy.

`voss_masters.py` is the single declaration of which master set is active.
`install_voss_v22.py` names `VOSS_V22` and `BGEE_V1` explicitly rather than
following `ACTIVE`, so it still rebakes V22 byte for byte — keep it that way.

### V22 and the indexed Lila installer are the authorities

The old V12/V11 six-command sequence was order-dependent because the now-retired
`wardrobe_match_to_idle` regraded files already on disk. That sequence is
historical and will overwrite the accepted indexed-colour atlases with an old
RGBA path. Do not use it for current runtime art.

Gate, stage and install the two current authorities explicitly:

```bash
cd ArtSource/Processing
python3 qa_ie_palette_port.py
python3 qa_ie_avatar_encode.py
python3 install_voss_v22.py stage
python3 install_voss_v22.py install --confirm-runtime-replace V22
python3 install_lila_ie_avatar.py stage
python3 install_lila_ie_avatar.py install --confirm-runtime-replace LILA
```

`install_voss_v22.py` consumes the V22 authorities and the exact 204-mask
inventory. `install_lila_ie_avatar.py` owns all 25 current Lila cells (V11
arrival plus the approved V6 NE/NW departures) and their exact 25-mask
inventory. Each installer swaps its compatibility atlas payload and versioned
raw indexed bundle as one rollback transaction.

Never call `v11.main()`, `v12.main()`, `process_voss_desk_ne_v01.py`,
`install_voss_idle_walk_seated_match_v02.py` or the two old Lila facing-fix
scripts to repair one current clip. They are retained as history, not as
partial installers for V22/indexed runtime art.

### `* 2.py` Finder duplicates are tracked

`ArtSource/Processing/` is full of them (`install_voss_idle_walk_seated_match_v02 2.py`,
etc.). Edit only the un-suffixed file and check `git status` afterwards to confirm
no ` 2.py` was touched.

### Historical `shutil.copy2` output can carry extended attributes

The current transactional installers copy without metadata, but historical
installers used `copy2`, and existing atlas files in an iCloud-synchronised
checkout may still carry xattrs. `codesign` then rejects the test bundle for
"resource fork, Finder information, or similar detritus". Build outside the
synced tree: `swift test --scratch-path <path outside iCloud>`.

### Material masks are categorical and complete

The accepted authoring truth is 204 Voss plus 25 Lila P-mode PNGs. Palette
indices 1–7 are materials; index 0 is background only. Any editor that
anti-aliases, resamples, converts to RGB or leaves index-0 holes inside the body
has destroyed the mask. `author_material_masks.load_mask` and
`qa_ie_avatar_encode.py` reject those cases. The draft command
`author_material_masks.py --write` has no merge and overwrites accepted masks.

### The old colour locks are retired

`identity_wardrobe_lock`, `warm_brown_lock`, `seated_authority_lock`,
`wardrobe_match_to_idle`, `lock_standup_handoff` and
`crunch.PRESERVE_WARDROBE` flattened wardrobe colour by design and are gone.
The invented `ClipPalette`/`finalise` colour surface and
`qa_wardrobe_lock_preservation.py` are gone with them. Do not restore the
symbols or set `RAINSHADOW_PRESERVE_WARDROBE=1`; migrate any deliberately
revived historical generator to authored material masks and `crunch_avatar`.
The removal ledger is in `Documentation/IEColourModelCutover.md` §E.

### Keep geometry and indexed-colour gates strict

`VossSeatScaleTests.swift` holds the 512→180 scale, source-canvas pivot and
seat-chain contract. `VossWardrobeColorTests.swift` now holds the exact bundle
inventories, allowed material indices, character palettes, all-frame raw-index
→ RGBA round trip, recolour isolation and rear/seat topology. The V17 RGB table
it replaced is stale against V22's red tie and brown trousers. Never waive a
wrong pose or view — V19's ≤2.5% rear-shirt waiver against a 0.1% Swift gate
shipped an entire rear hemisphere as front views. See
`Documentation/VossV19AnimationAudit.md`.

### One sampled cell does not validate a direction

One sampled cell missed an entire wrong rear hemisphere for four versions.
`qa_ie_avatar_encode.py` now inventories all 204 Voss masks and grades every
phase of every authored Voss direction; it also requires the exact 25 Lila
masks. Keep that coverage. A representative frame is still useful for visual
review, but never as a substitute for full inventory and phase validation.

### Verify a pipeline change by rebaking and diffing, not by reading

The shipped atlas inventory is 273 deterministic PNGs. A change intended to be
inert must come back 273/273 identical. The IE colour cutover was deliberately
non-inert and its exact proof is **249 visible frames changed, 24 transparent
`VossSeatedArms` frames identical**. No other identical output was permitted.
This is also why a blanket "all 273 must change" rule is wrong.

The index plane is shipped as a versioned raw JSON/`.indices` bundle outside
the `.atlas` directories, not as a P-mode runtime PNG. The current bundles do
not author palette index 1, so `ContactShadowNode` remains the shadow authority.

### Bundle v02: the plane is native, everything else is registered texture space

`avatar-v02.{json,indices}` stores the index plane at **native craft
resolution** (64 rows). Every shipped bundle now declares
`texture_filter: linear`, and **the runtime presents natively regardless of what
a bundle declares**: it resolves the plane to RGBA at native size and SpriteKit
performs the sole enlargement, matching BG:EE's non-nearest creature mode.

Lila's bundle was the last one still asking for Near Infinity's Super xBR, and
that prefilter is gone from play (3 September 2026). It was two scaler passes per
frame, colour and silhouette, run inside `ClientActorNode.init` — measured at
**22.0 s of blocked main thread** on an area transition in a Debug build, which
is what made entering the office after skipping the intro feel broken.
`IEResample` and `IEIndexedSprite.render` remain as the offline bake reference,
still pinned byte for byte by `IEResampleTests` and by the compatibility-atlas
round trip in `VossWardrobeColorTests`; nothing on the load path reaches them.

Super xBR cannot run on indices at all in any case. There is no colour halfway
between palette entry 37 and 52, the same reason `ie_avatar.resample_mask` is
nearest-only.

So one rule governs the whole pipeline, and breaking it is silent:

> **`indices` is native. `size`, `texture_px`, `trim_origin_top_left_px` and the
> pivot are texture space. Never index one with the other.**

`IEIndexedSprite.Frame` carries both — `nativeSize` for the plane, `size` for
the render — and every measurement has to pick deliberately. Three real bugs
came from mixing them, and each looked like something else:

- Slicing the plane with a bbox taken from `cell.rgba()` gives an empty array
  (`_ensure_minimum_head_width`).
- Iterating `frame.size` while calling `frame.index(x:yFromTop:)` walks off the
  plane and traps the whole test process with no failing assertion
  (`DepartureSpriteFacing.faceSide`).
- Registration and head-width corrections read on the *render* let the filter
  decide geometry. A nearest enlargement quantises every measured head width
  onto a multiple of about three; Super xBR measures the true edge, so 15 of 54
  frames tripped a 19px minimum instead of 5, each by its own factor, and the
  intra-clip jitter failed a stillness gate the art had not moved on.

### Anything that reshapes a plane must re-render, not edit the texture

`V22Cell.mirrored` and `.split` change the native plane and then call
`_reframe`, which renders again. Flipping or cutting the finished texture
instead is wrong and the round-trip test will say so: Super xBR's three passes
read the buffer they are writing, so it is not symmetric —
`flip(render(plane)) != render(flip(plane))`. The runtime renders from the
stored plane, so the bake must too.

For the same reason the SW→SE mirror identity is asserted on the **plane**, in
`install_voss_v22._validate_indexed_stage`, not on the PNG.

### The palette budget and the mirror identity live on the plane, not the atlas

The atlas carries thousands of interpolated colours by design — filtering is not
quantising. A "≤64 colours" assertion against the PNG now measures the
enlargement. Count distinct *indices* instead; `VossAtlasV20ValidationTests`
does.
When changing the runtime loader or resources, remember that
`RainShadow.xcodeproj/project.pbxproj` has two relevant
`membershipExceptions` include lists — iOS and macOS — and both must contain
every new Swift path plus the `Resources/Art/IE/Avatars/Lila` and
`Resources/Art/IE/Avatars/Voss` directory entries.

## Navigation authoring — traps that cost real time

Read this before touching `ArtSource/Processing/office_layout_plan.py`,
`CityDistrictCatalog.swift`, or anything that authors a nav point. Every item
below is a bug that actually shipped, and each one shipped with a green suite.

### `route` used to hide broken geometry — test reachability explicitly

The old `NavigationMap.route` flood-filled to the nearest *reachable* cell and
pathed there. It therefore succeeded from inside a sealed pocket, or from inside
a building, and reported nothing wrong. Three bugs lived behind it:

- the office floor sealed to **174 of 4,694** walkable cells,
- the office door with **no exact path**, so the exit to the city was unclickable,
- Harborpoint PD spawning the detective **inside an 820×680 station**, 1 of 5,795
  cells reachable, on a district reachable from the world map.

Use `reachesExactly` and flood-fill the runtime search map. A non-empty `path`
is not proof: GemRB relocates a blocked destination before searching, so that
test can pass after landing nearby. See "Measuring reachability" in
`Documentation/PathfindingSystem.md`.

### The layout planner validates a different grid than the game runs

`office_layout_plan.py` checks its own **128×96** BG:EE iso grid (half-steps
64/48). `SearchMap` rasterises
what it emits onto **16×12 world** cells — the diamond now spans exactly 8×8
search cells, so planner and runtime share a ratio. Geometry that rounds away
in the planner can still be solid at runtime if AABB insets are wrong, and the
planner historically printed `ALL CHECKS PASS` throughout the sealed-office bug.

Two consequences, both fixed by testing a solid's **extent** rather than its centre:

- Boundary solids were one inset AABB per iso cell outside the floor. Those
  approximate a 128×96 diamond; overhung neighbours still bite authored units
  into the floor if the inset is too loose.
- The partition doorway was cleared by centre, so the two jamb AABBs still bit
  ~8 world units each into a 21-unit aperture.

If you add solids, reject by corners. Conservative is correct: better to leave a
cell unstamped than to eat floor.

### Do not round hand-authored nav coordinates

Obstacles rasterise **conservatively** onto a 16×12 grid, so moving a point one
unit can drop it into a blocked cell — and now a solid claims every cell it
touches, so the blocked cells reach up to a cell further than the rectangle does.
Three city spawns failed re-validation purely because tidy numbers were
substituted for computed ones. Take what `nearestWalkablePoint` gives you.

(This bullet used to say obstacles rasterise *by cell centre*. They did until the
literal port; see "The search map is the only clearance authority".)

### Door and portal approach points go on the street, not at the door

All five city portal approaches were authored at the door **sprite's** coordinate.
The sprite is painted on the facade, so its position is inside the building's
obstacle, and every approach was unreachable. Approaches belong on the walkable
side the door faces — camera-near, ~120–150 units out in the shipped districts.

Runtime interactions use GemRB's 40-unit `MinDistance`, but authored approaches
still have to pass `reachesExactly`. Interaction range must not hide a snapped
approach placed across a wall or inside a sealed pocket.
