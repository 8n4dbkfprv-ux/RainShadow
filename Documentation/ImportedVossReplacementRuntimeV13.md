# Replacement Voss V13 — native material relief

Status on 2 September 2026: installed. Superseded on 3 September 2026 by
V14 (`Documentation/ImportedVossReplacementRuntimeV14.md`). V13 keeps
V12's V11 model, rig, animation, UVs, material assignments, 204 categorical
masks, projection registration and lighting. It changes value contrast only on
the 64-row native body plane: material-local relief immediately before indexed
palette encoding, followed by fixed clustering inside selected material runs.

Presentation correction on 3 September 2026: Voss now follows BG:EE's current
non-nearest creature path. The indexed plane is resolved at its native crop
size and SpriteKit linearly samples it once into the unchanged registered body.
Super xBR is no longer used by Voss at runtime; compatibility atlas PNGs remain
rollback payloads and are not the indexed presentation authority.

## Why

V12's high-resolution render contained coat, sleeve and hair modelling, but the
64-row reduction averaged too much of it into broad, clean value fields. In the
SW comparison, the mean adjacent shade change within one material was 0.63
palette steps, versus 0.98 in CHMC4. Merely raising the key light made the coat
brighter and flatter; a more specular trial did not recover the missing form.

V13 reinforces value variation that already exists in each material. A small
Gaussian neighbourhood is computed separately for labels 1–7; the difference
between a pixel and its same-material local mean is increased with bounded,
material-specific gains. The operation never samples across material borders,
never changes alpha or labels, and adds no noise, outline or painted detail.
The 3 September presentation pass keeps the fitted relief at 1.25, then applies
a 1.12× contrast map inside the existing 12-shade runs for shoes, trousers,
coat/waistcoat and hair. Skin, shirt and tie are deliberately untouched. The SW
measurement moves from 0.99 to 1.04; the same BG CHMC4 reference measures 0.98.
A rejected global-relief increase failed the existing 64-colour clip gate. The
accepted fixed shade map instead reduces front-idle palette inventories from 64
to 60 and cannot cross a material boundary. It restores definition lost to
display interpolation without noise or silhouette sharpening. The agreement is
a diagnostic, not a claim that different costumes and poses are identical.

## Authority and colour

The 3 September native-camera calibration subsequently removed the fixed
9%-of-window enlargement without rebaking this bundle. At 100% play zoom the
standing body is 64 logical points high, and only scene zoom changes its size.
Registered world dimensions and pivots remain unchanged. See
`NativeSpriteCameraCalibration.md` for verification and the remaining
SpriteKit/Retina and source-crop rounding differences from native BAM blitting.

Installer: `ArtSource/Processing/install_voss_replacement_v13.py`.
Surface function: `ArtSource/Processing/voss_surface_relief.py`.
Masters: V11 `FullAnimationAudit`, all 204 source/mask pairs, unchanged.

`fit_voss_surface_v13_gradients.py` samples the treated native plane over all
168 authored poses and fits in CIE94. Six V12 rows remain optimal. The cream
shirt moves from neutral row 248 to warm row 107, giving V13 rows
`(138, 107, 144, 159, 138, 100, 22)`.

## Gates

The full 248-cell stage passes V12's geometry, registration, head, phase,
foot-exchange, loop-closure, seat-chain and rear-material gates. Every Voss
frame also resolves byte-exactly from its native index plane without a
prefilter. Direct V12/V13 bundle comparison reports zero geometry differences
and zero material-topology differences over all 248 cells. The palette port,
complete mask/encode audit and the V13 unit regressions also pass.

The 3 September macOS build and shipping-renderer capture confirm the packaged
bundle declares `asset_authority: replacement_v13` and
`texture_filter: linear`. All 250 installed files match the reviewed stage;
224 non-empty compatibility PNGs and the index blob carry the strengthened shade
clusters; the 24 empty cells remain byte-identical. The pre-clustering
direct-linear runtime is preserved at
`ImportedVossReplacementRuntimeV13/PriorRuntime/replacement-v13-20260903T082122Z`.

Review artifacts live under
`ArtSource/Generated/Characters/Detective/ImportedVossReplacementRuntimeV13`.
The small BG comparison and rejected lighting variants live in the adjacent
`ImportedVossSurfaceV13` proof directory.

```sh
python3 ArtSource/Processing/fit_voss_surface_v13_gradients.py
python3 ArtSource/Processing/install_voss_replacement_v13.py stage
python3 ArtSource/Processing/review_voss_replacement_v13.py
RAINSHADOW_VOSS_ATLAS_ROOT="$PWD/ArtSource/Generated/Characters/Detective/ImportedVossReplacementRuntimeV13/Staging" \
  swift test -c release --scratch-path /tmp/RainShadowSwiftPMVossV13Release \
  --filter 'VossSeatScaleTests|VossAtlasV20ValidationTests|VossWardrobeColorTests|IEPaletteTests|IEResampleTests'
python3 ArtSource/Processing/install_voss_replacement_v13.py install --confirm-runtime-replace V13
```

The stage report hashes the relief code, palette fit, V11 Blender authority,
every source/mask pair and every output. Installation still requires a review
receipt bound to that exact bundle and preserves the complete prior runtime.
V12 and V22 remain explicit historical installers.
