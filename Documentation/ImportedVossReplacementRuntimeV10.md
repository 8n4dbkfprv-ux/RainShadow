# Replacement Voss V10 — runtime installation

## Authority and scope

V10 derives from the user's manually edited V09 replacement model. The user
requested installation on 2 September 2026. Until the complete staged runtime
payload passes, the existing V22 runtime remains authoritative.

The source chain is:

1. `Meshy_AI_Character_output-2.fbx` supplies the replacement geometry.
2. V08 retargets the Voss actions and supplies seven categorical material slots
   with value/bump modulation from the packed texture.
3. V09 freezes and replays the user's 5,706 face-assignment changes onto V08.
4. V10 reassigns 105 measured rear-collar faces (94 shirt, 11 tie) to coat.
   Geometry, UVs, rig and actions are unchanged. This retains 86.1% of the
   measured front shirt/tie pixels while removing rear-facing trim leakage.

The frozen V10 Blender authority is
`ArtSource/Generated/Characters/Detective/ImportedVossReplacementRuntimeV10/meshy_voss_replacement_runtime_v10.blend`.
Its SHA-256 is
`780f6aa720c4763af0fc035e678c0de8e5f80572fe3cb21658d4dc791def5bc8`.
The material-assignment SHA-256 is
`8287f4ba2a32906892d4619bf1c8681568092129a1c8a73a3a9d9fee5c06a0c1`.

The builder is `ArtSource/Blender/build_meshy_voss_replacement_runtime_v10.py`.
It validates the exact V09 authority hash and the measured face selection
before changing those assignments. The user's original V09 file is untouched.

## Render and palette contract

V10 keeps the BGEE_V2 64-row indexed craft and the existing 512-pixel canvas,
200-pixel standing body, foot row 433 and 180-world-unit display canvas. The
runtime continues to consume `avatar-v02.json`/`.indices`; compatibility PNGs
are rendered from those same native index planes with Super xBR.

The CIE94 fit over the full source inventory is:

| IE slot | Material | Gradient row |
|---|---|---:|
| METAL | shoes | 138 |
| MINOR | shirt | 248 |
| MAJOR | tie | 144 |
| SKIN | skin | 159 |
| LEATHER | trousers | 138 |
| ARMOR | coat/waistcoat | 100 |
| HAIR | hair | 22 |

The 204 source masks retain the Blender cast-shadow label for provenance.
The installer removes it, paired with its source pixels, **before** any
stabilization, scaling or indexing. `ContactShadowNode` remains the sole
runtime shadow owner. A mask-labelled cast shadow must not affect a body-height,
anchor-width or per-material-share measurement.

The front/back native body silhouettes both measure 35×64 (ratio 0.546875).
Their anchor band is therefore 0.53–0.56; this records the replacement model's
actual shape, not the previous V22 figure's narrower 0.43–0.46 band. Standing
height, registration, motion coherence and seated-chain gates remain strict.

## Validation

The complete render audit contains 168 authored master/mask pairs plus 36
byte-identical reverse sit-down pairs. It passes all 204 categorical-mask
checks and all 68 exact rear topology checks. Every walk has eight distinct
native planes and every stand-up has twelve; breathing loops have three to
five. A deterministic breathing loop can repeat a pose, so the old ImageGen
requirement for a different file hash in every source cell is not used as an
animation test.

`qa_ie_avatar_encode.py` now excludes a cast shadow from its body sample and
applies the runtime rear rule to NW/NNW/N upright clips and north seat clips:
zero shirt/tie pixels and no more than 3% skin. The 0.8% skin minimum remains
on views exposing the face. Previously the tool both counted a shadow as an
eighth garment and demanded a front-face minimum on rear views.

Pre-install checks completed:

- complete V10 source colour/material audit: passed;
- palette-port and shadow-contract QA: passed;
- five V10 mask/installer handoff regression tests: passed;
- 18 Swift palette and resampling tests: passed.

The full compatibility-payload geometry/animation gate and installation receipt
must be recorded below before calling V10 installed.

## Commands

```sh
python3 ArtSource/Processing/test_voss_replacement_v10.py
python3 ArtSource/Processing/install_voss_replacement_v10.py validate
python3 ArtSource/Processing/install_voss_replacement_v10.py stage
python3 ArtSource/Processing/install_voss_replacement_v10.py install --confirm-runtime-replace V10
```

The installer stages all 248 compatibility cells and the raw indexed bundle,
checks their exact round trip, then backs up and swaps all six runtime payloads
using the existing rollback transaction. Failed staging outputs are retained
under `FailedStaging-*` for diagnosis, never installed.

## Installation result — blocked before runtime replacement

All 248 cells and the indexed bundle were built under
`ArtSource/Generated/Characters/Detective/ImportedVossReplacementRuntimeV10/FailedStaging-b73472ec/`.
The exact staged rear-topology check passed and the bundle contains no embedded
shadow. No install transaction was run: all 250 existing runtime files remain
byte-for-byte unchanged against the pre-audit fingerprint.

The full staging gate found 13 issues, grouped as follows:

- SSW walking top-10%-silhouette width pulses 1.536×; its limit is 1.32× plus
  one craft sample. Measured widths are 28–43 canvas pixels, against 40.085
  allowed. A diagnostic using actual hair/upper-skin labels instead measures
  30.09–33.45 pixels on the source: the fixed top band is including shoulder
  pixels. Do not interpret this as proven skull deformation.
- NNW walk planted-foot sequence is `RRRLLLLR`, a four-frame repeated lead
  against the maximum of three.
- Eight standing-idle directions collapse to fewer than four distinct
  processed cells after the legacy idle stabilization. The isolated native
  audit's three-to-four-plane breathing result was not sufficient to prove
  that final compatibility gate.
- All three seated chains exceed the 18–29-pixel head-width band at some
  point: NE 40–49, SE 29–39, N 25–31. The NE seated hair alone is approximately
  43.8 canvas pixels wide versus 34.5 in the matching NW standing reference,
  so this is not solely the silhouette-band heuristic.

Swift independently confirmed the standing/walk raster, body-height, foot-row
and registration gates pass, and reproduced the two walking failures. The
index-to-RGBA round-trip stage was not reached because geometry failed first.

The next work is an animation/scale handoff pass followed by complete restaging.
Do not loosen the geometry limits or install these failed outputs. The user's
V09 edit, the frozen V10 mask authority, current active master selection and
current runtime palette have not been changed by this staging attempt.

The user approved that follow-up. See `ImportedVossReplacementAnimationV11.md`
for the completed idle/foot-exchange/facing corrections and the remaining
projection-scale decision. V11 is a separate, non-installed derivative and
does not alter this failed V10 stage or the frozen mask authority.
