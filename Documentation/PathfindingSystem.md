# Pathfinding and NPC locomotion

- Status: shipped — replaces the former grid A\* (`NavigationGrid`)
- Version: 1.0
- Date: 4 August 2026
- Related: [Technical Architecture](TechnicalArchitecture.md) §10–12 (actors, navigation, input), [Movement System Roadmap](MovementSystemRoadmap.md), [Game Design Document](GameDesignDocument.md) §8 (Controls)

## Purpose

This document is the authoritative reference for how RainShadow moves actors through the world. It covers two things:

1. The **shipped navigation stack**, rewritten to follow Baldur's Gate: Enhanced Edition / Infinity Engine practice: a raster search map, Lazy Theta\* any-angle search, actor occupancy with bumping, directed destination adjustment, and in-place door stamping.
2. The **NPC authoring convention** that follows from it. Every walking character added from here on — companions, watchers, district crowd figures, later clients — is written against `NavigationMap` and `RouteFollower`, never against authored polylines or `SKAction.move` chains.

The previous system is gone, not deprecated. `NavigationGrid` and its tests were deleted; there is no compatibility path back to authored per-scene polylines for locomotion.

## What changed

| Concern | Former system (`NavigationGrid`) | Shipped system |
|---|---|---|
| World representation | Cell grid derived from authored obstacle AABBs | Byte-per-cell raster **search map** with flag bits (`SearchMap`) |
| Search | 8-connected A\* with corner-cut rejection | **Lazy Theta\*** — 4-connected expansion plus line-of-sight shortcutting (`PathFinder`) |
| Path shape | Grid-axis steps, then string-pull simplification | Any-angle segments produced by the search itself |
| Path smoothing | Separate post-pass | None needed; LOS parent relinking is the smoothing |
| Search bound | Bounded only by grid extent | **Node budget** (`maxNodes`, default 32 000) |
| Blocked destination | Bounded Chebyshev ring scan for nearest cell | **Directed adjustment** back along the line toward the caller, then bounded reachable-cell fallback |
| Other actors | Not modelled | Stamped into the map as PC/NPC bits; bumpable actors are traversable (`ActorOccupancy`) |
| Blocked-by-actor recovery | None | **Bump**: the idle blocker sidesteps and returns; movers back off after repeated blocks |
| Door open/close | Rebuild the whole navigation grid | **Stamp/clear door cells in place** (`setEntranceDoorBlocking`) |
| Mid-walk correction | None | Periodic **corrective repath** while a route is active |
| Client NPC movement | Authored polyline + `SKAction.move` sequence | Pathfinder route + `RouteFollower` |

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

Queries come in point, radius, and line forms. Two behaviours are load-bearing and were the source of most rewrite bugs:

- **Radius queries consult geometry, not just cells.** `isPassable(at:radius:)` additionally calls `discOverlapsObstacle`, so an agent with real clearance cannot squeeze through a gap that is only wide enough for a point. Cell-only tests let actors clip thin barriers.
- **The map boundary is solid for any agent with radius > 0.** This reproduces the former grid's contract and keeps actors off the edge of authored floors.

`isWalkableLine` performs the geometric obstacle test before the cell walk, so the Theta\* shortcut check can never approve a segment that crosses a wall.

### PathFinder — Lazy Theta\*

Expansion is 4-connected over cells, but each node's parent is *lazily relinked* to its grandparent when `isWalkableLine` says the direct segment is clear. The result is an any-angle polyline emitted by the search itself, which is why there is no separate string-pull pass.

- **Weighted heuristic.** `heuristicWeight = 1.5`, GemRB's default. This trades strict optimality for a materially smaller expanded set and quicker responses — the correct trade for a click-to-move game.
- **Tie-breaking.** Equal-cost frontiers are broken by the cross product against the straight start→goal line, which biases the path toward the visual straight line instead of a staircase.
- **Node budget.** `defaultMaxNodes = 32_000`, BG:EE's "Path Search Nodes" default. Exceeding it fails the search rather than stalling a frame; `nodeBudgetCutoffCanFailLongSearches` pins that behaviour.

Return semantics are deliberately three-valued and every caller must respect them:

