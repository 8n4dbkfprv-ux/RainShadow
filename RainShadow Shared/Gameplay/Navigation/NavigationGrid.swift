import CoreGraphics

struct NavigationCell: Hashable {
    let column: Int
    let row: Int
}

/// Ground-space clearance used while planning and smoothing a route. The
/// anisotropic footprint matches an isometric actor's contact ellipse more
/// closely than a large circle, which would close narrow north/south passages.
struct NavigationAgentProfile: Equatable {
    let halfWidth: CGFloat
    let halfHeight: CGFloat

    static let point = NavigationAgentProfile(halfWidth: 0, halfHeight: 0)
    /// A conservative personal-space core inside the 54×20 painted shadow. The
    /// authored office doorway is intentionally tighter than the full shadow,
    /// matching BG's practice of separating selection ellipse from path space.
    static let detective = NavigationAgentProfile(halfWidth: 16, halfHeight: 4)
    /// Office obstacle art already includes its floor-contact clearance. This
    /// small additional core is the largest margin that preserves the authored
    /// chair/door passage when segments are checked exactly.
    static let officeDetective = NavigationAgentProfile(halfWidth: 3, halfHeight: 0)

    init(halfWidth: CGFloat, halfHeight: CGFloat) {
        precondition(halfWidth >= 0 && halfHeight >= 0)
        self.halfWidth = halfWidth
        self.halfHeight = halfHeight
    }
}

struct NavigationRoute: Equatable {
    let requestedDestination: CGPoint
    let resolvedDestination: CGPoint
    let waypoints: [CGPoint]

    var destinationWasAdjusted: Bool {
        hypot(
            requestedDestination.x - resolvedDestination.x,
            requestedDestination.y - resolvedDestination.y
        ) > 0.25
    }
}

/// Converts between authored navigation cells and world-space ground points.
/// The dimetric variant is the room's 2:1 isometric projection; keeping this
/// transform here prevents input, A*, and actor movement from disagreeing.
struct NavigationProjection {
    enum Kind: Equatable {
        case orthogonal
        case dimetric
    }

    let kind: Kind
    let origin: CGPoint
    let tileSize: CGSize

    static func orthogonal(origin: CGPoint, cellSize: CGSize) -> NavigationProjection {
        NavigationProjection(kind: .orthogonal, origin: origin, tileSize: cellSize)
    }

    static func dimetric(origin: CGPoint, tileSize: CGSize) -> NavigationProjection {
        NavigationProjection(kind: .dimetric, origin: origin, tileSize: tileSize)
    }

    func point(for cell: NavigationCell) -> CGPoint {
        switch kind {
        case .orthogonal:
            CGPoint(
                x: origin.x + (CGFloat(cell.column) + 0.5) * tileSize.width,
                y: origin.y + (CGFloat(cell.row) + 0.5) * tileSize.height
            )
        case .dimetric:
            CGPoint(
                x: origin.x + CGFloat(cell.column - cell.row) * tileSize.width * 0.5,
                y: origin.y + CGFloat(cell.column + cell.row) * tileSize.height * 0.5
            )
        }
    }

    func fractionalCell(for point: CGPoint) -> CGPoint {
        switch kind {
        case .orthogonal:
            return CGPoint(
                x: (point.x - origin.x) / tileSize.width - 0.5,
                y: (point.y - origin.y) / tileSize.height - 0.5
            )
        case .dimetric:
            let projectedX = (point.x - origin.x) / (tileSize.width * 0.5)
            let projectedY = (point.y - origin.y) / (tileSize.height * 0.5)
            return CGPoint(
                x: (projectedX + projectedY) * 0.5,
                y: (projectedY - projectedX) * 0.5
            )
        }
    }

    func cell(for point: CGPoint) -> NavigationCell {
        let fractional = fractionalCell(for: point)
        switch kind {
        case .orthogonal:
            return NavigationCell(
                column: Int(floor(fractional.x + 0.5)),
                row: Int(floor(fractional.y + 0.5))
            )
        case .dimetric:
            return NavigationCell(
                column: Int(fractional.x.rounded()),
                row: Int(fractional.y.rounded())
            )
        }
    }

