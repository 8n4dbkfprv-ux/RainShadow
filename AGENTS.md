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

## Projection lock (area art)

Canonical Baldur's Gate: EE orthographic camera constants live in
`ArtSource/Processing/ie_projection.py` (elevation asin(0.75), ground axes
±0.75, diamond 128×96, 16:12 ground ellipse). See
`Documentation/InfinityEngineGroundProjection.md`. After changing projection
math, rebake and hash-diff generated outputs; intended-inert edits must come
back identical.

### Grade a plate, do not eyeball it

`qa_plate_projection.py` measures the ground axes actually baked into a plate,
so "matches the camera" is a number. Every new or regenerated area master must
pass it before install. All eight shipped plates currently fail (the city ones
disagree with each other by up to 30°), because the V2 lock was prose in a
prompt with nothing measuring it. Painted masters still need regen under the V5
office / V3 city locks — status and blockers in
`Documentation/BGEEProjectionMasterRegen.md`.

Calibrate before trusting it: a plain 3×3 Sobel aliases on hard lines and read a
true 36.87° grid as 45°. The shipped estimator uses a smoothed structure tensor
and is accurate to 0.13° on a synthetic lattice.

### Never resize a plate across aspect ratios

Scaling x and y by different factors multiplies every ground slope by `sy/sx`.
Taking a 3:2 master straight to 2048×1152 shears 36.87° to 31.74° and nothing
reports an error. Use `process_city_districts_v02.fit_to_aspect`, which
centre-crops to the target aspect first and then scales uniformly.

## Character sprite pipeline — traps that cost real time

Read this before touching anything under `ArtSource/Processing/` that produces
character atlases. Every item below is a mistake that was actually made here.

### The installers must run in this order

`install_voss_idle_walk_seated_match_v02.py` ends with `lock_standup_handoff()`,
which grades the seat-transition endpoints against the **standing idles it just
wrote**. So the seat chains have to be installed first:

```bash
cd ArtSource/Processing
python3 process_voss_desk_ne_v12.py            # NE seat chain
python3 -c "import process_pre_rendered_characters_v12 as v12, \
process_pre_rendered_characters_v3 as raster; \
from process_pre_rendered_characters_v7 import pixelize_figure_v7; \
raster.pixelize_figure = pixelize_figure_v7; v12.process_voss_desk_chain_se()"
python3 install_voss_idle_walk_seated_match_v02.py   # idle + walk + handoff
python3 -c "import process_pre_rendered_characters_v11 as v11, \
process_pre_rendered_characters_v3 as raster; \
from process_pre_rendered_characters_v7 import pixelize_figure_v7; \
raster.pixelize_figure = pixelize_figure_v7; v11.process_lila()"
python3 process_lila_departure_facing_fix_v01.py
python3 process_lila_departure_nw_v01.py
```

Running the seat chains *after* the installer silently breaks
`VossWardrobeColorTests` — the handoff grade gets overwritten.

### `wardrobe_match_to_idle` is not idempotent

It reads `voss_stand_up_*_11` off disk, grades it toward the idle, and writes it
back. Running `install_voss_idle_walk_seated_match_v02.py` twice **without**
re-running the desk chains grades an already-graded frame again and drifts those
four cells. Always run the full sequence above; never the installer alone.

### Never call `v11.main()` or `v12.main()` to fix one clip

Both run the *whole* character chain and will clobber atlases you just baked from
newer masters. Call the specific stage — `process_voss_desk_chain_se()`,
`process_lila()` — as in the sequence above.

### Do not run `process_voss_desk_ne_v01.py`

It does **not** reproduce the shipped seat atlases; `process_voss_desk_ne_v12.py`
is the NE authority. Running v01 overwrites 48 good cells with a different bake.

### `* 2.py` Finder duplicates are tracked

`ArtSource/Processing/` is full of them (`install_voss_idle_walk_seated_match_v02 2.py`,
etc.). Edit only the un-suffixed file and check `git status` afterwards to confirm
no ` 2.py` was touched.

