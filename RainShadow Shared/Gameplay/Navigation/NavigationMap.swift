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
    private let doorObstacles: [CGRect]
    private(set) var entranceDoorBlocking: Bool

    /// Compatibility: impassable cell count for door open/closed assertions.
    var impassableCellCount: Int { searchMap.impassableCellCount }

    /// Legacy alias used by older tests that inspected `blocked.count`.
    var blockedCount: Int { impassableCellCount }

    init(
        worldBounds: CGRect,
        obstacles: [CGRect],
        agentProfile: NavigationAgentProfile = .point,
        doorObstacles: [CGRect] = [],
        entranceDoorBlocking: Bool = true,
        cellSize: CGSize = SearchMap.defaultCellSize,
        maxNodes: Int = PathFinder.defaultMaxNodes
    ) {
        // Door leafs are stamped separately so they can toggle without rebuild.
        let doorRects = doorObstacles.map(\.standardized)
        let staticObstacles = obstacles.map(\.standardized).filter { candidate in
            !doorRects.contains(where: { rectsApproximatelyEqual($0, candidate) })
        }

        let map = SearchMap(
            worldBounds: worldBounds,
            obstacles: staticObstacles,
            cellSize: cellSize,
            doorObstacles: doorObstacles
        )
        map.stampDoors(blocking: entranceDoorBlocking)

        self.searchMap = map
        self.agentProfile = agentProfile
        self.doorObstacles = doorObstacles.map(\.standardized)
        self.entranceDoorBlocking = entranceDoorBlocking
        self.pathFinder = PathFinder(searchMap: map, maxNodes: maxNodes)
        self.occupancy = ActorOccupancy(searchMap: map)
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

    // MARK: - Door

    /// Stamp or clear exterior door cells in place (no grid rebuild).
    func setEntranceDoorBlocking(_ blocking: Bool) {
        entranceDoorBlocking = blocking
        if doorObstacles.isEmpty {
            return
        }
        searchMap.setDoorObstacles(doorObstacles, blocking: blocking)
        occupancy.restampAll()
    }

    // MARK: - Routing

    func nearestWalkablePoint(to point: CGPoint) -> CGPoint? {
        pathFinder.nearestPassablePoint(
            to: point,
            actorRadius: agentProfile.radius,
            treatActorsAsBlocking: false
        )
    }

    /// Exact route when possible; otherwise snap to the nearest *reachable*
    /// cell toward the request (BG AdjustPosition + bounded fallback). An
    /// optional world-space radius preserves `requiresExactDestination`.
    func route(
        from startPoint: CGPoint,
        to requestedPoint: CGPoint,
        maximumFallbackWorldRadius: CGFloat? = nil
    ) -> NavigationRoute? {
        if let exact = path(
            from: startPoint,
            to: requestedPoint
        ) {
            return NavigationRoute(
                requestedDestination: requestedPoint,
                resolvedDestination: requestedPoint,
                waypoints: exact
            )
        }

        guard searchMap.isPassable(at: startPoint, radius: agentProfile.radius) else {
            return nil
        }

        let reachable = reachableCellCenters(from: startPoint)
        guard !reachable.isEmpty else { return nil }

        let candidates = reachable
            .map { point -> (point: CGPoint, distance: CGFloat) in
                (point, hypot(point.x - requestedPoint.x, point.y - requestedPoint.y))
            }
            .filter { candidate in
                if let maximumFallbackWorldRadius {
                    return candidate.distance <= maximumFallbackWorldRadius
                }
                return true
            }
            .sorted { lhs, rhs in
                if lhs.distance != rhs.distance { return lhs.distance < rhs.distance }
                if lhs.point.y != rhs.point.y { return lhs.point.y < rhs.point.y }
                return lhs.point.x < rhs.point.x
            }

        for candidate in candidates.prefix(32) {
            guard let fallbackPath = path(from: startPoint, to: candidate.point) else {
                continue
            }
            return NavigationRoute(
                requestedDestination: requestedPoint,
                resolvedDestination: candidate.point,
                waypoints: fallbackPath
            )
        }
        return nil
    }

    /// 4-connected flood fill of passable cell centers reachable from `start`.
    private func reachableCellCenters(from start: CGPoint) -> [CGPoint] {
        let startCell = searchMap.cell(for: start)
        guard searchMap.contains(startCell),
              searchMap.isPassable(at: start, radius: agentProfile.radius) else {
            return []
        }

        var visited = Set<SearchMapCell>()
        var queue: [SearchMapCell] = [startCell]
        visited.insert(startCell)
        var centers: [CGPoint] = [searchMap.center(of: startCell)]
        let neighbors = [(1, 0), (0, 1), (-1, 0), (0, -1)]
        var index = 0

        while index < queue.count {
            let current = queue[index]
            index += 1
            for (dx, dy) in neighbors {
                let next = SearchMapCell(column: current.column + dx, row: current.row + dy)
                guard searchMap.contains(next), !visited.contains(next) else { continue }
                let point = searchMap.center(of: next)
                guard searchMap.isPassable(at: point, radius: agentProfile.radius) else {
                    continue
                }
                visited.insert(next)
                queue.append(next)
                centers.append(point)
            }
        }
        return centers
    }

    /// Legacy cell-radius overload used by existing tests (assumes ~10u cells).
    func route(
        from startPoint: CGPoint,
        to requestedPoint: CGPoint,
        maximumFallbackCellRadius: Int
    ) -> NavigationRoute? {
        let cellDiagonal = hypot(searchMap.cellSize.width, searchMap.cellSize.height)
        let worldRadius = CGFloat(maximumFallbackCellRadius) * cellDiagonal
        return route(
            from: startPoint,
            to: requestedPoint,
            maximumFallbackWorldRadius: worldRadius
        )
    }

    func path(from startPoint: CGPoint, to targetPoint: CGPoint) -> [CGPoint]? {
        pathFinder.findPath(
            from: startPoint,
            to: targetPoint,
            actorRadius: agentProfile.radius,
            minDistance: 0,
            flags: [.allowBumpableActors]
        )
    }

    /// Path that treats other actors as hard blockers (no bumping).
    func pathAvoidingActors(from startPoint: CGPoint, to targetPoint: CGPoint) -> [CGPoint]? {
        pathFinder.findPath(
            from: startPoint,
            to: targetPoint,
            actorRadius: agentProfile.radius,
            minDistance: 0,
            flags: [.actorsAreBlocking]
        )
    }

    /// Expand sparse authored anchors into a walkable polyline via Theta*
    /// between consecutive anchors. Blocked anchors snap to nearest walkable.
    func waypoints(visiting anchors: [CGPoint]) -> [CGPoint]? {
        guard !anchors.isEmpty else { return [] }
        if anchors.count == 1 {
            if let only = resolveWalkableAnchor(anchors[0]) {
                return [only]
            }
            return nil
        }

        var resolved: [CGPoint] = []
        resolved.reserveCapacity(anchors.count)
        for anchor in anchors {
            guard let point = resolveWalkableAnchor(anchor) else { return nil }
            if let last = resolved.last, distance(from: last, to: point) <= 0.25 {
                continue
            }
            resolved.append(point)
        }
        guard resolved.count >= 2 else { return resolved.isEmpty ? nil : resolved }

        var combined: [CGPoint] = [resolved[0]]
        for index in 1..<resolved.count {
            let from = combined[combined.count - 1]
            let to = resolved[index]
            guard let leg = path(from: from, to: to) else { return nil }
            if leg.isEmpty { continue }
            for point in leg {
                if let last = combined.last, distance(from: last, to: point) <= 0.25 {
                    continue
                }
                combined.append(point)
            }
        }
        return combined
    }

    /// Corrective repath from the actor's current position to an existing goal
    /// (BG:EE "Enhanced Path Search").
    func repath(from current: CGPoint, to destination: CGPoint) -> [CGPoint]? {
        path(from: current, to: destination)
    }

    // MARK: - Occupancy helpers

    func registerActor(
        id: String,
        kind: NavigationActorKind,
        at position: CGPoint,
        radius: CGFloat? = nil,
        isMoving: Bool = false,
        personalSpaceCells: Int = ActorLocomotionPacing.personalSpaceCells
    ) {
        occupancy.register(
            OccupyingActor(
                id: id,
                kind: kind,
                position: position,
                radius: radius ?? agentProfile.radius,
                isBumpable: !isMoving,
                isMoving: isMoving,
                personalSpaceCells: personalSpaceCells
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

    private func resolveWalkableAnchor(_ point: CGPoint) -> CGPoint? {
        if searchMap.isPassable(at: point, radius: agentProfile.radius) {
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
