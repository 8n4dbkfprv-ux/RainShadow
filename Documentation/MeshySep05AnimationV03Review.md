# Meshy September 5 animation candidate V03

The repaired imported character has a complete staged animation bundle, but is
**not ready to replace the installed V14 character**. No runtime assets were
installed by this work.

The source and review artifacts are in
`ArtSource/Generated/Characters/Detective/MeshySep05AnimationV03/`.
`meshy_sep05_animation_v03.blend` is the live-authored imported-model authority.
This is separate from the procedural V23 generator.

## Completed

- Idle and walk in nine authored facings; seated idle, stand-up and reversed
  sit-down in the three required seat directions.
- 204 beauty/material master pairs, assembled into 248 runtime cells including
  mirrored and desk-layer cells.
- Exact seated/standing endpoints and reversed transition geometry.
- Three verified clothing faces explicitly assigned the coat surface to remove
  erroneous texture samples. Mesh geometry, UVs and skin weights remain equal
  to the repaired V02 source. The original downloaded FBX is unchanged.
- Indexed palette round-trip validation passes. Cached staging now checks the
  source, Blender file and builder hashes before reusing converted cells.
- macOS test app built successfully; the exact staged indexed bundle was copied
  into that isolated app and rendered in the office. The capture is diagnostic
  camera output, not a successful native framebuffer QA capture.

## Remaining failures

The corrected candidate's staged Swift run executed 32 tests in five suites and
reported 25 issues. Seated scale and transition checks pass, including the head
measurement previously broken by a stray hair pixel on the coat.

- Four walk directions fail foot-exchange checks: S, SW, NW and N.
- Five NW walk frames retain one or two shirt-colored native pixels at the
  collar.
- Sixteen north-facing seat/transition frames exceed the rear-view skin limit:
  eight seated frames and four frames in each transition. The maximum seated
  skin share is approximately 4.94%, against the existing 3% limit.

Gait experiments were not accepted. A trial lowering the seated forearms was
also rejected after side-view inspection exposed an awkward sleeve/coat shape.
These trials are not in the staged actions. Do not recolor legitimate exposed
shirt or hands just to make a rear-material check pass, and do not relax the
existing thresholds. The next authoring pass needs to resolve the walk's foot
exchange and the seated arm/clothing relationship, with intermediate visual and
collision checks.

The game capture also shows the known office chair/seat-anchor authoring
mismatch; changing the actor's scale is not a correction for that room issue.

## Reproduce and review

Run `python3 ArtSource/Processing/stage_meshy_sep05_animation_v03.py` to rebuild
the candidate, and `python3 ArtSource/Processing/preview_meshy_sep05_animation_v03.py`
to regenerate previews from the staged native index planes. Neither installs
runtime assets. A stage report must be read even when the builder exits zero:
geometry failures are collected there for review.

Staged tests:

```sh
RAINSHADOW_VOSS_ATLAS_ROOT="$PWD/ArtSource/Generated/Characters/Detective/MeshySep05AnimationV03/Staging" swift test --skip-build --scratch-path /tmp/RainShadowSwiftPMMeshySep05 --filter 'VossSeatScaleTests|VossAtlasV20ValidationTests|VossWardrobeColorTests|IEPaletteTests|IEResampleTests'
```

`review_status.json`, `swift_validation.log`, `stage_build.log`,
`source_authority.json`, and `rear_material_correction.json` preserve the exact
results and source provenance. `walk_staged.gif`, `stand_up_staged.gif`,
`sit_down_staged.gif`, and `game_seated_corrected.png` show the current candidate.
