# Enemy combat roles — October 10

`EnemyTactics.swift` replaces the live director's fixed technique priority with
scored, deterministic choices. This is RainShadow gameplay policy, not a BG3 AI
port. The GemRB navigation files and TemplePlus action transition table are unchanged.

## Roles and loadouts

- **Bruiser:** sword, normal melee and Power Strike. Closes to attack range;
  the accuracy penalty must be worthwhile before spending the technique.
- **Opportunist:** sword, Trip Attack and Feinting Cut. Values Trip when a
  conscious nearby melee ally will act before the victim's next turn. Otherwise
  weighs Feint's protection against the damage sacrificed. Repeated conditions
  and already-spent techniques offer no benefit.
- **Archer:** existing Lookout bow, backup sword, Aimed Shot, Pinning Shot and
  limited Fire Arrows. Values Pinning when halved speed stops a melee approach,
  creates distance before a shot, and can retreat with leftover movement.
  Safe firing positions plateau in value, preventing endless retreat.

The lane has a Bruiser and Opportunist; the gate keeps its Bruiser and Lookout.
Roles are shown in the initiative names for former generic Hands and in Examine.
HP, damage, initiative bonuses, character art and animation payloads are unchanged.
Selected attacks use their existing distinct animations.

## Decisions and safety

Normal attacks, techniques, fire ammunition, attack approaches, archer repositioning,
bonus shoves, extinguishing flames and safe barrel chains compete for value.
Scores use the shared hit/damage preview, finishing potential, useful conditions,
initiative timing, movement cost, proximity to threats and oil barrels, and the
cost of spending an encounter technique or Fire Arrow. The scores are authored
heuristics, not a full combat simulation or a guarantee of an optimal turn.

The planner never rolls dice or consumes resources. It enumerates candidates in
stable order and preserves occupancy after every query. Navigation certifies
paths; accepted moves spend the actual route length. After walking, decisions
are recomputed at the actual arrival position. Full-turn Aimed Shot remains
unavailable after movement. Dash is an explicit fallback when there is no useful
attack, and sparse straight paths are truncated to a newly certified integral
endpoint rather than dropping the entire long segment.

Explosions evaluate the entire visible chain and reject any blast that would hit
a conscious ally, including the shooter. Goading retains its target restriction.
Concealed enemies are not candidate targets; the director retains its last-seen
search and can extinguish flames while no target is visible. This encounter
format still supports one player combatant; broader party targeting, spellcasters,
healers, boss mechanics and difficulty profiles are future work.

## Save compatibility

`Combatant.enemyRole` is optional. Encounter creation and restoration assign
missing roles by stable enemy ID order and existing bow equipment. The migration
preserves health, positions, initiative, turn budget, dice state, ammunition and
spent techniques. Existing role assignments are preserved. New roles restrict
NPC technique eligibility in both preview and resolution; player options stay
unchanged. Reopen the game through `Play Combat.command` to rebuild and resume.

## Verification

- `EnemyTacticsTests`: role-specific choices, initiative-aware Trip, finishers,
  poor accuracy, used charges, pinning, Fire Arrow conservation, archer retreat
  termination, chain explosion ally safety, extinguishing, deterministic/read-only
  planning, old saves, blocked/hidden targets and approach/Dash budgets.
- Combat/navigation regression subset: 139 tests in 19 suites passed.
- Native QA: 19 checks passed, including `EnemyTacticsQA` with two rounds each of melee and archer encounters, movement
  and attack animation playback, turn completion and save equality. Uses isolated
  temporary saves; never changes the player's combat checkpoint.
- macOS and iOS Simulator target builds passed.

Native QA invocation after the macOS build:

```sh
RAINSHADOW_QA_COMBAT="$PWD/output/enemy-tactics-oct10" \
RAINSHADOW_QA_APPROACH_ONLY=1 RAINSHADOW_QA_ENEMY_TACTICS=1 \
/tmp/RainShadowCombatApp/Build/Products/Debug/RainShadow.app/Contents/MacOS/RainShadow
```

Report and screenshots: `output/enemy-tactics-oct10/`.
