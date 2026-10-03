# Cinematic behavior audit — 2 October 2026

The reference is GemRB **1c45c1850d9b5d61a23b3a569499ef57543e2c3f**, the same
revision as RainShadow's movement/render ports. GemRB is an open-source
reimplementation, not the proprietary Infinity Engine source. This audit aligns
the implemented action subset; it does not certify every IE game or every script
opcode. The EE breakable-cutscene contract is separately documented by IESDP,
because `SetCutSceneBreakable` is a TODO at this GemRB revision.

## Verified differences and repairs

These are the upstream comparisons required by AGENTS.md. Source links are pinned,
so the evidence does not depend on later changes to master.

| Behavior | Before | Corrected |
|---|---|---|
| ActionOverride | Issuer blocked on the target's work | Issuer releases; target executes its own queue. BG2 clearing preserves previous overrides and discards ordinary target actions. |
| Repeated CutSceneId | Debug assertion; duplicate subjects unsupported | Blocks append to the same subject queue in script order. |
| Immediate action processing | Interleaved individual actions across subjects | Drain a subject until it blocks, then process the next subject. |
| MoveViewPoint / MoveViewObject | Blocked; object was continuously followed | Non-blocking; object position sampled at dispatch. Explicit MoveViewPointUntilDone is the blocking alternative. |
| Camera movement | Camera jumped immediately; a separate SKAction timer pretended to scroll | Actual integer viewport steps on the 15 Hz clock; completion follows arrival or the area boundary. |
| Camera speed / distance | Ad hoc fractions of actor speed; y unprojected | `scroll.ids * 2` projected pixels per tick; Euclidean distance in screen/map coordinates. |
| Face / FaceObject | Slow dialogue pivot; Lila asserted on obsolete art assumptions | Immediate orientation plus one update of queue delay. Lila uses her current sixteen-direction idle set. |
| DisplayStringHead | Blocked for the text lifetime; one shared label | Non-blocking and independent actor labels. Reading pauses are explicit Wait cues. |
| Fades | Only issuing track waited; other scripts advanced | All cinematic action queues and their wait clocks suspend during the fade, matching the pinned GlobalTimer. Office locomotion and area script/trigger ticks also freeze. Viewport/fade rails continue. |
| Batched ticks | Later waits started at the end of the batch | All intermediate deadlines are processed, matching one-tick advancement. |
| MoveToPoint | Unrouted single-point polyline (client discarded the sole point) | Query the area's NavigationMap, then drive the existing actor locomotion. Shipped movement now uses that action rather than a separate polyline cue. |
| JumpToPoint / skip | Client ignored supplied endpoint; plain jumps left movement alive; stand-up could keep animating | Stop old movement, synchronize its position, use the supplied endpoint; recovery authors its own animation/visibility actions. |
| Callback lifetime | Old or synchronous callbacks could finish another cue/run or re-enter dispatch | Run/actor generations invalidate stale callbacks; completion steps are drained after the current command batch. No scroll SKAction timer remains. |
| Mode and input | Denied skip fell through to normal input; dialogue could retain cutscene mode | Mode owns input even when skipping is denied; ordinary controls/overlays/panning are gated. EndCutSceneMode is independent of queue completion; entrance ends mode before reopening dialogue. |
| Skip recovery | Flattened unfinished tracks were claimed to guarantee an identical ending | Every shipped sequence has an authored recovery list, like EE's failsafe script. Settle actors before facing/camera/dialogue; departure also snaps the door and camera restore. |

### Action queues

