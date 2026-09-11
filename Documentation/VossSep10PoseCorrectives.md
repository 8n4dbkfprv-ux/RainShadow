# Voss — September 10 coat and grip correctives (V04)

The nearly open hand contacts recorded in this V04 report are fixed by [VossSep10OpenHandCleanup.md](VossSep10OpenHandCleanup.md). V05 preserves the V04 coat and closed-grip corrections and is the current editable delivery for this imported character.

V04 addresses the long coat catching the legs during sitting and extended strides, and the tight-grip finger/thumb intersections left by V03. The editable authority is `ArtSource/Blender/VossMeshySep10PoseCorrectivesV04/voss_sep10_pose_correctives.blend`. This is the imported September character, not the scripted V23 character or the game's installed V14 atlases. Runtime assets were not replaced.

## Concept reference

The user supplied the model's original front/back concept art after the V04 corrective pass. An unchanged copy is stored at `source/voss_concept_front_back.png` beside the model; the original supplied file was `d8bd8279-9c9d-42bf-8495-50e3cba8b72c.png`.

Use it as the visual reference for subsequent work: fitted dark leather gloves with visible fingers and narrow shirt cuffs; a long, worn brown coat with broad lapels, cuff straps, a rear waist strap and a central rear split; a brown waistcoat, pale shirt, dark red tie and dark trousers. Preserve these garment details and the illustrated silhouette when refining deformation. Saving this reference did not change the V04 mesh, rig or materials.

## Deliverables

- `voss_sep10_pose_correctives.blend`: editable mesh, rig, automatic corrective drivers, packed original textures, existing pose assets and a new motion-review action.
- `voss_sep10_pose_correctives.fbx`: neutral character, skeleton, skin weights, 33 corrective morphs and three embedded textures, without an animation clip.
- `voss_sep10_pose_correctives_motion_review.fbx`: the same character with the example bone and morph animation baked together.
- `review/`: seated front/side/rear inspection, stride and glove close-ups, plus the earlier coat inspection images.
- `source/voss_before_pose_correctives.blend`: the untouched V03 starting checkpoint.

## Changes

Six horizontal support cuts add 928 vertices to the lower coat while preserving the positions of all 10,112 existing base vertices. UVs are interpolated on the new cuts. The head, body proportions, original materials and glove images are retained; all 58 rest bones are unchanged.

Thirty sampled coat shapes cover entry into and exit from sitting and the two extended stride poses. The seated panels fall beside the thighs; the rear hem gains clearance for the trailing leg during a stride. Upper attachment regions taper into the original deformation. The rig reads thigh rotation and blends the neighboring corrective samples automatically.

Finger weights spread each bend more gradually across the knuckles without introducing cross-digit influences. Each hand has a closed-grip relief shape, and the thumb swings around the index finger instead of through it. Small seam clearances supplement those shapes. Original texture appearance and finger-joint controls are retained.

The complete-grip amount follows the smallest middle-joint curl among the four fingers, reaching one at 60 degrees. This drives the grip shape and the first thumb bone's Y/Z opposition. Thumb X curl remains separately poseable. The five `V04 ...` armature properties display the calculated coat/grip amounts. The legacy pointing and relaxed pose assets are retained; they have not received separate corrective shapes.

## Review and verification

Open the Blender file and play `Voss V04 - Coat and grip motion review`, frames 1–401 at 24 fps. It opens at frame 361. This sequence demonstrates deformation and transitions; it is not an authored game walk cycle.

| Frame | Pose |
| --- | --- |
| 1 | Standing, arms down |
| 41 | Seated |
| 121 | Left extended stride |
| 201 | Right extended stride |
| 281 | Closed grips |
| 361 | Seated with closed grips |
| 401 | Return to standing |

The lower coat has **zero measured intersections with the trousers across all 401 frames**, both in the Blender authority and in a fresh import of the animated FBX. Both fully closed hands have **zero nonadjacent triangle intersections** at the standing and seated grip endpoints in both files. Sitting and both strides were also sampled independently at 41 steps each; the trousers remained clear throughout.

The mesh has 11,040 vertices, 28,020 edges, 16,974 polygons and 22,092 triangles. Inspection found zero non-manifold vertices/edges, inconsistent winding edges, zero-area faces or unweighted vertices. Weight totals range from 0.999999951 to 1.000000589. Original base-vertex displacement is exactly zero; pose corrections live in shape keys.

The fresh animated FBX import retains all 58 bones, 33 corrective morphs and three embedded textures. Maximum posed-surface error across 13 aligned review samples is 0.0032 mm. Blender's default FBX import adds one frame; use `anim_offset=0` or compare source frame F to imported frame F+1.

Measurements are in `pose_corrective_validation.json` and `fbx_roundtrip_validation.json` beside the model. Small seam contacts remain in some nearly open hand poses while the arms move, and internal contacts remain in the imported upper clothing. The checks above concern the specified coat/trouser and closed-grip problems, not all possible garment contacts. They do not certify arbitrary new poses or collisions with an external chair or held prop.

## Animation handoff

Use the Blender authority for authoring and sprite rendering so the corrections follow the rig. FBX preserves the morph targets and the baked example, but does not transfer Blender driver formulas. New animations made outside Blender must also animate the corrective morph weights, or return to Blender to bake them with the bone motion. Do not discard the morph animation from the review FBX and expect its coat correction to survive.
