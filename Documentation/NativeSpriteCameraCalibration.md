# Native sprite camera calibration

3 September 2026. Replaces the fixed 9%-of-window play-camera target. This is a
presentation change, not a character rebake or a change to world geometry.

## Engine evidence and adaptation

GemRB at the project's pinned `1c45c185` initialises `GameControl.viewport` from
the view frame's size. `ScaleViewport` returns at 100%; other steps apply
`viewport.Scale(scale)`. See [GameControl.cpp](https://github.com/gemrb/gemrb/blob/1c45c185/gemrb/core/GUI/GameControl.cpp#L2323-L2336)
and [Region.cpp](https://github.com/gemrb/gemrb/blob/1c45c185/gemrb/core/Region.cpp#L268-L276).
The relevant upstream excerpt is:

```cpp
auto scale = GetScalePercent();
if (scale == 100) {
    return;
}
viewport.Scale(scale);
```

RainShadow's previous adapter instead held visible world height at 781.25,
irrespective of the window. A 64-row Voss therefore grew to 9% of every window's
height before player zoom. The calibration now is:

```text
world body height = 200 / 512 * 180 = 70.3125 (unchanged)
100% camera scale = 70.3125 / 64 = 1.0986328125 world units / view point
live camera scale = 100% camera scale * engine zoom percent / 100
visible world height = current view height * live camera scale
```

At 100%, Voss's standing body is 64 logical view points high, at 50% it is 128,
and at 25% it is 256. Resizing the view changes how much world is visible,
not the creature's magnification. Office, wards and city interiors share this
calibration. A small office may consequently have more black around it.

That resize behaviour is RainShadow's adaptation, not a literal statement about
every GemRB backend. In particular, SDL2 sets a logical renderer size and handles
window resizes behind that logical surface; SDL1's display setup is different.
Native-world calibration alone is not proof of either backend's presentation.

`CameraZoom`'s step arithmetic and `AreaViewport`'s clamp are unchanged. Native
index planes, linear filtering, palette rows, masks, registered frame sizes and
pivots, actor/door/furniture proportions, navigation and projection are unchanged.
The opening exterior retains its fixed-height cinematic camera. HUD fallback
dimensions remain logical screen points and no longer depend on world height.

## Limits of the match

This is an adaptation of the native-sprite/whole-view zoom principle, not a claim
to reproduce Beamdog's proprietary renderer pixel for pixel. SpriteKit uses
logical points; a 2x Retina display backs 64 points with 128 physical pixels.
Linear filtering and fractional camera positions may still soften edges.

The independently compiled software reference and a controlled Metal
presentation comparison are now in `GemRBSoftwareSpriteReference.md`. They
quantify the remaining gap; they do not replace the shipping scene renderer.

Existing source-pixel crop rounding is retained to preserve animation/seat
registration. The SW index plane is 26x64; its 81x200 registered crop maps to
25.92x64 logical points at 100%. Rounded crop extents differ from the ideal
native grid by at most 0.16 points. No per-pose fitting is introduced to hide it.

## Verification

`DefaultPlayZoomTests` binds the calibration to the installed SW index plane,
checks every nonempty frame's rounding bound, and tests multiple window heights
and the entire zoom ladder. Existing camera clamp, office/city world-scale and
Voss registration/colour tests remain required. `qa_plate_density.py` derives
camera demand from the same 64-row/70.3125-unit contract and keeps its source
density acceptance threshold unchanged.

The macOS capture dump reports view dimensions, base/live camera scales,
native texture dimensions and transformed indexed-frame dimensions in logical
points, so QA can verify the shipping SpriteKit adapter rather than just the
standalone arithmetic.

Measured results on 3 September:

- 108 targeted Swift tests and 17 density-QA Python tests passed.
- macOS Debug and iOS Simulator Debug builds succeeded.
- Live-scene dumps at 1280x720 and 1600x900 both reported a 100% camera scale
  of 1.0986328125 and the same 40x42.88-point seated Voss crop.
- At 50% (step 6), the 30x64 native standing endpoint reported
  60.16x128 points through the actual node-to-scene/camera transform.
- Captures ran under a separate QA bundle identifier, leaving the user's game
  save namespace untouched. The normal build identifier was restored afterward.
- The full plate-density audit still reports six source-detail failures
  (the city-building interior plus five ward plates). No plate, source-density
  acceptance floor or provenance was changed by this work.

Review renders are `Review/native_camera_*.png` under
`ArtSource/Generated/Characters/Detective/ImportedVossReplacementRuntimeV13`.
The existing `SKView.texture(from:crop:)` exporter sizes PNGs from their
world-space crop, not from the logical window dimensions. These are composition
reviews, not 1:1 screenshots; use the view-point dump for magnification checks.