    var samplingStep: CGFloat {
        switch kind {
        case .orthogonal:
            return min(tileSize.width, tileSize.height) * 0.25
        case .dimetric:
            let axisStep = hypot(tileSize.width * 0.5, tileSize.height * 0.5)
            return min(axisStep, tileSize.height) * 0.25
        }
    }
}

final class NavigationGrid {
    let projection: NavigationProjection
    let columns: Int
    let rows: Int
    let agentProfile: NavigationAgentProfile
    private let obstacles: [CGRect]
    private let worldBounds: CGRect?
    private(set) var blocked: Set<NavigationCell> = []

    static let defaultDestinationSearchRadius = 8

    /// Compatibility initializer for ordinary screen-aligned grids and tests.
    convenience init(
        origin: CGPoint,
        columns: Int,
        rows: Int,
        cellSize: CGSize,
        obstacles: [CGRect],
        agentProfile: NavigationAgentProfile = .point,
        worldBounds: CGRect? = nil
    ) {
        self.init(
            projection: .orthogonal(origin: origin, cellSize: cellSize),
            columns: columns,
            rows: rows,
            obstacles: obstacles,
            agentProfile: agentProfile,
            worldBounds: worldBounds
        )
    }

    init(
        projection: NavigationProjection,
        columns: Int,
        rows: Int,
        obstacles: [CGRect],
        agentProfile: NavigationAgentProfile = .point,
        worldBounds: CGRect? = nil
    ) {
        precondition(columns > 0 && rows > 0)
        precondition(projection.tileSize.width > 0 && projection.tileSize.height > 0)
        if let worldBounds {
            precondition(!worldBounds.isNull && !worldBounds.isEmpty)
        }
        self.projection = projection
        self.columns = columns
        self.rows = rows
        self.agentProfile = agentProfile
        self.worldBounds = worldBounds?.standardized
        self.obstacles = obstacles.map {
            $0.insetBy(dx: -agentProfile.halfWidth, dy: -agentProfile.halfHeight)
        }

        for column in 0..<columns {
            for row in 0..<rows {
                let cell = NavigationCell(column: column, row: row)
                if self.obstacles.contains(where: { $0.contains(projection.point(for: cell)) }) {
                    blocked.insert(cell)
                }
            }
        }
    }

    /// Resolves a tap to the exact ground point when possible, otherwise to the
    /// closest walkable projected cell. Unlike the old five-ring search, this
    /// works beside large props and at the edge of the room.
    func nearestWalkablePoint(to point: CGPoint) -> CGPoint? {
        let targetCell = projection.cell(for: point)
        if fitsWithinNavigationBounds(point),
           isWalkable(targetCell),
           !isInsideObstacle(point) {
            return point
        }

        var best: (distanceSquared: CGFloat, point: CGPoint)?
        for column in 0..<columns {
            for row in 0..<rows {
                let cell = NavigationCell(column: column, row: row)
                guard isWalkable(cell) else { continue }
                let candidate = projection.point(for: cell)
                let dx = candidate.x - point.x
                let dy = candidate.y - point.y
                let distanceSquared = dx * dx + dy * dy
                if best == nil || distanceSquared < best!.distanceSquared {
                    best = (distanceSquared, candidate)
                }
            }
        }
        return best?.point
    }

    /// Produces the exact route when possible. If the requested point is blocked
    /// or belongs to a disconnected component, only a bounded ring around that
    /// point is considered and the nearest *reachable* cell is used. This keeps
    /// wall clicks responsive without selecting a point on the far side of a
    /// sealed room.
    func route(
        from startPoint: CGPoint,
        to requestedPoint: CGPoint,
        maximumFallbackCellRadius: Int = NavigationGrid.defaultDestinationSearchRadius
    ) -> NavigationRoute? {
        if let exactPath = path(from: startPoint, to: requestedPoint) {
            return NavigationRoute(
                requestedDestination: requestedPoint,
                resolvedDestination: requestedPoint,
                waypoints: exactPath
            )
        }

        guard maximumFallbackCellRadius >= 0,
              fitsWithinNavigationBounds(startPoint),
              !isInsideObstacle(startPoint),
              isWalkable(projection.cell(for: startPoint)) else {
            return nil
        }

        let targetCell = projection.cell(for: requestedPoint)
        let reachable = reachableCells(from: projection.cell(for: startPoint))
        let candidates = reachable
            .filter { cell in
                max(
                    abs(cell.column - targetCell.column),
                    abs(cell.row - targetCell.row)
                ) <= maximumFallbackCellRadius
            }
            .map { cell in (cell: cell, point: projection.point(for: cell)) }
            .sorted { lhs, rhs in
                let lhsDistance = squaredDistance(lhs.point, requestedPoint)
                let rhsDistance = squaredDistance(rhs.point, requestedPoint)
                if lhsDistance != rhsDistance { return lhsDistance < rhsDistance }
                if lhs.cell.row != rhs.cell.row { return lhs.cell.row < rhs.cell.row }
                return lhs.cell.column < rhs.cell.column
            }

        for candidate in candidates {
            guard let fallbackPath = path(from: startPoint, to: candidate.point) else { continue }
            return NavigationRoute(
                requestedDestination: requestedPoint,
                resolvedDestination: candidate.point,
                waypoints: fallbackPath
            )
        }
        return nil
    }

