# Native world renderer

3 September 2026. Enabled by default for scenes with a loaded area. The opening
cinematic remains on its existing presentation path.

## What changed

`BaseGameScene.didFinishUpdate` submits the existing world graph, after its normal
updates/actions, to `IENativeWorldRenderer`. The renderer keeps accumulated
depth and stable insertion order, quantises placement onto one native viewport,
and composites into an opaque RGBA byte buffer. One nearest-filtered camera-child
sprite presents that completed buffer. HUD, cinematic chrome and debug overlays
remain separate. Navigation, camera clamp, zoom ladder, animation logic and the
registered model/seat geometry are unchanged.

Voss uses his original indexed frame and palette, including index-1 shadows,
with an integer native pivot. No linear sampling or Super xBR occurs between
those native texels. The existing frame textures/registered bounds remain for
fallback and scene bookkeeping. The 26×64 SW standing frame is still 26×64 in
the world buffer; play zoom enlarges the *whole buffer*, not individual sprites.
At 100%, native pixels map to logical view points; Retina backing pixels are a
final display enlargement, not extra source detail.

`RAINSHADOW_NATIVE_WORLD=0` restores the prior SpriteKit presentation. A missing
Metal compositor or unsupported authored sprite blend also retains the original
presentation instead of silently substituting a blend. So does a frame that
exceeds the cold-start conversion budget — see "Warm-up" below. The original scene graph
remains intact underneath the opaque display plane; this currently incurs extra
rendering work, which the compositor-only timings below do not include.

## Authority and explicit boundaries

The selected reference is GemRB
`1c45c1850d9b5d61a23b3a569499ef57543e2c3f`. Relevant upstream operations:

```cpp
// SDLVideo::BlitGameSprite
Region srect(Point(0, 0), spr->Frame.size);
Region drect = Region(p - spr->Frame.origin, spr->Frame.size);
// SDL1 BlitSpriteClipped, repeated for x/w:
int trim = dst.h - dclipped.h;
src.h -= trim;
if (dclipped.y > dst.y) { src.y += trim; }
// Pixels.h ShaderBlend<true>, repeated for green/blue:
dst.r = DIV255(src.a * src.r) + DIV255((255 - src.a) * dst.r);
```

The Metal copy performs those two DIV255 truncations separately, plus the
existing integer tint/grey/sepia operations. Native clipping includes the SDL1
both-edges trim and clipped-source mirroring, tested against the CPU port. No
fixed-function GPU alpha blending is used between ordinary world draw items.

This is **not** a claim of complete original Infinity Engine or BG:EE parity:

- GemRB's decoded RGBA, RLE, SDL fast-blit and GL paths differ. In particular,
  the raw RGBA mask expression is not the RLE dither branch. The existing
  RainShadow wall-cover adapter is retained: categorical baked world mask,
  opaque cover or 50% checker, now evaluated on native viewport pixels. Its
  orientation and coverage are tested, not mislabeled as RGBA-mask equivalence.
- Painted high-resolution backgrounds/props are sampled onto the native plane;
  they are not decoded WED/TIS tiles. Floating world coordinates and registered
  pivots round to the native plane; GemRB's coordinates are already integral.
- SpriteKit rasterises authored warped sprites, paths, fog and particle groups
  into bounded native-sized source images. Their source rasterisation is not a
  GemRB port. Crop masks remain applied. Rain uses a persistent simulation copy
  (paused with its live ancestors), not a freshly restarted emitter each frame.
- Authored additive light/rain art retains saturating alpha-weighted addition;
  it is not GemRB's byte-wrapping `ShaderAdditive`. No new ADD/MOD claim is made.
- The final whole-buffer zoom is nearest. No evidence establishes that every
  proprietary Beamdog backend/version uses this exact presentation policy.

## Source passes carry a depth/stencil attachment

`renderSource` builds its own `MTLRenderPassDescriptor`, and it must attach a
`depth32Float_stencil8` texture the way `SKView` does. SpriteKit binds a
depth-stencil state with `frontFaceStencil`/`backFaceStencil` set for some
draws, and against a pass with a nil `stencilAttachment` that is a hard
`validateCommonDrawErrors:` assert, not a degraded frame.

Measured, not assumed. Of the four node kinds that reach `SKRenderer` here, two
take that path and both ship:

| node | stencils? | in game |
| --- | --- | --- |
| `SKCropNode` with a *sprite* mask | yes | `addWindowRain` with `office_window_glass_mask` |
| `SKShapeNode` filled on a non-convex path | yes | every `HighlightOutlineLayer` polygon |
| `SKCropNode` with an `SKShapeNode` mask | no | pre-V11 rollback branch |
| stroked ellipse / `SKLabelNode` / `SKEmitterNode` | no | ground circle, title, rain |

The attachment is cleared per pass and never stored; it is scratch for
SpriteKit, not a buffer this renderer reads. Textures are cached by pixel size.
Adding it changed no output: the office capture is byte-identical to the
pre-fix build and the in-app QA gate still passes all 224 Voss frames.

## Warm-up

