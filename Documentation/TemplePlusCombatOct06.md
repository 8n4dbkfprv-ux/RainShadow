# TemplePlus combat adaptation

Laurens selected TemplePlus on October 6, 2026 as the source for RainShadow's
turn-based combat adaptation. The integration will use selected rules ported to
Swift above RainShadow's existing navigation, actors and SpriteKit presentation.
Selecting this source does not automatically adopt every Temple of Elemental Evil
rule, character statistic or content asset.

Status: source selected and initial dependency audit complete. No combat runtime
or third-party implementation has been added by this decision record. The first
encounter scope below is proposed implementation work.

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

The first bounded port should be the action-budget transition logic, verified
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
- `SaveSnapshot` has no tactical encounter snapshot. Persist turn state, budgets,
  conditions, combatant positions and random state before supporting resumable
  fights. Saving only the existing story trigger cannot restore a mid-fight turn.

## First playable encounter

Proposed scope: one Wharf Ladder crew encounter with initiative, movement,
basic attack, a defined defensive action, end turn, simple enemy decisions and
nonlethal victory/defeat feeding the existing aftermath. Party membership and
Lila's presence need encounter authoring; her available appearance does not by
itself make her a staged combatant.

The current `CharacterBodyCode.frameCount` explicitly rejects attack, hit and
death, and equipment advertises idle/walk support only. A rules prototype may
use clearly provisional targeting and text feedback. A finished encounter needs
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
