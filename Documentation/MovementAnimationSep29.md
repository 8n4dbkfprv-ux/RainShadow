# Creature movement animation — September 29, 2026

The movement animation adapter was compared with GemRB `1c45c185`.
The VossCHMF manifest, indexed planes, palette, native pivots and 1,556-frame
inventory are unchanged. Root-motion arithmetic and navigation are unchanged.

## Source comparison

[`Actor::AdvanceAnimations`](https://github.com/gemrb/gemrb/blob/1c45c185/gemrb/core/Scriptable/Actor.cpp)
selects the stance and orientation, then calls `first->NextFrame()` when the
actor is not immobilized. This is drawing-state work, not part of `DoStep`.

[`Animation::NextFrame`](https://github.com/gemrb/gemrb/blob/1c45c185/gemrb/core/Animation.cpp)
uses integer milliseconds:

```cpp
tick_t delta = 1000 / fps;
```

On a delayed draw, it catches up and discards the remainder:

```cpp
tick_t inc = (time - starttime) / delta;
frameIdx += inc;
starttime = time;
```

Pause holds the last time and adjusts the start time on resume. At the default
15 fps the threshold is 66 ms, independently of the 15 Hz gameplay tick.
`IEActorAnimation` ports the looping game-animation branch; it does not claim
to implement attack/death one-shots or status-effect immobilization.

[`CharAnimations::GetAnimation`](https://github.com/gemrb/gemrb/blob/1c45c185/gemrb/core/CharAnimations.cpp)
looks up `Anims[stanceID][Orient]`. Cached animations keep their own frames and
timers. Newly loaded clips start with `newanim->SetFrame(0)`. The new playback
cache follows that behavior, including elapsed-time catch-up when a cached clip
is selected again. It does not transfer one global stride phase between all
directions or restart every idle turn.

[`Movable::DoStep`](https://github.com/gemrb/gemrb/blob/1c45c185/gemrb/core/Scriptable/Movable.cpp)
assigns `SetOrientation(step.orient, false)`. `Backoff` and the zero-speed branch
select READY; completed walking clears the path and returns to AWAKE.

## Corrections

- Voss's walking frames no longer advance only on successful movement steps.
  Drawing selects the clock and frames for the current stance/direction after
  movement updates. Backoff and zero movement speed no longer hold a walking
  frame. Arrival selects idle, and pause preserves the current frame/timing.
- Voss's standing idle no longer restarts an SKAction at frame zero whenever
  he changes facing. Directions have independent cached clocks.
- Starting a route does not aim the visible actor ahead of the first movement
  step. Lila's departure strip uses `movable.orientation`, not a look-ahead
  vector over future route segments. Direction changes have no crossfade.
- The procedural idle body turns and Lila's vertical idle bob were removed.
  These were invented root/body motions rather than authored stance frames.
  Same-cell floor clicks retain the body heading; GemRB requests HEAD_TURN
  there, rather than orienting the entire creature toward the click.
- Current Voss uses all ten walk phases per direction. Lila retains her eight
  phases. Neither inventory is coerced to the other's cycle length.

## Art adapters retained

VossCHMF has no dedicated READY or HEAD_TURN clip. Both use authored standing
idle as a visible fallback. Lila has only a SW arrival strip, NW/NE departure
strips and one standing idle; arbitrary-direction NPC animation is therefore
still limited by the supplied art. No mirrored handbag, synthesized geometry,
or substitute historical Voss atlas is introduced.

The four reviewed chair chains, their authored timing and seat-egress
registration remain the room-specific adapter. They are not claimed as a
literal GemRB character stance implementation. The 65-frame seated idle still
uses the authored SpriteKit sequence.

## Verification

- 56 tests in six suites pass: animation timing, actor wiring, current Voss
  inventory and all-frame pixel hash, chair endpoints, movement commands,
  arrival, and office/city movement integration.
- macOS Debug and iOS Simulator Debug builds pass.
- `Tests/RuntimeQA/qa_movement_animation.swift` links the actual macOS
  actor objects. Its isolated SpriteKit nodes verify first walk frame, timed
  advance, pause/resume, backoff pose and stationary root, arrival, completion
  count, same-cell heading, and both Lila exit strips without a blend layer.
  This is an executable presentation check, not an interactive scene playtest.
- The old source-string assertions for the retired Voss seat loader were
  updated to the current validated VossCHMF loader. The stronger inventory,
  native-pixel and exact chair endpoint tests remain unchanged and pass.

To reproduce the actor harness after building macOS Debug to
`/tmp/RainShadowMovementControlsMac`, prepare a linker file list from
`Build/Intermediates.noindex/RainShadow.build/Debug/RainShadow macOS.build/Objects-normal/arm64/RainShadow.LinkFileList`,
omitting only `AppDelegate.o` (the app entry point). Then run from the repo:

```sh
swiftc -parse-as-library \
  -I /tmp/RainShadowMovementControlsMac/Build/Products/Debug \
  Tests/RuntimeQA/qa_movement_animation.swift \
  -Xlinker -filelist -Xlinker /tmp/rainshadow-movement-audit/actor-qa-objects.txt \
  -o /tmp/rainshadow-movement-audit/actor-animation-qa
/tmp/rainshadow-movement-audit/actor-animation-qa
```

The harness creates no scene and does not read or write player saves.
