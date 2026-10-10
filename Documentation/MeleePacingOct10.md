# Melee animation pacing — October 10

Normal sword attacks, Power Strike, Feinting Cut and Trip Attack now have a
three-part presentation clock: longer preparation, the original fast contact
arc, and longer recovery. These are authored RainShadow timings, not measured
BG3 animation durations.

| Attack | Previous clip | Revised clip | Revised contact |
|---|---:|---:|---:|
| Normal melee | 0.80 s | 1.10 s | 0.533 s |
| Power Strike | 0.933 s | 1.40 s | 0.783 s |
| Feinting Cut | 0.722 s | 1.00 s | 0.561 s |
| Trip Attack | 0.889 s | 1.15 s | 0.561 s |

`WeaponTechniqueMotion.meleeTime(atFrame:move:)` maps authored frame markers to
presentation time. `meleeFrame` is its inverse; `meleePhase` samples the body and
equipment together. Preparation ends at the existing trail-start frame. Contact
through the trail-end frame keeps the original 15 or 18 frames/second. Recovery
stretches the remaining poses, including the final rest pose, to the new duration.

`MeleeAttackPresentation` and `MeleeSwingTrail` share this mapping. The director
already keys damage, dodges and reactions to the presentation's impact marker,
so they follow the new clock. The 0.12-second trail fade remains short and finishes
before the longer recovery ends. Recovery continues to lock input; pause freezes
all presentation time. Results still resolve once before animation and reloads
never repeat the attack.

Applies to player and NPC playback, including matching armor and sword layers.
The approved art bundles, rigs, hashes, combat rules and AI are unchanged. Bow,
Sneak Attack and Bear animations retain their existing clocks. The constants in
`MeleeAttackAnimationSet` continue to describe the source clip; live combat uses
`WeaponTechniqueMotion` for presentation pacing.

## Verification

Passed: 57 tests in 10 suites, 175 native pacing checks, 103 existing native
melee checks, and both macOS and iOS Simulator builds. Impact screenshots were
visually reviewed for normal, Power Strike and armored Trip playback.

- Unit regressions cover monotonic/inverse pose sampling, exact contact markers,
  preserved swing speed, longer wind-up/recovery, and trail fade ordering.
- Related melee, techniques, Trip, reactions, previews, bow and stealth regressions.
- `MeleePacingQA`: all four attacks in unarmored and armored form, pause, contact,
  trail visibility, recovery, equipment and accepted save state. Captures impact
  PNGs and timed GIF samples using an isolated temporary save.
- Existing native melee QA covers ordinary, armored, unarmed, miss, knockout,
  enemy playback and reload behavior.
- macOS and iOS Simulator builds.

Native pacing QA after building the macOS target:

```sh
RAINSHADOW_QA_COMBAT="$PWD/output/melee-pacing-oct10" \
RAINSHADOW_QA_APPROACH_ONLY=1 RAINSHADOW_QA_MELEE_PACING=1 \
/tmp/RainShadowCombatApp/Build/Products/Debug/RainShadow.app/Contents/MacOS/RainShadow
```

Run `RAINSHADOW_QA_MELEE_ONLY=1` with its own output directory for the existing
native melee regression harness. Reopen `Play Combat.command` to rebuild and
play with the revised pacing.