| Result | Meaning |
|---|---|
| `nil` | No route. Do not move; show invalid feedback. |
| `[]` | Already at the destination. Do not move, but this is **success**, not failure. |
| non-empty | Waypoints to follow, first waypoint ahead of the actor. |

Two goal-relaxation mechanisms exist, and they are separate on purpose:

- `minDistance` lets a caller stop short of a goal that is itself impassable — the "walk up to the thing and stop" case. Exact `findPath` never relocates a goal.
- `adjustPositionDirected` implements BG's `AdjustPosition`: when the requested point is blocked, walk the goal back along the line toward the caller until it lands somewhere passable. Because the adjustment is directed rather than a ring scan, the actor stops on the near side of an obstacle instead of appearing at an arbitrary neighbouring cell.

### ActorOccupancy — bumping and congestion

Actors register with an id, a kind (`player` / `npc`), a position, and a radius; occupancy stamps the matching bit into the search map and restamps on every position update.

- **Bumpable by default when idle.** A registered actor is bumpable while it is not moving, matching BG:EE's treatment of party members and friendly NPCs as soft obstacles.
- **Planning through bumpables.** `PathFinderFlags.allowBumpableActors` (the default for `NavigationMap.path`) lets a route pass through idle actors. `actorsAreBlocking` gives the strict variant for queries that must not assume a bump will happen.
- **Bump request.** When a mover's next position overlaps an idle bumpable actor, `bumpRequest` returns the blocker's id, a `sidestepPoint` chosen on the passable side away from the mover, and the `returnPoint` it should walk back to. The scene is responsible for driving both legs, which keeps animation and state-machine ownership with the actor node.
- **Congestion back-off.** `recordCongestion` counts consecutive blocked advances; at `maxCongestionRetries` (8) the mover should wait rather than repath forever. This is the guard against the two-actors-shuffling-in-a-doorway failure that IE is remembered for.

### NavigationMap — the scene API

The only navigation type scenes and layout helpers should use.

| Member | Use |
|---|---|
| `route(from:to:maximumFallbackWorldRadius:)` | **Player click/tap resolution.** Exact path when possible, otherwise the nearest *reachable* point within the bound, reported via `NavigationRoute.resolvedDestination` / `destinationWasAdjusted`. |
| `path(from:to:)` | Direct route with bumpable actors traversable. Returns `nil` / `[]` / waypoints per the table above. |
| `pathAvoidingActors(from:to:)` | Same, but other actors are hard blockers. |
| `waypoints(visiting:)` | Expands sparse authored anchors into a walkable polyline by pathing between consecutive anchors. **This is how scripted NPC beats are authored.** |
| `repath(from:to:)` | Corrective repath from a live position to an existing goal. |
| `nearestWalkablePoint(to:)` | Snap an arbitrary point (hotspot approach, spawn) onto walkable floor. |
| `setEntranceDoorBlocking(_:)` | Toggle door cells in place; no rebuild. |
| `registerActor` / `updateActor` / `unregisterActor` | Occupancy lifecycle for anything that occupies floor. |

`route` and `path` are not interchangeable. `route` is the forgiving, player-facing entry point that is allowed to move the goal; `path` is exact and fails honestly. Tests that assert "the player can get there by clicking" must use `route`; tests that assert "this specific line is walkable" must use `path`.

Fallback candidate selection inside `route` uses a 4-connected flood fill of reachable cell centres, sorted by distance to the request with deterministic tie-breaks, then tries the closest handful. Selecting from *reachable* cells rather than merely *passable* ones is what prevents the old failure where a tap across a wall snapped to a point the actor could not actually walk to.

### Dynamic doors

The office entrance door is registered as a door obstacle at construction, then toggled: `setEntranceDoorBlocking(true/false)` stamps or clears exactly those cells and restamps actors. The falling-door and returning-door animations call it directly. Nothing rebuilds the map, and `impassableCellCount` remains a valid assertion target for open-versus-closed state (`fallenEntranceDoorClearsDoorStampWithoutRebuild`).

Any future dynamic geometry — a shifted screen, a raised grate, a collapsed shelf — should follow this pattern: register the rect as a door obstacle at construction and stamp it on state change.

