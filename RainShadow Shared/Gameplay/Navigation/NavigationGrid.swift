import CoreGraphics

struct NavigationCell: Hashable {
    let column: Int
    let row: Int
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
    private let obstacles: [CGRect]
    private(set) var blocked: Set<NavigationCell> = []

    /// Compatibility initializer for ordinary screen-aligned grids and tests.
    convenience init(origin: CGPoint, columns: Int, rows: Int, cellSize: CGSize, obstacles: [CGRect]) {
        self.init(
            projection: .orthogonal(origin: origin, cellSize: cellSize),
            columns: columns,
            rows: rows,
            obstacles: obstacles
        )
    }

    init(projection: NavigationProjection, columns: Int, rows: Int, obstacles: [CGRect]) {
        precondition(columns > 0 && rows > 0)
        precondition(projection.tileSize.width > 0 && projection.tileSize.height > 0)
        self.projection = projection
        self.columns = columns
        self.rows = rows
        self.obstacles = obstacles

        for column in 0..<columns {
            for row in 0..<rows {
                let cell = NavigationCell(column: column, row: row)
                if obstacles.contains(where: { $0.contains(projection.point(for: cell)) }) {
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
        if isWalkable(targetCell), !isInsideObstacle(point) {
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

    /// Returns nil when no route exists. An empty route means the actor is
    /// already at the destination, which is intentionally distinct from failure.
    func path(from startPoint: CGPoint, to targetPoint: CGPoint) -> [CGPoint]? {
        guard !isInsideObstacle(startPoint), !isInsideObstacle(targetPoint) else { return nil }

        let start = projection.cell(for: startPoint)
        let goal = projection.cell(for: targetPoint)
        guard isWalkable(start), isWalkable(goal) else { return nil }
        if start == goal {
            return distance(from: startPoint, to: targetPoint) > 0.25 ? [targetPoint] : []
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
            guard isWalkable(cell), !isInsideObstacle(point) else { return false }

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

    private func heuristic(_ a: NavigationCell, _ b: NavigationCell) -> CGFloat {
        distance(from: projection.point(for: a), to: projection.point(for: b))
    }

    private func distance(from a: CGPoint, to b: CGPoint) -> CGFloat {
        hypot(a.x - b.x, a.y - b.y)
    }
}
