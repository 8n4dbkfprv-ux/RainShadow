# Noir concept V01 — AR0809 scale audit

## Result

The concept is not at AR0809 object scale. The generated room envelope is also
larger than the installed AR0809-registered shell, so there are two independent
errors: a global room zoom and oversized furnishings.

All plate measurements below are on the normalized 4096x2304 concept. Generated
object bounds are approximate (about ±5–10%) because the paint-over is a single
flattened RGB image. Target bounds come from the AR0809-registered office layout
and its 178 px rendered-adult scale.

## Room and projection

| Measurement | Noir concept | Installed AR0809 shell | Difference |
|---|---:|---:|---:|
| Non-black room envelope | 3159x2221 px | 2701x1868 px | 1.170x wide, 1.189x deep |
| Measured positive ground axis | +31.34 deg | +31.72 deg | -0.38 deg |
| Measured negative ground axis | -43.62 deg | -42.24 deg | -1.38 deg |

The shell must be restored from the installed plate, not uniformly resized.
Plane-local registration owns the exact AR0809 control points.

## Furniture and dressing

| Element | Approx. concept bounds | AR0809/runtime target | Keep this fraction of current size |
|---|---:|---:|---:|
| Detective desk | 857x551 px | 204x176 px | about 28% |
| Rear-facing desk chair | 404x438 px | 130x146 px | about 33% |
| Each visitor chair | about 306x350 px | 120–125x135–141 px | 38–41% |
| Burgundy rug | about 1726x947 px | 500x275 px | about 29% |
| Two filing cabinets together | about 497x526 px | about 197x203 px | about 39% |
| Low bookcase/credenza | about 490x379 px | about 125x111 px | about 28% |
| Case board / wall map mass | about 360x375 px | 84x105 px per major board | 23–28% |
| Coat-rack-and-coat mass | about 404x514 px | about 64x157 px | narrow and reduce to about 30% height-scale |
| Wastebasket | about 164x220 px | 46x57 px | about 27% |
| Archive boxes | roughly 180–240 px across | 52–86x64–78 px | about 35–40% |

## Desktop objects

| Element | Approx. concept bounds | Target | Keep this fraction of current size |
|---|---:|---:|---:|
| Banker lamp | about 225x196 px | 50x61 px | about 27% |
| Rotary telephone | about 220x127 px | 49x35 px | about 25% |
| Typewriter | about 269x220 px | 55x46 px | about 20–22% |
| Paper/file clusters | about 250–320 px across | 56–82 px across | about 25–30% |
| Ashtray | about 70–90 px across | 24x18 px | about 25–30% |

## Native AR0809 cross-check

Measured directly in the supplied 896x640 reference:

- work tables are roughly 81–94 px across and 60–81 px high on screen;
- chairs and stools are roughly 17–28 px wide and 35–53 px high;
- the two rugs are roughly 151–188 px wide and 127–143 px deep;
- individual crate faces are roughly 30–42 px;
- desktop papers, bottles and lights are generally 8–20 px features.

Mapping the reference room envelope to the installed 4096 plate is about 3.21x.
That independently puts a common table near 260–300 px across, a chair near
55–90 px wide, a rug near 485–600 px across, and small tabletop features near
25–65 px. This agrees with the registered runtime targets and rejects the
concept's 857 px desk, 404 px chair and 200+ px tabletop objects.

## Production correction

1. Start again from the unchanged installed shell pixels.
2. Composite registered desk/chair art at the authored seat anchor; do not
   extract or shrink the generated versions.
3. Use the target plate bounds above for every other prop.
4. Keep the desk, chair and actor occluders split for seated/stand-up sorting.
5. Re-run projection, density, navigation, seated-fit and occlusion QA after the
   new composition.
