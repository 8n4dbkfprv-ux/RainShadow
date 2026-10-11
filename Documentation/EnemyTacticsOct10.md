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

## October 11 — combat comparison and enemy Shove

The original Shove candidate was restricted to archers with an unspent standard
action. Melee enemies could never choose it; archers could never choose it after
shooting. The resolver and presentation already supported both cases.

Every role now evaluates a legal, raster-certified shove landing, independently
of the standard action and remaining movement. Melee actors attack before pushing
their victim out of reach. A successful push can force an opposing melee actor to
spend movement closing again, free an archer, protect a wounded fighter, or put a
rival within an ally's melee reach before that rival's turn. The score is weighted
by the actual shove success probability. It rejects pushes that spoil an imminent
allied melee attack, deliver a rival to a vulnerable ally, merely grant an opposing
bow separation, or nudge someone against a wall without a positional benefit.
No new approach-to-shove search is added, so archers don't run into melee just to
push and retreat again. Resolution, bonus-action consumption, animation, weight
limits, goading restrictions and save format are unchanged.

Evidence and limits:

- [Larian Patch 2](https://baldursgate3.game/news/patch-2-now-live_89), Combat and
  Balance, explicitly documents a fix for NPCs running towards a target to Shove
  and then away again to make a ranged attack. This confirms AI use of Shove and
  that such wasteful positioning was a bug, not a behaviour to copy.
- [Larian Patch 6](https://baldursgate3.game/news/patch-6-now-live_108) documents
  AI pathfinding through dangerous surfaces and steep terrain. The original comparison preceded the hazard work below. Painted scenery
  is never treated as a damaging landing without a matching terrain query.
- [Werglia's Refectory encounter](https://www.youtube.com/watch?v=n9jSLhS83bw)
  is a relevant 2023 PC Tactician reference, but playback could not be inspected
  in the research tools. No turn timings or individual NPC choices from that
  recording are asserted here. These scores remain RainShadow design decisions.

The code comparison also confirms that archers already sample clear firing lanes
and can spend leftover movement retreating, while melee approach/Dash choices
require certified routes. Repeated actions can still be correct with the same
loadout and positions. High ground, opportunity attacks, Disengage, jumping and
party-wide target selection are not added by this change.

Regression coverage adds melee attack-then-shove, an archer with both attack and
movement spent, allied archer protection, harmful destinations, wall clipping,
and deterministic planning without state/occupancy changes. `EnemyTacticsQA`
also runs guaranteed-success melee and archer shoves on the shipped area raster,
checking actual contact animation, displacement, normal attacks, turn completion
and saved outcomes. Its isolated snapshots do not modify the player's save.

Validation: 54 tests across seven combat/movement suites passed; macOS and iOS
Simulator builds passed; 34 native checks passed. Final report and contact-frame
captures: `output/enemy-shove-oct11-final/`.


## October 11 — oil surfaces and waterfront drops

Both Wharf Ladder and the Shipping Room now have combat oil barrels. An old
Shipping Room checkpoint with no barrels receives certified floor placements on
load; existing intact, broken and exploded barrel entries are preserved.
A Fire Arrow creates a saved, wall-clipped footprint within 56 ground units of
each exploding barrel. The fire expires at the start of round `ignitionRound + 3`.
Entering or crossing it applies Burning (1d4 at the end of the affected actor's
turn, two turns); standing in live oil refreshes Burning. Leaving the oil allows
Extinguish. There are no real-time damage ticks or stacked ticks for overlapping
surfaces. Fire visuals clear when the encounter finishes.

Shove evaluates burning destinations and terminal drops into the wharf's existing
terrain-12 water. Falling uses the ordinary push distance, the airborne portion of the
backwards-fall reaction, a gravity-driven drop, submersion and a water splash. It removes the victim from this
nonlethal fight; Voss recovers at his saved last dry position after the loss
narration. The indoor floor has no drop hazard. Explosion impulses retain their
ground-clipped water behavior, but landing in burning oil ignites survivors.

The fall adapter permits the body's clearance fringe to overhang water; every
sample must still contain only floor/deep water and no actor, door, wall or
railing. It does not edit `SearchMap`, `PathFinder`, walkability, area rasters,
geometry or character payloads. Save/reload commits the result once, with no
repeated explosion or fall. New optional fields keep earlier checkpoints readable.

Enemy scores include fire exposure, escape from burning oil, and successful
water removal. This is a bounded candidate policy, not a global hazard-aware
pathfinder or a copy of Larian's AI. A route through fire has a substantial
penalty, and automatic fallback approaches reject it. The player sees warnings
on movement/approach paths and shove landing previews, plus the barrel's fire
lifetime before ignition.

Native verification is in `EnemyTacticsQA.hazards`, selected with
`RAINSHADOW_QA_HAZARDS_ONLY=1` alongside the existing approach/enemy QA flags.
It fires actual player arrows in both areas, verifies impact timing, pause,
saves and reloads, and performs an overboard shove at a real pier edge.


Validation: 83 tests across nine combat/navigation suites passed, including the
new hazard tests against both shipped rasters. macOS and iOS Simulator target
builds passed. Native QA passed 32 checks; screenshots and the report are under
`output/combat-hazards-oct11-water-fix-final/`. Only macOS was exercised interactively.


### Water-fall presentation correction

The first version could register an overboard result while the body remained at
deck height: `applyAreaLighting` also sets the actor's floor-height offset, so
calling it after the fall offset erased that displacement every frame. The
director now applies the airborne offset after floor lighting and before stencil
setup. `CombatWaterFallMotion` keeps the character opaque during the descent,
triggers the splash only at the lower water plane, and then continues downward
while fading. It uses the first six backwards-fall poses, not the floor-collapse
or get-up portions. The ground contact shadow is hidden during flight.

Native regression checks inspect the actual visible node's position, reaction,
height and alpha at the airborne and splash moments, and freeze both axes during
tactical pause. This specifically catches a correct math helper being overwritten
later in the rendering update.

### Burning-oil texture pass

`CombatFireSurfaceVisual` now uses two transparent image-generator assets:
`burning_oil_surface_v01.png` for glossy, charred oil and
`oil_fire_flame_v01.png` for detailed flame tongues. One continuous ground
decal is sampled across the certified fire cells, retaining the existing floor
clipping. Flame sprites vary in height, sway and orientation over a subtle
additive glow. Mipmaps filter the high-resolution artwork at gameplay scale.
Combat timing, damage, saves and pause behavior are unchanged.

The original prompts, source paths and SHA-256 hashes are recorded in
`BurningOilTexturesOct11.json`. Runtime PNGs are in
`RainShadow Shared/Resources/Art/Combat/` and included in both app targets.

Texture-pass validation: macOS and iOS Simulator builds passed. The native
hazard QA passed all 32 checks; both burning-oil screenshots were inspected at
gameplay scale. Results: `output/oil-fire-textures-oct11-final/`. iOS was
build-checked only.