[GameScript.cpp — EvaluateAllBlocks, ExecuteAction, HandleActionOverride](https://github.com/gemrb/gemrb/blob/1c45c1850d9b5d61a23b3a569499ef57543e2c3f/gemrb/core/GameScript/GameScript.cpp)
contains:

```cpp
// and then add the actions to that object's queue.
Sender->ReleaseCurrentAction();
HandleActionOverride(scr, aC);
target->ClearActions(1);
target->AddAction(newAction);
```

The previous `.actionOverride` recursively inherited the target cue's duration
and reported completion to the issuing track. It now queues a marked entry on
the target. `Scriptable::ClearActions(1)` preserves marked overrides. An internal
clear command stops replaced actor movement and invalidates its callback.

[Scriptable.cpp — ProcessActions](https://github.com/gemrb/gemrb/blob/1c45c1850d9b5d61a23b3a569499ef57543e2c3f/gemrb/core/Scriptable/Scriptable.cpp)
loops over an actor's queue until `WaitCounter`, `CurrentAction`, fade or movement
requires yielding. Same-subject blocks therefore serialize; ActionOverride is
not a join. The shipped scripts now sequence continuation on the moving actor itself; the
local `waitForSubject` extension has been removed.

### Viewport, facing, overhead text and waits

[Actions.cpp — MoveViewPoint / MoveViewObject](https://github.com/gemrb/gemrb/blob/1c45c1850d9b5d61a23b3a569499ef57543e2c3f/gemrb/core/GameScript/Actions.cpp#L1125):

```cpp
// these two don't appear to be blocking at all
core->timer.SetMoveViewPort(scr->Pos, parameters->int0Parameter << 1, true);
```

`MoveViewPointUntilDone` separately polls `ViewportIsMoving()`.
[GlobalTimer.cpp — DoStep](https://github.com/gemrb/gemrb/blob/1c45c1850d9b5d61a23b3a569499ef57543e2c3f/gemrb/core/GlobalTimer.cpp)
uses integer distance, `count * speed`, and integer point interpolation. The
port represents viewport **centres** in y-up coordinates; existing
`AreaViewport` still owns clamping. Actor projection is not applied twice.

[Actions.cpp — Face / FaceObject](https://github.com/gemrb/gemrb/blob/1c45c1850d9b5d61a23b3a569499ef57543e2c3f/gemrb/core/GameScript/Actions.cpp#L1782):

```cpp
actor->SetOrientation(actor->Pos, target->Pos, false);
actor->SetWait(1);
Sender->ReleaseCurrentAction();
```

The `false` is immediate orientation. Dialogue's slow facing uses a different
call path and is preserved. `DisplayStringHead` is registered with action flags
`0`; its visible lifetime does not become a Wait. Wait and SmallWait decrement
per engine update, so advancing five ticks must visit a deadline at tick two
before scheduling another wait from there.

### Fades, mode and breaking

`FadeToColor` and `FadeFromColor` release the sender, but
`Scriptable::ProcessActions` stops when `core->timer.IsFading()`.
`GlobalTimer::Update` also says:

```cpp
// don't update scripts if we're fading in or out or shaking the screen
if (IsFading() || shakeCounter) {
```

This is a global script freeze, not an actor-local fade duration. Viewport and
fade updates run before that guard. There is no cinematic zoom rail.

[GameControl.cpp — SetCutSceneMode](https://github.com/gemrb/gemrb/blob/1c45c1850d9b5d61a23b3a569499ef57543e2c3f/gemrb/core/GUI/GameControl.cpp#L2701)
resets the scrolling vector and sets `IgnoreEvents`. It does not require action
queues to be empty before EndCutSceneMode restores input.
[Interface.cpp — SetCutSceneMode](https://github.com/gemrb/gemrb/blob/1c45c1850d9b5d61a23b3a569499ef57543e2c3f/gemrb/core/Interface.cpp#L2437)
also calls `CloseTopWindow` on entry; the bridge closes existing overlays and
clears held scroll input before starting the cinematic.

[IESDP — SetCutSceneBreakable](https://gibberlings3.github.io/iesdp/scripting/actions/bgeeactions.htm#387)
documents a separate area failsafe script for an interrupted sequence. It does
not guarantee that executing all remaining actions in arbitrary track order
produces a safe ending. RainShadow now authors recovery for the opening,
entrance and departure, including the skipped exit's door and camera restoration.

## Removal of the deliberate cinematic extensions

The follow-up request removes the previous presentation exceptions rather than
retaining them as options:

- Removed `cameraScale`, its independent subject/rail, scale constants and
  smoothstep interpolation. Pans preserve the existing viewport scale, including
  teardown. Player zoom remains the separate GemRB zoom-ladder port.
- Removed the letterbox cue/node. `SetCutSceneMode` hides the entire HUD
  immediately, matching Interface's `ToggleViewsVisible(!active, "HIDE_CUT")`.
  The opening's title overlay and cinematic crossfade were removed as well.
- Removed additive warm-window bloom. The pinned Actions.cpp passes only
  `pointParameter.x` to the fade timer. Both actions draw a black alpha overlay.
- Removed doorway alpha ramps. The entrance/departure scripts use explicit
  `HideCreature` and routed `MoveToPoint`; `JumpToPoint` no longer changes
  visibility implicitly. The old `followPath` cue has been removed.
- Removed the one-second grace and pointer/confirm skipping. Breaking requires
  an explicit `SetCutSceneBreakable(true)` and Escape is accepted immediately.
  Runtime `false` disables breaking immediately. The default is unbreakable.
- Removed terminal-form conversion and automatic draining of unfinished cues.
  Escape clears interrupted queues. Authored recovery runs through ordinary
  queues, preserving its actual waits, animations and fades. No recovery means
  no synthetic execution of the discarded work.
- `Wait` now accepts integer seconds; fractional authored timing uses `SmallWait`
  ticks. The custom cross-track join has been removed; movement owns its own
  continuation. `PlaySequence` is non-blocking and `WaitAnimation` separately
  waits for the stance to finish (or the upstream `> round_size` limit).
- Removed the post-departure SpriteKit camera ease; the script authors its
  viewport placement before releasing camera ownership.

### Additional quoted comparisons

[GlobalTimer.cpp](https://github.com/gemrb/gemrb/blob/1c45c1850d9b5d61a23b3a569499ef57543e2c3f/gemrb/core/GlobalTimer.cpp),
`SetFadeToColor` / `SetFadeFromColor`, documents the zero convention:

> oddly, if a 0 is passed, the last used duration is used (first time the engine default)

`CutsceneFadeTimer` now preserves that convention and truncates the computed
alpha to an integer byte. Its counter/fallback branches follow `DoFadeStep`:
scripts resume on the update that completes the fade (not one tick later),
fade-to suspends fallback countdown, fallback clears black after 150 later
updates, and fallback itself does not suspend scripts. The timer continues
when the cinematic queues have finished. Constants come from the pinned
[BG2 gametime.2da](https://github.com/gemrb/gemrb/blob/1c45c1850d9b5d61a23b3a569499ef57543e2c3f/gemrb/unhardcoded/bg2/gametime.2da):
`FADE_DEFAULT 20`, `FADE_RESET 150`. There is no zero-means-instant exception.

[Actions.cpp](https://github.com/gemrb/gemrb/blob/1c45c1850d9b5d61a23b3a569499ef57543e2c3f/gemrb/core/GameScript/Actions.cpp),
`MoveToPoint`: `actor->WalkTo(parameters->pointParameter, parameters->int0Parameter);`.
The director asks NavigationMap for the actor-blocking path, lifting the moving
actor's stamp, then feeds that path to the existing Movable locomotion.
No navigation, raster or projection algorithm was changed.

`HideCreature`: `actor->SetBase(IE_AVATARREMOVAL, parameters->int0Parameter);`.
This is a visibility change, not an alpha animation. The scene's existing actor
occupancy update removes the hidden actor from navigation.

`PlaySequence` calls `PlaySequenceCore` without a wait; `WaitAnimation` releases
when the actor's stance differs or `int1Parameter > core->Time.round_size`.
The shipped get-up sequence uses Voss's current chair animation. A late animation
callback can release only its matching WaitAnimation, never a later walk.

## Scope of the comparison

The shipped action subset is compared with the pinned GemRB implementation and
EE's documented breaking behavior. Swift catalogs and stage adapters remain the
content interface; this work does not add a BCS parser, every IE opcode or a
movie decoder. The virtual camera/chrome subjects have been removed. Scripts use actual actor
queues or the opening's world-script queue.

## Verification

- 32 core cinematic tests pass. They exercise actual integer viewport pans, fade alpha/default
  reuse/reset, runtime breakability, discarded interrupted actions, normal
  recovery timing, PlaySequence/WaitAnimation and both shipped office routes.
- `python3 ArtSource/Processing/qa_cutscene_director.py` compiles the production
  SpriteKit director, chrome, runner and viewport against small stage/actor test
  doubles. It checks fixed scale, absence of bars, full GUI hiding, black alpha
  blending, callback lifetimes and animation wait behavior without loading or
  changing game assets or saves. All 24 checks pass.
- macOS Debug and iOS Simulator Debug builds pass with signing disabled.
- The broader run executes 317 tests: 309 pass, 8 fail (10 assertions/errors).
  All 10 issues reproduce against the saved pre-audit baseline: two dialogue
  framing assertions; missing retired opening-page JSON in two pager tests;
  office door stamps, a fractional departure endpoint, a retired Sable Row
  portal and one city landmark route. These authoring/resource assertions are
  preserved, not loosened to conceal the failures.

This machine uses `/Applications/Xcode-beta.app/Contents/Developer` via
`DEVELOPER_DIR`; SwiftPM uses that toolchain's `swift`, `--disable-sandbox`, a
`/tmp` scratch path and `/tmp` module caches. The command-line-tools Swift lacks
its Testing macro plugin here. No runtime art or save files were regenerated.
