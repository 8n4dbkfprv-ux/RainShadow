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
