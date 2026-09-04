# Third-party notices

## GemRB

RainShadow's navigation stack is **derived from GemRB**, the open-source
reimplementation of the Infinity Engine. It is a transliteration, not an
independent implementation reaching the same answers: the structures, the
control flow, the constants and much of the reasoning in the comments come from
GemRB's source.

- Project: <https://gemrb.org>
- Source: <https://github.com/gemrb/gemrb>
- Licence: **GPL-2.0-or-later** (`SPDX-License-Identifier: GPL-2.0-or-later`)
- Upstream revision this port tracks: `1c45c1850d9b5d61a23b3a569499ef57543e2c3f`
  (`master`, 28 August 2026)

### Files derived from GemRB

Under `RainShadow Shared/Gameplay/Navigation/`:

| RainShadow | GemRB |
|---|---|
| `PathFinder.swift` | `gemrb/core/PathFinder.cpp`, `gemrb/core/PathFinder.h`, `gemrb/core/BucketPriorityQueue.h` |
| `Movable.swift` | `gemrb/core/Scriptable/Movable.cpp`, `gemrb/core/Scriptable/Movable.h` |
| `Path.swift` | `gemrb/core/PathFinder.h` (`Path`, `PathNode`) |
| `Orientation.swift` | `gemrb/core/Orientation.h` |
| `Geometry.swift` | `gemrb/core/Geometry.cpp`, `gemrb/core/Core.cpp` (`Feet2Pixels`, `PersonalDistance`, `WithinPersonalRange`) |
| `SearchMap.swift` | `gemrb/core/TileProps.h`, `gemrb/core/TileProps.cpp`, `gemrb/core/Map.cpp` |
| `SearchMapTerrain.swift` | `gemrb/core/TileProps.h`, `gemrb/plugins/AREImporter` terrain table |
| `SearchMapVisibility.swift` | `gemrb/core/Map.cpp` (`Explore`) |
| `ActorOccupancy.swift` | `gemrb/core/PathFinder.cpp` (`BlockSearchMapFor`, `ClearSearchMapFor`), `gemrb/core/Scriptable/Selectable.cpp` |
| `MovementOrderQueue.swift` | `gemrb/core/Scriptable/Actor.cpp` (`NewPath`), `gemrb/core/GUI/GameControl.cpp` |
| `CameraZoom.swift` | `gemrb/core/GUI/GameControl.cpp` (`zoomLevel`, `GetScalePercent`, `SetScalePercent`, `OnMouseWheelScroll`), `gemrb/core/Region.cpp` (`Region::Scale`, `Region::Unscale`) |
| `AreaViewport.swift` | `gemrb/core/GUI/GameControl.cpp` (`MoveViewportTo`'s clamp block, `MoveViewportUnlockedTo`) |
| `HighlightResolver.swift`, `HighlightableObject.swift` | `gemrb/core/GUI/GameControl.cpp` (`OutlineDoors`, `OutlineContainers`, `OutlineInfoPoints`), `gemrb/core/Map.cpp` (`DrawHighlightables`) |
| `GroundCircle.swift` | `gemrb/core/Scriptable/Selectable.cpp`, `gemrb/core/Scriptable/Selectable.h`, `gemrb/core/Scriptable/Actor.cpp` (`SetCircleSize`, `ShouldDrawCircle`), `gemrb/includes/ie_stats.h`, `gemrb/includes/RGBAColor.h` |
| `IEColorCycle.swift` | `gemrb/core/GUI/GUIAnimation.cpp`, `gemrb/core/GUI/GUIAnimation.h` (`ColorCycle`, `GlobalColorCycle`) |
| `FogGrid.swift` | `gemrb/core/FogRenderer.h` (`FogPoint`, `FogRenderer::CELL_SIZE`, `OPAQUE_FOG`, `TRANSPARENT_FOG`) |
| `FogEdgeMask.swift` | `gemrb/core/FogRenderer.cpp` (`DrawFog`, `DrawVisibleCell`, `DrawExploredCell`, `DrawFogCellVertices`, `DrawFogSmoothing`, `SetFogVerticesByOrigin`) |

`RainShadow Shared/Core/Scene/FogMaskRenderer.swift` is the same fog-geometry
port a second time in GLSL for SpriteKit. `FogEdgeMask.swift` is the readable,
unit-tested software reference. The runtime uploads only the 255/128/0 cell
states and evaluates the four-triangle cardinal fan and the two diagonal
smoothing draws per fragment. This is an API adaptation: SpriteKit exposes a
fragment shader but no public raw-geometry node with per-vertex colours.
The all-black passes are analytically combined before the final framebuffer
write; an upstream 8-bit backend that rounds after every individual draw may
differ at a rounding boundary. Viewport overscan borders are not ported here:
RainShadow already draws black outside the area, and this shader spans only
the fog-grid world frame. It does not change camera clamping or area extent.

The port preserves two easily missed compositor details from the pinned code.
`DrawVisibleCell` passes its cardinal `dirs` into `DrawFogSmoothing`, suppressing
a diagonal when either incident edge was already drawn; `DrawExploredCell`
passes `Direction::O`, so its diagonals are not suppressed. Also, each call ends
in `DrawRawGeometry(..., BlitFlags::BLENDED)`: overlapping 128/255 and north/south
passes combine by source-over, not by taking their maximum.

`ArtSource/Processing/qa_fog_geometry_shader.swift` reads the shipped GLSL and
renders it through SpriteKit, comparing it with an independent transcription
of the pinned 12-vertex masks. It covers all 256 binary neighbour topologies for
both visible/remembered centres and both remembered/unexplored neighbours, 512
mixed-state fixtures, uniform fills, default-outdoor-scale ramps, and node
opacity. On the macOS Retina readback, 1,040,064 samples across 1,539 topologies
matched within 1/255 (31 August 2026). This also verifies the image-row to
world-row upload flip. Run it after changing either fog transcription:

```sh
swift ArtSource/Processing/qa_fog_geometry_shader.swift
```

### Files derived from GemRB — character colour model

RainShadow's character sprite colour model is a second port from the same
upstream. The Infinity Engine's answer to "what colour is this pixel" is two
lookups — a gradient index picks a row of a palette table, a shade picks a
column — and these files are that answer transliterated.

| RainShadow | GemRB |
|---|---|
| `RainShadow Shared/Gameplay/Navigation/IEPalette.swift` | `gemrb/core/Palette.cpp`, `gemrb/core/Palette.h` (`Palette`, `Palette(color, back)`, `TranslucentShadowColor`, `CopyColors`) |
| `RainShadow Shared/Gameplay/Navigation/IEPaperdollColours.swift` | `gemrb/core/CharAnimations.cpp` (`SetupPaperdollColours`, `enum PALETTES`) |
| `RainShadow Shared/Gameplay/Navigation/IEGradientTables.swift` | `gemrb/core/Interface.h` (`LoadPalette<SIZE>`, `GetPalette16`, `GetPalette256`) |
| `RainShadow Shared/Gameplay/Navigation/PLTSprite.swift` | `gemrb/plugins/PLTImporter/PLTImporter.cpp` (`Import`, `GetSprite2D`) |
| `ArtSource/Processing/ie_palette.py` | all four of the above, transliterated a second time for the art pipeline |

`PLTSprite.swift` is specifically the inventory-paperdoll PLT path. It is not
the provenance for RainShadow's play-scale indexed avatar bundle.
`RainShadow Shared/Gameplay/Navigation/IEIndexedSprite.swift` and
`RainShadow Shared/Gameplay/Actors/IEAvatarNode.swift` use the avatar model
whose closest engine counterparts are `gemrb/plugins/BAMImporter`
(`GetFrameInternal`: indexed cells with dimensions/centre) and
`gemrb/core/CharAnimations.cpp` (`SetupPaperdollColours`: a character-owned
palette). That data-model split is adapted from GemRB, but the files do not
transliterate its BAM parser or renderer: RainShadow's `RSIEAV1` container,
manifest/blob validation, texture cache and SpriteKit adapter are original.
The indexed-first integration in `DetectiveActorNode.swift` and
`ClientActorNode.swift` is original too.

`ArtSource/Processing/extract_ie_gradients.py` reads the gradient bitmaps
`LoadPalette<SIZE>` expects and is derived by the same route.
`ArtSource/Processing/qa_ie_palette_port.py` and
`Tests/RainShadowCoreTests/IEPaletteTests.swift` hold the two ports to
upstream's answers and to each other.

**Not derived from GemRB.** `ArtSource/Processing/ie_avatar.py`,
`author_material_masks.py`, `ie_avatar_bundle.py`, `install_voss_v22.py`'s
paired encode and `install_lila_ie_avatar.py` are ours. GemRB has no encoder and
neither did the Infinity Engine — BioWare pre-rendered its avatars offline with
in-house tools and the engine only ever read the finished BAM and PLT files.
The material assignment, paired raster transform, `RSIEAV1` raw container and
transactional installers are therefore RainShadow work. The gradient tables
and character-palette construction those indices address are the
upstream-derived half.

The current cutover covers play-scale BAM-style avatar indices only. The
existing paperdoll and portrait have not been re-encoded as PLT and do not gain
a material mask by implication.

### Files derived from GemRB — render pipeline

RainShadow's render path is a third port from the same upstream. The engine's
answer to "what does this sprite look like on screen" is a small set of integer
pixel shaders chosen by a flag word, and these files are that answer
transliterated.

| RainShadow | GemRB |
|---|---|
| `RainShadow Shared/Gameplay/Navigation/IEBlit.swift` | `gemrb/core/Sprite2D.h` (`enum BlitFlags`), `gemrb/core/Video/Pixels.h` (`ShaderTint`, `ShaderGreyscale`, `ShaderSepia`, `RGBBlendingPipeline`), `gemrb/core/Game.cpp` (`ApplyGlobalTint`) |
| `RainShadow Shared/Core/Scene/IEBlitShader.swift` | the same three shaders, transliterated a second time in GLSL for SpriteKit |
| `RainShadow Shared/Gameplay/Navigation/IESoftwareBlit.swift` | `core/Video/Pixels.h` (`RGBBlendingPipeline`, `ShaderBlend<true>`), `core/Region.cpp` (`Intersect`), `plugins/SDLVideo/SDLVideo.cpp` (`BlitGameSprite`, SDL1 `BlitSpriteClipped`), native clipped mirror traversal |
| `RainShadow Shared/Core/Scene/IENativeCompositor.swift` | second transliteration of the above integer RGBA blend/tint/grey/sepia and native SDL1 clipping in Metal; authored additive art and baked wall-cover remain explicit adapters |
| `RainShadow Shared/Gameplay/Navigation/IENativeViewport.swift`, `Core/Scene/IENativeWorldRenderer.swift` | RainShadow world/scene adapters: integer native viewport and frame placement, shared framebuffer, final whole-buffer zoom; scope in `NativeWorldRenderer.md` |
| `DetectiveActorNode.applyBodyTint`, `ClientActorNode.applyBodyTint` | `gemrb/core/Map.cpp` (`Map::DrawMap`'s per-actor tint, `Map::GetLighting`) |
| `GameAreaScene.refreshAreaAnimations`' tint | `gemrb/core/Map.cpp` (`Map::DrawMap`'s area-animation tint) |
| `BaseGameScene.syncWorldGreyscale`, `worldBlitFlags` | `gemrb/core/Map.cpp` (`Map::DrawMap`'s per-object flag composition, `TimeStoppedFor` → `BlitFlags::GREY`) |
| `RainShadow Shared/Gameplay/Navigation/AreaWallStencil.swift` | `gemrb/core/Map.cpp` (`Map::DrawStencil`, `SetDrawingStencilForObject`, `SetDrawingStencilForScriptable`), `gemrb/core/Polygon.h` (`WF_DITHER`, `WF_COVERANIMS`) |
| `RainShadow Shared/Core/Scene/WallStencilTexture.swift`, `IEBlitShader`'s `STENCIL_DITHER` path | the same stencil, adapted to an `SKShader` sampling a baked mask |
| `RainShadow Shared/Gameplay/Navigation/DrawQueue.swift` | `gemrb/core/Map.cpp` (`Map::SortQueues`' comparator, `DrawMap`'s far-to-near walk) |

`IEBlitFlags` ports only the flag members RainShadow draws with, at upstream's
values rather than renumbered; the omitted members are listed in the source.

**Three deliberate deviations**, all recorded in `IEBlitShader.swift` and all
forced by the target rather than chosen:

- The GLSL copy unpacks the flags into separate float toggles. SpriteKit
  compiles a GLSL ES 1.0 subset, which has no bitwise operators, so
  `flags & BlitFlags::GREY` cannot be written at all.
- The GLSL copy works in byte space — scale to 0...255, floor, operate, scale
  back — because a float `* 0.25` is not a truncating `>> 2`.
- The GLSL copy un-premultiplies alpha first. `SKTexture` pixels are
  premultiplied and the engine's `Color` is straight; tint and greyscale are
  linear and survive the difference, but sepia's `+ 21` and `- 32` are absolute
  byte offsets that would land wrong on a partially transparent pixel.

`Tests/RainShadowCoreTests/IEBlitTests.swift` holds the Swift port to upstream's
arithmetic, including the two answers most likely to be "corrected" by a later
reader: tinting by white gives 254, not 255, and the engine's greyscale peaks at
189, not 255.

`ArtSource/Processing/qa_ie_blit_shader.swift` checks the other side, the way
`qa_ie_palette_port.py` does for the colour model: it renders through SpriteKit
and compares the GLSL copy against the integer copy, so the second
transliteration is verified rather than merely reviewed.

`qa_ie_software_blit.py` compiles verbatim C++ blocks from the same pinned
GemRB commit into a temporary oracle using `ie_software_oracle.cpp.in`. The
generated blocks retain GemRB's GPL-2.0-or-later provenance; no SDL backend is
vendored or installed. `IESoftwareBlitTests` differentially checks complete
buffers, not just selected source colours. This reference is separate from the
native-world integration: the three GLSL adaptations above do **not**
establish exact blending, placement, filtering or display scaling. Scope,
measured results and remaining gaps are recorded in
`Documentation/GemRBSoftwareSpriteReference.md`. The existing unresolved
distribution/licensing decision in `NavigationOpenQuestions.md` still applies.

**Not derived from GemRB.** `ActorSceneLighting`'s three grades are authored art
direction with no upstream counterpart, and `ActorSceneLighting.globalTint` — the
adaptation that folds a blend weight into a multiplier — is ours. Upstream's
global tint is authored directly as a multiplier and has no weight.

## Near Infinity

RainShadow's sprite resampling and colour metric are **derived from Near
Infinity**, the open-source Infinity Engine browser and editor. Unlike GemRB,
which only ever reads finished sprites, Near Infinity *makes* them — it has a
BAM converter, and that is the part RainShadow needs, because the Infinity
Engine itself never enlarged a sprite at bake time.

- Project: <https://github.com/Argent77/NearInfinity>
- Licence: **LGPL-2.1** — a *different* licence from GemRB's GPL-2.0-or-later.
  Both are copyleft; they are not the same obligation, and neither is answered
  by the other. See `Documentation/NavigationOpenQuestions.md`.

### Files derived from Near Infinity

| RainShadow | Near Infinity |
|---|---|
| `ArtSource/Processing/ie_resample.py` | `gui/converter/bam/BamFilterTransformResize.java` (`scaleSuperXBR`, `scaleSuperXBR2x`, `scaleLanczos`, `scaleLanczosSample`, `lanczos`, `diagonalEdge`) |
| `RainShadow Shared/Gameplay/Navigation/IEResample.swift` | the same functions, transliterated a second time for the runtime |
| `ArtSource/Processing/ie_colorconvert.py` | `resource/graphics/ColorConvert.java` (`convertRGBtoLab`, `getColorDistanceLabCIE94`, `COLOR_DISTANCE_CIE94`) |

`Tests/RainShadowCoreTests/IEResampleTests.swift` and
`ArtSource/Processing/emit_ie_resample_fixture.py` hold the two resampler
transliterations to each other, pixel for pixel, including at the shipping
3.125x scale.

**Two deliberate deviations from upstream**, both recorded in the ports:

- Upstream computes the Super xBR weights and the Rec. 709 luma in Java
  `float`; both ports use double precision throughout. Python and Swift agree
  with each other, which is what the round-trip test needs; neither claims
  bit-identity with the Java.
- `max_doublings` / `maxDoublings` is ours. Upstream doubles while the factor
  exceeds one; capping the xBR passes and letting Lanczos cover the remainder
  is an option upstream does not offer.

`ArtSource/Processing/ie_avatar.py` and `author_material_masks.py` remain ours —
see the note under the GemRB section. What changed is that they now ask their
colour question with Near Infinity's metric instead of an invented one.

### Data extracted from Baldur's Gate: Enhanced Edition

`RainShadow Shared/Resources/Art/IE/pal16.bin` and `pal256.bin` are the
`MPALETTE` and `MPAL256` gradient tables from a retail BG:EE installation,
extracted unchanged. They are **Beamdog/BioWare data, not original work**, and
they are shipped inside `RainShadow Shared/Resources/` as a deliberate project
decision — one that contradicts the rule stated in
`ArtSource/Processing/extract_ie_reference.py`'s own docstring, that everything
under `RainShadow Shared/Resources/` must be original. See
`Documentation/NavigationOpenQuestions.md`.

And one outside it:

| RainShadow | GemRB |
|---|---|
| `RainShadow Shared/Gameplay/Actors/GroundCircleNode.swift` | `gemrb/core/Scriptable/Selectable.cpp` (`DrawCircle`), `gemrb/core/Video/Video.cpp` (`DrawEllipse`) |

`RainShadow Shared/Core/Scene/BaseGameScene.swift` carries one derived function,
`refreshActorHover`, from `GameControl::WillDraw`; the file as a whole is not a port.

`ArtSource/Processing/bake_area_searchmap.py` reproduces `SearchMap`'s
rasterisation and is derived by the same route.

`Documentation/PathfindingSystem.md` records what was ported, what was
deliberately adapted, and what was deliberately left out.
`Documentation/NavigationOpenQuestions.md` §1 records the licensing decision this
notice does not make.

### What this means

GPL-2.0-or-later is a copyleft licence. Distributing a work derived from GemRB
carries obligations — source availability and licence compatibility among them —
and this notice exists so that the derivation is on the record rather than buried
in source comments. It is a statement of provenance, not legal advice; the
project has not yet chosen a licence of its own.

Behaviour, algorithms and engine constants are not themselves copyrightable;
expression is. The files listed above copy expression, which is why they are
listed.