    /// Expands a sparse authored anchor list into a walkable polyline by A*
    /// between consecutive anchors. Blocked anchors snap to the nearest
    /// walkable ground point. Returns nil if any leg cannot be routed without
    /// crossing obstacles (walls, furniture, partition).
    ///
    /// Used for scripted client entrance/exit so linear SKAction moves never
    /// cut through architecture — each micro-segment is already clearance-tested.
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
            if leg.isEmpty {
                continue
            }
            for point in leg {
                if let last = combined.last, distance(from: last, to: point) <= 0.25 {
                    continue
                }
                combined.append(point)
            }
        }
        return combined
    }

    private func resolveWalkableAnchor(_ point: CGPoint) -> CGPoint? {
        if fitsWithinNavigationBounds(point),
           !isInsideObstacle(point),
           isWalkable(projection.cell(for: point)) {
            return point
        }
        return nearestWalkablePoint(to: point)
    }

    /// Returns nil when no route exists. An empty route means the actor is
    /// already at the destination, which is intentionally distinct from failure.
    func path(from startPoint: CGPoint, to targetPoint: CGPoint) -> [CGPoint]? {
        guard fitsWithinNavigationBounds(startPoint),
              fitsWithinNavigationBounds(targetPoint),
              !isInsideObstacle(startPoint),
              !isInsideObstacle(targetPoint) else {
            return nil
        }

        let start = projection.cell(for: startPoint)
        let goal = projection.cell(for: targetPoint)
        guard isWalkable(start), isWalkable(goal) else { return nil }
        if start == goal {
            let targetDistance = distance(from: startPoint, to: targetPoint)
            guard targetDistance <= 0.25 || canTravelDirectly(from: startPoint, to: targetPoint) else {
                return nil
            }
            return targetDistance > 0.25 ? [targetPoint] : []
        }

        var open: Set<NavigationCell> = [start]
        var closed: Set<NavigationCell> = []
        var cameFrom: [NavigationCell: NavigationCell] = [:]
        var gScore: [NavigationCell: CGFloat] = [start: 0]
        var fScore: [NavigationCell: CGFloat] = [start: heuristic(start, goal)]

        while let current = open.min(by: { lhs, rhs in
            let lhsF = fScore[lhs, default: .greatestFiniteMagnitude]
            let rhsF = fScore[rhs, default: .greatestFiniteMagnitude]
            if lhsF != rhsF { return lhsF < rhsF }
            let lhsH = heuristic(lhs, goal)
            let rhsH = heuristic(rhs, goal)
            if lhsH != rhsH { return lhsH < rhsH }
            if lhs.row != rhs.row { return lhs.row < rhs.row }
            return lhs.column < rhs.column
        }) {
            if current == goal {
                return makeSmoothedPath(
                    from: startPoint,
                    to: targetPoint,
                    cells: reconstructPath(endingAt: current, cameFrom: cameFrom)
                )
            }

            open.remove(current)
            closed.insert(current)
            for neighbor in neighbors(of: current) where !closed.contains(neighbor) {
                guard canTravelDirectly(
                    from: projection.point(for: current),
                    to: projection.point(for: neighbor)
                ) else { continue }
                let tentative = gScore[current, default: .greatestFiniteMagnitude]
                    + movementCost(from: current, to: neighbor)
                if tentative < gScore[neighbor, default: .greatestFiniteMagnitude] {
                    cameFrom[neighbor] = current
                    gScore[neighbor] = tentative
                    fScore[neighbor] = tentative + heuristic(neighbor, goal)
                    open.insert(neighbor)
                }
            }
        }
        return nil
    }

    private func reconstructPath(
        endingAt goal: NavigationCell,
        cameFrom: [NavigationCell: NavigationCell]
    ) -> [NavigationCell] {
        var cells: [NavigationCell] = [goal]
        var cursor = goal
        while let previous = cameFrom[cursor] {
            cells.append(previous)
            cursor = previous
        }
        return cells.reversed()
    }

    private func makeSmoothedPath(
        from startPoint: CGPoint,
        to targetPoint: CGPoint,
        cells: [NavigationCell]
    ) -> [CGPoint]? {
        var candidates = cells.dropFirst().map(projection.point(for:))
        if candidates.isEmpty || distance(from: candidates.last!, to: targetPoint) > 0.25 {
            candidates.append(targetPoint)
        } else {
            candidates[candidates.count - 1] = targetPoint
        }

        var result: [CGPoint] = []
        var anchor = startPoint
        var index = 0
        while index < candidates.count {
            var furthest: Int?
            for candidateIndex in index..<candidates.count {
                if canTravelDirectly(from: anchor, to: candidates[candidateIndex]) {
                    furthest = candidateIndex
                } else {
                    break
                }
            }
            guard let furthest else { return nil }
            let waypoint = candidates[furthest]
            result.append(waypoint)
            anchor = waypoint
            index = furthest + 1
        }
        return result
    }

    private func canTravelDirectly(from start: CGPoint, to end: CGPoint) -> Bool {
        guard fitsWithinNavigationBounds(start),
              fitsWithinNavigationBounds(end),
              !obstacles.contains(where: {
                  segmentIntersectsInterior(from: start, to: end, of: $0)
              }) else {
            return false
        }

        let length = distance(from: start, to: end)
        let samples = max(1, Int(ceil(length / max(0.5, projection.samplingStep))))
        var previousCell = projection.cell(for: start)

        for sample in 1...samples {
            let progress = CGFloat(sample) / CGFloat(samples)
            let point = CGPoint(
                x: start.x + (end.x - start.x) * progress,
                y: start.y + (end.y - start.y) * progress
            )
            let cell = projection.cell(for: point)
            guard fitsWithinNavigationBounds(point),
                  isWalkable(cell),
                  !isInsideObstacle(point) else {
                return false
            }

            let dx = cell.column - previousCell.column
            let dy = cell.row - previousCell.row
            if dx != 0 && dy != 0 {
                let horizontal = NavigationCell(column: previousCell.column + dx, row: previousCell.row)
                let vertical = NavigationCell(column: previousCell.column, row: previousCell.row + dy)
                guard isWalkable(horizontal), isWalkable(vertical) else { return false }
            }
            previousCell = cell
        }
        return true
    }

    private func isInsideObstacle(_ point: CGPoint) -> Bool {
        obstacles.contains { $0.contains(point) }
    }

    private func isWalkable(_ cell: NavigationCell) -> Bool {
        cell.column >= 0 && cell.column < columns
            && cell.row >= 0 && cell.row < rows
            && !blocked.contains(cell)
            && fitsWithinNavigationBounds(projection.point(for: cell))
    }

    /// The search map boundary is a solid just like an obstacle. Checking the
    /// four corners of the contact footprint works for both the orthogonal city
    /// grid and the office's convex dimetric grid polygon.
    private func fitsWithinNavigationBounds(_ point: CGPoint) -> Bool {
        let offsets: [CGPoint]
        if agentProfile == .point {
            offsets = [.zero]
        } else {
            offsets = [
                CGPoint(x: -agentProfile.halfWidth, y: -agentProfile.halfHeight),
                CGPoint(x: agentProfile.halfWidth, y: -agentProfile.halfHeight),
                CGPoint(x: -agentProfile.halfWidth, y: agentProfile.halfHeight),
                CGPoint(x: agentProfile.halfWidth, y: agentProfile.halfHeight)
            ]
        }

        let epsilon: CGFloat = 0.001
        for offset in offsets {
            let sample = CGPoint(x: point.x + offset.x, y: point.y + offset.y)
            if let worldBounds {
                guard sample.x >= worldBounds.minX - epsilon,
                      sample.x <= worldBounds.maxX + epsilon,
                      sample.y >= worldBounds.minY - epsilon,
                      sample.y <= worldBounds.maxY + epsilon else {
                    return false
                }
            }

            let fractional = projection.fractionalCell(for: sample)
            guard fractional.x >= -0.5 - epsilon,
                  fractional.x <= CGFloat(columns) - 0.5 + epsilon,
                  fractional.y >= -0.5 - epsilon,
                  fractional.y <= CGFloat(rows) - 0.5 + epsilon else {
                return false
            }
        }
        return true
    }

    /// Exact segment/rectangle clipping prevents narrow solids from falling
    /// between clearance samples. The tiny inset preserves the existing rule
    /// that merely touching an authored obstacle edge remains legal.
    private func segmentIntersectsInterior(
        from start: CGPoint,
        to end: CGPoint,
        of obstacle: CGRect
    ) -> Bool {
        let rect = obstacle.standardized
        guard rect.width > 0, rect.height > 0 else { return false }
        let interior = rect.insetBy(
            dx: min(0.001, rect.width * 0.25),
            dy: min(0.001, rect.height * 0.25)
        )
        let deltaX = end.x - start.x
        let deltaY = end.y - start.y
        var minimumT: CGFloat = 0
        var maximumT: CGFloat = 1

        func clip(origin: CGFloat, delta: CGFloat, lower: CGFloat, upper: CGFloat) -> Bool {
            if abs(delta) <= CGFloat.ulpOfOne {
                return origin >= lower && origin <= upper
            }
            let first = (lower - origin) / delta
            let second = (upper - origin) / delta
            minimumT = max(minimumT, min(first, second))
            maximumT = min(maximumT, max(first, second))
            return minimumT <= maximumT
        }

        return clip(origin: start.x, delta: deltaX, lower: interior.minX, upper: interior.maxX)
            && clip(origin: start.y, delta: deltaY, lower: interior.minY, upper: interior.maxY)
    }

    private func reachableCells(from start: NavigationCell) -> Set<NavigationCell> {
        guard isWalkable(start) else { return [] }
        var visited: Set<NavigationCell> = [start]
        var queue: [NavigationCell] = [start]
        var index = 0

        while index < queue.count {
            let current = queue[index]
            index += 1
            for neighbor in neighbors(of: current) where !visited.contains(neighbor) {
                guard canTravelDirectly(
                    from: projection.point(for: current),
                    to: projection.point(for: neighbor)
                ) else { continue }
                visited.insert(neighbor)
                queue.append(neighbor)
            }
        }
        return visited
    }

    private func neighbors(of cell: NavigationCell) -> [NavigationCell] {
        var result: [NavigationCell] = []
        for dx in -1...1 {
            for dy in -1...1 where !(dx == 0 && dy == 0) {
                let next = NavigationCell(column: cell.column + dx, row: cell.row + dy)
                guard isWalkable(next) else { continue }
                if dx != 0 && dy != 0 {
                    let horizontal = NavigationCell(column: cell.column + dx, row: cell.row)
                    let vertical = NavigationCell(column: cell.column, row: cell.row + dy)
                    guard isWalkable(horizontal), isWalkable(vertical) else { continue }
                }
                result.append(next)
            }
        }
        return result
    }

    private func movementCost(from start: NavigationCell, to end: NavigationCell) -> CGFloat {
        distance(from: projection.point(for: start), to: projection.point(for: end))
    }

    /// Admissible estimate in the same projected-world metric as `movementCost`.
    /// Euclidean between cell centers stays consistent with step costs; a pure
    /// grid-index octile heuristic would be dimensionally mismatched here.
    private func heuristic(_ a: NavigationCell, _ b: NavigationCell) -> CGFloat {
        distance(from: projection.point(for: a), to: projection.point(for: b))
    }

    private func distance(from a: CGPoint, to b: CGPoint) -> CGFloat {
        hypot(a.x - b.x, a.y - b.y)
    }

    private func squaredDistance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        let dx = a.x - b.x
        let dy = a.y - b.y
        return dx * dx + dy * dy
    }
}
