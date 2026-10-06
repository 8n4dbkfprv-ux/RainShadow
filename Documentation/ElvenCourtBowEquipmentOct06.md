# Elven Court Bow equipment — October 6

The textured Elven Court Bow is an inventory weapon for Voss. Drag it into the
first ready-weapon slot to show it in the world and inventory portrait; drag it
back into the bag to unequip it. Replacing the sword returns the sword to the bag.
The existing first occupied weapon-slot priority is unchanged. The bow requires
an empty off-hand and cannot itself be placed in the off-hand.

New and existing saves receive one bow. The additive `hasReceivedElvenCourtBow`
receipt prevents repeat grants, including after dropping the bow. Migration checks
carried, equipped, ground and resolved-container items. A full bag defers the grant
until a later load has room. No attack, projectile or ammunition behavior is added.

## Art authority

- Original textured/rigged master, unchanged:
  `ArtSource/Blender/ElvenCourtBowOct05/Elven_Court_Bow.blend`.
- Separate live-MCP production scene:
  `ArtSource/Blender/ElvenCourtBowRuntimeOct06/Elven_Court_Bow_Runtime.blend`.
- Attachment: `hand.R`, fitted to the finger grasp, 0.8 uniform scale; exact local
  animation and paperdoll matrices recorded in that directory's `attachment.json`.
  Their orientations differ because the portrait and animation hand poses differ.
- Animation authority: `SwordMaterialsV8Oct01/AnimationProduction/render_plan.json`.
  Uses October 1 V8 idle/walk actions, hold timing, camera and registration boxes.
- Export: 336 transparent renders, body holdout occlusion, 384×384, Cycles 8 samples,
  orthographic base scale 1.72, elevation asin(0.75). All views use a 1.5×
  camera margin at 576×576; the encoder removes that margin in its affine mapping.
  Never independently fit weapon crops. A separate native-sprite collection uses
  a 0.014m cord radius so the string survives the roughly one-pixel reduction;
  the authoring master, icon and portrait retain the physical 0.00095m radius.
- `ArtSource/Processing/package_elven_court_bow.py stage` encodes 1,200 idle/walk
  frames in `VossElvenCourtBow`. Canvas 128×128, pivot (64,46), display 140.625².
  `install` copies only the new bow bundle and its two UI images.
- Paperdoll uses the approved sword paperdoll camera and 768×1088 registration;
  icon is a separate transparent 384×384 render-derived image.
- Review sheets, render progress and payload hash are in the production directory.

VossCHMF, LilaSentinel, armor, sword and their approved payloads remain unchanged.
The new overlay supports Voss's idle and walk actions; seated transitions hide it,
following the existing weapon behavior. Lila has no fitted bow overlay yet.

## Verification

`ElvenCourtBowTests` covers swapping/unequipping without losing either item,
two-handed rules, additive grant/save migration, all 1,200 registrations and idle
holds. The live macOS equipment QA supports `RAINSHADOW_QA_WEAPON_ITEM=elven-court-bow`
with `RAINSHADOW_QA_WEAPON=<output directory>`, using an isolated save. It checks
world and portrait visibility, synchronized walking, armor combinations, reload,
unequip and dropped-item grant suppression.

Bow payload SHA-256: `bd630bdbd7230680d52c9c5b117c74303636e7696c30163ca7bd10ab2372a136`.

Validation completed: 82 focused tests passed, macOS and iOS Simulator builds
succeeded, and the isolated live macOS QA passed all 58 checks, including ten
walking phases. Screenshots and `report.json` are in `ElvenCourtBowRuntimeOct06/LiveQA`.
The broad 1,178-test suite is not green: it reports older area/character baseline
and missing legacy-art failures outside this change. Its `AreaExportTests` also
rewrote the opening plate name; that test side effect was restored before delivery.

## Hand attachment correction

The first attachment used the middle of the wrist-to-knuckle bone, leaving the
bow behind the palm. The corrected portrait grip center is (-0.387, -0.147, 0.902)m,
about 6cm from that anchor, inside the finger grasp. A subsequent geometry audit
found that the first outward rotation still intersected the forearm. The final
attachment rotates about the unchanged grasp center, with separate orientations
for the portrait and animation hand poses. Character geometry, poses and sprite
payloads remain unchanged. The live QA captures the unarmored hand before armor.

`scale_audit.json` measures a 1.89259m authoring bow, 0.8 uniform carrying scale,
1.51407m carried length and 1.75966m character height (86.04%). This scale is retained;
the reference supplies no absolute dimensions. `grip_before_after.png` shows the
correction composited against the actual installed portrait, not just a Blender preview.

Correction verified in the actual unarmored inventory portrait, plus idle/walk
sprites in all sixteen directions. Both app builds and 82 focused tests pass;
the live equip/unequip QA again passes all 58 checks. Latest screenshots and report:
`ArtSource/Blender/ElvenCourtBowRuntimeOct06/LiveQA/GripFix/`.

## Arm clearance correction

Triangle intersection checks against the evaluated character mesh found 799
forearm/upper-arm intersections in the preceding portrait attachment. Rotating
the bow around the grasp center removes them without changing its size or moving
the handle. The portrait uses a 45° forward and −5° sideways adjustment from that
attachment. Animation uses 45° forward, 20° sideways and 30° around the bow's long
axis, keeping the guards clear of the coat throughout the walking cycle.

The final portrait and all 21 distinct idle/walk source poses have zero arm or
non-hand body triangle intersections. Right-hand contact is intentionally excluded
from the body check. The lowest animated bow point stays 0.11038m above the floor.
The source poses produce 336 rendered views and 1,200 timed runtime frames.
Measurements are in `arm_clearance_portrait_audit.json` and
`arm_clearance_animation_audit.json`; matrices are in `attachment.json`. The live
MCP render recipe is retained as `render_arm_clearance_via_live_mcp.txt` alongside
the corrected production blend. The original bow master remains unchanged.

The corrected assets pass source/native canvas edge checks, both macOS and iOS
Simulator builds, 82 focused tests and all 58 isolated live equipment checks.
The actual unarmored inventory portrait was visually reviewed after installation.
Latest screenshots and report: `ElvenCourtBowRuntimeOct06/LiveQA/Clearance/`.
