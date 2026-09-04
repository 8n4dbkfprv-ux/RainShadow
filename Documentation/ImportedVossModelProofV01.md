# Imported Voss model — rigging proof V01

## Scope

The user supplied `/Users/laurensvanoorschot/Downloads/Voss.blend`, an
AI-generated sculpt, for an animation feasibility test. The source SHA-256 is
`c644017f170437f29ce54076855b4ab830624378ffe6bc3f0fb3d3c2f4edc842`.
The source file is read-only in this workflow and remains byte-identical.

This is a deformation proof, not a replacement character master. It does not
touch `voss_masters.py`, the V23 rig authority, indexed masks, palettes, atlases
or installed runtime resources.

## Source assessment

The file contains a strong neutral standing sculpt with a suitable detective
silhouette, distinct facial geometry, swept hair and a detailed belted coat.
It has one mesh with 971,082 vertices and 1,942,197 polygons. It has no armature,
actions, vertex groups, materials, UVs, textures, colour attributes or shape
keys. In other words, it is a detailed textureless statue rather than an
animation-ready asset.

## Proof conversion

`ArtSource/Blender/rig_imported_voss_proof_v01.py` works only on the open copy:

1. It centres, grounds and uniformly scales the sculpt to the existing 1.82-unit
   Voss master height.
2. It decimates the copy to 79,983 vertices / 159,999 faces. This retains more
   than enough surface detail for a 64-row sprite while making deformation
   practical.
3. It builds an 18-bone skeleton with joint centres fitted to this sculpt and
   reuses V23's four action definitions: idle, walk, seated idle and stand-up.
4. It applies automatic weights, normalises them and fails if any vertex or
   required deform group is missing.
5. It retargets rig-object height per keyed pose so the evaluated lowest
   geometry meets `z = 0`; it does not change the inherited bone motion.
6. It renders a diagnostic clay pass and saves a separate proof blend under
   `ArtSource/Generated/Characters/Detective/ImportedVossModelProofV01`.

All 79,983 vertices receive weights across the required 18 groups. All keyed
poses are grounded after retargeting. The proof renders all eight walk phases,
idle, seated idle and the beginning/middle/end of stand-up.

## Visual review

The model is viable. Its face, head, hair and coat silhouette survive both the
91.8% polygon reduction and the full action set. The walk has a clear planted-foot
exchange, and the seated/stand-up chain remains recognisably the same figure.

Production work remains before sprite encoding:

- Author the seven categorical material regions. The source provides no
  materials or UV information, so hair, skin, coat, shirt, tie, trousers and
  shoes must be selected on the mesh and assigned explicitly.
- Hand-clean weights around shoulders, elbows, knees, coat skirt and belt. The
  automatic bind is a feasibility result, not final deformation authoring.
- Refit the seated pose and coat tails against the actual desk/chair register.
- Render all nine authored western facings and every action phase through the
  material-ID, hard-shadow and indexed-colour pipeline.
- Re-run the strict 64-row scale, mask, palette, rear-topology, seat-chain and
  runtime inventory gates before any install is considered.

The sculpt's fists are baked into its geometry; the existing action set does
not require opening them. Any future hand interaction would require remodelling
or separate hand geometry.

## Reproduce

```sh
/Applications/Blender.app/Contents/MacOS/Blender --background \
  /Users/laurensvanoorschot/Downloads/Voss.blend \
  --python-exit-code 1 \
  --python ArtSource/Blender/rig_imported_voss_proof_v01.py
python3 -B ArtSource/Processing/review_imported_voss_rig_proof_v01.py
```
