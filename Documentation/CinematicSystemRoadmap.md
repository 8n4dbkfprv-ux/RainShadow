# Cinematic system

Updated 2 October 2026. The pinned upstream comparisons and the removal of the
former cinematic extensions are recorded in
[Cinematic parity audit](CinematicParityAuditOct02.md).

## Runtime and authorship

`CutsceneCatalog` contains the opening exterior, Lila's entrance and departure.
`CutsceneRunner` owns subject action queues on the 15 Hz logic clock;
`CutsceneDirector` applies them to SpriteKit. `CutsceneViewport` advances the
camera using GemRB's integer scroll arithmetic. `CutsceneFadeTimer` owns the
black overlay's byte alpha, remembered duration and fade-reset fallback.

A track corresponds to a CutSceneId block. Repeated subjects append to the same
queue. Different subjects run concurrently. ActionOverride releases its issuer
and queues work on another actor; BG2 clearing preserves previous overrides.
Movement and its subsequent camera/dialogue actions are authored on the same
actor queue, so there is no custom cross-track join.

| Operation | Queue behavior |
|---|---|
| Wait / SmallWait | Integer seconds / integer logic updates |
| MoveToPoint | NavigationMap route followed by existing actor locomotion |
| JumpToPoint / HideCreature | Position / visibility change; no implicit fade |
| PlaySequence / WaitAnimation | Start stance without blocking / wait for that stance or engine round limit |
| Face / FaceObject | Immediate orientation, one update of queue delay |
| MoveViewPoint / MoveViewObject | Non-blocking; object position sampled once |
| MoveViewPointUntilDone | Blocks until viewport arrival or boundary stop |
| DisplayStringHead | Non-blocking; reading pauses need explicit Wait |
| FadeToColor / FadeFromColor | Suspend script processing globally; zero reuses the previous duration |
| StartCutSceneMode / EndCutSceneMode | Hide/show GUI and change input ownership independently of queue lifetime |
| SetCutSceneBreakable | Explicit runtime opt-in/out; Escape only, with no grace period |

Cinematics retain the current viewport scale. There are no cinematic zooms,
letterboxes, warm bloom, doorway alpha ramps or extra SpriteKit transition/ease.
The opening uses a world-script queue; the office scenes use actor queues.
Dialogue graph state stays with DialogueSession, through the stage adapter.

## Interruption

All shipped sequences author `skipTracks`, corresponding to EE's failsafe
script. Escape interrupts the current actions and runs that recovery as normal
queues. It does not terminalize, teleport or execute discarded actions implicitly.
Recovery explicitly places/hides actors, waits for animations when necessary,
and restores dialogue/control. Callbacks from discarded work cannot finish new
work, and completion is single-fire.

The pinned GemRB SetCutSceneBreakable implementation is unfinished; this action
uses the [documented EE contract](https://gibberlings3.github.io/iesdp/scripting/actions/bgeeactions.htm#387).

## Verification and boundaries

Run the core cinematic tests and production-director harness after changing cue
semantics. Build both Apple targets after changing the SpriteKit adapter. Keep
existing actor bundles, world art, projection, search raster and viewport clamp
as their respective authorities. This is an implemented action-subset port, not
a BCS interpreter or a movie player. New behavior needs a quoted engine comparison;
new presentation exceptions must not be introduced as parity fixes.
