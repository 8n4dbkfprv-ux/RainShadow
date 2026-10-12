# Tabletop character presentation — October 12

Implements the character direction in [PR 36](https://github.com/8n4dbkfprv-ux/RainShadow/pull/36).
The user's explicit clarification retains palette swaps. The design document
now includes PR 36's tabletop proposal and records that palette decision.

## Runtime

- Voss, Lila, NPC variants and Bear Form keep a single rigid pose per facing.
  Walking, running, dashing, ladder traversal and stealth move the whole piece.
  Actions retain their existing gameplay/impact timing; figures do not articulate.
  Defeat tips the complete piece onto its side. Walking footsteps are suppressed.
- Movement follows Laurens’s animated reference: repeated 0.64 s whole-piece
  hops (0.56 s arc, 0.08 s planted beat), 12 world units high with up to 4.3°
  of directional lean. No limb animation or squash/stretch. The shadow stays
  on the terrain, counter-rotated beneath the tilted base. Pause freezes the
  motion; arrival completes the current hop. `TabletopMiniatureMotion` observes
  root positions after navigation/SKActions and only offsets artwork. Terrain
  height remains additive; hidden originals share the update for proxy hand-offs.
- Opening fix: Lila’s entrance continuation waits for final placement before
  dialogue freezes the world. Skipping resets body, base, tilt and shadow
  immediately, including jumps smaller than the relocation threshold.
- Human bases are 25 mm relative to a 32 mm sculpt; Bear Form uses 50 mm.
  The Blender-rendered base has a bevelled ink-black resin rim and wet-slate top.
  Allies use a brass pin line, combat enemies oxblood, neutrals plain ink-black.
  It follows terrain elevation and per-pixel wall cover. Voss/Lila's base replaces
  the IE selection-circle drawing and hover target.
- The display uses SpriteKit at viewport resolution, smooth full-colour textures
  and antialiased alpha. It bypasses the IE native framebuffer, multiply grade,
  pause greyscale and checkerboard dither. Walls retain per-fragment cover with
  smooth partial visibility; this is not a whole-actor transparency effect.
- Existing paths, movement budgets, collision, occupancy, camera projection,
  saves, equipment identities and legacy bundle hash checks are retained.
- Desk interaction uses the standing piece at its navigation point. There is no
  chair sit/stand animation or furniture-specific body offset in tabletop mode.

## Art/import authority

`ArtSource/Processing/package_tabletop_miniatures.py` imports 144 independently
rendered source views: Voss, Lila, Bear, shortsword, mail, helmet (with and without
mail), bow and arrow. Voss and equipment use the approved registration affine;
Lila and Bear retain their source projection. Every view is tightly cropped with
its pivot adjusted, never resized to fit the crop. Source SHA-256 hashes are in
`Resources/Art/IE/Tabletop/provenance.json`.

Helmet and mail renders have a 256-pixel camera window inside a 384-pixel canvas
(64-pixel overscan on each edge). Bow and arrow have per-view overscan recorded
in `padded_views.json`. This padding is translated away before the common body
registration affine; treating it as scale shrinks and displaces equipment.
`qa_tabletop_registration.py` compares all 96 equipment views against the
untouched approved silhouettes and centroids, including unarmoured helmets.

Voss uses continuous lighting from the approved neutral/region Blender passes.
Lila, Bear and equipment retain their original full-colour Blender pixels.
Separate material and continuous-shade planes support existing saved palette
rows. Only changed paint regions are recoloured. The old 128-pixel sprite
reduction, twelve-step quantisation and embedded indexed shadows are bypassed.
The named legacy `VossCHMF`, `LilaSentinel` and equipment bundles are not replaced.

`ArtSource/Blender/tabletop_base.py` is the reproducible base source. Execute its
`build(output_directory)` through live Blender MCP. It creates an isolated scene
and renders ally/hostile/neutral PNGs without modifying existing scene objects,
character geometry, rigs or materials. Camera elevation is asin(0.75), 48.59°,
within PR 36's exploration range and matching the existing character renders.

The `Tabletop` folder is copied intact into both app targets. Runtime palette
variants share frame caches by character and complete palette. Missing miniature
data fails clearly instead of silently substituting old pixel art.

## Verification

Build macOS and iOS using the README commands (set `DEVELOPER_DIR` to the installed
Xcode if the system default is CommandLineTools). Launch the macOS executable
with `RAINSHADOW_QA_TABLETOP=<output-directory>` for an isolated SpriteKit review.
It writes `report.json` and `miniatures.png`, checks every human facing across
walk/run/dash phases, equipment synchronization, palette updates, registration,
source resolution, base presence and bundled resource loading.
It also verifies real Voss/Lila movement and arrival, pause, material-isolated
palette changes and rendered wall-mask pixels. Three additional equipment
contact sheets cover all sixteen facings with mail, helmet only, and bow/arrow.

Run `CharacterAppearanceTests`, `VossCurrentRuntimeTests`, `LilaCurrentRuntimeTests`,
`MovementIntegrationTests` and `GameDesignDocumentCanonTests` in SwiftPM. Legacy
integer-port tests remain valid for their preserved reference implementation.

Validated October 12: macOS and iOS Simulator Debug builds succeeded; 22 core
tests across those five suites passed; 788 SpriteKit checks passed. All 96
equipment views match approved placement (minimum silhouette IoU 0.941,
maximum centroid error 0.330 native pixels). All sixteen helmet directions were
visually reviewed with and without mail after correcting the overscan import.
Review images and reports are under `output/tabletop-miniatures-oct12/`.

Movement follow-up: macOS and iOS Simulator Debug builds pass; all four movement
integration tests pass. The extended SpriteKit harness passes 817 checks,
including bounded hops and planted arrival at 30/60/120 fps, pause/resume,
teleport handling, real Voss/Lila routes, equipped terrain offsets, the large
bear shadow and the scene's final presentation pass. It also writes
`movement-frames/` for visual review. The rendered route preview and report are
in `output/tabletop-movement-oct12/` (`movement.gif`, `report.json`).

## Remaining art-direction work

This is the character cutover using existing approved sculpts. New wardrobe
sculpts/textures, area terrain boards, walnut/felt surroundings, board-specific
base tops, practical-light simulation, macro dialogue portraits, the remaining noncombat
prop UI and a separately rendered 55° combat camera remain subsequent work.
World-space physical dice and combat prop UI are implemented in
`TabletopCombatOct12.md`.
The current terrain plates remain placeholders as PR 36 specifies. The base's
visual diameter does not expand the navigation collider or alter narrow routes.

Reference-hop follow-up: the 817 SpriteKit checks pass with the new hop rhythm,
and both app targets build. The actual fresh-game opening, natural Lila entrance,
dialogue placement, departure and mid-hop skip pass all eight end-to-end checks.
The initial Voss terrain comparison uses 0.001 world-unit tolerance for SpriteKit’s
float-backed transform, rather than exact equality with the double height map.
Review: `output/tabletop-hops-oct12/movement.gif` and `opening/`.

Four movement integration tests and the cutscene catalog suite pass. The unchanged
cutscene runner/action-override unit suites report 46 issues in existing cue
completion expectations; this presentation work does not modify those sources
or tests. The real opening is verified separately by `RAINSHADOW_QA_TABLETOP_OPENING`.
