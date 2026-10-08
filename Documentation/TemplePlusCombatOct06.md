# TemplePlus combat adaptation

Laurens selected TemplePlus on October 6, 2026 as the source for RainShadow's
turn-based combat adaptation. The integration uses selected rules ported to
Swift above RainShadow's existing navigation, actors and SpriteKit presentation.
Selecting this source does not automatically adopt every Temple of Elemental Evil
rule, character statistic or content asset.

Status: playable nonlethal combat is integrated into the gate, lane, clock-room
and E1 encounters. `CombatBudget` ports the pinned transition matrix and lookup;
`TacticalCombat` implements the explicitly adapted brawl rules. The dependency
audit below records why this is a selective Swift port.

## Audited source

Repository: [GrognardsFromHell/TemplePlus](https://github.com/GrognardsFromHell/TemplePlus).
Audit baseline: [`03d7204510bc8401c67c59b3e4e23b6eefb087d0`](https://github.com/GrognardsFromHell/TemplePlus/tree/03d7204510bc8401c67c59b3e4e23b6eefb087d0),
returned by the upstream master commit API on October 6. Pin this revision for
the first port rather than following a moving branch.

TemplePlus patches the original engine. `CombatSystemAddresses`,
`ActionSequenceSystem` and `TurnBasedSys` bind functions and state at fixed
binary addresses. Their constructors and `TempleFix` replacements cannot be
linked directly into RainShadow. The audit supports selective adaptation; it
does not establish a standalone combat library or a complete extractable ruleset.

| Upstream source | Candidate for adaptation | Boundary to replace |
|---|---|---|
| [turn_based.cpp](https://github.com/GrognardsFromHell/TemplePlus/blob/03d7204510bc8401c67c59b3e4e23b6eefb087d0/TemplePlus/turn_based.cpp) | `AddToInitiative`, conflict arbitration and actor advancement. Initiative rolls a d20 plus dispatched modifiers and uses a secondary ordering value. | Object handles, group arrays, stat/condition dispatch, original sorting callback and initiative refresh. |
| [action_sequence.cpp](https://github.com/GrognardsFromHell/TemplePlus/blob/03d7204510bc8401c67c59b3e4e23b6eefb087d0/TemplePlus/action_sequence.cpp) | The action-budget transition table, `GetHourglassTransition` and `TurnBasedStatusUpdate`'s copy-before-commit pattern. | Global sequence storage, action callbacks, Python cost modifiers, animation and path services. |
| [d20.cpp](https://github.com/GrognardsFromHell/TemplePlus/blob/03d7204510bc8401c67c59b3e4e23b6eefb087d0/TemplePlus/d20.cpp) | Standard attack/movement cost callbacks and separation of validation, performance and animation-frame callbacks. | Full dependency tracing is still needed before porting attack resolution. |
| [combat.cpp](https://github.com/GrognardsFromHell/TemplePlus/blob/03d7204510bc8401c67c59b3e4e23b6eefb087d0/TemplePlus/combat.cpp) | Encounter and turn lifecycle reference. | Original engine AI, party, UI, time events and scripting. |

The first bounded port is the action-budget transition logic, verified
against the pinned table. Upstream distinguishes movement, standard and full-round
actions; a generic pool of interchangeable action points would be an adaptation,
not a literal port. Define any changed rules explicitly. The misleadingly named
`attackrollcpp.cpp` contains a binary trip fix, not an independent attack resolver.

## RainShadow integration

- Keep combat state and action validation independent of SpriteKit. Supply
  explicit actor IDs, stats, random input and navigation results. Return events
  for presentation rather than granting damage or rewards from animation code.
- Use the existing SearchMap, PathFinder and occupancy system for reachable
  movement. Combat budgets accepted paths; it must not introduce another
  world-geometry clearance test. Ground-distance conversion needs a documented
  mapping to RainShadow's projection, not raw screen-space pixel distance.
- Dispatch played encounters from `WharfLadderDirector.resolve`. Finish through
  `WharfLadderStory.resolve(encounter, outcome: ..., in: ...)`, preserving quiet
  crossings, visit guards, aftermath and exactly-once rewards. Pass an explicit
  outcome so a played victory is not marked as auto-resolved.
- `ItemDefinition` already supplies ascending defence bonuses and weapon damage
  bands. Their mapping to attack rules requires an explicit adapter; do not
  silently reinterpret those values as a complete D20 stat block.
- `SaveSnapshot.tacticalCombat` stores a versioned encoded checkpoint. Accepted
  actions persist positions, HP, guard state, order, budget, round and RNG before
  presentation. Relaunch resumes at the accepted endpoint, including if the app
  closed during walking or hit feedback. Completion and checkpoint removal share
  the story transaction. Legacy saves default to no active encounter.

## Playable encounter scope

Initial scope: the existing Wharf Ladder crew encounters with initiative, movement,
nonlethal strike, defend (+4 defence until the actor's next turn), end turn,
yield, enemy decisions and victory/defeat feeding the existing aftermath. Voss
is the playable combatant; Lila is not added to a scene that does not stage her.
Each brawl starts with 12 HP for Voss and 7 for each hand. Equipment contributes
its existing defence bonus. Strikes use a d20 plus attack bonus against ascending
defence, natural 1 misses and natural 20 hits, with no critical multiplier.
Voss's nonlethal damage is 3–5, the crew's 1–3. Weapons, ammunition, spellcasting,
opportunity attacks and party control are not implemented by this brawl slice.
A first-blow opening adds 20 initiative; rattled opponents use attack bonus 0
instead of 2. These are authored RainShadow adaptations, not TemplePlus fidelity
claims. HP is the current brawl's endurance and resets for the next encounter.

Movement measures the accepted navigation path with y divided by the existing
0.75 projection scale. The authored combat conversion is 8 world units per foot;
one normal move grants 240 units (30 feet), and two moves consume the standard
action as the TemplePlus table specifies. Encumbrance reduces that allowance.
The initial centre-to-centre melee reach is 105 world units to accommodate the
existing occupancy footprints. All rules stay separate from the GemRB movement
implementation.

The current `CharacterBodyCode.frameCount` explicitly rejects attack, hit and
death, and equipment advertises idle/walk support only. This playable prototype
uses facing changes, impact rings, damage/miss labels and a combat log. Knocked-out
opponents leave the scene and occupancy; it does not pretend to have strike or
falling animation strips. A finished encounter needs
approved combat presentation and synchronized equipment support while preserving
VossCHMF, LilaSentinel and their payload authorities. Do not substitute historical
atlases to obtain missing poses.

Verify the pure core first: every action-budget transition, rejected actions
leaving state untouched, reproducible initiative/ties, actor removal, round
advancement and nonlethal outcomes. Then exercise actual navigation, turn input
gating, save/reload and exactly-once aftermath/rewards through the live scene.
Reactions, spells and broader enemy tactics follow that first encounter.

## Provenance

TemplePlus's pinned [license](https://github.com/GrognardsFromHell/TemplePlus/blob/03d7204510bc8401c67c59b3e4e23b6eefb087d0/LICENSE)
is MIT, copyright 2015 Circle of Eight. When implementation is copied or ported,
retain the full notice and license, add per-file upstream revision/function
references, and extend `ThirdPartyNotices.md` with the actual derived files.
The repository license is not permission to redistribute the original game's
binary, art or other separately licensed material. RainShadow's existing GemRB
licensing question remains recorded in `NavigationOpenQuestions.md`.

Related: [Wharf Ladder story combat](WharfLadderStoryCombatOct05.md) and
[character runtime recovery](CharacterRuntimeRecoveryOct05.md).


## Playing and verification

Open `Play Combat.command` for the shipping-office entrance with an isolated,
persistent playtest save. Open the painted door, click the opening and choose a
dialogue reply. The same combat is enabled through normal city travel.
Click ground to move, click an opponent to strike, use Defend or 1, End Turn or
Enter, and Yield or 3. Space pauses. A cyan/red mouse path preview shows whether
the requested route fits the remaining allowance. Inventory, travel and dialogue
choices cannot interrupt an active action. On touch devices, use the visible
buttons; no keyboard is required.

Core verification uses `TacticalCombatTests`, `WharfLadderStoryTests` and
`SaveStoreTests`. Live macOS verification uses `RAINSHADOW_QA_COMBAT=<output path>`
with a disposable save and fixed seed; read its `report.json`. The older
`RAINSHADOW_QA_WHARF` harness explicitly retains the historical cinematic branch
in DEBUG builds, so it remains a story-contract regression rather than claiming
to test the playable battle. Production encounters always use played combat.

Verified October 6, 2026:

- 32 tests passed across `TacticalCombatTests`, `WharfLadderStoryTests` and
  `SaveStoreTests` using the macOS SwiftPM package.
- macOS Debug and iOS Simulator Debug builds passed. The complete TemplePlus
  MIT notice was verified in both built app bundles.
- The live macOS harness passed all 24 checks, covering actual movement and
  attack input, advancing enemy walk frames, pause/input gating, identical
  save/resume state, and all four encounters with their authored aftermath.
  Report: `output/combat-qa-verified/report.json`; screenshots are beside it.
- The gate and clock-room screenshots were visually reviewed. The iOS build
  was compiled but has not been exercised on a simulator or physical device.


## Sneak Attack — October 7

Voss starts with a configurable 1d6 Sneak Attack ability. It adds damage to a
successful shortsword or bow attack when the attacker has net advantage, or a
conscious ally is within the game's melee reach of the target with an unblocked
line. Net disadvantage prevents it; opposing advantage/disadvantage cancel.
The roll uses two d20s and keeps the higher/lower result when appropriate.
Natural twenties roll twice the Sneak Attack dice; the existing base weapon
flat damage bands remain unchanged. Techniques can also receive the damage
bonus, after their normal damage adjustment. Ordinary enemies do not get the
ability; an authored `Combatant.sneakDice` opts them in (0–6 dice).

The bonus is spent only on a hit and refreshes when that actor ends its turn.
A miss still spends the normal attack action and reveals the attacker. There
is no extra-attack or opportunity-reaction system in the current combat model.
The explicit **Sneak attack** button refuses an ineligible target without
spending actions or rolls. It selects the shortsword at melee distance and the
bow at range. Explicit Sneak Shots use ordinary arrows; Fire arrow remains
fiery and can also gain the bonus against creatures. Barrels never receive it.
Bonus damage is saved atomically with the attack and displayed at its existing
impact marker, with a purple flash and a separate bonus label.

**Hide** uses one dedicated cunning-action allowance per actor turn, leaving
the TemplePlus standard/move budget unchanged. This is a RainShadow adaptation:
we have no rogue class progression, general bonus-action economy, perception
checks, darkvision or light-dependent stealth. Hide succeeds outside hostile
120-degree sight cones, or behind opaque terrain. It gives attack advantage
until attacking, taking damage, transforming or entering enemy sight reveals
the character. Movement checks the entire certified route for exposure,
including an enemy moving past a hidden actor. Sight queries use the existing
SearchMap adapter; no navigation/rendering port was changed. Red sight previews
are terrain-clipped and appear when Hide or Sneak attack is selected.

Hidden state, the Hide allowance, spent Sneak Attack, last seen position and
combat facing survive save/load. Older saves default safely. Enemies turn and
search toward the last seen location, revealing Voss if they regain sight.
They cannot directly attack a target that remains hidden. Existing weapon and
character animation bundles are reused without asset changes.

Reference rules: [BG3 Sneak Attack](https://bg3.wiki/wiki/Sneak_Attack_(Melee))
and [Hide](https://bg3.wiki/wiki/Hide). This is the scoped adaptation above,
not a claim of complete BG3 or TemplePlus stealth-rule parity.

Verification: 74 combat, bear, barrel, weapon-animation and Sneak Attack core
tests passed, including 10 Sneak Attack tests. macOS Debug and iOS Simulator
Debug builds passed. The live macOS Sneak Attack harness passed 40 checks in
`output/sneak-attack-qa/report.json`, covering both weapons, pointer input,
ineligible actions, sight-cone traversal, enemy search, impact timing and
save/reload. Melee impact, bow impact, blocked Hide and movement-exposure
captures were visually reviewed. iOS was compiled, not interactively exercised.
The existing player/enemy weapon-technique playtest also passed all 160 checks
in `output/sneak-technique-regression-qa/report.json` after the change.

## October 8 — Blade Ward replaces Defend

The human action bar and key **1** now cast Blade Ward for one standard action.
The previous +4 defence action is removed. Inspired by
[BG3 Blade Ward](https://bg3.wiki/wiki/Blade_Ward), the spell halves physical
attack damage, rounded down, including weapon techniques, Sneak Attack, arrows
and claws. Fire-arrow impact is physical; subsequent burning and barrel
explosions are fire and bypass the ward. A one-point physical hit becomes zero
damage and displays `WARDED`, with a hit/ward reaction rather than a dodge.

Duration is stored separately from turn-cleared weapon conditions: two turns
at cast, one at the next caster turn, removed at the start of the following
caster turn. Recasting refreshes two turns without stacking. Casting reveals a
hidden caster. The spell is granted directly to Voss in this prototype, without
a class-selection or spell-learning system. It cannot be cast in Bear Form;
an existing ward remains during transformation. This is a scoped adaptation,
not a complete BG3 spell system.

`bladeWardTurns` is optional in checkpoints. Old `defending` values remain
readable but no longer grant armour. The accepted cast is saved once; its UI
status remains on the prior presented state until the half-second cast marker.
Reload restores the ward without replaying the casting action.

The new 16-frame, 16-fps casting action draws the free palm inward, traces
outward, holds and recovers with planted feet. It has all 16 facings and matching
sword, mail and helmet layers. Bow/arrow layers are stowed during the gesture.
The actor, head, proportions, mesh, weights and skeleton are unchanged.
Authored through live Blender MCP in a private scene copied from the reviewed
human rig; incremental backup and reproduction scripts live in
`ArtSource/Blender/BladeWardOct08/`. The source action is
`BladeWard_Authored.blend`; `author_ward.py` and `render_mcp_source.py` reproduce
poses/rendering, and `ArtSource/Processing/package_human_ward.py` packages them.
The four additive `HumanBladeWard*` bundles retain the original palette and
pivot; `BladeWardAnimationSet` pins their hashes. Approved VossCHMF and bear
payloads remain unchanged.

`BladeWardVisual` uses the director's pause-aware clock for formation, rising
particles, persistent shimmer and blocked-hit flash. It follows the protected
actor, changes size with Bear Form, and disappears on expiry or defeat.

Validation: 68 tests across seven combat suites passed. All 1,280 render jobs
completed, body/material masks overlap exactly, all facings contain at least
13 distinct poses, and rest endpoints match. Both macOS Debug and iOS Simulator
Debug builds passed; all four shipped bundle hashes match in both builds.
The live ward playtest passed 22 checks, including casting/impact timing,
pause, inventory, damage reduction, expiry and save/reload. Casting and hit
captures were reviewed visually. iOS was build-tested only.
Run with `RAINSHADOW_QA_BLADE_WARD_ONLY=1` and
`RAINSHADOW_QA_COMBAT=<output-directory>`.
Report/captures: `output/blade-ward-oct08/`; animation preview:
`output/blade-ward-oct08/cast-animation.gif`.
The bear-form regression playtest also passed all 110 checks with its updated
action bar; report: `output/blade-ward-bear-oct08/report.json`.

## October 8 — explicit melee and retreat

The human action bar now starts with **Melee Attack**. It selects ordinary melee
without consuming an action until a valid target is clicked, reuses the existing
sword animation, and shows cyan reachable targets / red unavailable targets.
Hovering reports a valid strike, out-of-reach target, blocked line, or spent
standard action. Clicking an out-of-reach enemy is inert. Click the button again
or Escape to return to movement; direct enemy-click attacks still work. Bear
form keeps Claw Attack instead of showing the human melee button.

**Flee Combat [3]** replaces Yield in both forms. RainShadow uses a 60-foot
escape threshold (480 world units, measured by the existing ground-projected
combat distance). This is an authored map-scale choice, not an exact BG3 rule.
Every conscious enemy must be at least that far away. A rejected click reports
how much farther the player must retreat. Flee is available only on the player's
turn while standing; it needs no standard action after movement and respects
pause, inventory, and in-flight animation locks.

Escape has a separate saved `fled` outcome. It preserves human health, ends Bear
Form, removes encounter presentation/occupancy, and returns to exploration at
the retreat position. It clears the current request without granting crossing,
loot, injury, victory, or defeat aftermath. The encounter can be requested again
on a later visit. Enemy state is recreated on the next encounter, as in the
existing encounter lifecycle. Human health now persists in `SaveSnapshot` and
is used when starting the next fight; older saves default to 12. The existing
nonlethal victory/loss recovery remains unchanged. Legacy `yield()` is retained
only for defeat regression fixtures, with no player UI binding.

QA entry point: `RAINSHADOW_QA_ESCAPE_ONLY=1` with `RAINSHADOW_QA_COMBAT` set to
an output directory. `CombatEscapeTests` covers distance boundaries, nearest
conscious enemies, turn/prone restrictions, bear reversion, unchanged HP/action
budget/random state, old saves, and story retry without rewards.

Verification: 60 focused core/persistence tests passed; the live escape/melee
harness passed 24 checks and the bear regression passed 110 checks. Final macOS
and iOS Simulator builds succeeded (iOS build-only). Screenshots and reports are
in `output/flee-melee-oct08/` and `output/flee-bear-oct08/`.
