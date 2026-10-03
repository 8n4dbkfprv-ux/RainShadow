# Player movement controls — September 29, 2026

The control adapter now follows the pinned GemRB revision `1c45c185` at the
command boundary as well as inside `Movable`. This comparison concerns GemRB,
not a claim to have inspected the proprietary Infinity Engine source.

## Source comparisons and corrections

### Replacement commands clear the previous route first

[`GameControl::CommandSelectedMovement`](https://github.com/gemrb/gemrb/blob/1c45c185/gemrb/core/GUI/GameControl.cpp)
stops the actor before creating a non-appended movement command:

```cpp
if (!append) {
    actor->Stop();
}
```

Previously `MovementOrderQueue.order` called `walkTo` against the live path.
That mistakenly applied the following-actor rate limit to fresh player clicks,
and preserved the previous route when a replacement search failed. A second
order while paused could report success while retaining the first destination.

Accepted replacements now stop first and reset the existing retry budget.
`Movable`'s rate limit and failed-repath behavior are unchanged.

### Blocked cursor clicks do not cancel movement

The same source's `OnMouseUp` returns before movement dispatch:

```cpp
if (lastCursor == IE_CURSOR_BLOCKED) {
    return false;
}
```

The adapter previously stopped in that branch. It now returns `.blocked`,
distinct from an accepted command whose path search fails (`.refused`). The
actor preserves its completion, and both scenes preserve waypoint pips.
The existing transient blocked-click marker remains an authored UI adaptation.

### Shift-click is dispatched before same-cell handling

`OnMouseUp` passes the Shift modifier to `CommandSelectedMovement` as append.
[`Movable::AddWayPoint`](https://github.com/gemrb/gemrb/blob/1c45c185/gemrb/core/Scriptable/Movable.cpp)
searches from the last path node. It does not test the actor's current cell
before deciding to append.

The adapter now handles append before its same-cell branch. Shift-clicking at
the actor's feet queues a return leg instead of cancelling the outward walk.
Interactions still replace movement, and ordinary same-cell clicks retain the
existing head-turn presentation.

### Replanning follows collision triggers, not elapsed wall time

[`Map::UpdateScripts`](https://github.com/gemrb/gemrb/blob/1c45c185/gemrb/core/Map.cpp)
has two relevant triggers:

```cpp
if (!actor->GetRandomBackoff() && actor->GetSpeed() > 0) {
    actor->NewPath();
}
```

and, in the moving branch:

```cpp
if (nearActor) {
    actor->NewPath();
}
```

The previous 0.75-second timer was not this logic. `prepareStep` now runs
before `DoStep` on each detective logic tick. Backoff expiry replans without
also stepping that tick. Nearby-actor detection uses `IEGeometry.personalDistance`
and the animation circle size, as `GetActorInRadius` does. Empty floor leaves
queued legs intact. A genuinely triggered `NewPath` can still discard them.

This is the controllable-player, noncombat branch (`GA_CAN_BUMP`). Occupancy
is the adapter's inventory of live scheduled actors. The hostile/non-bumping
radius branch is outside this change. Existing synchronous-search, retry-budget,
and last-cell-arrival adaptations remain; the raster and pathfinder are unchanged.

### Escape resets targeting rather than stopping the actor

`GameControl::DispatchEvent` handles Escape with:

```cpp
core->ResetActionBar();
core->SetEventFlag(EF_RESETTARGET);
```

Both scene handlers now retain their cutscene/overlay priorities and clear
transient targeting feedback without cancelling movement or waypoint pips.
There is no new Stop binding: explicit Stop remains separate from Escape,
and the existing internal cancellation API remains available.

## Verification

Behavioral regressions cover same-tick replacement while paused, failed
replacement, blocked clicks preserving movement, same-cell waypoint appends,
walking all queued legs on empty floor, the personal-distance boundary for a
nearby actor, self exclusion, and backoff expiry without a movement step.
The focused run passed 57 tests in six suites. Both macOS and iOS Simulator
Debug builds succeeded with code signing disabled. No interactive playtest was
performed.

`ActorLocomotionPacingTests.actorsWireDeltaLocomotionAndShippedPacingConstants`
has two pre-existing source-string failures: it requires
`completeSeatFrameSequence` and the old `loadSeatAnimationFrames` assignment.
Neither exists in the baseline HEAD detective source. Those character-runtime
assertions are not changed by this movement correction.

The broader `ActorFootprintTests` check also reports three office assertions:
two floor-cell baseline counts and one occupied approach adjacency check.
Those tests call unchanged office geometry, occupancy, and `NavigationMap.path`
directly; they do not exercise `MovementOrderQueue` or the scene controls.
Their baselines and authored geometry were left intact rather than relaxed.

Follow-up: the animation comparison in `MovementAnimationSep29.md` replaced
the obsolete Voss loader source-string assertions with the current named-bundle
contract. Those actor-wiring tests and the stronger all-frame asset tests now pass.
