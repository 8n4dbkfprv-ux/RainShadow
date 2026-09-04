# GemRB software sprite reference

3 September 2026. The selected exactness target is GemRB at
`1c45c1850d9b5d61a23b3a569499ef57543e2c3f`, not an unspecified mixture of the
original Infinity Engine, BG:EE, GemRB SDL1 and GemRB OpenGL.

## Status — reference implemented and integrated into the native world path

`IESoftwareBlit` implements the decoded RGBA software pixel pipeline and native
integer frame placement/clipping. It produces an explicit top-down byte buffer.
It is independently compared to **compiled, verbatim pinned C++**, not just to a
second handwritten formula. The C++ adapter supplies containers, traversal and
file IO; the arithmetic, intersection, placement and SDL1 clipping blocks being
tested are extracted from the pinned commit. This is not a booted SDL backend.

The subsequent integration is documented in `NativeWorldRenderer.md`. Playable
areas now use the shared native framebuffer by default, with an explicit legacy
rollback switch. The reference test itself remains independent of that adapter.
The reference adapter reads the existing native indices/palette and quantises a
copy of the registered pivot. No Blender model, mask, palette, index plane,
compatibility atlas, registered seat geometry or save data was changed.

## Exact contract and evidence

From [SDLVideo.cpp](https://github.com/gemrb/gemrb/blob/1c45c185/gemrb/plugins/SDLVideo/SDLVideo.cpp),
`BlitGameSprite` creates the destination with the **native source size**:

```cpp
Region srect(Point(0, 0), spr->Frame.size);
Region drect = Region(p - spr->Frame.origin, spr->Frame.size);
```

The reference keeps integer top-down coordinates, out-of-crop pivots, colour-key
index zero, and SDL1's clipped-region mirror traversal. It also preserves the
SDL1 clipping quirk: when both ends are clipped, `src.x/src.y` advances by the
**total** trim, not just the left/top trim. This is intentionally not corrected.

From [Pixels.h](https://github.com/gemrb/gemrb/blob/1c45c185/gemrb/core/Video/Pixels.h):

```cpp
#define DIV255(x) ((x + 1 + (x >> 8)) >> 8)
dst.r = DIV255(src.a * src.r) + DIV255((255 - src.a) * dst.r);
```

Each product truncates separately. A 100-valued channel at alpha 128 over another
100-valued channel becomes **99**, not 100. The port retains the alpha result,
the existing tint/grey/sepia arithmetic, grey's precedence over sepia, and the
pipeline's byte-wrapping raw-mask expression, FIXME included. The raw mask is an
already resolved alpha iterator, **not** the game's wall-stencil texture.

Only the decoded RGBA source-over pipeline is claimed. Unsupported flags throw.
SDL's `SDL_LowerBlit` fast path, the separate RLE blender, additive/multiply and
half-transparency dispatch, and stencil generation are not silently substituted
with this function. Those branches require their own differential fixtures.

### RainShadow registration adapter

The imported model is not a BAM. Its native plane and registration metadata live
in different spaces. `softwareFrame(for:)` uses the bundle's **single shared**
`texture_scale` (3.125 for V13) to map the pivot into native coordinates, then
rounds to the nearest integer, ties away from zero. It never derives a new scale
from each crop or pose. Width/height are the native plane's actual dimensions.

This rounding is an explicit RainShadow adaptation, not evidence of GemRB's BAM
importer rounding floats. BAM centres are already integers. Every nonempty frame
is checked to stay within 0.5 native pixels of the authored pivot on each axis.
The original registered metadata and shipping node remain unchanged.

## Measured results

- **1,296 differential cases**, including all 248 installed Voss frames
  (224 nonempty), random/adversarial geometry, alpha, masks and shader modes.
- **37,348,160 RGBA bytes compared; zero mismatches** against compiled C++.
- Seven reference tests passed; 50 colour, camera and seat-registration
  regression tests passed. The existing shader QA passed 165 colour pairs plus
  its stencil checks. macOS and iOS Simulator Debug builds succeeded.

An additional isolated SpriteKit/Metal test renders the same SW frame, palette,
tint and background into an explicitly sized 96x96 **BGRA8Unorm** attachment:

| Presentation | Pixels different from the software reference |
|---|---:|
| Registered fractional geometry + linear sampling | 853 / 9,216 |
| Integer native geometry + nearest sampling | 0 / 9,216 |
| Precomposed opaque software buffer, unblended 1:1 quad | 0 / 9,216 |

The first comparison changes **placement and filtering together**; it does not
assign all 853 differences to smoothing alone. The two exact GPU results apply
to this opaque/binary-alpha frame at 100%, not all frames, fades, zoom levels,
walls or device displays. This is a controlled adapter test using the production
shader source and installed metadata, **not a live-game screenshot**.

`SKView.texture(from:)` cannot be assumed to return logical-size pixels. Even
`SKRenderer` with `resizeFill` adopted a 48-point scene on a 96-pixel Retina
attachment here. The QA uses a fixed 96-unit scene with `.fill`, a 96-pixel Metal
viewport, waits for texture upload, and reads attachment bytes directly. No
resizing or CoreGraphics conversion intervenes in the byte comparison.

## Limits on a full runtime exactness claim

1. The live scene queue now reaches a native framebuffer, including backgrounds,
   actor layers, shadows and cover. Authored source rasterisation is still an adapter.
2. Verify each additional blend/stencil branch against its selected software source.
   SpriteKit's ordinary fractional-alpha blending is not `ShaderBlend`.
3. Whole-buffer nearest zoom is now defined. This does not establish equivalence
   to proprietary Beamdog backends or other GemRB renderer branches.

The reference is now a runnable acceptance target for that work. Do not relabel
the current game "pixel-exact Infinity Engine rendering" on the strength of the
primitive test or the single-frame Metal result. GemRB is a reimplementation;
agreement with it does not prove agreement with Beamdog's proprietary BG:EE.

## Reproduce

```sh
python3 ArtSource/Processing/qa_ie_software_blit.py --gemrb /path/to/local/gemrb
```

The checkout needs the pinned commit; its working-tree contents are not used.
No GitHub plugin, SDL installation or network is needed once that commit exists.
Pass `--skip-presentation` for only the C++/Swift reference gate.

Reports, native renders and the labelled 4x-nearest comparison are under
`ArtSource/Generated/Characters/Detective/ImportedVossReplacementRuntimeV13/Review/SoftwareReference`.
The report records upstream file hashes and the exact compiled C++ hash.
The 4x contact sheet is for inspection only, never an input to the metric.
