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
