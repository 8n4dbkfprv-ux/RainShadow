import CoreGraphics
import Foundation

/// Scene-facing BG:EE-style navigation: search-map raster + Lazy Theta* + actor
/// occupancy. Replaces the former AABB grid A* (`NavigationGrid`).
final class NavigationMap {
    let searchMap: SearchMap
    let agentProfile: NavigationAgentProfile
    let occupancy: ActorOccupancy
    private(set) var pathFinder: PathFinder

    /// Door leaf rects registered for stamp/clear without rebuilding the map.
    private let doorObstacles: [DoorObstacle]
    private(set) var entranceDoorBlocking: Bool

    /// Compatibility: impassable cell count for door open/closed assertions.
    var impassableCellCount: Int { searchMap.impassableCellCount }

    /// Legacy alias used by older tests that inspected `blocked.count`.
    var blockedCount: Int { impassableCellCount }

    /// Adopt an already-built search map — the path a painted `SR` raster takes.
    init(
        searchMap: SearchMap,
        agentProfile: NavigationAgentProfile = .point,
        doorObstacles: [DoorObstacle] = [],
        entranceDoorBlocking: Bool = true
    ) {
        Self.applyDoorStartState(
            on: searchMap,
            doors: doorObstacles,
            entranceDoorBlocking: entranceDoorBlocking
        )
        self.searchMap = searchMap
        self.agentProfile = agentProfile
        self.doorObstacles = doorObstacles.map(\.standardized)
        self.entranceDoorBlocking = entranceDoorBlocking
        let occupancy = ActorOccupancy(searchMap: searchMap)
        self.occupancy = occupancy
        self.pathFinder = PathFinder(searchMap: searchMap, traversability: occupancy)
    }

    init(
        worldBounds: CGRect,
        obstacles: [CGRect],
        agentProfile: NavigationAgentProfile = .point,
        doorObstacles: [DoorObstacle] = [],
        entranceDoorBlocking: Bool = true,
        cellSize: CGSize = SearchMap.defaultCellSize,
        defaultTerrain: SearchMapTerrain = .stone
    ) {
        // Door leafs are stamped separately so they can toggle without rebuild.
        let doorRects = doorObstacles.map(\.rect.standardized)
        let staticObstacles = obstacles.map(\.standardized).filter { candidate in
            !doorRects.contains(where: { rectsApproximatelyEqual($0, candidate) })
        }

        let map = SearchMap(
            worldBounds: worldBounds,
            obstacles: staticObstacles,
            cellSize: cellSize,
            doorObstacles: doorObstacles,
            defaultTerrain: defaultTerrain
        )
        Self.applyDoorStartState(
            on: map,
            doors: doorObstacles,
            entranceDoorBlocking: entranceDoorBlocking
        )

        self.searchMap = map
        self.agentProfile = agentProfile
        self.doorObstacles = doorObstacles.map(\.standardized)
        self.entranceDoorBlocking = entranceDoorBlocking
        let occupancy = ActorOccupancy(searchMap: map)
        self.occupancy = occupancy
        self.pathFinder = PathFinder(searchMap: map, traversability: occupancy)
    }

    /// Convenience initializer matching the old orthogonal `NavigationGrid` tests.
    convenience init(
        origin: CGPoint,
        columns: Int,
        rows: Int,
        cellSize: CGSize,
        obstacles: [CGRect],
        agentProfile: NavigationAgentProfile = .point,
        worldBounds: CGRect? = nil
    ) {
        let bounds = worldBounds ?? CGRect(
            x: origin.x,
            y: origin.y,
            width: CGFloat(columns) * cellSize.width,
            height: CGFloat(rows) * cellSize.height
        )
        self.init(
            worldBounds: bounds,
            obstacles: obstacles,
            agentProfile: agentProfile,
            doorObstacles: [],
            entranceDoorBlocking: false,
            cellSize: cellSize
        )
    }

