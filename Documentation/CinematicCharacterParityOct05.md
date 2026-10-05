# Cinematic character behavior — October 5

The walking adapters were checked against the repository's pinned GemRB revision,
`1c45c1850d9b5d61a23b3a569499ef57543e2c3f`. This is source-level agreement with
that Infinity Engine reimplementation, not a claim of a frame-for-frame capture
comparison with the closed-source BG:EE executable. VossCHMF and LilaSentinel,
their approved payload hashes, equipment, palettes and seated registration remain
unchanged.

## Upstream comparisons and corrections

### Actors remain physical during a cutscene

[Movable::DoStep](https://github.com/gemrb/gemrb/blob/1c45c1850d9b5d61a23b3a569499ef57543e2c3f/gemrb/core/Scriptable/Movable.cpp)
checks both participants:

```cpp
if (actorInTheWay && blocksSearch && actorInTheWay->BlocksSearchMap()) {
```

Its wall branch separately includes:

```cpp
if (blocksSearch && !core->InCutSceneMode() &&
    bool(area->GetBlocked(wallProbe) & PathMapFlags::SIDEWALL)) {
```

Lila previously stamped NPC occupancy but constructed her mover with
`blocksSearchMap: false`. She now participates in the same actor collision,
bumping and backoff as Voss. Both actor adapters pass the director's cutscene
mode to `DoStep`. That skips the per-step SIDEWALL check only; it does not disable
actor occupancy or pathfinding clearance. Normal movement retains the wall check.
The scene now relays bump requests in both directions. Bump recovery runs on
each actor's 15 Hz logic clock instead of Lila's old per-render-frame pump.

### Backoff is serviced and replanned

[Map::UpdateScripts](https://github.com/gemrb/gemrb/blob/1c45c1850d9b5d61a23b3a569499ef57543e2c3f/gemrb/core/Map.cpp)
contains:

```cpp
actor->DecreaseBackoff();
if (!actor->GetRandomBackoff() && actor->GetSpeed() > 0) {
    actor->NewPath();
}
```

`Movable.advanceBackoff` implements this for both adapters: the expiration tick
replans but does not also step. Lila previously never decremented backoff; Voss
only decremented it. The helper follows `Actor::NewPath`'s saved destination,
minimum distance and retry-limit branch. The repository's documented omission
of `Actor::WalkTo`'s unconditional `ResetPathTries` remains intact.

### Animation uses the cached stance and direction

[CharAnimations::GetAnimation](https://github.com/gemrb/gemrb/blob/1c45c1850d9b5d61a23b3a569499ef57543e2c3f/gemrb/core/CharAnimations.cpp)
selects `Anims[stanceID][Orient]` and returns an existing animation without
resetting it. New animations start at frame zero.

[Actor::AdvanceAnimations and DrawActorSprite](https://github.com/gemrb/gemrb/blob/1c45c1850d9b5d61a23b3a569499ef57543e2c3f/gemrb/core/Scriptable/Actor.cpp)
use these separate calls:

```cpp
first->NextFrame();
Holder<Sprite2D> currentFrame = anim->CurrentFrame();
```

The draw therefore uses the **post-advance** index; `NextFrame`'s return value
is ignored by the actor advancement call. Voss previously displayed the earlier
index through `ActorAnimationClock` and reset his walk clock on re-entry. He now
uses `IEActorAnimationPlayback`, as Lila already did, including standing idle.
This preserves independent stance/direction clocks, integer `1000 / 15` frame
duration, catch-up with discarded remainder, and pause handling. Movement still
uses integral root positions, the original speed and fixed logic ticks.

### Arrival facing and action completion

`DoStep` ends a path with `NewOrientation = Orientation`; it does not face the
actor toward a fixed compass direction. Lila's arrival now retains that final
orientation. The entrance catalog explicitly queues `FaceObject` toward Voss
before dialogue, including skip recovery. While backing off she displays idle
in her current movement direction.

[GameScript::MoveToPoint](https://github.com/gemrb/gemrb/blob/1c45c1850d9b5d61a23b3a569499ef57543e2c3f/gemrb/core/GameScript/Actions.cpp)
releases an action when the actor cannot move:

```cpp
if (!actor->InMove()) {
    actor->ClearPath();
    Sender->ReleaseCurrentAction();
}
```

Voss's scripted move adapter now releases its completion when movement is
abandoned. A failed ordinary gameplay approach still does not fire an object
interaction. Clearing an action explicitly discards its completion.

## Verification

- macOS Debug and iOS Simulator Debug builds passed.
- 89 focused Swift tests passed: CinematicMovementTests, CutsceneCatalogTests,
  IEActorAnimationTests, LiteralPortTests, MovementIntegrationTests,
  MovementOrderQueueTests, CharacterRuntimeIdentityTests, ActorFacingTests and
  MovableTests.
- `RAINSHADOW_QA_CINEMATIC_CHARACTERS=<directory>`: 15 deterministic production
  actor checks passed, including matching root positions and walk frames,
  paused clocks, walk restart, arrival facing, blocking/backoff/resume and
  scripted versus gameplay completion. The hook bypasses GameBootstrap and
  validates the packaged character payload hashes without opening a player save.
- `RAINSHADOW_QA_OFFICE_RESTORE=<directory>`: all 30 existing scene integration
  checks passed with the explicit Face action. Native-renderer captures of
  Lila walking and standing were reviewed. The check also covers Voss's seated
  recovery, office exit and current characters after city travel.

Logs and reports for this run are in
`/tmp/rainshadow-character-cinematics-oct05/`.

The broader test selection is **not green**. Unchanged CutsceneRunnerTests still
assert that ActionOverride joins the issuing queue and Face is instantaneous;
ActorLocomotionPacingTests assert retired frame-strip/transition implementation
text; EmptyCoatCaseIntroductionTests expect the old command subject; and Lamp
Ward tests reference missing RS0400/RS0401 validation fixtures. Catalog assertions
in the edited suite were updated to the current actor-owned continuation and
explicit facing, with simulated completions for overridden actor queues. No
runtime behavior was changed to satisfy the stale assertions.
