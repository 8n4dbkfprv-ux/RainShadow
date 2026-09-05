# Meshy staged style audit

Examined the user's `voss_standing_idle_ssw_02.png`, its matching
`Frames/idle_ssw_02.png`, the staging/encoding code, GemRB's BAM import and
sprite drawing code, and Near Infinity's resize converter.

The staging PNG's appearance is partly introduced by our processing and partly
already present in the authored Blender materials. A compatible palette and
blitter do not establish a match to Baldur's Gate's art direction.

## Measured processing chain

The source body occupies 360 rows. `crunch_avatar` reduces this to a 35×64
native image, assigns each pixel to one of its material's 12 selected shades,
then makes the 200-row compatibility image with Super xBR. The attached PNG
is that enlarged compatibility image, not the raw native index plane.

For this frame, 508 of 706 coat pixels (71.95%) land on shade 10. Five coat
shades are used overall. This collapses the subtle lighting into large uniform
regions. Hair similarly puts 44 of 65 pixels into one shade. These measurements
describe this frame, not every animation or a measured BG reference population.

Before staging, `build_meshy_sep05_cleanup_v01.uv_surface` replaces surface
textures with solid colors except for the face. It uses a shared roughness of
0.80 and specular level of 0.23. Fine clothing surface detail therefore cannot
survive into the sprites. The source render itself has broad, subdued shading.

Although the crunch spec contains `soften_radius=1.2`, this staging call uses
`crunch_avatar`, whose reduction path does not call the Gaussian softener.
Do not attribute this example to that unused setting.

Diagnostic comparison, all bodies displayed at a common 200-pixel height:
`ArtSource/Generated/Characters/Detective/MeshySep05StyleAudit/processing_comparison.png`.
Measurements are alongside it in `metrics.json`. Nearest enlargement in the
middle two panels exposes native samples; it is an inspection method.

## Upstream evidence and limits

- [IESDP BAM V1](https://gibberlings3.github.io/iesdp/file_formats/ie_formats/bam_v1.htm)
  stores per-frame width, height, center and indexed pixels. There is no
  mandatory 64-row humanoid size. Our 64-row choice was calibrated to a specific
  decoded reference family, not specified by the format.
- [GemRB BAMImporter](https://github.com/gemrb/gemrb/blob/1c45c185/gemrb/plugins/BAMImporter/BAMImporter.cpp)
  consumes authored BAM image data. It is not BioWare's offline model-to-sprite
  production pipeline.
- [GemRB CharAnimations](https://github.com/gemrb/gemrb/blob/1c45c185/gemrb/core/CharAnimations.cpp)
  selects palettes and recolors animation parts. Palette replacement preserves
  the authored shade pattern; it does not generate garment or facial detail.
- [GemRB SDLVideo](https://github.com/gemrb/gemrb/blob/1c45c185/gemrb/plugins/SDLVideo/SDLVideo.cpp)
  uses `spr->Frame.size` for both source and destination in `BlitGameSprite`.
  This path does not apply our reduction, shade fitting, or Super xBR bake.
- [Near Infinity resize converter](https://github.com/Argent77/NearInfinity/blob/master/src/org/infinity/gui/converter/bam/BamFilterTransformResize.java)
  supplies Super xBR as a conversion option. Its availability does not establish
  that Baldur's Gate used it to author or display the user's screenshot.

GemRB is a reimplementation, and this evidence does not establish the exact
proprietary BG:EE zoom/filter settings in the screenshot or BioWare's historical
offline material/lighting setup.

## Recommended next authoring pass

Keep runtime rendering changes separate from this asset problem. Start with one
standing pose: retain or author material detail, strengthen readable folds and
lighting, and fit palette ramps that preserve those values. Compare the native
indexed result directly with decoded BG character frames at matched body scale,
before applying any display enlargement. Review that one pose before rebuilding
the entire animation set. Increasing resolution or adding noise alone would not
establish the requested style.

The initial audit changed no source model, production processing recipe, or runtime art.

## Applied follow-up: remove Super xBR

At the user's request, the Meshy V03 staging recipe now uses nearest-neighbor
compatibility enlargement. Its derived mirrors and desk splits use that same
mode; review previews also use nearest sampling. Historical installers retain
their explicit/default historical behavior so pinned rebakes remain reproducible.

All 248 rebuilt compatibility PNGs were independently compared against direct
palette lookup of their bundled native indices followed by nearest enlargement:
every pixel matched, apart from the deliberately excluded atlas corner markers.
The complete native index blob is byte-identical to the previous stage.
`nearest_validation.json` records this check. `StagingBeforeNearest` preserves
the prior candidate for comparison.

The current runtime loader already resolves native indices directly and does
not execute Super xBR. Its legacy `texture_filter=linear` metadata remains
unchanged; `compatibility_filter=nearest` records the offline atlas choice.
The native software framebuffer and its rendering arithmetic were not changed.
The 64-row authored source resolution and palette fitting remain separate
authoring choices, not requirements imposed by GemRB. No runtime assets were
installed by this follow-up.