    private static func applyDoorStartState(
        on searchMap: SearchMap,
        doors: [DoorObstacle],
        entranceDoorBlocking: Bool
    ) {
        if doors.contains(where: { !$0.id.isEmpty }) {
            searchMap.restampDoors()
        } else {
            searchMap.stampDoors(blocking: entranceDoorBlocking)
        }
    }

    /// Stamp or clear exterior door cells in place (no grid rebuild).
    func setEntranceDoorBlocking(_ blocking: Bool) {
        entranceDoorBlocking = blocking
        if doorObstacles.isEmpty {
            return
        }
        searchMap.setDoorObstacles(doorObstacles, blocking: blocking)
        occupancy.restampAll()
    }

    /// Stamp only the doors that are currently shut. Opening one outdoor leaf
    /// clears its cells without rebuilding the search map, which is the IE
    /// door split RainShadow copies.
    func setActiveDoorObstacles(_ doors: [DoorObstacle]) {
        entranceDoorBlocking = !doors.isEmpty
        searchMap.setDoorObstacles(doors, blocking: !doors.isEmpty)
        occupancy.restampAll()
    }

    /// Open or shut one authored door. City portals and the office leaf share
    /// this so a mixed set of start-states can coexist on one map.
    func setDoor(_ id: String, open: Bool) {
        searchMap.setDoor(id: id, open: open)
        if doorObstacles.contains(where: { $0.id == id }) {
            entranceDoorBlocking = !open && doorObstacles.filter { $0.id != id }.isEmpty
                ? !open
                : entranceDoorBlocking
        }
        occupancy.restampAll()
    }

    // MARK: - Routing

    /// `circleSize` for this map's agent, in search cells.
    var circleSize: Int { agentProfile.circleSize }

    /// Snap an arbitrary point onto floor a body of this size can stand on.
    /// Used for spawns and authored anchors, not for player orders — `findPath`
    /// relocates a blocked goal on its own.
    ///
    /// This asks `AdjustPosition` for clearance (`size = circleSize`), where
    /// `PathFinder.adjustPositionNavmap` — the engine's own `BumpAway` helper —
    /// asks only for a passable cell. A spawn has to fit; a sidestep only has to
    /// be somewhere to stand for a moment.
    func nearestWalkablePoint(to point: CGPoint) -> CGPoint? {
        let snapped = searchMap.center(
            of: pathFinder.adjustPosition(goal: searchMap.cell(for: point), size: circleSize)
        )
        guard searchMap.blockedInRadiusTile(at: snapped, size: circleSize).contains(.passable) else {
            return nil
        }
        return snapped
    }

    /// Whether a click here is worth issuing at all.
    ///
    /// `GameControl::UpdateCursor` reads this straight off the search map, and
    /// `OnMouseUp` refuses the order when it says blocked. Keeping the refusal
    /// at the click layer is what makes unreachable geometry legible; `findPath`
    /// relocating a blocked goal is for scripted moves and for goals blocked by
    /// a body rather than by terrain.
    func isOrderableFloor(_ point: CGPoint) -> Bool {
        guard searchMap.contains(point) else { return false }
        // Terrain only. An occupied cell reads as impassable — `GetBlockedTile`
        // clears `PASSABLE` wherever an actor is stamped — but a body standing
        // on floor is something to bump, not something that makes the ground
        // unclickable. Distinguishing them is the point of testing both bits:
        // floor under an actor keeps `ACTOR`, a wall keeps neither.
        return !searchMap.blockedInRadiusTile(at: point, size: circleSize)
            .isDisjoint(with: [.passable, .actor])
    }

