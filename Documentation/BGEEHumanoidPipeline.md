# BG:EE humanoid pipeline

**Status: active (`crunch.ACTIVE = BGEE_V1`), installed 2026-08-21.**

## Measured reference

Infinity Engine BAM cells are variable-sized frames with their own width,
height, and centre coordinates; they are not fixed 512px squares. The format
also stores an indexed palette and a compressed-colour/transparency index. The
implementation used for cross-checking is GemRB's
[`BAMImporter.cpp`](https://github.com/gemrb/gemrb/blob/master/gemrb/plugins/BAMImporter/BAMImporter.cpp),
with field layout checked against the GitHub-hosted
[`BAM V1` IESDP specification](https://github.com/gibberlings3/iesdp/blob/master/file_formats/ie_formats/bam_v1.htm).

GemRB ships a representative medium-human BG walk resource,
[`CHMB1G11.BAM`](https://github.com/gemrb/gemrb/blob/master/demo/override/CHMB1G11.BAM),
in its public demo data. It was decoded frame by frame rather than judged from
a screenshot:

| Measurement | Result |
|---|---:|
| Stored frame | 44×71px |
| Walk frames measured | 90 |
| Nontransparent bounding-box height, including shadow | 53–67px |
| Crown to ground anchor | 52–60px; median 55px |
| Non-shadow silhouette width / height | median 0.427 |
| Nontransparent palette indices per frame | 44–59 |
| Nontransparent palette indices across the clip | 76 |

Those values are a representative craft target, not a claim that every IE
creature has one universal size. BAM frames are explicitly variable.

The measurement is repeatable without checking the reference BAM into this
repository:

```bash
python3 ArtSource/Processing/qa_infinity_bam_humanoid.py /path/to/CHMB1G11.BAM
```

## RainShadow comparison

Before this change, V15 retained all 200 vertical body samples and up to 128
colours. It preserved more source detail than the measured humanoid animation.
The runtime body itself was already correctly registered: a 200px visible body
inside a 512px cell displayed on a 180-unit node is **70.3125 world units**.
Changing that would invalidate door, furniture, desk, camera, and seated-pose
registration.

`BGEE_V1` therefore changes craft density without changing physical size:

| Contract | BG reference | RainShadow active |
|---|---:|---:|
| Native crown-to-ground craft | 52–60px (median 55) | 64px |
| Palette use | 44–59 indices/frame | 64-entry per-material budget |
| Alpha | indexed transparent colour | hard 1-bit silhouette plus existing alpha-1 sentinels |
| Runtime cell | variable | unchanged 512×512px |
| Registered standing body | variable | unchanged 200px |
| Runtime world height | game-specific | unchanged 70.3125 units |

The earlier RainShadow figures had the correct height but read too slender next
to the decoded reference. The active correction widens torso/coat rows by 15%
on the 64-row native craft, ramps in below the head, and ramps back to 1.0x at
the legs. It is not a stretch of the finished 512px atlas cell. Measured across
the installed animations:

| Runtime set | Before median width / height | Active median width / height |
|---|---:|---:|
| Voss standing idle | 0.352 | 0.383 |
| Voss walk | 0.375 | 0.398 |
| Lila arrival/departure | 0.345 | 0.360 |

The decoded `CHMB1G11` median is 0.427, but that is one male outfit and facing
mix rather than a universal humanoid width. The active figures now sit within
ordinary outfit/pose variation while retaining their distinct builds. Voss's
median head widths remain exactly 22px idle / 19px walk; every standing cell
remains 200px high with its foot at row 433.

64 rows is the smallest grid near the measured range that preserves Voss's
left/right planted-foot exchange in every one of RainShadow's nine authored
directions. A 56-row trial lost the WNW gait and repeated NNW foot leads. The
four-row margin over the reference maximum is therefore a motion-integrity
choice, not a scale increase: the result is still enlarged into the same 200px
registered body.

At the 1152-point reference viewport, the 9% BG:EE default displays the body at
about **103.7 points**. Camera zoom step 10 shows about **148.1 points**
(12.86%), providing the tighter original-BG1-like presentation without a second
asset bake. GemRB's EE-compatible 27-step zoom and five-percentage-point stride
are implemented in
[`GameControl.cpp`](https://github.com/gemrb/gemrb/blob/master/gemrb/core/GUI/GameControl.cpp)
and its 100% default is declared in
[`GameControl.h`](https://github.com/gemrb/gemrb/blob/master/gemrb/core/GUI/GameControl.h).

## Active recipe and invariants

- `native_rows = 64`, `colors = 64`, hard alpha, per-material ramp palette.
- `soften_radius = 1.8`, then highlight-side value contrast `1.35`.
- `torso_width_scale = 1.15`, ramped below the unchanged head and back to
  `lower_width_scale = 1.0` for the lower legs, feet, height, and ground contact.
- 512×512 cells, 200px standing body, foot row 433, anchor, node size, actor
  scale, and world registration are unchanged.
- SpriteKit uses linear filtering at play zoom; nearest sampling is used only
  while enlarging the native craft into the registered texture body.
- Voss V22 and all 25 Lila cells are rebuilt through the same active recipe.

Do not compare `native_rows / actor_world_height` with an area plate's
ground-plane pixels per world unit. Those pixels describe different projected
axes. Re-evaluate the native grid against decoded humanoid frames and motion QA,
while using the 200px registered body for physical scale.
