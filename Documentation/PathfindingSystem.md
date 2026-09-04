# Pathfinding and NPC locomotion

- Status: shipped — literal port of GemRB `master` (`1c45c185`, 28 August 2026)
- Version: 2.1
- Date: 28 August 2026
- Related: [Technical Architecture](TechnicalArchitecture.md) §10–12 (actors, navigation, input), [Movement System Roadmap](MovementSystemRoadmap.md), [Game Design Document](GameDesignDocument.md) §8 (Controls), [Navigation open questions](NavigationOpenQuestions.md), [Third-party notices](ThirdPartyNotices.md)

## Purpose

This document is the authoritative reference for how RainShadow moves actors through the world. It covers two things:

1. The **shipped navigation stack**, transliterated from GemRB `master`: a raster search map, Lazy Theta\* any-angle search, actor occupancy with bumping, directed destination adjustment, and in-place door stamping.

> **v2.0 — the port went literal.** v1.0 was a paraphrase, written from
> documentation and reasoning rather than from the source. Reading GemRB beside
> it showed the paraphrase had drifted, and that several "deliberate divergences"
> had been decided without the engine code in front of us. This version ports the
> structures themselves — `Path`/`PathNode`, `Movable`, `PathMapFlags`,
> `NormalizeDeltas`, `PlotCircle`, `AdjustPositionDirected` — and adopts the
> engine's behaviour wherever it differed. The table under
> [What the literal port changed](#what-the-literal-port-changed) is the record.
>
> **v2.1 — the last two adaptations came out.** v2.0 kept a world-space AABB
> conjunct on top of every cell query, because our solids are finer than the
> raster. v2.1 removes it and makes the raster carry the truth instead: obstacles
> rasterise **conservatively**, so a solid claims every cell it touches, which is
> how a painted `SR.BMP` is authored in the first place. The engine's own line
> queries and position adjustments were corrected at the same time, and
> `MoveLine` / `RandomWalk` / `RunAwayFrom` landed. See
> [What v2.1 changed](#what-v21-changed).
2. The **NPC authoring convention** that follows from it. Every walking character added from here on — companions, watchers, district crowd figures, later clients — is written against `NavigationMap` and `Movable`, never against authored polylines or `SKAction.move` chains.

The previous system is gone, not deprecated. `NavigationGrid` and its tests were deleted; there is no compatibility path back to authored per-scene polylines for locomotion.

## What changed

v1.0 replaced a grid A\* (`NavigationGrid`) with a paraphrase of the engine.
v2.0 replaced the paraphrase with the engine. The table under
[What the literal port changed](#what-the-literal-port-changed) is the v1 → v2
record; this one is the original rewrite, kept because the *shape* of the stack
dates from it.

| Concern | Former system (`NavigationGrid`) | Shipped system |
|---|---|---|
| World representation | Cell grid derived from authored obstacle AABBs | Byte-per-cell raster **search map** with `PathMapFlags` (`SearchMap`) |
| Search | 8-connected A\* with corner-cut rejection | **Lazy Theta\*** — 4-connected expansion plus line-of-sight shortcutting (`PathFinder`) |
| Path shape | Grid-axis steps, then string-pull simplification | Any-angle segments produced by the search itself |
| Path smoothing | Separate post-pass | None needed; LOS parent relinking is the smoothing |
| Search bound | Bounded only by grid extent | Wall-clock guard (`searchTimeThreshold`) |
| Blocked destination | Bounded Chebyshev ring scan for nearest cell | **Directed cone** back toward the caller (`AdjustPositionDirected`) |
| Other actors | Not modelled | Stamped into the map as PC/NPC bits; bumpable actors are traversable (`ActorOccupancy`) |
| Blocked-by-actor recovery | None | **Bump**: the blocker relocates itself and comes back; movers back off on an unbumpable one |
| Door open/close | Rebuild the whole navigation grid | **Stamp/clear door cells in place** (`setEntranceDoorBlocking`) |
| Mid-walk correction | None | Periodic **corrective repath** while a route is active (`Actor::NewPath`) |
| Client NPC movement | Authored polyline + `SKAction.move` sequence | Pathfinder route + `Movable` |

## Reference model

BG:EE inherits the Infinity Engine's split between a coarse **search map** used for planning and a finer space used for actual movement. The search map is a low-resolution raster (one byte per cell, 16×12 screen pixels per cell in the original) whose bits describe passability, see-through, flyability, projectile transit, and footstep material. Actors and doors write into that same raster at runtime, so dynamic obstacles cost a stamp rather than a rebuild. Search is a weighted, node-budgeted any-angle expansion; the engine exposes the budget to players as a "Path Search Nodes" setting. Actors that are idle and friendly are treated as soft obstacles — a mover can plan through them, and on contact the blocker steps aside and returns rather than deadlocking.

RainShadow adopts that structure, and specifically GemRB's `Map::FindPath` shape for the search itself, because it produces the readable, slightly-suboptimal, always-responsive paths that classic point-and-click locomotion depends on. It does not adopt the original's pixel resolutions, screen-space cell units, or the parts of IE multi-agent behaviour that players remember as bugs.

### Sources

- [GemRB engine overview](https://www.gemrb.org/Engine-overview.html) — area representation, search map role, and the reimplementation of IE runtime systems.
- [IESDP: area (ARE) format](https://gibberlings3.github.io/iesdp/file_formats/ie_formats/are_v1.htm) — how an area references its search-map and height-map rasters alongside doors, regions, and actor spawns.
- [IESDP: creature animation](https://gibberlings3.github.io/iesdp/file_formats/ie_formats/ini_anim.htm) — orientation cycles and mirrored eastern facings, which constrain how paths are consumed by sprites.
- [Beamdog Enhanced Edition postmortem](https://www.gamedeveloper.com/programming/postmortem-overhaul-games-i-baldur-s-gate-enhanced-edition-i-) — EE-era engine work and constraints.
- GemRB source behaviour for `Map::FindPath` / `AdjustPosition`, mirrored here as `PathFinder.findPath` / `PathFinder.adjustPositionDirected`.

## Shipped architecture

Four types under `RainShadow Shared/Gameplay/Navigation/`, layered so that only the top one is scene-facing.

| Layer | File | Responsibility |
|---|---|---|
| Raster | `SearchMap.swift` | Cell grid, flag bits, radius/line queries, obstacle rasterization, door and actor stamping |
| Search | `PathFinder.swift` | Lazy Theta\*, weighted heuristic, node budget, destination adjustment, nearest passable point |
| Actors | `ActorOccupancy.swift` | Actor registration/stamping, bump requests, congestion back-off |
| Scene API | `NavigationMap.swift` | Composes the three above; the only type scenes and layouts should touch |

### SearchMap

A world-space raster. Unlike BG's screen-space cells, RainShadow cells are expressed in the scene's logical world units so the same code serves the dimetric office and the larger city district.

- Cell size defaults to `SearchMap.defaultCellSize` (16×12), matching the BG:EE cell aspect.
- Static obstacles are rasterized once at construction. Door leaf rects are held separately so they can toggle later.
- Flag bits mirror GemRB's `PathMapFlags`: `passable`, `doorImpassable`, `playerActor`, `npcActor`. `actor` is the union of the two actor bits; `areaMask` isolates authored terrain from runtime stamps, which is what lets a door or actor be cleared without disturbing the baked terrain underneath.

Queries come in point, radius, and line forms. Three behaviours are load-bearing:

- **Rasterisation is conservative.** A cell is solid when an obstacle overlaps its footprint with positive area, not when it covers the cell centre. Edge contact does not count, so a solid ending exactly on a cell boundary does not claim the cell beyond it. This is what lets the raster be the *only* clearance authority, as it is in the engine: centre sampling under-covers every solid by up to half a cell and misses a solid thinner than 16×12 entirely. The cost is that solids fatten by up to a cell, which is a rectangle-authoring constraint.
- **Clearance is `circleSize`, and nothing else.** `blockedInRadiusTile` tests a disc of `size − 2` cells — `GetBlockedInRadiusTile` — while `paintSearchMap` stamps `size − 1`. The asymmetry is the engine's, and is why BG characters brush along walls but keep a wide berth around each other.
- **The map boundary is solid** because a cell outside the grid reads impassable, so a body that needs its neighbours cannot stand in the outermost ring. There is no separate boundary inset any more.

Two line walks, and the difference between them matters. `blockedInLineTile` steps a whole cell at a time and is what `IsVisibleLOS` uses; `blockedInLine` steps in **world units** and is what `IsWalkableTo` uses. The tile walk ceils each axis independently, so a diagonal run goes corner to corner and never looks at the cells between — harmless for sight, and not harmless for a Theta\* shortcut, where the cell it steps over is a desk.

### PathFinder — Lazy Theta\*

Expansion is 4-connected over cells, but each node's parent is *lazily relinked* to its grandparent when `isWalkableLine` says the direct segment is clear. The result is an any-angle polyline emitted by the search itself, which is why there is no separate string-pull pass.

- **Weighted heuristic.** `heuristicWeight = 1.5`, GemRB's default. This trades strict optimality for a materially smaller expanded set and quicker responses — the correct trade for a click-to-move game.
- **Tie-breaking.** Equal-cost frontiers are broken by the cross product against the straight start→goal line, which biases the path toward the visual straight line instead of a staircase.
- **No node budget.** The engine bounds the search by wall clock — a 15 s guard checked every 25 expansions — not by a node count. A node cap fails *deterministically* on a big map, which is why the office used to carry a budget three times the default; a time guard only fires on a search that has genuinely run away.
- **Nodes are laid off the source.** Children are `current + (16·dx, 12·dy)` in **world** space, so every node carries the caller's sub-cell offset instead of snapping to a cell centre.

`findPath` returns a `Path`. An empty one means **do not walk**, and covers both
"already standing there" and "nothing found" — the engine draws no distinction,
because both leave the actor where it is. The v1.0 three-valued `nil` / `[]` /
points contract was ours, and it forced every caller to decide which it had. That
question is answered at the *order* layer now: `Movable::WalkTo`'s same-cell head
turn, and `NavigationMap.isOrderableFloor`.

Goal relaxation:

- `adjustPositionDirected` (`AdjustPositionDirected`) runs **inside** `findPath`
  whenever the goal is itself blocked. It casts a sparse cone — five orientations
  at increasing radius — back toward the caller and takes the closest passable
  candidate, so the actor stops on the near side of an obstacle. A goal that is
  passable but *disconnected* is not relaxed at all; the search simply fails.
- `minDistance` lets a caller stop short of a goal, gated on line of sight when
  `PF_SIGHT` is set.

Because a blocked goal is relocated, a non-empty path does not prove the
requested point was reached. Use `NavigationMap.reachesExactly` for that.

### ActorOccupancy — bumping and congestion

Actors register with an id, a kind (`player` / `npc`), a position, and a radius; occupancy stamps the matching bit into the search map and restamps on every position update.

- **Bumpable by default when idle.** A registered actor is bumpable while it is not moving, matching BG:EE's treatment of party members and friendly NPCs as soft obstacles.
- **Planning through bumpables.** `PathFinderFlags.allowBumpableActors` (the default for `NavigationMap.path`) lets a route pass through idle actors. `actorsAreBlocking` gives the strict variant for queries that must not assume a bump will happen.
- **The decision lives in the walker.** `Movable::DoStep` probes, decides, and acts; `ActorOccupancy` only answers *who is standing where*. The v1.0 `BumpRequest` — a sidestep point and a return point for the scene to drive — is gone, along with the scene loop that consumed it.
- **Look ahead, not around.** The probe walks outward along the heading, `r` from `((max(circleSize, 3)) − 1) × 3` down to `1`, taking the first actor it meets: `DoStep` "want[s] to only check directly along the way and not be blocked by actors who are on the sides".
- **`BumpAway` / `BumpBack`.** A bumped actor relocates itself through `AdjustPositionNavmap` and remembers where it stood; it reclaims the spot from its own `DoStep` once free, giving up past `MAX_BUMP_BACK_TRIES` (16) within its own personal space. An idle actor still needs its tick pumped, which is what `ClientActorNode.advanceBumpRecovery` does.
- **Backoff, not cancel.** When the blocker cannot be bumped, `Movable::Backoff` drops the walk stance and waits a *randomised* number of ticks — `RAND(MAX_PATH_TRIES, MAX_PATH_TRIES × 2)` — then retries the same step; the route is never discarded. GemRB describes the randomisation as "inspired by network media access control algorithms": two actors blocking each other draw different waits and so cannot deadlock in lockstep.
- **Abandon near the goal.** A mover whose path is a single node and is already within personal range gives up rather than shoving, so close-range approaches do not push furniture-adjacent NPCs around.
- **Retry budget.** `pathTries` / `MAX_PATH_TRIES = 8` lives on `Movable` and counts failed **searches**, which is the axis `Actor::NewPath` caps. The v1.0 `recordCongestion` pair counted failed *steps* — a different axis with no engine counterpart — and is gone.

### NavigationMap — the scene API

The only navigation type scenes and layout helpers should use.

| Member | Use |
|---|---|
| `path(from:to:identity:)` | Direct route; idle actors are planned through and bumped. Returns a `Path` — empty means do not walk. |
| `pathAvoidingActors(from:to:identity:)` | `Movable::WalkTo`'s flags: other actors are hard blockers. |
| `findPath(from:to:minDistance:flags:identity:)` | The general entry point, for callers that need `minDistance` or `PF_BACKAWAY`. |
| `isOrderableFloor(_:)` | Whether a click here is worth issuing at all (`IE_CURSOR_BLOCKED`). Terrain only — ground with a body on it stays orderable. |
| `reachesExactly(from:to:)` | Whether a destination is reachable **as asked**, rather than relocated near it. The instrument for approaches and for every reachability assertion. |
| `route(from:to:)` | Exact route plus where it actually landed, for scripted approaches that need to know a goal moved. No longer flood-fills. |
| `waypoints(visiting:)` | Expands sparse authored anchors into one `Path` by searching between consecutive anchors. **This is how scripted NPC beats are authored.** |
| `repath(from:to:)` | Corrective repath from a live position to an existing goal. |
| `nearestWalkablePoint(to:)` | Snap an arbitrary point (spawn, authored anchor) onto standable floor. Not for player clicks. |
| `reachableCellCenters(from:)` | 4-connected flood fill. Measurement only — never routing. |
| `setEntranceDoorBlocking(_:)` | Toggle door cells in place; no rebuild. |
| `registerActor` / `updateActor` / `unregisterActor` | Occupancy lifecycle for anything that occupies floor. |

**Player floor clicks are refused, not relocated.** `FindPath` moves a blocked
goal on its own, which is right for a scripted approach and wrong for a tap on a
wall — it would walk somewhere the player did not point at. The engine refuses at
the click layer: `GameControl::OnMouseUp` returns early on `IE_CURSOR_BLOCKED`,
and `UpdateCursor` has already greyed the cursor so the refusal is legible before
the click lands. `MovementOrderQueue.order` checks `isOrderableFloor` first, and
that is the whole guard. Snapping the player to a tile they did not click is a
convenience the engine does not offer, and it made blocked geometry unreadable.

`route` no longer differs from `path` in what it will accept — only in what it
reports. Its v1.0 bounded fallback, a 4-connected flood fill over every reachable
cell run synchronously on the main thread, is gone.

### Dynamic doors

The office entrance door is registered as a door obstacle at construction, then toggled: `setEntranceDoorBlocking(true/false)` stamps or clears exactly those cells and restamps actors. The falling-door and returning-door animations call it directly. Nothing rebuilds the map, and `impassableCellCount` remains a valid assertion target for open-versus-closed state (`fallenEntranceDoorClearsDoorStampWithoutRebuild`).

Any future dynamic geometry — a shifted screen, a raised grate, a collapsed shelf — should follow this pattern: register the rect as a door obstacle at construction and stamp it on state change.

### Corrective repathing

`MovementOrderQueue.correctiveRepath` is `Actor::NewPath` on BG:EE's "Enhanced
Path Search" cadence: every `correctiveRepathInterval` (0.75 s) while an actor is
walking, it re-issues `WalkTo` toward `Destination` with
`FindPathRequestType.walkToFromNewPath`. A bottleneck that clears mid-walk — a
door that fell, an NPC that bumped aside — immediately yields the shorter path.
Past `MAX_PATH_TRIES` failed searches it drops the route rather than grinding.

**Rebuilding to `Destination` destroys intermediate waypoints.** v1.0 re-appended
later goals and called the engine's behaviour a bug; this ports the engine's.

## Scene integration contract

`DetectiveOfficeScene` and `CityDistrictScene` run the same per-frame order from `update(_:)`, and any new scene with walking actors must too:

1. **Advance locomotion.** `updateLocomotion(at:worldIsPaused:)` on each actor node. This drains wall-clock delta into whole 15 Hz logic ticks (`LogicTickClock`) and calls `Movable.doStep` once per tick, advancing one authored walk frame with it. A standing actor spends its ticks rotating one facing bin toward `pendingFacing` instead.
2. **Push occupancy.** Feed every visible actor's live position and `isMoving` to `NavigationMap.updateActor`. Unregister actors that are hidden.
3. **Corrective repath.** `MovementOrderQueue.correctiveRepath` on the actor's `Movable`.
4. **Relay bump requests.** `DoStep` decides; the scene only delivers. `Movable` has no handle on its neighbours, so `actorInTheWay->BumpAway()` arrives as an actor id in `StepOutcome.bumpedActorID` for the scene to pass on, and an idle bumped actor needs `advanceBumpRecovery()` pumped.
5. **Sync reticles.** Pips are a pure function of the live path, so there is nothing to prune.

Everything after step 1 is gated on the world not being paused, so modal dialogue, the map, the journal, and the inventory freeze navigation without cancelling the active route.

Each actor node owns its `Movable` and its own tick counter (`currentTick`), which is the engine's `Game::Ticks` for that actor: `DoStep` refuses more than one step per tick value and `WalkTo` rate-limits against it, so both need a counter that only ever increases. Scenes issue orders through `DetectiveActorNode.issueOrder(via:to:...)`, which runs `MovementOrderQueue` against that `Movable` and then syncs the node's animation state.

Actors are handed their area with `attachNavigation(_:id:)`. Without it a `Movable` cannot search, look ahead for a blocker, or relocate itself when pushed.

### Waypoint queue rules (from `Movable::AddWayPoint`)

There is no separate queue. The engine keeps ordered goals **inside the path**:
`AddWayPoint` marks the node it extends from and splices the new leg on, and
`DoStep` clears the mark on arrival. `Movable.pendingWaypoints` is what reticles
are drawn from, so a pip cannot outlive its goal or drift out of step with the
route. v1.0's scene-owned `queuedMovementGoals`, and the pruning pass that kept
it honest, are gone.

- **Append from the last node, not the actor.** Legs chain end-to-end, so the queue survives the actor being anywhere along the current leg.
- **An append with nothing to append to is a plain move.** `if (!path) { WalkTo(Des); return; }`.
- **An empty leg is not a waypoint.** "If the waypoint is too close to the current position, no path is generated" — the existing path keeps walking rather than being stranded.
- **Appended legs ignore actors.** `AddWayPoint` files a bare search where `WalkTo` passes `PF_SIGHT | PF_ACTORS_ARE_BLOCKING`. The asymmetry is deliberate: whoever is in the way now will have moved before a later leg is walked.
- **A plain click wipes the queue**, as `actor->Stop()` clears the whole path.
- **Every goal is marked on the ground, including the last.** `DrawTargetReticles` draws a reticle per waypoint node and then unconditionally at `Destination` ("always draw last step").
- **A stale failure verdict is discarded first.** A waypoint is a new order, not the retry of a failed one, so `pathSearchFailed` is cleared rather than consumed — otherwise `WalkTo` would answer it and file nothing.

One divergence remains, and it is at the click layer rather than in the queue: a
waypoint onto impassable ground shows the blocked marker instead of being
silently dropped. Refusals should be legible.

## Agent profiles

`NavigationAgentProfile` carries both clearances, because we need two where the
engine needs one. `circleSize` is the engine's `personal_space`, in search-map
cells, and drives `GetBlockedInRadiusTile`. The world-unit half-extents drive the
geometric conjunct that our finer-than-a-cell solids require (see
[Two adaptations](#two-adaptations-made-deliberately)); radius is the larger
half-extent, so anisotropic footprints clear narrow gaps conservatively.

`circleSize` is **derived** from the radius by `circleSize(forRadius:)` rather
than shared with `ActorLocomotionPacing.personalSpaceCells`. That number is for
actor-vs-actor spacing and lives on `OccupyingActor`; routing it into static
clearance too would replace a 3-unit office footprint with a 32-unit disc and
seal the room.

| Profile | Half-extents | `circleSize` | Used by |
|---|---|---|---|
| `.point` | 0 × 0 | 2 | Pure geometry tests and anchor snapping |
| `.detective` | 16 × 4 | 3 | City district — personal-space core in open street space |
| `.officeDetective` | 3 × 0 | 2 | Office interior — obstacle art already bakes in floor-contact clearance |
| `.officeClient` | 3 × 0 | 2 | Lila, matching the detective's office clearance |

New NPCs pick an existing profile rather than inventing one. A per-NPC profile is only justified when its floor footprint genuinely differs (a large animal, a cart), and it must come with a test that the office and district maps remain traversable for it.

## How NPCs are written from here on

The client NPC (Lila) has been migrated off authored polylines and `SKAction.move` onto the pathfinder plus `Movable`. She is the reference implementation; treat `ClientActorNode` as the template.

### Frozen rules

1. **All floor-bound movement comes from `NavigationMap`.** No `SKAction.move`/`follow` chains for locomotion, and no hand-authored waypoint lists consumed directly as positions. Authored anchors are input to `waypoints(visiting:)`, never a path themselves.
2. **`Movable` owns advancement.** One `doStep(walkScale:time:)` per 15 Hz tick, driven from the scene's `update`. This is what makes retarget, cancel, arrival, and bumping deterministic and testable. Pace reaches it as `walkScale`, never as a scalar speed — a scalar cannot express a `NormalizeDeltas` step, which is rounded up per axis.
3. **Every floor-occupying actor registers with occupancy** on becoming visible and unregisters on being hidden or removed. An unregistered NPC is invisible to pathfinding and will be walked through.
4. **Idle NPCs are bumpable; moving NPCs are not.** Do not hard-block the player with a stationary NPC. If a beat genuinely requires an immovable body, model it as a static obstacle, not as an unbumpable actor.
5. **A non-empty path does not mean the destination was reached.** `FindPath` relocates a blocked goal, so anything that cares — an approach, a reachability assertion — must use `reachesExactly`.
6. **Facing while walking comes from the path node**, which `FindPath` computed with `GetOrient` and `DoStep` assigns outright. Never re-derive it from velocity: that is what the retired look-ahead vector and hysteresis band did, and the engine has neither. Standing actors turn one bin per tick via `GetNextFace`. Nine source orientations plus seven mirrored, per Technical Architecture §10.4; never mirror the whole figure where a sprite contract forbids it (Lila's handbag/light contract).
7. **Single-agent correctness is not negotiable.** Multi-actor work must not regress detective-only office navigation tests.

### Adding a walking NPC

1. **Node.** Subclass or model on `ClientActorNode`: sprite body, contact shadow, a private `Movable`, a tick counter, a locomotion mode enum, and a `movementCompletion`.
2. **Attach the area.** Call `attachNavigation(_:id:)` on spawn. Without it the `Movable` cannot search, look ahead for a blocker, or relocate itself when pushed.
3. **Movement entry point.** Expose a `walk(path:completion:)` that calls `movable.adopt(_:)` and starts the walk cycle, and/or an order entry point that runs `MovementOrderQueue` against the `Movable`. Handle the empty-path case by completing immediately.
4. **Per-tick advance.** Implement `updateLocomotion(at:worldIsPaused:)` and call it from the scene's `update`. Drain the wall-clock delta into whole ticks, increment the tick counter, call `movable.doStep(walkScale:time:)` once per tick, take facing from `movable.orientation`, and finish on `arrived` or `abandoned`. Return early while paused so overlays do not consume route progress.
5. **Occupancy.** Register on spawn with a stable id and the appropriate `NavigationActorKind`; call `updateActor` every frame with the live position and `isMoving`; unregister when hidden.
6. **Bumping.** Expose `bumpAway()` so a mover can push this actor aside, and pump `advanceBumpRecovery()` while it is idle so it can reclaim its spot.
7. **Scripted beats.** Author sparse anchors (door threshold, desk-side stop) and expand them with `waypoints(visiting:)`. The result is a `Path` that respects current obstacles, including a door that happens to be open.
8. **Reactive movement.** For anything responding to the world — approaching a hotspot, following the player — order at the moment of the decision. Never precompute and cache a path across a state change.
9. **Tests.** Add coverage in `NavigationMapTests` that the NPC's anchors resolve, that its route stays clear of authored obstacles, and that its profile can traverse the maps it appears in. `officeClientArrivalCrossesPartitionApertureOnce` and `officeClientDepartureRetracesInteriorThenCrossesExteriorDoor` are the models.

### Anti-patterns

| Do not | Because |
|---|---|
| Drive an NPC with `SKAction.move` sequences | Cannot be retargeted, cancelled, or bumped mid-segment; timing drifts per segment |
| Store an authored polyline as the NPC's path | Breaks the instant a door, prop, or actor changes state |
| Skip occupancy registration for "background" NPCs | The player and other NPCs will path straight through them |
| Treat an idle NPC as a hard blocker | Produces the doorway soft-locks this rewrite exists to avoid |
| Skip `isOrderableFloor` on a player click | `FindPath` relocates a blocked goal, so the click silently walks somewhere the player did not point at. The engine refuses at the click layer |
| Use a non-empty path to test whether somewhere is reachable | Same reason, and it is why three separate sealed-geometry bugs shipped green. Use `reachesExactly`. See "Measuring reachability" below |
| Give an actor a `Movable` without `attachNavigation` | It cannot search, look ahead for a blocker, or relocate itself when pushed — it will stand still and look broken |
| Re-derive a nav map to change one obstacle | Doors and dynamic geometry stamp in place |

### Scripted beats versus reactive movement

Both go through the pathfinder; they differ only in when the path is requested. A scripted beat (client arrival, a scheduled exit) resolves its anchors at the moment the beat fires. Reactive movement resolves at the moment of the trigger and is expected to be re-resolved by corrective repathing. Neither may bake a path at scene construction, because door and actor state at construction is not the state the walk will execute in.

## Testing

Five suites carry the stack, and they are layered on purpose:

| Suite | Covers |
|---|---|
| `NavigationMapTests` | The search: any-angle shortcutting, corner-cut rejection, thin-obstacle rejection under a real footprint, boundary-as-solid, goal relocation vs. honest failure, `minDistance`, actor hard-blocking, `BumpAway`/`BumpBack`, `Backoff`'s randomised wait, in-place door stamping, and the office/city reachability suites |
| `ActorLocomotionTests` | `DoStep` and the orders that feed it, plus `core/Orientation.h`'s arithmetic |
| `ActorLocomotionPacingTests` | The engine constants, `NormalizeDeltas` axis by axis, and the scene wiring it greps for as source text |
| `MovementOrderQueueTests` | Click policy: refusal, head turn, append, replan, abandon |
| `MovementIntegrationTests` | The whole loop on shipped geometry — order in, `DoStep` per tick, arrival out |

Three properties of the old `RouteFollowerTests` are **invalid by construction**
and are deliberately not carried over: constant speed, segmentation invariance,
and timestep independence. `NormalizeDeltas` rounds each axis up and `DoStep`
emits one step per tick, so travel is quantised by design — a route split into
more segments really does take more ticks, because each node costs its own
rounding. Exact per-tick displacement tables replace them, which assert more.

Build and test commands are macOS-only; see the [repository README](../README.md) under "Verification". Use the documented `/tmp` scratch path when running `swift test` to avoid Finder-metadata codesigning failures on the test bundle.

## Measuring reachability

**A non-empty path is the wrong instrument**, for the same reason `route` was in
v1.0. `FindPath` relocates a goal it cannot reach, so a route existing says only
that *somewhere near* was reached — it succeeds from inside a sealed pocket, or
inside a building, and reports nothing wrong. Three shipped bugs hid behind the
v1.0 version of this trap: the office floor sealed to 174 of 4,694 cells, the
office door unreachable, and Harborpoint PD spawning the detective inside an
820×680 station with 1 of 5,795 cells reachable. Every test covering those areas
passed the whole time.

Use `NavigationMap.reachesExactly(from:to:)`, which demands the search land in
the cell that was asked for. For connectivity, flood-fill the **runtime** search
map with `reachableCellCenters(from:)`.

`officeFloorIsOneConnectedRoomAtRuntimeResolution` and
`everyCityDistrictSpawnAndApproachIsStandable` (both in `NavigationMapTests`) are
the shape to copy for any new area. Assert connected cell count *and*
`reachesExactly` for every authored approach — scenes issue approaches with
`requiresExactDestination`, so an approach that is merely *near* reachable is a
broken interaction.

Note that destinations are cell-resolved: `FindPath` terminates on the search
node inside the goal cell, which carries the caller's sub-cell offset. Assert the
**cell**, not the point. Comparing points fails on the grid, not on a bug.

For a visual, capture the plate with `RAINSHADOW_START_SCENE=office
RAINSHADOW_CAPTURE=<path> RAINSHADOW_CAPTURE_MODE=room`; the crop equals
`navigationWorldBounds`, so a cell grid overlays onto it linearly.

## What the literal port changed

Each row is a place v1.0 differed from the engine, and what it does now. The
left column is what `Documentation/MovementSystemRoadmap.md` cites from GemRB
`master`; the right is what shipped before this port.

| | GemRB `master` | v1.0 (paraphrase) |
|---|---|---|
| Step arithmetic | `NormalizeDeltas`: `STEP_RADIUS = 2`, axis special cases, `min(step, remaining)` clamp, **`ceil()` per axis** | float step along a *projected*-length unit vector |
| Steps per tick | exactly one, advancing at most one node | a float budget spent across as many waypoints as it reached |
| Path type | `Path` = `[PathNode]` + `currentStep`; nodes carry `orient` and a `waypoint` flag, and are not consumed | bare `[CGPoint]`, destructively `removeFirst()`ed |
| Waypoint queue | marked **inside the path** (`AddWayPoint` sets the flag, `DoStep` clears it) | a scene-owned `queuedMovementGoals` array kept in step by hand |
| Facing while walking | `SetOrientation(step.orient, false)` — the node's stored orientation | recomputed per tick from a look-ahead vector with a 3° hysteresis band |
| Orientation numbering | `S = 0` clockwise, so `W = 4`, `N = 8`, `E = 12` | `east = 0`, counter-clockwise |
| Blocked destination | `AdjustPositionDirected` runs **inside** `FindPath` | `findPath` never relocated a goal; callers opted in |
| `AdjustPositionDirected` | sparse **cone**: five orientations at increasing radius, ranked by distance | a straight-line ring walk back toward the caller |
| Search bound | 15 s wall-clock guard, checked every 25 expansions | `maxNodes = 32 000`, which the office had to triple |
| Child node | `current + (16·dx, 12·dy)` in **world** space — sub-cell offsets survive | `center(of: childCell)`, snapping to the cell centre |
| Theta\* order | assign parent and distance **first**, then LOS-test, then fall back to A\* | LOS-tested first |
| Heuristic | cell units; `crossProduct >> 3` | world units; `/ 8` |
| Flags | `PASSABLE / TRAVEL / NO_SEE / SIDEWALL / DOOR_OPAQUE / DOOR_IMPASSABLE / PC / NPC` | four bits, different positions; no `TRAVEL`, `NO_SEE` or `SIDEWALL` |
| Walls in `DoStep` | probes `Pos + (dx, dy)` for `SIDEWALL` and abandons | no equivalent — there was no `SIDEWALL` |
| Collision probe | `r` from `((max(circleSize, 3)) − 1) × 3` down to `1` along the heading | a single probe one step ahead |
| Bumping | `BumpAway` / `BumpBack` owned by the actor, `MAX_BUMP_BACK_TRIES = 16` | a scene-driven `BumpRequest` carrying sidestep and return points |
| Retry budget | `pathTries` / `MAX_PATH_TRIES = 8`, counting failed **searches** | `maxCongestionRetries`, counting failed **steps**; built and unused |
| Failed search | `PathSearchFailed` latch, reported on the next `WalkTo` for the same point | `nil` returned inline |
| `pathAbandoned` | a latch the next `WalkTo` refuses on | absent (v1.0 called cancelling "equivalent"; it is not) |

### What this costs, and what it buys

**Movement is quantised.** `ceil()` makes every step a whole world unit, so the
gait is 7 units per tick east-west and 6 north-south — 105 and 90 units per
second. Two consequences follow and neither is a bug:

- The *effective* vertical ratio a player sees is 6/7, about 0.857, not the 0.75
  `NormalizeDeltas` multiplies by. The old derivation quoted 101.9 and 76.4
  px/s, which describes the arithmetic before the rounding — a pace no Infinity
  Engine creature has ever walked.
- The pace is no longer scale-free. v1.0 phrased it in body heights so a sprite
  rebake could not invalidate it; a whole-unit step cannot be phrased that way.
  The actor covers 7/16 of a search cell per tick — exactly BG's stride in cell
  terms — and reads slower than BG only because our adult is drawn ~1.4× taller
  against the same cell.

**A blocked goal is relocated, not refused.** `AdjustPositionDirected` inside
`FindPath` means a non-empty path no longer proves the requested point was
reached. Two guards carry the weight that `path(...) != nil` used to:

- `NavigationMap.isOrderableFloor` refuses a click on impassable ground at the
  *click* layer, which is where the engine refuses it
  (`GameControl::OnMouseUp` returns early on `IE_CURSOR_BLOCKED`). Ground with a
  body standing on it is still orderable — that is something to bump.
- `NavigationMap.reachesExactly` is the reachability instrument. Approaches
  issued with `requiresExactDestination`, `DialogueApproach`, and every area
  reachability assertion use it. See [Measuring reachability](#measuring-reachability).

**Destinations are cell-resolved.** `FindPath` terminates on the search node
inside the goal cell (`nmptDest = nmptCurrent`), and that node carries the
*caller's* sub-cell offset. A route therefore ends within the requested cell
rather than on the requested point. `NavigationRoute.destinationWasAdjusted`
compares cells for exactly this reason: landing a few units off a click is the
grid, not a snap.

### What v2.1 changed

| | GemRB `master` (`1c45c185`) | v2.0 |
|---|---|---|
| Clearance authority | the raster alone (`GetBlockedInRadiusTile`) | the raster **and** a world-space AABB disc (`canStand`, `isPassable(at:radius:)`) |
| Obstacle rasterisation | painted at cell resolution by hand | cell **centre** sampled against each rectangle |
| Blocked-goal test | `GetBlockedInRadiusTile & PASSABLE` — an occupied cell relocates the goal | tolerated `ACTOR` on the goal, deliberately |
| `IsWalkableTo` | navmap-space `GetBlockedInLine` | tile-space `GetBlockedInLineTile`, which skips cells on a diagonal |
| `IsVisibleLOS` | `SIDEWALL` only, `stopOnImpassable = false` | `SIDEWALL ∪ NO_SEE ∪ DOOR_OPAQUE`, `stopOnImpassable = true` |
| `AdjustPosition` fallback | `size = -1` — `GetBlockedTile` on the cell alone | the caller's `circleSize` |
| `AdjustPositionNavmap` | `size = -1`; it is `BumpAway`'s helper | the caller's `circleSize`, sending a shoved actor far further than a sidestep |
| `ClearSearchMapFor` before a search | the requester's own footprint comes off the raster | it stayed on, so with `PF_ACTORS_ARE_BLOCKING` no route could leave the actor's own personal space |
| `BlocksSearchMap` | read on the **blocker** too, in `DoStep` and when stamping | read only on the walker; a ghost stamped the raster and was bumped |
| Near-goal give-up | `WithinPersonalRange(this, step, 1)` on the 16:12 ellipse | a circular `circleSize × cellWidth` radius |
| Same-cell `WalkTo` | `ClearPath` + `SetStance(HEAD_TURN)` | also aimed the turn at the click |
| `MoveLine` / `RandomWalk` / `RunAwayFrom` | present | absent |
| `CalculateLinePath` / `LineEnd` / `RunAwayPoint` / `RandomWalkPoint` | present | absent |

Three consequences are worth stating plainly, because each is a behaviour change
a player could notice.

**A goal with somebody standing on it moves aside.** `GetBlockedInRadiusTile`
clears `PASSABLE` wherever an actor is stamped, so `FindPath` relocates the
destination rather than walking onto it and bumping for the spot. In the office
this shows up on the shared desk/phone approach while the client stands over it:
the walk ends one cell short, 17–21 world units off, which is inside arm's reach.
`DialogueApproach` picks from a ring of candidates and simply takes another one.
v2.0 tolerated an occupied goal deliberately; that deviation is gone.

**Solids are up to a cell fatter.** Conservative rasterisation closed one
authored spot that had never really been open: the north-east plaza in the city
block grid is ringed by lots that meet corner to corner with an 11.6-unit gap
between them — narrower than one search cell and far narrower than a person.
Centre sampling left the odd cell centre free in that seam, so the plaza read as
connected. `CityStreetPlan.arrivalPoint(from: .north)` moved onto the
north–south street; it was the only authored city point on the wrong side of it.

**Search cost moved.** The navmap-space line walk samples every cell a Theta\*
shortcut crosses, which is several times the work of the tile walk. A
district-crossing search is ~23 ms in Release and ~4 s in a `-Onone` test build;
the engine's 15-second wall-clock guard is what bounds the pathological case.
Two allocation-level optimisations keep the debug figure inside it — the
`PlotCircle` scanlines are memoised per radius, and the line walk skips a cell it
just probed — and neither changes an answer.

### One adaptation, made deliberately

**`circleSize` is derived per profile, not shared with `personal_space`.**
`NavigationAgentProfile.circleSize(forRadius:)` sizes the clearance disc to each
profile's tuned world radius. Routing the actor-spacing number (4) into static
clearance as well would replace a 3-unit office footprint with a 32-unit disc and
seal the room. This is called out at the call site; reverting it is a decision,
not a tidy-up.

`NavigationAgentProfile.halfWidth` / `.halfHeight` survive, but no longer reach
the pathfinder: they are persisted in `AreaDefinition`, they derive `circleSize`
when one is not given, and QA still measures with them.

### Deliberately not ported

- **The async pathfinder.** GemRB `master` searches on worker threads
  (`PathFinderScheduler`, `FindPathRequestId`, and the `FindPathScheduled` state
  whose whole rationale is "the request takes a tick or two"). That is a
  threading strategy, not movement logic, and with one or two actors it buys
  nothing. `Movable.walkTo` searches synchronously. `MovementState` is ported
  minus that case; `pathSearchFailed` is kept, because it is what makes an
  unreachable destination terminate rather than be refiled forever.
- **`Actor::WalkTo`'s `ResetPathTries()`.** Upstream resets the retry counter on
  every entry, including the one `Actor::NewPath` makes — so `MAX_PATH_TRIES` can
  never accumulate past one and the budget it guards is unreachable. Ours does
  not reset, which is what makes `MovementOrderQueue.correctiveRepath` able to
  abandon. This is an upstream bug, not a divergence to adopt.
- **`BumpBack`'s alignment gate.** The engine lets only friendly actors
  (`IE_EA < EA_GOODCUTOFF`) give up on reclaiming their spot; a hostile keeps
  trying forever. RainShadow has no alignment axis, and inventing one to
  reproduce a branch nothing would take would be worse than the omission.
- **`RandomWalk`'s action-queue branches.** The off-screen check that makes an
  unseen actor wait 1–40 seconds needs a viewport this layer cannot see, and the
  `RandomWalkTime` parameters count moves down to a `ReleaseCurrentAction`. Both
  belong to an action queue RainShadow does not have. `randomWalk` reports what
  the engine would have queued (`RandomWalkOutcome`) and the caller drives it.
- **`LineStepper` as a shared type.** `blockedInLine` and `blockedInLineTile`
  inline the engine's walk rather than sharing a stepper: they run per Theta\*
  child expansion, and in a `-Onone` test build the extra call frame per world
  step costs more than the duplication does. Both copies say so.


## Known limits

- `PathMapFlags` is now the engine's full byte — `TRAVEL`, `NO_SEE` and `SIDEWALL` included, derived from the terrain table by `SearchMapTerrain.areaFlags`. `TRAVEL` is set but not yet *consumed*: BG triggers area transitions through it, and we still use hotspot and edge-exit rects. `WorldCursor` takes its travel state from those rects rather than from the flag.
- Footstep **material** is modelled per scene (`FootstepSurface`) rather than per cell. BG resolves it through the search map's material channel into `terrain.2da`; BG:EE itself ships no `terrain.2da`, so this is a seam kept deliberately.
- No formation or group pathing; that remains Movement System Roadmap P4–P5.
- Bump resolution is single-blocker per step. A crowd of three or more idle actors in a corridor resolves over successive ticks rather than as one coordinated shuffle — as it does in the engine.
- `Backoff` makes a blocked mover wait; it does not yet surface player feedback explaining the wait.
- Conservative rasterisation fattens every authored solid by up to a cell. Corridors have to be authored at cell resolution to survive it; `AreaReachabilityTests` and `CityWorldExtentTests` are what catch one that does not.
- `bake_area_searchmap.py` is not the generator that owns the six city `.sr.png` rasters — those carry roof and world-map-exit terrain it cannot produce, and it does not reproduce them. Do **not** re-bake a city area with it. The authored rectangles reach the painted raster at load instead, through `SearchMap`'s terrain initialiser, which unions them in without touching terrain a rectangle cannot express.