    /// Whether `to` is reachable **as asked**, rather than relocated near it.
    ///
    /// `FindPath` moves a blocked goal itself (`AdjustPositionDirected`), so a
    /// non-empty path no longer means "the requested point is reachable" — it
    /// means *something near it* is. Approaches issued with
    /// Authoring and reachability assertions need the stricter question even
    /// though runtime interactions use `MinDistance`: the search must land in
    /// the cell that was asked for, so proximity cannot hide sealed geometry.
    ///
    /// This is the same trap `route` used to set — it flood-filled to the
    /// nearest reachable cell and so succeeded from inside a sealed pocket,
    /// which hid three shipped bugs. See `Documentation/PathfindingSystem.md`.
    func reachesExactly(from start: CGPoint, to target: CGPoint) -> Bool {
        guard isOrderableFloor(target) else { return false }
        let targetCell = searchMap.cell(for: target)
        let found = path(from: start, to: target)
        guard let landed = found.destination else {
            // Empty means "do not walk": already standing in the cell, or nothing found.
            return searchMap.cell(for: start) == targetCell
        }
        return searchMap.cell(for: landed) == targetCell
    }

    /// The general entry point. An empty `Path` means "do not walk" — the engine
    /// draws no distinction between "already there" and "nowhere to go", because
    /// both leave the actor standing.
    func findPath(
        from startPoint: CGPoint,
        to targetPoint: CGPoint,
        minDistance: CGFloat = 0,
        flags: PathFinderFlags = [.sight],
        identity: String? = nil
    ) -> Path {
        var finder = pathFinder
        finder.identity = identity
        let search = {
            finder.findPath(
                from: startPoint,
                to: targetPoint,
                circleSize: self.circleSize,
                minDistance: minDistance,
                flags: flags
            )
        }
        // The requester's own footprint comes off the raster for the duration,
        // as `PathFinder::ClearSearchMapFor` does before every search. With
        // `PF_ACTORS_ARE_BLOCKING` set, leaving it on rejects every cell inside
        // the actor's own personal space and no route can leave the start.
        guard let identity else { return search() }
        return occupancy.withStampLifted(id: identity, search)
    }

    /// Direct route; idle actors in the way are planned through and bumped.
    func path(
        from startPoint: CGPoint,
        to targetPoint: CGPoint,
        identity: String? = nil
    ) -> Path {
        findPath(from: startPoint, to: targetPoint, flags: [.sight], identity: identity)
    }

    /// `Movable::WalkTo`'s flags — plan around other actors rather than through
    /// them. Scenes try this first and fall back to `path`.
    func pathAvoidingActors(
        from startPoint: CGPoint,
        to targetPoint: CGPoint,
        identity: String? = nil
    ) -> Path {
        findPath(
            from: startPoint,
            to: targetPoint,
            flags: [.sight, .actorsAreBlocking],
            identity: identity
        )
    }

    /// Corrective repath from a live position to an existing goal
    /// (BG:EE "Enhanced Path Search").
    func repath(from current: CGPoint, to destination: CGPoint, identity: String? = nil) -> Path {
        path(from: current, to: destination, identity: identity)
    }

    /// Exact route, reporting where the search actually landed.
    ///
    /// Retained for scripted approaches that need to know a goal moved.
    /// `findPath` relocates a blocked destination itself now, so this no longer
    /// runs a flood fill and no longer differs from `path` in what it will
    /// accept — only in what it reports.
    func route(from startPoint: CGPoint, to requestedPoint: CGPoint) -> NavigationRoute? {
        let found = path(from: startPoint, to: requestedPoint)
        guard let resolved = found.destination else { return nil }
        return NavigationRoute(
            requestedDestination: requestedPoint,
            resolvedDestination: resolved,
            waypoints: found.remainingPoints,
            destinationWasAdjusted: searchMap.cell(for: resolved)
                != searchMap.cell(for: requestedPoint)
        )
    }

