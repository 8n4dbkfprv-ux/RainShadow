# Combat-start banner — October 9

New encounters display **Combat Begins** beneath the initiative portraits in an
original RainShadow brass-and-charcoal frame. The frame was generated with the
built-in image generator; the title uses the shared Baskerville UI font and is
rendered live by SpriteKit. The unmodified RGBA asset and its alpha channel are
bundled for macOS and iOS. The exact generation prompt is in
`CombatStartBannerArtOct09.json`.

`CombatStartBanner` fades in and settles over 0.3 seconds, holds until 1.5 seconds,
then fades upward and removes itself at 1.9 seconds. The director's presentation
clock drives the animation so inventory and tactical pause freeze it. The art and
title scale together to fit between the HUD rails without changing aspect ratio.

`WharfLadderDirector` explicitly identifies fresh encounters (`restored == nil`).
Saved encounters resume without replaying the banner, including saves made while
the entrance was visible. The banner owns no combat state and consumes no rolls,
actions or turns. While it is present, `busy` blocks commands and world orders and
the director holds AI advancement. Inventory remains available.

## Verification

The macOS live harness has a focused mode:

```sh
RAINSHADOW_QA_COMBAT="$PWD/output/combat-banner-oct09" \
RAINSHADOW_QA_BANNER_ONLY=1 \
/tmp/RainShadowCombatApp/Build/Products/Debug/RainShadow.app/Contents/MacOS/RainShadow
```

It checks bundled artwork, input/AI gating, pause and inventory, removal and enemy
turn continuation, fade phases, narrow layout, and save reload. It saves full-game
captures and 680/320-point banner previews beside its `report.json`.

Validated October 9: macOS Debug and iOS Simulator Debug builds passed. The live
run passed all 21 checks; results and captures are in
`output/combat-banner-final-oct09/`. `git diff --check` passed.
