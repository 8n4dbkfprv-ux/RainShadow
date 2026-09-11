# Voss — September 10 animation mesh cleanup

This is an isolated cleanup of the September 9 imported character with rigged gloves. The game’s installed Voss atlases and runtime selector were not changed.

The editable delivery is `ArtSource/Blender/VossMeshySep10AnimationCleanupV03/voss_sep10_animation_cleanup.blend`. The matching `.fbx` contains the mesh, skeleton, skin weights and three embedded textures. The Blender file also retains the four glove pose assets and adds a diagnostic body-pose action. The FBX deliberately contains no animation clips.

## Accepted repairs

- Removed 56 accidental patch faces and their unused edges/vertices. These were small dangling triangles and overlapping shells attached to the principal surface.
- Separated seven pinched vertices into their proper surface fans. This fixes four remaining shared connections without moving the surface. Every retained face keeps its original vertex correspondence, material assignment and UV coordinates.
- Normalized 4,728 imported weight totals. Before correction the minimum total was 0.879; the relative influences were preserved. The measured change to the posed surface from normalization was below 0.00013 mm.
- Unfolded the intersecting patch at the left thumb/index junction. The bounded adjustment affects 1,086 densely sampled vertices, averaging 0.476 mm and capped at 4 mm. It reduces nonadjacent triangle overlaps within the neutral left glove from 31 to zero. The original glove images, UVs and materials were retained.
- Corrected thumb weights, including residual index-finger influences. A 40-degree index curl previously displaced the tested thumb core by 2.526 mm on the left and 5.235 mm on the right. Both now measure zero.

All retained body vertices outside the glove adjustment have exactly their previous coordinates. All 58 bone rest matrices are unchanged. No head/body reshaping, texture repainting, global smoothing or material replacement was performed.

## Verification

The final mesh has 10,112 vertices, 26,164 edges, 16,046 polygons and 20,236 triangles. It has zero non-manifold edges or vertices, inconsistent winding edges, zero-area faces, loose vertices or unweighted vertices. Retained-face UV error and material-assignment mismatch are both zero.

All ten fingers pass isolated three-joint bend tests. Each moves its own geometry, with zero measured displacement outside its hand or in the other fingers’ strongly weighted distal regions. Returning to neutral produces zero position error.

Eight body stress poses were checked: rest, arms down, bent elbows, left/right strides, sitting, overhead reach, and torso bend/twist. Coordinates remain finite, and no edge stretches beyond twice its neutral length in those checks. These are deformation diagnostics, not a collision-free production-animation certification.

A fresh import of the final FBX preserves all 58 bones, including 30 finger bones, all three embedded textures and the named skin weights. Geometry round-trip error is under 0.000125 mm; named-weight error is zero. Every finger moves in the fresh import.

Detailed measurements are beside the model in `mesh_validation_final.json`, `finger_validation.json`, `deformation_validation_final.json`, `hand_pose_intersections.json`, and `fbx_roundtrip_validation.json`.

## Remaining animation work

The coat/trouser and complete-grip items below are superseded by the V04 corrective pass documented in [VossSep10PoseCorrectives.md](VossSep10PoseCorrectives.md). This section records the V03 checkpoint, not the current V04 result.

The imported long coat still intersects the legs in extended strides and seated poses, and the sleeves can fold into themselves at strong bends. Reliable seated draping needs dedicated coat controls or authored pose correctives. Experimental lower-coat weight transfers were not accepted; the original normalized coat weights are restored, within floating-point precision, with no added bone influences.

Both open gloves have zero measured internal overlaps. Relaxed, tightly closed grip and pointing poses still contain local surface contact/intersections, so a close-up fist should receive a pose-specific corrective pass. Independent finger control does not by itself prevent these collisions.

Small pre-existing contacts also remain in the imported clothing and hair folds. A clean manifold mesh is not a guarantee of an intersection-free surface.

## Reviewing the Blender file

The file opens at frame 25, the arms-down pose. The action `QA - Voss Sep10 deformation checks` has labeled timeline markers:

| Frame | Pose |
| --- | --- |
| 1 | Rest |
| 25 | Arms down |
| 49 | Elbows bent |
| 73 | Left stride |
| 97 | Right stride |
| 121 | Seated |
| 145 | Overhead reach |
| 169 | Torso bend/twist |
| 193 | Return to rest |

These poses are inspection samples; their interpolation is not an authored walk cycle. The four existing `Voss Sep09 Hands` pose assets remain available. Both incremental backups and the prior September 9 delivery are preserved.