### Corrective repathing

Scenes recompute the active route every `correctiveRepathInterval` (0.75 s) while an actor is walking, mirroring BG:EE's "Enhanced Path Search". A bottleneck that clears mid-walk — a door that fell, an NPC that bumped aside — immediately yields the shorter path instead of the actor finishing a route planned against stale state.

## Scene integration contract

`DetectiveOfficeScene` and `CityDistrictScene` run the same per-frame order from `update(_:)`, and any new scene with walking actors must too:

1. **Advance locomotion.** `updateLocomotion(at:worldIsPaused:)` on each actor node, which is where its `RouteFollower` steps.
2. **Prune completed queue goals.** Drop goals the actor has already reached so the live leg stays accurate and waypoint pips disappear.
3. **Push occupancy.** Feed every visible actor's live position and `isMoving` to `NavigationMap.updateActor`. Unregister actors that are hidden.
4. **Corrective repath.** If a destination is pending, the actor is still walking, and `correctiveRepathInterval` has elapsed, `repath` the *current* leg from the live position and re-append later queued goals.
5. **Process bump requests.** If the mover overlaps an idle bumpable actor, drive that actor's sidestep and queue its return.

Everything after step 1 is gated on the world not being paused, so modal dialogue, the map, the journal, and the inventory freeze navigation without cancelling the active route. `CityDistrictScene` currently has a single actor and therefore no bump step; `DetectiveOfficeScene` implements the full loop as `pruneCompletedQueuedGoals()`, `updateActorOccupancy()`, `performCorrectiveRepathIfNeeded(at:)`, and `processBumpRequests()`.

Each scene holds `queuedMovementGoals` — the ordered player goals (BG:EE waypoint queue), as distinct from the current pathfinder waypoint list — because corrective repathing needs the original intent, not the truncated tail of the active route. Plain click / tap replaces the queue; Shift+click (macOS) or long-press (iOS) appends a goal routed from the last queued point.

## Agent profiles

`NavigationAgentProfile` separates planning clearance from the selection/display footprint. Radius is the larger half-extent, so anisotropic footprints still clear narrow gaps conservatively.

| Profile | Half-extents | Used by |
|---|---|---|
| `.point` | 0 × 0 | Pure geometry tests and anchor snapping |
| `.detective` | 16 × 4 | City district — personal-space core in open street space |
| `.officeDetective` | 3 × 0 | Office interior — obstacle art already bakes in floor-contact clearance |
| `.officeClient` | 3 × 0 | Lila, matching the detective's office clearance |

New NPCs pick an existing profile rather than inventing one. A per-NPC profile is only justified when its floor footprint genuinely differs (a large animal, a cart), and it must come with a test that the office and district maps remain traversable for it.

## How NPCs are written from here on

The client NPC (Lila) has been migrated off authored polylines and `SKAction.move` onto the pathfinder plus `RouteFollower`. She is the reference implementation; treat `ClientActorNode` as the template.

### Frozen rules

