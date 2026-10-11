# Combat targeting and Examine — October 10

Hover a visible rival to preview the attack a click would perform: ordinary melee,
selected bow/ammunition, weapon technique, Sneak Attack (melee or ranged according
to reach/equipment), or bear claws. The separate parchment card leaves the action
bar's generated slots and symbols intact. It shows the Action
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
RNG sequence, or the action bar's artwork in the original October 10 pass.

Verified: 99 core tests across 14 suites, 22 native combat checks, and both
macOS and iOS Simulator Debug builds passed. Native parchment forecast and
Examine screenshots were visually reviewed.

## October 11 — resource terminology and costs

Combat now uses Action, Bonus Action, Movement, Main Hand Attack, Armour Class,
Cunning Action: Hide, Wild Shape: Bear and Dismiss Wild Shape. The parchment
bar shows remaining Action and Bonus Action counts alongside movement. Disabled
buttons explain the missing resource or prerequisite, with dynamically sized
tooltips. All text retains the shared Baskerville UI styles.

BG3 references checked: [resources](https://bg3.wiki/wiki/Resources),
[Shove](https://bg3.wiki/wiki/Shove),
[Cunning Action: Hide](https://bg3.wiki/wiki/Cunning_Action:_Hide),
[common Hide](https://bg3.wiki/wiki/Hide),
[Wild Shape: Bear](https://bg3.wiki/wiki/Wild_Shape:_Bear), and
[Dismiss Wild Shape](https://bg3.wiki/wiki/Dismiss_Wild_Shape).

- One Bonus Action is shared by Shove, Voss's Cunning Action: Hide and bear
  transformation. Voss's existing stealth kit explicitly grants Cunning Action:
  Hide; other actors' common Hide costs an Action. Failed eligibility checks spend
  nothing. Resisted shoves still consume the Bonus Action.
- Bear transformation preserves the Action, permitting claws, roar or Dash that
  turn. Dismissal is free and neither spends nor restores turn resources.
- The custom Aimed Shot now costs one Action, allowing movement before or after
  the shot and an automatically planned approach. Other attacks, Blade Ward and
  Dash also use the Action. Movement remains independent and Dash adds one speed
  allowance. This uses the existing TemplePlus transition table without altering
  its entries; a saved optional field carries the separate Bonus Action.
- Old checkpoints preserve spent Actions and movement. Their existing shove/hide
  flags also block the Bonus Action, preventing a load from refunding it. All
  resources refresh on the actor's next turn.

This aligns the existing controls' resource model, not every BG3 class or combat
rule. Weapon techniques still recharge per encounter, bear health/duration and
uses remain authored RainShadow values, and our current attack, damage, range,
stealth visibility and nonlethal rules remain in force. The UI describes those
limits honestly; no Short Rest, spell-slot, Reaction or class-progression system
is implied by the new labels.

Validation: 119 tests across 12 combat suites passed, including shared Bonus
Action spending, legacy-save migration, free dismissal, movement/attack ordering
and enemy tactics. Both macOS and iOS Simulator Debug builds passed. Native QA
passed 28 checks with resource spending through real controls and 360/920-point
bar captures. Screenshots and report: `output/combat-resources-oct11-launchservices/`.
Direct executable launches twice stalled on a blank startup screen; launching
the same build with `open -n -W --env RAINSHADOW_QA_COMBAT=... --env
RAINSHADOW_QA_TARGETING_ONLY=1 <app path>` completed successfully. iOS was
build-checked only.

## Verified-only events — October 11

The user requested removal of invented combat event wording. Action announcements,
floating results and the visible combat log now use a restricted vocabulary.
Character and target names are substituted into the observed BG3 templates.

Evidence:
- [Main Hand Attack log example](https://www.reddit.com/r/BaldursGate3/comments/18q25jx):
  the `Actor used Action on Target` template.
- [Condition log examples](https://bg3.wiki/wiki/Talk:Moonbeam) and
  [Larian forum discussion](https://forums.larian.com/ubbthreads.php?Number=830871&ubb=showflat):
  `received Condition:` and `lost Condition:` templates.
- [Sneak Attack (Melee)](https://bg3.wiki/wiki/Sneak_Attack_(Melee)),
  [Sneak Attack (Ranged)](https://bg3.wiki/wiki/Sneak_Attack_(Ranged)),
  [bear actions](https://bg3.wiki/wiki/Wild_Shape:_Bear),
  [Shove](https://bg3.wiki/wiki/Shove),
  [Hiding](https://bg3.wiki/wiki/Hiding_(Condition)),
  [Knocked Out](https://bg3.wiki/wiki/Knocked_Out_(Condition)) and
  [Blade Ward](https://bg3.wiki/wiki/Blade_Ward_(Condition)) document retained names.
- [Critical Miss feedback example](https://www.reddit.com/r/BG3/comments/l8amw7)
  and [attack-roll rules](https://bg3.wiki/wiki/Critical_miss).

Removed `Shoved`, `Resisted`, `Overboard`, bespoke damage/roll explanations,
turn narration, movement instructions in the idle announcement line, barrel
narration, `Burning removed`, `Dash: movement increased`, and the extra Blade
Ward label on damage absorption. Shove keeps its action announcement and visual
reaction; it does not invent a result label or claim a saving throw.

Custom weapon techniques and their Weakened/Slowed effects remain functional but
are omitted from event announcements and floating conditions. They are not
silently renamed to a different BG3 ability. Fire ammunition uses the verified
base `Ranged Attack` announcement. Floating damage is numeric; misses retain
`Miss!` / `Critical Miss!`, and supported applied conditions appear separately.
Sneak damage is included once in the total. A fully absorbed hit shows `0`.

`CombatEventText` restricts the visible saved log to exact supported templates
and names, so older checkpoints cannot restore deleted custom prose. The
underlying log remains decodable without changing the save schema. Impact
markers still govern outcome reveal. Existing action-bar descriptions, targeting
instructions and eligibility errors continue to explain actual RainShadow
mechanics; this change concerns event text, not a conversion of custom abilities
or every tooltip to BG3 rules.

Validation: 121 tests across 12 combat suites passed, including old-checkpoint
filtering, custom-maneuver suppression and hit/miss/ward/nonlethal feedback.
Both macOS and iOS Simulator Debug builds passed; iOS was build-checked only.
Native Shove QA completed 108 checks across sword, armored, bow, resisted and
hidden-player cases, including absence of the removed labels, retained action
announcements, animation timing and save/load invariants. The enemy scenario
then timed out waiting for the AI Shove presentation, so the full native suite
was not green. No AI policy was changed for this text-only request. Report and
captures: `output/combat-verified-shove-oct11/`; successful Shove contact was
visually inspected. The fixture's obsolete whole-budget-equality assertion was
updated to check the separate Bonus Action while preserving Action/movement.

## Targeting and tooltip wording — October 11 follow-up

The user extended the wording cleanup to targeting. Attack forecasts now separate
Action cost, Damage, Range, percentage, Movement and Advantage/Disadvantage.
The data still comes from the accepted combat rules and prospective stopping
position. Removed the bespoke `Unavailable`, `Approach`, `on surviving hit`,
`Includes Sneak` and explanatory roll paragraphs. Fire ammunition uses `Arrow of
Fire` in forecasts. The Examine footer is `Examine [T]` / `Close [T / Esc]`.

Eligibility checks retain their existing order and predicates. Their messages
now use documented BG3 vocabulary: `Target is invalid`, `Target is out of sight`,
`Target is blocked!`, `Target is too far`, `Can't reach`, `Can't use`,
`Not enough space!`, `You cannot do this in your current form!`, and
`Not enough movement`. Generic `Can't use` is used for custom restrictions that
have no verified specific BG3 string; it does not introduce a different rule.
References: [BG3 ShowError](https://docs.baldursgate3.game/index.php?title=ShowError),
[movement feedback](https://steamcommunity.com/app/1086940/discussions/0/3823047940150611042/).

Action-bar descriptions are shorter. Normal melee/ranged attacks, Shove and Dash
use short published descriptions; custom techniques show numerical modifiers
instead of invented prose. References:
[Main Hand Attack](https://bg3.wiki/wiki/Melee_Attack),
[Ranged Attack](https://bg3.wiki/wiki/Ranged_Attack),
[Shove](https://bg3.wiki/wiki/Shove), [Dash](https://bg3.wiki/wiki/Dash).
Range, damage, duration and resource values remain RainShadow values. Custom
ability names remain identifiable on their buttons; this is terminology and
presentation work, not a claim that every ability follows BG3's rules.

Validation: 121 core tests across 12 combat suites passed, macOS and iOS Simulator
Debug builds passed, and native targeting QA passed all 28 checks. The checks
cover forecast purity, costs, blocked actions, Examine, shortcuts, form resource
transitions and narrow/wide bars. Inspected forecast and disabled Shove tooltip
captures in `output/combat-tooltips-oct11/`. iOS was build-checked only.

## Generated tooltip parchment — October 11

Combat targeting, Examine and action-bar hover descriptions now share a dedicated
Image Generator parchment master with a fine aged-brass rim and diamond/leaf
corner fittings. The centre stays pale for the existing dark Baskerville text.
The action-bar plate and controls retain their existing artwork and hit regions.

The unmodified RGBA master and complete built-in generation prompt are saved in
`ArtSource/Generated/UI/CombatTooltipV01/`. The runtime copy is
`Resources/Art/UI/Common/ui_combat_tooltip_parchment_v01.png`, included in both
app targets. `UIPaintedChrome` nine-slices the master through a scaled parent
node, preserving approximately 19-point corner caps as descriptions grow.
Text padding clears the fittings; targeting and tooltip dimensions still follow
their live text. No combat rules or wording changed for this artwork request.

Validation: macOS and iOS Simulator Debug builds passed. Native targeting QA
passed all 32 checks, including bundled artwork and rendered-frame bounds at
360/920-point bar widths. Visually reviewed attack forecasts, Examine and the
narrow hover tooltip in `output/combat-tooltip-art-oct11-v2/`. iOS was
build-checked only. Master and installed source PNG share SHA-256
`e08b1d99e9e8dc009cf008716849114ee5cc6cd137e8dba9671bfa077e0260a4`.
