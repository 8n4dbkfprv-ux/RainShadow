# Replacement Voss V14 — face black-point compression

Status on 3 September 2026: **installed**. V14 keeps V13's V11 model, rig,
animation, UVs, material assignments, 204 categorical masks, projection
registration, lighting, native-plane relief and linear presentation. It
changes only the darkest end of the skin and hair 12-shade rows after
indexed encoding, so isolated last-ramp samples no longer read as holes on
the 64-row face.

## Why

V13's native relief recovered coat and hair form, but the south-facing face
still contained the last two hair-ramp shades where the fringe crosses the
brow, plus the darkest skin shade in the eye/nose well. At native size those
pixels are shade 11; after linear display sampling they read as black
abnormalities. A first V14 candidate lifted only skin and locked every hair
index to V13. The measured change was real and the displayed face still
looked the same, because the dominant marks were hair.

The accepted map keeps eight readable dark clusters and folds only the
near-black tail:

- skin shades `7–11` → `6, 7, 7, 7, 7`
- hair shades `8–11` → `7, 7, 8, 8`

Geometry, masks, UVs, lighting and every native index outside skin and hair
stay byte-identical to V13.

## Authority and colour

Installer: `ArtSource/Processing/install_voss_replacement_v14.py`.
Source correction: `ArtSource/Processing/render_meshy_voss_replacement_v14.py`.
Masters: V11 `FullAnimationAudit` masks, unchanged; V14 face frames live in
`ImportedVossReplacementFaceV14/FullAnimationAudit`.

Palette rows remain V13's CIE94 fit `(138, 107, 144, 159, 138, 100, 22)`.
Presentation remains native indexed RGBA sampled directly by SpriteKit
linear filtering; Super xBR is not used by Voss at runtime.

## Gates

The full 248-cell stage passes V12's geometry, registration, head, phase,
foot-exchange, loop-closure, seat-chain and rear-material gates. Direct
V13/V14 bundle comparison reports zero geometry differences, zero material
topology differences and zero native-index differences outside skin and
hair: 216 frames / 11,950 native pixels changed (3,051 skin, 8,899 hair).
On the S-facing native face crop, V13 skin/hair deepest shade 11 with 12
and 8 pixels in shades 9–11; V14 deepest 7 / 8 with zero pixels in 9–11.

The palette port, complete 204-mask encode audit, shadow contract, V14 unit
regressions and the replacement Swift suites also pass. The packaged
bundle declares `asset_authority: replacement_v14` and
`texture_filter: linear`. V13 remains at
`ImportedVossReplacementRuntimeV13` and in the V14 prior-runtime backup
`ImportedVossReplacementRuntimeV14/PriorRuntime/replacement-v14-20260903T193755Z`.

Review artifacts live under
`ArtSource/Generated/Characters/Detective/ImportedVossReplacementRuntimeV14`.

```sh
python3 ArtSource/Processing/install_voss_replacement_v14.py stage
python3 ArtSource/Processing/review_voss_replacement_v14.py
RAINSHADOW_VOSS_ATLAS_ROOT="$PWD/ArtSource/Generated/Characters/Detective/ImportedVossReplacementRuntimeV14/Staging" \
  swift test -c release --scratch-path /tmp/RainShadowSwiftPMVossV14Release \
  --filter 'VossSeatScaleTests|VossAtlasV20ValidationTests|VossWardrobeColorTests|IEPaletteTests|IEResampleTests'
python3 ArtSource/Processing/install_voss_replacement_v14.py install --confirm-runtime-replace V14
```

The stage report hashes the face authority, palette fit, V11 Blender
authority, every source/mask pair and every output. Installation still
requires a review receipt bound to that exact bundle and preserves the
complete prior runtime. V12, V13 and V22 remain explicit historical
installers.