    /// 4-connected flood fill of standable cell centres reachable from `start`.
    ///
    /// Not used for routing. This is the instrument the area reachability tests
    /// measure with — `route` used to succeed from inside a sealed pocket, which
    /// hid three shipped bugs. See `Documentation/PathfindingSystem.md`.
    func reachableCellCenters(from start: CGPoint) -> [CGPoint] {
        let startCell = searchMap.cell(for: start)
        guard searchMap.contains(startCell),
              searchMap.blockedInRadiusTile(at: startCell, size: circleSize).contains(.passable)
        else {
            return []
        }

        var visited: Set<SearchMapCell> = [startCell]
        var queue: [SearchMapCell] = [startCell]
        var centers: [CGPoint] = [searchMap.center(of: startCell)]
        let neighbors = [(1, 0), (0, 1), (-1, 0), (0, -1)]
        var index = 0

        while index < queue.count {
            let current = queue[index]
            index += 1
            for (dx, dy) in neighbors {
                let next = SearchMapCell(column: current.column + dx, row: current.row + dy)
                guard searchMap.contains(next), !visited.contains(next) else { continue }
                guard searchMap.blockedInRadiusTile(at: next, size: circleSize).contains(.passable)
                else { continue }
                visited.insert(next)
                queue.append(next)
                centers.append(searchMap.center(of: next))
            }
        }
        return centers
    }

    /// Expand sparse authored anchors into one walkable path by searching
    /// between consecutive anchors. This is how scripted NPC beats are authored.
    func waypoints(visiting anchors: [CGPoint]) -> Path? {
        guard !anchors.isEmpty else { return Path() }

        var resolved: [CGPoint] = []
        resolved.reserveCapacity(anchors.count)
        for anchor in anchors {
            guard let point = resolveWalkableAnchor(anchor) else { return nil }
            if let last = resolved.last, distance(from: last, to: point) <= 0.25 { continue }
            resolved.append(point)
        }
        guard let first = resolved.first else { return nil }
        if resolved.count == 1 {
            return Path(nodes: [PathNode(point: first, orient: .south)])
        }

        var combined = Path()
        var cursor = first
        for index in 1..<resolved.count {
            let leg = path(from: cursor, to: resolved[index])
            guard leg.isPresent else { return nil }
            combined.append(leg)
            cursor = leg.destination ?? cursor
        }
        return combined
    }

    // MARK: - Occupancy helpers

    func registerActor(
        id: String,
        kind: NavigationActorKind,
        at position: CGPoint,
        radius: CGFloat? = nil,
        isMoving: Bool = false,
        personalSpaceCells: Int = ActorLocomotionPacing.personalSpaceCells,
        blocksSearchMap: Bool = true
    ) {
        occupancy.register(
            OccupyingActor(
                id: id,
                kind: kind,
                position: position,
                radius: radius ?? agentProfile.radius,
                isBumpable: !isMoving,
                isMoving: isMoving,
                personalSpaceCells: personalSpaceCells,
                blocksSearchMap: blocksSearchMap
            )
        )
    }

    func updateActor(id: String, position: CGPoint, isMoving: Bool) {
        occupancy.updatePosition(id: id, to: position, isMoving: isMoving)
    }

    func unregisterActor(id: String) {
        occupancy.unregister(id: id)
    }

    // MARK: - Private

    /// An authored anchor is accepted where it stands if the raster says a body
    /// fits there, and otherwise snapped to the nearest cell that one does. The
    /// question is `GetBlockedInRadiusTile`'s, not a world-space disc's — the
    /// raster is the only clearance authority the engine has.
    private func resolveWalkableAnchor(_ point: CGPoint) -> CGPoint? {
        if searchMap.contains(point),
           searchMap.blockedInRadiusTile(at: point, size: circleSize).contains(.passable) {
            return point
        }
        return nearestWalkablePoint(to: point)
    }

    private func distance(from a: CGPoint, to b: CGPoint) -> CGFloat {
        hypot(a.x - b.x, a.y - b.y)
    }
}

private func rectsApproximatelyEqual(_ a: CGRect, _ b: CGRect) -> Bool {
    abs(a.origin.x - b.origin.x) < 0.001
        && abs(a.origin.y - b.origin.y) < 0.001
        && abs(a.size.width - b.size.width) < 0.001
        && abs(a.size.height - b.size.height) < 0.001
}
