# Lila replacement — October 2 Desert Sentinel

`ClientActorNode` now uses **LilaSentinel**, the user's Meshy Desert Sentinel
character. `LilaAnimationSet` requires the entire named bundle before display.
The historical 25-frame `Lila` resource and its compatibility atlas remain as
regression fixtures; they are no longer the client's runtime authority.

## Blender source and repair

The self-contained source is
`ArtSource/Blender/LilaDesertSentinelOct02/Lila_Production.blend`.
It was authored and rendered through the live Blender MCP connection. It contains
the preserved original high-resolution mesh, the repaired working mesh, packed
PBR textures, material-region assignments, rig, two actions and sprite camera.
Voss's previously open Blender session was preserved as `SessionBeforeLila.blend`.

The supplied FBX had 320,499 vertices and 641,286 triangles, UVs and PBR maps,
but no armature or actions. A decimated working copy allowed QuadriFlow to
produce usable quads. The final mesh has 36,714 vertices, 36,728 faces and 73,452
triangles. Remesh openings and duplicate hair vertices were repaired; the final
audit reports **zero boundary edges, non-manifold edges and degenerate faces**.
New UVs and 2048-pixel colour, roughness, metallic and tangent-normal maps were
baked from the original. The head and silhouette were reviewed before/after.

The 59-bone rig includes thirty finger bones, torso/neck/head controls,
limb chains and six tunic controls. Every vertex has normalized deformation
weights, every finger joint influences mesh vertices, and shoulder smoothing is
restricted to a weighted region. The walking loop closes with zero evaluated
vertex displacement between its first frame and repeated endpoint. Maximum
measured ground penetration is under 4 mm (less than 0.18 native sprite pixels).
`model_validation.json` records the measurements and original FBX hash.

## Local reference and animation contract

The local Steam BG:EE installation supplied private comparison sprites:

- `CHFB1G11`: ten unique walk phases at the engine's 15 fps.
- `CHFB1G12`: a 56-frame idle, with eleven poses and the exact measured hold schedule.

The motion is reconstructed on the new rig from these sprite references; the
original game's skeletal animation is unavailable. No reference image pixels
are installed. Resource hashes and extracted phase information are under
`Reference/`. The authored walk uses planted-foot trajectories, alternating
arm swing and tunic motion. Idle uses head and upper-body turns.

Every direction is rendered independently. The bundle has **1,056 frames**:
sixteen directions × (ten walk frames + 56 idle frames). The two Blender actions
are `Lila_CHFB_Walk_10` and `Lila_CHFB_Idle_56`. The office uses the authored
conversation idle facing northeast toward Voss; walking reads the current
`Movable.orientation` directly.
The existing animation clock, movement/navigation, tint, stencil and shadow
systems remain the authorities.

## Masks, projection and packaging

The seven categorical face regions are metal, trousers, tunic, skin, belt,
boots and hair, in the engine's standard slot order. Cycles Material Index is
captured through the compositor Viewer as an exact integer mask, independently
of colour and shading. All 336 unique poses have P-mode material masks under
`Masks/`; background is 0 and visible material labels are 1–7.

The orthographic camera has elevation `asin(0.75)` and scale 2.88, with its target
at z=0.82. Renders are 384×384, reduced onto a fixed 128×128 native canvas at
44.4444 pixels/metre. There is no per-frame bounding-box scale fitting. The
registered root pivot is derived from this camera, and the display canvas is
140.625 world units, matching the current Voss canvas convention. Contact shadows
remain external (`ContactShadowNode`).

`ArtSource/Processing/package_lila_sentinel_oct02.py stage` fits seven palette
ramps using CIE94, encodes the native planes, checks all inventories and pose
uniqueness, and writes `Stage/LilaSentinel`. It never launches Blender or alters
the model. `render_plan.json` records every source action/frame/camera input.
Installation requires a review receipt bound to the staged blob hash:

```sh
python3 ArtSource/Processing/package_lila_sentinel_oct02.py stage
python3 ArtSource/Processing/package_lila_sentinel_oct02.py install
```

The app loads `Resources/Art/IE/Avatars/LilaSentinel`, preserved as an explicit
folder in both Xcode targets. SwiftPM copies the same IE resource tree.

## Verification and rollback

`LilaCurrentRuntimeTests` checks complete loading, every decoded native pixel,
all ten unique walk phases in all directions, exact idle holds, index ranges,
and rejection of the old Lila as the current character. Staged and installed
runs also include Voss's exact current hashes, locomotion and animation-clock
regressions. Both runs pass 29 tests. macOS Debug and iOS Simulator Debug builds
pass. Physical iOS device execution has not been performed.

`OfficeRestoreQA` additionally exercises the actual client's routed entrance,
walk playback, idle and exit fade, alongside its existing Voss and area-return
checks. All 30 checks pass in the built macOS app. It uses the scene's existing
cutscene mode and door controls so normal dialogue pause does not freeze the
test actor. Its captures/report are saved under `LiveQA/`.

`RuntimeBeforeInstall/` holds the prior actor and project integration files and
protected hashes for current Voss, all three equipment bundles and historical
Lila. Those art bundles remain unchanged. To roll back this replacement, restore
the saved actor/project files together; retain the new source and staged assets
for further authoring. Do not run a historical Voss installer.
