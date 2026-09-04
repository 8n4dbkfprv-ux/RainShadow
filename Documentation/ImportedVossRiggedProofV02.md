# Imported Voss rigged FBX — retarget proof V02

## Scope

The user supplied
`/Users/laurensvanoorschot/Downloads/Meshy_AI_Character_output.fbx` as a rigged
alternative to the 54 MB sculpt tested in V01. Its SHA-256 is
`2e05b86d0f44777895815ff74001337b1255d919616c7b5c32a46dbba1f3892f`.
The source remains read-only and byte-identical.

This is an isolated retarget proof. It does not replace `voss_masters.py`, alter
the V23 authority, write indexed atlases or touch installed runtime resources.

## Source assessment

The FBX is animation-ready geometry rather than a statue:

- 5,149 vertices / 10,310 polygons;
- one connected mesh;
- a 24-bone humanoid armature and matching armature modifier;
- 22 deform vertex groups, with every vertex weighted and sums in
  `0.99999986...1.00000016`;
- one UV set;
- one one-frame bind clip;
- no material slots, textures, colour attributes or shape keys.

This density is preferable to the V01 decimated proof's 79,983 vertices. The
FBX retains authored skin weights, so the production base no longer depends on
Blender's automatic heat bind.

## Retarget

`ArtSource/Blender/rig_meshy_voss_fbx_proof_v02.py` imports the FBX into an
empty scene, scales its evaluated body to the established 1.82-unit Voss height
and transfers V23's local rotational deltas through each source/target rest
frame. V23 image-space L/R labels cross to Meshy's anatomical L/R names while
preserving the actual X side.

The proof creates four native target-armature actions:

- idle, four frames;
- walk, eight frames;
- seated idle, eight frames;
- stand-up, twelve frames.

The temporary V23 source rig is deleted after baking. Every keyed pose is then
grounded at the rig-object layer against the evaluated FBX geometry. The final
stand-up frame is pixel-identical to idle frame zero, and all eight rendered
walk frames are distinct.

The supplied weights produce a cleaner first deformation than V01's automatic
bind, especially at elbows, knees and the seated hips. The coat remains one
continuous skinned surface, so its hem and belt still need manual inspection at
all nine authored directions. The FBX also carries less fine facial and hair
surface relief than the original high-density sculpt; the native 64-row render,
not a large clay preview, must decide whether any detail transfer is useful.

## Infinity Engine material masks

The user's correction is right: conventional PBR textures are not required for
the avatar colour model. RainShadow's accepted mask contract is categorical:

| mask | Blender category | IE range |
|---:|---|---|
| 1 | shoes | METAL |
| 2 | shirt | MINOR |
| 3 | tie | MAJOR |
| 4 | skin | SKIN |
| 5 | trousers | LEATHER |
| 6 | coat and waistcoat | ARMOR |
| 7 | hair | HAIR |
| 8 | baked shadow | fixed palette shadow index |

Index zero remains background only. Lighting selects one of twelve shades
inside the category's selected gradient row. The FBX's UV set is useful for
authoring and review, but the production truth should be explicit face material
assignments rendered through the existing flat material-ID pass. Because the
source is one connected mesh with no slots, those seven face regions must be
authored; they cannot be recovered from missing source textures.

## Remaining production work

1. Assign and review all seven categorical material regions in the rest mesh.
2. Inspect/repair coat, belt, shoulder, hip and knee weights through every clip.
3. Render all nine western facings plus the three seated facings using the
   locked BGEE camera, lighting, material-ID and hard-shadow passes.
4. Crunch to the fixed native 64-row body scale, fit gradient rows from the new
   masters and run the full 204-frame mask/palette/round-trip inventory.
5. Compare the native head and hair against the supplied CHMC4 paperdoll and
   matching `CHMC4G12` world frame before considering an install.

## Reproduce

```sh
/Applications/Blender.app/Contents/MacOS/Blender --background \
  --factory-startup --python-exit-code 1 \
  --python ArtSource/Blender/rig_meshy_voss_fbx_proof_v02.py
python3 -B ArtSource/Processing/review_meshy_voss_fbx_proof_v02.py
```