### `shutil.copy2` carries extended attributes into the atlases

The installers copy masters with `copy2`, which preserves xattrs. On an
iCloud-synced checkout that makes `codesign` reject the test bundle with
"resource fork, Finder information, or similar detritus". Build outside the synced
tree instead: `swift test --scratch-path <path outside iCloud>`.

### Colour locks flatten the wardrobe by design

`seated_authority_lock` and `identity_wardrobe_lock` were written for monochrome
masters and fix them by stamping one chroma ratio over most of the body. They are
now gated behind `crunch.PRESERVE_WARDROBE` (off by default; set
`RAINSHADOW_PRESERVE_WARDROBE=1` when installing masters that actually have a
wardrobe). If you add a colour pass to either function, gate it too — the flatteners
are spread across **eight** separate places, including a final "coat snap AFTER lum"
block that runs last and overrides everything before it. Verify with
`qa_wardrobe_lock_preservation.py`, not by eye.

### A waiver looser than the Swift gate cannot make an install succeed

`Tests/RainShadowCoreTests/VossSeatScaleTests.swift` and `VossWardrobeColorTests.swift`
are what actually gate shipping. When an installer waives its Python-side check
past the matching Swift threshold, it does not pass the payload — it moves the
failure to a red suite *after* the runtime has been replaced. V19 shipped that
way: a ≤2.5% rear-shirt waiver against a 0.1% gate let an entire rear hemisphere
install as front views, so Voss walks away from the camera facing you. Keep every
waiver at `Swift gate + a small raster margin`, and never waive a wrong pose or a
wrong view — that is correctness, not craft. See
`Documentation/VossV19AnimationAudit.md`.

### One sampled cell does not validate a direction

The core rear check reads exactly one cell, `voss_standing_idle_n_00.png`. The
other 35 rear cells went unmeasured for four versions, and a generator can ignore
the back scaffold for a whole direction. Validate every phase of every affected
direction, not a representative.

### Verify a pipeline change by rebaking and diffing, not by reading

The atlases are deterministic. After any pipeline edit, run the full sequence and
hash-compare against a snapshot taken before it. A change intended to be inert must
come back 233/233 identical. This caught an auto-detection heuristic that silently
diverged 86 of 233 frames.

## Navigation authoring — traps that cost real time

Read this before touching `ArtSource/Processing/office_layout_plan.py`,
`CityDistrictCatalog.swift`, or anything that authors a nav point. Every item
below is a bug that actually shipped, and each one shipped with a green suite.

### `route` hides broken geometry — never test reachability with it

`NavigationMap.route` flood-fills to the nearest *reachable* cell and paths there.
It therefore succeeds from inside a sealed pocket, or from inside a building, and
reports nothing wrong. Three bugs lived behind it:

- the office floor sealed to **174 of 4,694** walkable cells,
- the office door with **no exact path**, so the exit to the city was unclickable,
- Harborpoint PD spawning the detective **inside an 820×680 station**, 1 of 5,795
  cells reachable, on a district reachable from the world map.

Use `path` (honest `nil`) and flood-fill the runtime search map. See "Measuring
reachability" in `Documentation/PathfindingSystem.md`.

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

Obstacles rasterise **by cell centre** on a 16×12 grid, so moving a point one unit
can drop it into a blocked cell. Three city spawns failed re-validation purely
because tidy numbers were substituted for computed ones. Take what
`nearestWalkablePoint` gives you.

### Door and portal approach points go on the street, not at the door

All five city portal approaches were authored at the door **sprite's** coordinate.
The sprite is painted on the facade, so its position is inside the building's
obstacle, and every approach was unreachable. Approaches belong on the walkable
side the door faces — camera-near, ~120–150 units out in the shipped districts.

Interactions are issued with `requiresExactDestination`, so scenes refuse a snapped
approach. "Route-reachable" is not good enough for an approach point.
