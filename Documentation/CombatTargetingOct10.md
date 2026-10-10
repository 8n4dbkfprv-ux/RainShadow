# Combat targeting and Examine — October 10

Hover a visible rival to preview the attack a click would perform: ordinary melee,
selected bow/ammunition, weapon technique, Sneak Attack (melee or ranged according
to reach/equipment), or bear claws. The separate parchment card leaves the action
bar's generated slots and symbols intact. It shows the standard-action/full-turn
cost, hit percentage, damage on hit, advantage/disadvantage, Sneak Attack critical
range, Blade Ward mitigation, and relevant on-hit conditions. An unavailable
attack shows the blocking reason instead of promising a hit percentage. Shove
uses its existing contested-check preview and certified landing point.

`CombatAttackPreview` is read-only: it never advances RNG or spends resources.
Resolution and preview share attack eligibility, natural 1/20 handling, weapon
damage bands and maneuver damage adjustments. Advantage uses 1−(1−p)²;
disadvantage uses p². Normal damage includes eligible Sneak Attack; only its dice
are doubled on a natural 20, matching the current RainShadow rules. Blade Ward
halves the combined physical damage, rounding down. Fire Arrow burning is listed
separately from immediate weapon damage. Player ammunition is validated against
inventory by the director, as it is when firing.

Click the card's Examine footer or press T while hovering the rival to inspect
health, defence, attack bonus, damage, movement, weapon, conditions and spent
techniques. Examine pauses combat presentation and consumes world/action input.
T, Escape, right-click, or its Close footer closes it without spending a turn.
Hidden rivals cannot be inspected. It is a compact combat readout, not a complete
creature encyclopedia or a reveal of concealed actors.

## macOS controls

| Key | Action |
| --- | --- |
| Space / Enter | End turn |
| Shift+Space | Toggle tactical pause |
| F | Switch ranged/melee targeting; select claws in bear form |
| C | Hide |
| V | Shove |
| R | Sneak Attack |
| G | Dash |
| T | Examine hovered rival / close Examine |
| Escape / right-click | Close Examine first; otherwise cancel targeting |

Existing 1–9 bindings, WASD/arrow camera movement, and I for inventory remain.
Combat shortcuts ignore key repeats and command/control/option combinations.
They defer to open scene overlays. The launcher and action-bar hints list the
new controls. The numbered bear shortcuts retain their form-specific mapping.

## Verification

- `CombatAttackPreviewTests`: exact probabilities, natural-roll bounds, cancelling
  advantage sources, atomic preview, eligibility agreement, damage against 960
  resolved maneuver/ward/seed combinations, Sneak critical ranges and bear form.
- Native `RAINSHADOW_QA_TARGETING_ONLY=1` branch: hover/cost/damage, F through the
  scene's keyboard handler, Examine by click and T, blocked world/End Turn input,
  close/cancel, Aimed Shot cost and spent-action feedback. Screenshots and report:
  `output/combat-targeting-oct10/`.
- Build both macOS and iOS Simulator schemes; combat core regression tests.

No changes to the GemRB navigation, rendering or camera ports, character atlases,
combat action costs, RNG sequence, or the action bar's artwork.

Verified: 99 core tests across 14 suites, 22 native combat checks, and both
macOS and iOS Simulator Debug builds passed. Native parchment forecast and
Examine screenshots were visually reviewed.
