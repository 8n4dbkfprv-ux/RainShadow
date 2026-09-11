# Voss office chair alignment

Voss V07 is now registered to the chair painted into `office_suite_plate.png`.
The sprite bundle, model, palette, plate pixels and navigation root are unchanged.

There were two independent faults:

1. The old separate-prop chair offset put the replacement sprite beside the
   current painted chair. `OfficeInteriorScale.PaintedDeskSeat` now records the
   cushion centre at plate pixel **(2144, 1312)**, measured with y downward.
   The V07 seated NE pose's projected thigh-root midpoint is **(-0.771, 23.659)**
   display units relative to its bundled pivot. Subtracting that contact offset
   from the mapped cushion gives the correct body placement.
2. `visualHeightOffset` assigned the body y position on every floor-height
   refresh. The office intentionally reports height zero while seated, so this
   erased the chair's vertical registration every frame. It now applies only
   the change in terrain height, preserving furniture and transition offsets.

The room supplies its registration through `DetectiveActorNode.registerSeat`.
Seated idle and sit-down use the same registered offset; standing-up retains it
until the existing egress animation returns the body to its walking root.
Separate-prop fallback layouts retain their previous registration. The opening
ground point stays **(2175.4100, 1079.2862)**; the painted-seat body offset is
approximately **(-88.7190, -14.1452)** world units. Walking, pathfinding, sprite
scale and desk collision geometry were not adjusted to disguise the mismatch.

Validation is saved in
`ArtSource/Generated/Characters/Detective/VossChairAlignmentV01/`:

- `before_after.png`: actual native-renderer captures around the desk.
- `transition_review.png`: seated, middle standing-up, and standing endpoint.
- `validation.json` and capture logs: successful registration checks and the
  hash check confirming all 251 installed sprite-delivery files are unchanged.
- `build.log`: successful macOS Debug build.

The opt-in real-actor regression runs with `RAINSHADOW_QA_VOSS_CHAIR=1` alongside
`RAINSHADOW_CAPTURE_VOSS_POSE=seated_idle:0`, `RAINSHADOW_START_SCENE=office`,
`RAINSHADOW_SKIP_INTRO=1` and the existing capture output settings. It verifies
the live scene's placement, repeats 120 identical floor-height updates, checks
that a three-unit terrain change adds to the furniture offset and restores
correctly, and asserts that the navigation root did not move. The comparison
allows 0.001 world units because SpriteKit stores node positions at float
precision. Captures were taken in an isolated preview app with a separate
bundle identity.
