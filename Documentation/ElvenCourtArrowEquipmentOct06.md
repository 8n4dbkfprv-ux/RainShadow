# Elven Court Arrow equipment — October 6

The textured arrow is ammunition for Voss's Elven Court Bow. New and existing
saves receive one arrow in the bag. Equip it in any of the three ammunition
slots (the Coat Pockets row) while the bow is the first occupied ready-weapon
slot. The bow stays in the right hand and the arrow appears in the left hand in
the inventory portrait and idle/walk sprites. Returning the arrow to the bag,
removing the bow, or readying a sword hides the held arrow. The ammunition stays
equipped when the weapon changes and reappears when the bow is readied again.

The arrow uses the existing ammunition category, quiver slots and stack handling
(maximum 20). The bow remains two-handed; the shield/off-hand slot is still
blocked. This implements carrying and equipment visuals, not firing, ammunition
consumption, projectiles or attack animations. Lila has no fitted arrow overlay.

`hasReceivedElvenCourtArrow` is an additive save receipt, defaulting to false in
older saves. Migration recognizes carried, equipped, ground and resolved-container
arrows, never grants a dropped arrow again, and defers a grant when the bag is full.

## Art and attachment

- Master: `ArtSource/Blender/ElvenCourtArrowOct06/Elven_Court_Arrow.blend`, with
  the packed Image Generator atlas from `Textures_V03`.
- Live Blender MCP production scene:
  `ArtSource/Blender/ElvenCourtArrowRuntimeOct06/Elven_Court_Arrow_Runtime.blend`.
- `hand.L` attachments use separate portrait and animation matrices because
  their finger poses differ. `attachment.json` records both, the source grasp
  point 0.23m from the nock, and the portrait grasp at (0.306, -0.088, 0.846)m.
  The initial mirrored attachment missed the left-hand grip and was corrected
  before export. `arrow_hand_closeup.png` records the corrected placement.
- Length remains 0.82m at scale 1. The portrait retains the physical 8mm shaft.
  The sprite/icon collection uses a 22mm shaft for approximately one-pixel
  visibility at native resolution, like the bow's native cord treatment.
- Physical geometry clearance checks found no non-hand body intersections in
  the final portrait and all 21 unique idle/walk poses. Hand contact is excluded
  from this test. `animation_clearance_audit.json` records the animation results;
  minimum animated tip height is 0.27479m. The approved body/finger poses are unchanged.
- The approved V8 render plan supplies 336 source views, 16 facings and 1,200
  timed frames. Renders use the body as a holdout, 576² with 1.5× camera margin,
  ortho scale 2.58 and 16 Cycles samples. The encoder removes that camera margin
  using the approved body's registration boxes rather than fitting arrow crops.
- `ArtSource/Processing/package_elven_court_arrow.py stage` validates and encodes
  `VossElvenCourtArrow`; `install` copies only that bundle, portrait and icon.
  Runtime canvas is 128², pivot (64,46), display size 140.625². The portrait uses
  the existing 768×1088 camera and registration.

Arrow payload SHA-256:
`de0853e3f748570352faaf03e458cc1f2f03cab2e82fa2028d5fc533a9059329`.

VossCHMF, LilaSentinel, helmet, mail, sword and bow payload hashes are unchanged.
The arrow owns an independent sprite, palette, tint shader and wall stencil.
Seated/transition poses hide it, consistent with the existing weapon behavior.

## Verification

- 86 focused tests in eight suites passed, including quiver rules, weapon priority,
  equip/unequip, save compatibility and all 1,200 frame registrations/idle holds.
- macOS and iOS Simulator Debug builds succeeded.
- Live macOS equipment QA passed 83 checks and observed all ten walking phases:
  `RAINSHADOW_QA_WEAPON_ITEM=elven-court-bow`, with an isolated QA save.
- Actual unarmored inventory portrait visually reviewed after installation.
  Screenshots and report: `ElvenCourtArrowRuntimeOct06/LiveQA/`.
- Source and native canvas edge checks passed. No existing character, armor or
  bow assets were regenerated or replaced.
