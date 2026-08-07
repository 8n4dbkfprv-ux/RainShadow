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

`office_layout_plan.py` checks its own **128×64 iso** grid. `SearchMap` rasterises
what it emits onto **16×12 world** cells — 2.6× finer across, 1.7× taller.
Geometry that rounds away in the planner is solid at runtime, and the planner
printed `ALL CHECKS PASS` throughout the sealed-office bug.

Two consequences, both fixed by testing a solid's **extent** rather than its centre:

- Boundary solids were one 104×52 AABB per iso cell outside the floor. Those
  approximate a 128×64 diamond, so each overhung its neighbours by 40×20 and the
  union bit ~20×10 authored units into the floor on every edge.
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
