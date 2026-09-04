# Imported Voss material regions — indexed proof V03

## Scope

This pass authors the seven Infinity Engine material regions on the supplied
rigged Meshy FBX and proves that they survive RainShadow's indexed-colour
pipeline in one southwest idle frame. It is an isolated approval artifact. It
does not replace `voss_masters.py`, regenerate the 204-frame Voss inventory or
write any installed runtime resource.

The input is
`/Users/laurensvanoorschot/Downloads/Meshy_AI_Character_output.fbx`, SHA-256
`2e05b86d0f44777895815ff74001337b1255d919616c7b5c32a46dbba1f3892f`.
The retargeted V02 baseline remains byte-identical at SHA-256
`03c44fccbbf776f377b20390d45e63332ac7b6703496ec401655987a425af9ea`.

## Authored regions

The FBX is one connected, untextured mesh, so the source contains no recoverable
material boundaries. `author_meshy_voss_material_regions_v03.py` assigns every
rest-mesh polygon to exactly one region using its supplied deform weights and
local geometry. The slots use the production IE order:

| mask | region | rest-mesh faces | IE range |
|---:|---|---:|---|
| 1 | shoes | 1,110 | METAL |
| 2 | shirt | 28 | MINOR |
| 3 | tie | 119 | MAJOR |
| 4 | skin | 1,459 | SKIN |
| 5 | trousers | 3,654 | LEATHER |
| 6 | coat and waistcoat | 3,565 | ARMOR |
| 7 | hair | 375 | HAIR |
| 8 | baked hard shadow | render pass | fixed shadow index |

Index zero is background only. The narrow shirt aperture deliberately leaves
the lapels in the coat region. The hair follows CHMC4's asymmetric silhouette:
the viewer-left temple opens quickly, while the viewer-right side/back lock
descends toward the jaw. The rear converges into a shallow nape arc, separated
from the coat by visible skin. The 375 polygons form one connected cap and no
hair polygon shares an edge with the coat. The top crown may reach the front
plane, but the forehead/face band below it is a hard exclusion; the brow, nose,
cheeks and jaw remain skin. The boundary is designed to remain readable after
reduction rather than following sculpt grooves that disappear at native size.

The authored blend retains all 5,149 vertices, 10,310 polygons, 24 bones, the
supplied complete skin weights, one UV layer and the V02 idle, walk, seated-idle
and stand-up actions.

## Native result

`render_meshy_voss_material_proof_v03.py` renders seven western idle beauty and
flat material-ID diagnostics from S through N with the locked V23 BGEE camera
and lighting. The indexed approval frame remains SW only; the extra angles
expose crown, temple and nape-boundary mistakes that a single three-quarter
view can hide.
`review_meshy_voss_material_proof_v03.py` then runs the same mask-aware native
reduction and indexed encoder used by the accepted Voss pipeline.

The proof passes these gates:

- mask is paletted PNG data with exactly labels 0–8;
- all seven materials and the shadow survive native reduction;
- the asymmetric hair cap remains one connected rest-mesh component and 43
  hair pixels survive in the native SW frame;
- no authored hair face shares an edge with a coat face;
- the body is exactly 64 native rows and 27 pixels wide on a 90×108 canvas;
- the active Voss gradient rows are reused unchanged: 138, 5, 247, 159, 138,
  100 and 1;
- source FBX and V02 retarget proof hashes remain unchanged;
- all 250 existing Voss runtime files fingerprint identically before and after.

The matching reference panel uses `CHMC4G12`, cycle 20, phase 0. At equal body
height the rigged model is broader and carries a longer, heavier coat silhouette
than CHMC4. That difference belongs to mesh geometry and costume design, not to
the material-mask implementation.

## Approval boundary

This proves the material-region workflow only for one SW idle phase. Production
approval still requires every phase and authored direction to be inspected for
hairline, shirt/tie visibility, back-facing topology and deformation at the
coat, belt, shoulders, hips and knees. The strict full-inventory mask, palette
and round-trip gates remain mandatory before any runtime install.

The seven-angle idle diagnostic now passes the rear-boundary review: the former
diagonal nape seam, rear spike and hair-on-collar fan are removed; viewer-right
rear coverage is one polygon loop lower; and a skin nape separates hair from
coat in NW/NNW/N. This remains an idle material proof, not approval of every
animation phase or a runtime install.

## Reproduce

```sh
/Applications/Blender.app/Contents/MacOS/Blender --background \
  ArtSource/Generated/Characters/Detective/ImportedVossRiggedProofV02/meshy_voss_retarget_proof_v02.blend \
  --python-exit-code 1 \
  --python ArtSource/Blender/author_meshy_voss_material_regions_v03.py
/Applications/Blender.app/Contents/MacOS/Blender --background \
  ArtSource/Generated/Characters/Detective/ImportedVossMaterialProofV03/meshy_voss_material_proof_v03.blend \
  --python-exit-code 1 \
  --python ArtSource/Processing/render_meshy_voss_material_proof_v03.py
python3 -B ArtSource/Processing/review_meshy_voss_material_proof_v03.py
```