Converting a texture the compositor has not seen costs a decode, a redraw and
two full-size copies — about 38 MB a copy for `office_suite_plate` at
4096×2304 — and the first frame in an area wants several at once. Conversion is
now budgeted per frame: the first one is always allowed through whatever its
size, and once the budget is spent the frame is abandoned, which the existing
"retain the original presentation" path already handles. The area therefore
appears immediately on SpriteKit's own presentation and swaps to the native
buffer within a frame or two, instead of blocking on the whole working set.

Two related changes: bytes are taken straight from the `CGImage` when it is
already 8-bit straight-row premultiplied RGBA in sRGB/DeviceRGB, where the
redraw would have been the identity; and the texture cache evicts
least-recently-drawn entries instead of emptying itself, because a wholesale
clear at a working set near the 192 MB cap re-decodes everything on the very
next frame.

## Verification

- Pinned extracted C++ vs CPU: 1,296 cases, 248 Voss frames, 37,348,160 byte
  comparisons, zero mismatches.
- Production Metal vs that CPU port: 1,280 overlapping native draws, clipping
  on both edges, mirrors, tint/grey/sepia, all 65,536 alpha/channel pairs;
  4,793,984 byte comparisons, zero mismatches.
- In-app production library/traversal/compositor: all 224 nonempty Voss frames
  over an asymmetric RGB background, ordinary and mirrored placement, exact
  bytes; per-pixel asymmetric wall cover and foreground draw-order checks.
- 55 selected core tests passed (native viewport, camera scale, blit, wall
  stencil, Voss seat and wardrobe). Existing GLSL QA passed 165 colour pairs
  and its stencil checks.
- macOS Debug and iOS Simulator Debug builds passed. The macOS window was
  inspected through the desktop UI: walking, changing fog, ground rings and
  tactical-pause greyscale worked while the HUD remained separate. Its visible
  counter reported about 60 FPS when foregrounded (30 FPS while inactive).
  This is a spot check, not an iOS device or sustained performance benchmark.
- Live native captures: office, actor-focused standing pose, and Sable Row at
  50%, 100%, 155%. A 1280×720 window produces 640×360, 1280×720, 1984×1116
  buffers respectively. Resizing changes visible native pixels, not source size.
- Measured Sable Row compositor at 155%: 29 warm frames, median 11.75 ms,
  p95 13.18 ms; cold first frame 240.77 ms. At 50%: median 3.13 ms,
  p95 4.94 ms (14 warm frames). These are local compositor timings, **not FPS**.
- Re-measured after the warm-up budget (3 September 2026), same 1280×720 window,
  Debug: Sable Row at 155% 29 warm frames, median 12.64 ms, p95 16.00 ms, cold
  first frame **9.87 ms** (was 240.77 ms — the cold frame now defers the bulk of
  its conversions instead of doing them all at once). Office: median 3.21 ms,
  p95 4.49 ms, cold 6.91 ms. Warm medians are within run-to-run noise of the
  numbers above; the cold frame is the change.
- Area entry, `RAINSHADOW_TRACE_LOAD=1`, Debug, office reached by playing the
  intro through:

  | phase | before | after |
  | --- | --- | --- |
  | `init.ClientActorNode` | 21 694 ms | 4 ms |
  | `router.makeScene office` | 21 889 ms | 204 ms |
  | `scene.buildScene` | 672 ms | 307 ms |
  | office entry, total | ~22.8 s | ~0.5 s |

  The whole of the old figure was Super xBR prefiltering Lila's 25 frames twice
  each on the main thread. See AGENTS.md, "Bundle v02".

The office's current actor/default-camera framing mismatch was observed during
capture and left alone. `RAINSHADOW_CAPTURE_FOCUS=actor` is a diagnostic camera
override, not a room or navigation fix.

## Reproduce

```sh
python3 ArtSource/Processing/qa_ie_software_blit.py --gemrb /path/to/pinned/gemrb
python3 ArtSource/Processing/qa_ie_native_compositor.py
swift ArtSource/Processing/qa_ie_blit_shader.swift
```

On the Debug macOS app, set `RAINSHADOW_CAPTURE=<absolute PNG path>`,
`RAINSHADOW_CAPTURE_MODE=native`, `RAINSHADOW_NATIVE_QA=1`,
`RAINSHADOW_START_SCENE=city`, `RAINSHADOW_CAPTURE_SIZE=1280x720`,
`RAINSHADOW_CAPTURE_ZOOM=155`, `RAINSHADOW_NATIVE_WARM_FRAMES=30`.
The native mode exports exact framebuffer pixels, **without HUD or final display
scaling**. The ordinary camera capture and actual-window review are distinct.

Native PNGs and compositor/capture logs are saved under
`ArtSource/Generated/Characters/Detective/ImportedVossReplacementRuntimeV13/Review/NativeWorld/`.

No Blender file, mask, index bundle, palette row or compatibility atlas was
regenerated. GemRB attribution and the unresolved shipping-license decision
remain in `ThirdPartyNotices.md` and `NavigationOpenQuestions.md`.
