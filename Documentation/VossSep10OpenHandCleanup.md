# Voss — September 10 open-hand cleanup (V05)

V05 fixes the nearly open hand contacts left by V04. Both hands now clear the measured self-intersection checks in opening, relaxed and small independent-finger motion. The original glove textures and V04 coat and closed-grip corrections are preserved. This updates the imported character source; the game's installed sprites are unchanged.

The editable authority is `ArtSource/Blender/VossMeshySep10HandSeamsV05/voss_sep10_open_hand_cleanup.blend`. The same folder contains the neutral `voss_sep10_open_hand_cleanup.fbx`, the baked `voss_sep10_open_hand_motion_review.fbx`, validation reports and before/after review images. The supplied concept art and a complete V04 checkpoint are retained in `source/`.

## Repair

Two new local corrective shapes relieve narrow seam folds and the thumb/index joins. They affect 280 vertices on the left and 543 on the right, averaging 0.177 mm and 0.201 mm of displacement. Maximum local displacement is 1.00 mm on the left and 1.60 mm on the right. The correction fades smoothly to zero by 20% of the existing complete-grip amount, preserving the full-grip solution.

Small automatic thumb-opposition adjustments provide clearance when the fingers take the relaxed pose or when the thumb bends independently. Standard complete-grip motion retains V04's thumb opposition. The hand's X curl remains the authored input; the existing Y/Z thumb drivers apply the additional clearance.

The base mesh, UVs, materials, skin weights, bone rest positions and all pre-existing shape-key geometry are unchanged. The mesh remains at 11,040 vertices, 28,020 edges, 16,974 polygons and 22,092 triangles, with 58 bones and now 35 corrective morphs. It has zero non-manifold edges/vertices, inconsistent winding edges or zero-area base faces.

## Verification

- **1,869 additional pose samples:** zero self-intersections in either hand. These cover opening/closing in six body/arm poses, 161-step relaxed-hand transitions in three poses, and small independent bends of all ten fingers in two arm positions.
- **621-frame motion review:** zero hand self-intersections and zero lower-coat/trouser intersections in every frame.
- **Fresh animated FBX import:** the same 621 frames pass both checks. Maximum surface-position error across 18 reference frames is 0.00315 mm. All 58 bones, 35 morphs and three embedded textures survive.
- **Fresh neutral FBX import:** both hands are clear, maximum surface-position error is 0.00144 mm, and the packed texture hashes match the original images exactly.

Detailed results are beside the model in `hand_seam_validation.json`, `fbx_roundtrip_validation.json` and `fbx_neutral_validation.json`.

## Review and handoff

The Blender file opens at frame 421 with relaxed hands. Play `Voss V05 - Open hand and coat motion review` at 24 fps. The earlier coat and grip review remains at frames 1–401; the new examples are:

| Frame | Example |
| --- | --- |
| 421 | Standing, relaxed hands |
| 461 | Seated, relaxed hands |
| 481 | Seated, open hands |
| 521 | Left index bends independently |
| 561 | Left thumb bends independently |
| 601 | Right thumb bends independently |
| 621 | Return to open hands |

Use the Blender authority for further animation and sprite rendering. The neutral FBX includes the corrective morph targets, and the motion-review FBX bakes their weights together with the bone animation. FBX does not transfer Blender's automatic driver formulas; new external animation must also drive or bake the morphs. The review is a deformation demonstration, not a production walk cycle.
