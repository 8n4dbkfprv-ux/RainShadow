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