1. **All floor-bound movement comes from `NavigationMap`.** No `SKAction.move`/`follow` chains for locomotion, and no hand-authored waypoint lists consumed directly as positions. Authored anchors are input to `waypoints(visiting:)`, never a path themselves.
2. **`RouteFollower` owns advancement.** One `advance(from:deltaTime:speed:)` call per frame, driven from the scene's `update`. This is what makes retarget, cancel, arrival, and overshoot deterministic and testable, and it is why bumping can interrupt a walk mid-segment.
3. **Every floor-occupying actor registers with occupancy** on becoming visible and unregisters on being hidden or removed. An unregistered NPC is invisible to pathfinding and will be walked through.
4. **Idle NPCs are bumpable; moving NPCs are not.** Do not hard-block the player with a stationary NPC. If a beat genuinely requires an immovable body, model it as a static obstacle, not as an unbumpable actor.
5. **Respect the three-valued path result.** `nil` and `[]` mean different things; collapsing them produces both phantom "can't go there" feedback and skipped scripted beats.
6. **Facing derives from movement.** 16 facing bins from velocity, nine source orientations plus seven mirrored, per Technical Architecture §10.4. Never mirror the whole figure where a sprite contract forbids it (Lila's handbag/light contract).
7. **Single-agent correctness is not negotiable.** Multi-actor work must not regress detective-only office navigation tests.

### Adding a walking NPC

1. **Node.** Subclass or model on `ClientActorNode`: sprite body, contact shadow, a private `RouteFollower`, a locomotion mode enum, and a `movementCompletion`.
2. **Movement entry point.** Expose a `walk(path:completion:)` that calls `routeFollower.replaceRoute(with:from:)` and starts the walk cycle. Handle the "already there" case by completing immediately.
3. **Per-frame advance.** Implement `updateLocomotion(at:worldIsPaused:)` and call it from the scene's `update`. Advance the follower, apply position, update the facing bin, and finish when the follower stops moving. Return early while paused so overlays do not consume route progress.
4. **Occupancy.** Register on spawn with a stable id and the appropriate `NavigationActorKind`; call `updateActor` every frame with the live position and `isMoving`; unregister when hidden.
5. **Scripted beats.** Author sparse anchors (door threshold, desk-side stop) and expand them with `waypoints(visiting:)`. The result is a walkable polyline that respects current obstacles, including a door that happens to be open.
6. **Reactive movement.** For anything responding to the world — bump sidesteps, approaching a hotspot, following the player — call `route` or `path` at the moment of the decision. Never precompute and cache a path across a state change.
7. **Tests.** Add coverage in `NavigationMapTests` that the NPC's anchors resolve, that its route stays clear of authored obstacles, and that its profile can traverse the maps it appears in. `officeClientArrivalCrossesPartitionApertureOnce` and `officeClientDepartureRetracesInteriorThenCrossesExteriorDoor` are the models.

### Anti-patterns

| Do not | Because |
|---|---|
| Drive an NPC with `SKAction.move` sequences | Cannot be retargeted, cancelled, or bumped mid-segment; timing drifts per segment |
| Store an authored polyline as the NPC's path | Breaks the instant a door, prop, or actor changes state |
| Skip occupancy registration for "background" NPCs | The player and other NPCs will path straight through them |
| Treat an idle NPC as a hard blocker | Produces the doorway soft-locks this rewrite exists to avoid |
| Call `path` for player click resolution | Player taps need `route`'s destination adjustment and reachable fallback |
| Re-derive a nav map to change one obstacle | Doors and dynamic geometry stamp in place |

### Scripted beats versus reactive movement

Both go through the pathfinder; they differ only in when the path is requested. A scripted beat (client arrival, a scheduled exit) resolves its anchors at the moment the beat fires. Reactive movement resolves at the moment of the trigger and is expected to be re-resolved by corrective repathing. Neither may bake a path at scene construction, because door and actor state at construction is not the state the walk will execute in.

## Testing

`Tests/RainShadowCoreTests/NavigationMapTests.swift` replaced `NavigationGridTests` and holds the full invariant set: any-angle shortcutting, corner-cut rejection, thin-obstacle rejection under a real footprint, boundary-as-solid, bounded fallback rings, disconnected-destination fallback, already-there versus unreachable, node-budget cutoff, `minDistance`, actor hard-blocking, bump sidestep, congestion back-off, in-place door stamping, and the office/city layout reachability suites. `OfficeInteriorScaleTests` and `OfficeClientVisitSequencerTests` were updated to the `route`/`path` split described above.

Build and test commands are macOS-only; see the [repository README](../README.md) under "Verification". Use the documented `/tmp` scratch path when running `swift test` to avoid Finder-metadata codesigning failures on the test bundle.

## Known limits

- Search-map flags currently model passability, doors, and actors only. BG's see-through, flyable, projectile-transit, and footstep-material bits are not modelled yet; the flag set is an `OptionSet` with room for them, and line-of-sight queries plus footstep material are the natural next consumers.
- No formation or group pathing; that remains Movement System Roadmap P4–P5.
- Bump resolution is single-blocker per request. A crowd of three or more idle actors in a corridor resolves over successive frames rather than as one coordinated shuffle.
- Congestion back-off makes a blocked mover wait; it does not yet surface player feedback explaining the wait.
