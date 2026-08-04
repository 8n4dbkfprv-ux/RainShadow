import CoreGraphics
import Foundation

/// Ground-space clearance used while planning a route. Matches BG's practice of
/// separating selection ellipse from path space; radius is taken as the larger
/// half-extent so anisotropic footprints still clear narrow gaps.
struct NavigationAgentProfile: Equatable, Sendable {
    let halfWidth: CGFloat
    let halfHeight: CGFloat

    static let point = NavigationAgentProfile(halfWidth: 0, halfHeight: 0)
    /// City / open-world detective personal-space core.
    static let detective = NavigationAgentProfile(halfWidth: 16, halfHeight: 4)
    /// Office obstacle art already includes floor-contact clearance.
    static let officeDetective = NavigationAgentProfile(halfWidth: 3, halfHeight: 0)
    /// Client (Lila) uses the same office clearance as the detective.
    static let officeClient = NavigationAgentProfile(halfWidth: 3, halfHeight: 0)

    init(halfWidth: CGFloat, halfHeight: CGFloat) {
        precondition(halfWidth >= 0 && halfHeight >= 0)
        self.halfWidth = halfWidth
        self.halfHeight = halfHeight
    }

    /// Circle radius used for BG-style radius queries on the search map.
    var radius: CGFloat {
        max(halfWidth, halfHeight)
    }
}

struct NavigationRoute: Equatable, Sendable {
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

struct PathFinderFlags: OptionSet, Sendable {
    let rawValue: Int

    static let actorsAreBlocking = PathFinderFlags(rawValue: 1 << 0)
    /// Prefer bumpable actors as traversable (default BG:EE behaviour).
    static let allowBumpableActors = PathFinderFlags(rawValue: 1 << 1)
}

/// Lazy Theta* pathfinder ported from GemRB `Map::FindPath`.
///
/// Expands 4-connected on the search map, shortcuts with world-resolution LOS
/// (any-angle movement), uses a weighted heuristic with a cross-product
/// tie-breaker, and caps expansion with a BG-style node budget.
struct PathFinder {
    /// GemRB default heuristic weight — finds slightly sub-optimal paths faster.
    static let heuristicWeight: CGFloat = 1.5
    /// BG:EE "Path Search Nodes" default.
    static let defaultMaxNodes = 32_000

    let searchMap: SearchMap
    var maxNodes: Int

    init(searchMap: SearchMap, maxNodes: Int = PathFinder.defaultMaxNodes) {
        self.searchMap = searchMap
        self.maxNodes = max(1, maxNodes)
    }

    /// Returns nil when no route exists. An empty waypoint list means the actor
    /// is already at the destination (distinct from failure).
    func findPath(
        from startPoint: CGPoint,
        to targetPoint: CGPoint,
        actorRadius: CGFloat = 0,
        minDistance: CGFloat = 0,
        flags: PathFinderFlags = [.allowBumpableActors]
    ) -> [CGPoint]? {
        let treatActorsAsBlocking = flags.contains(.actorsAreBlocking)
            && !flags.contains(.allowBumpableActors)

        // Exact pathfinding never relocates the goal — that is `route()` /
        // `adjustPositionDirected` territory (BG AdjustPosition). Out-of-bounds
        // targets fail unless `minDistance` allows stopping short of them.
        guard searchMap.contains(startPoint) else { return nil }
        guard searchMap.isPassable(
            at: startPoint,
            radius: actorRadius,
            treatActorsAsBlocking: treatActorsAsBlocking
        ) else {
            return nil
        }

        let destination = targetPoint
        let targetPassable = searchMap.contains(targetPoint)
            && searchMap.isPassable(
                at: targetPoint,
                radius: actorRadius,
                treatActorsAsBlocking: treatActorsAsBlocking
            )
        if !targetPassable && minDistance <= 0 {
            return nil
        }

        if targetPassable,
           hypot(destination.x - startPoint.x, destination.y - startPoint.y) <= 0.25 {
            return []
        }

        let startCell = searchMap.cell(for: startPoint)
        var goalCell = searchMap.cell(for: destination)
        if !searchMap.contains(goalCell) {
            // Clamp goal to the nearest in-bounds cell for expansion; arrival is
            // still governed by minDistance against the original target.
            guard minDistance > 0,
                  let nearest = nearestPassablePoint(
                    to: destination,
                    actorRadius: actorRadius,
                    treatActorsAsBlocking: treatActorsAsBlocking
                  ) else { return nil }
            goalCell = searchMap.cell(for: nearest)
        }
        guard searchMap.contains(startCell), searchMap.contains(goalCell) else { return nil }

        if startCell == goalCell {
            if searchMap.isWalkableLine(
                from: startPoint,
                to: destination,
                radius: actorRadius,
                treatActorsAsBlocking: treatActorsAsBlocking
            ) {
                return hypot(destination.x - startPoint.x, destination.y - startPoint.y) > 0.25
                    ? [destination]
                    : []
            }
            return nil
        }

        let mapSize = searchMap.cellCount
        var isClosed = [Bool](repeating: false, count: mapSize)
        var parents = [CGPoint?](repeating: nil, count: mapSize)
        var distFromStart = [CGFloat](repeating: .greatestFiniteMagnitude, count: mapSize)

        let startIndex = cellIndex(startCell)
        distFromStart[startIndex] = 0
        parents[startIndex] = startPoint

        var open = BinaryHeap()
        open.push(startPoint, cost: 0)

        let dxCross = goalCell.column - startCell.column
        let dyCross = goalCell.row - startCell.row
        let squaredMinDist = minDistance * minDistance
        var foundDestination = destination
        var found = false
        var expansions = 0

        let neighbors: [(Int, Int)] = [(1, 0), (0, 1), (-1, 0), (0, -1)]

        while let currentPoint = open.pop() {
            expansions += 1
            if expansions > maxNodes { break }

            let currentCell = searchMap.cell(for: currentPoint)
            let currentIndex = cellIndex(currentCell)
            guard searchMap.contains(currentCell), parents[currentIndex] != nil else { continue }

            if currentCell == goalCell {
                // Prefer the exact requested destination when the goal cell is reached.
                foundDestination = destination
                found = true
                break
            }

            if minDistance > 0,
               parents[currentIndex] != nil,
               squaredDistance(currentPoint, targetPoint) <= squaredMinDist {
                foundDestination = currentPoint
                goalCell = currentCell
                found = true
                break
            }

            if isClosed[currentIndex] { continue }
            isClosed[currentIndex] = true

            for (dx, dy) in neighbors {
                let childCell = SearchMapCell(
                    column: currentCell.column + dx,
                    row: currentCell.row + dy
                )
                guard searchMap.contains(childCell) else { continue }
                let childIndex = cellIndex(childCell)
                if isClosed[childIndex] { continue }

                let childPoint = searchMap.center(of: childCell)
                guard searchMap.isPassable(
                    at: childPoint,
                    radius: actorRadius,
                    treatActorsAsBlocking: treatActorsAsBlocking
                ) else { continue }

                // Lazy Theta*: try parent → child LOS shortcut first.
                let parentPoint = parents[currentIndex] ?? currentPoint
                let parentCell = searchMap.cell(for: parentPoint)
                let parentIndex = cellIndex(parentCell)
                let oldDist = distFromStart[childIndex]

                var newDist = distFromStart[parentIndex]
                    + cellDistance(parentCell, childCell)
                var newParent = parentPoint

                if newDist < oldDist {
                    if searchMap.isWalkableLine(
                        from: parentPoint,
                        to: childPoint,
                        radius: actorRadius,
                        treatActorsAsBlocking: treatActorsAsBlocking
                    ) {
                        parents[childIndex] = newParent
                        distFromStart[childIndex] = newDist
                    } else {
                        // Fall back to A*: best already-closed neighbour.
                        distFromStart[childIndex] = .greatestFiniteMagnitude
                        for (ndx, ndy) in neighbors {
                            let visCell = SearchMapCell(
                                column: childCell.column + ndx,
                                row: childCell.row + ndy
                            )
                            guard searchMap.contains(visCell) else { continue }
                            let visIndex = cellIndex(visCell)
                            guard isClosed[visIndex] else { continue }
                            let candidateDist = distFromStart[visIndex]
                                + cellDistance(visCell, childCell)
                            if candidateDist < distFromStart[childIndex] {
                                distFromStart[childIndex] = candidateDist
                                parents[childIndex] = searchMap.center(of: visCell)
                                newParent = parents[childIndex]!
                                newDist = candidateDist
                            }
                        }
                        if distFromStart[childIndex] >= oldDist { continue }
                    }
                } else {
                    continue
                }

                let heuristic = weightedHeuristic(
                    from: childCell,
                    to: goalCell,
                    dxCross: dxCross,
                    dyCross: dyCross
                )
                open.push(childPoint, cost: distFromStart[childIndex] + heuristic)
            }
        }

        guard found else { return nil }
        return reconstructPath(
            from: startPoint,
            to: foundDestination,
            parents: parents
        )
    }

    /// Walk the goal back toward the caller until a passable fit is found
    /// (GemRB `AdjustPositionDirected`).
    func adjustPositionDirected(
        from source: CGPoint,
        toward goal: CGPoint,
        actorRadius: CGFloat,
        minDistance: CGFloat = 0,
        treatActorsAsBlocking: Bool = false,
        maxRadiusCells: Int = 24
    ) -> CGPoint? {
        let dx = source.x - goal.x
        let dy = source.y - goal.y
        let length = hypot(dx, dy)
        let stepX: CGFloat
        let stepY: CGFloat
        if length <= CGFloat.ulpOfOne {
            stepX = searchMap.cellSize.width
            stepY = 0
        } else {
            stepX = dx / length * searchMap.cellSize.width
            stepY = dy / length * searchMap.cellSize.height
        }

        for ring in 0...maxRadiusCells {
            let candidate = CGPoint(
                x: goal.x + stepX * CGFloat(ring),
                y: goal.y + stepY * CGFloat(ring)
            )
            if minDistance > 0, squaredDistance(candidate, goal) < minDistance * minDistance {
                continue
            }
            guard searchMap.contains(candidate),
                  searchMap.isPassable(
                    at: candidate,
                    radius: actorRadius,
                    treatActorsAsBlocking: treatActorsAsBlocking
                  ) else {
                continue
            }
            return candidate
        }
        return nearestPassablePoint(
            to: goal,
            actorRadius: actorRadius,
            treatActorsAsBlocking: treatActorsAsBlocking
        )
    }

    func nearestPassablePoint(
        to point: CGPoint,
        actorRadius: CGFloat = 0,
        treatActorsAsBlocking: Bool = false
    ) -> CGPoint? {
        if searchMap.isPassable(
            at: point,
            radius: actorRadius,
            treatActorsAsBlocking: treatActorsAsBlocking
        ) {
            return point
        }

        var best: (distanceSquared: CGFloat, point: CGPoint)?
        for column in 0..<searchMap.columns {
            for row in 0..<searchMap.rows {
                let cell = SearchMapCell(column: column, row: row)
                let candidate = searchMap.center(of: cell)
                guard searchMap.isPassable(
                    at: candidate,
                    radius: actorRadius,
                    treatActorsAsBlocking: treatActorsAsBlocking
                ) else { continue }
                let distanceSquared = squaredDistance(candidate, point)
                if best == nil || distanceSquared < best!.distanceSquared {
                    best = (distanceSquared, candidate)
                }
            }
        }
        return best?.point
    }

    // MARK: - Private

    private func cellIndex(_ cell: SearchMapCell) -> Int {
        cell.row * searchMap.columns + cell.column
    }

    private func cellDistance(_ a: SearchMapCell, _ b: SearchMapCell) -> CGFloat {
        hypot(
            CGFloat(a.column - b.column) * searchMap.cellSize.width,
            CGFloat(a.row - b.row) * searchMap.cellSize.height
        )
    }

    private func weightedHeuristic(
        from cell: SearchMapCell,
        to goal: SearchMapCell,
        dxCross: Int,
        dyCross: Int
    ) -> CGFloat {
        let xDist = CGFloat(cell.column - goal.column)
        let yDist = CGFloat(cell.row - goal.row)
        let crossProduct = abs(xDist * CGFloat(dyCross) - yDist * CGFloat(dxCross)) / 8
        let distance = hypot(
            xDist * searchMap.cellSize.width,
            yDist * searchMap.cellSize.height
        )
        return Self.heuristicWeight * (distance + crossProduct)
    }

    private func reconstructPath(
        from start: CGPoint,
        to destination: CGPoint,
        parents: [CGPoint?]
    ) -> [CGPoint] {
        var points: [CGPoint] = [destination]
        var current = destination
        var guardCounter = 0
        while guardCounter < searchMap.cellCount {
            guardCounter += 1
            let cell = searchMap.cell(for: current)
            guard searchMap.contains(cell), let parent = parents[cellIndex(cell)] else { break }
            if hypot(parent.x - current.x, parent.y - current.y) <= 0.25 { break }
            if hypot(parent.x - start.x, parent.y - start.y) <= 0.25 {
                break
            }
            points.append(parent)
            current = parent
        }
        points.reverse()
        if let last = points.last, hypot(last.x - destination.x, last.y - destination.y) > 0.25 {
            points.append(destination)
        } else if !points.isEmpty {
            points[points.count - 1] = destination
        }
        // Drop the start if it was prepended as a parent.
        if let first = points.first, hypot(first.x - start.x, first.y - start.y) <= 0.25 {
            points.removeFirst()
        }
        return points
    }

    private func squaredDistance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        let dx = a.x - b.x
        let dy = a.y - b.y
        return dx * dx + dy * dy
    }
}

/// Min-heap open set for Theta* (replaces GemRB's bucket priority queue).
private struct BinaryHeap {
    private var storage: [(point: CGPoint, cost: CGFloat)] = []

    mutating func push(_ point: CGPoint, cost: CGFloat) {
        storage.append((point, cost))
        siftUp(storage.count - 1)
    }

    mutating func pop() -> CGPoint? {
        guard let first = storage.first else { return nil }
        if storage.count == 1 {
            storage.removeLast()
            return first.point
        }
        storage[0] = storage.removeLast()
        siftDown(0)
        return first.point
    }

    private mutating func siftUp(_ index: Int) {
        var child = index
        while child > 0 {
            let parent = (child - 1) / 2
            if storage[child].cost >= storage[parent].cost { break }
            storage.swapAt(child, parent)
            child = parent
        }
    }

    private mutating func siftDown(_ index: Int) {
        var parent = index
        while true {
            let left = parent * 2 + 1
            let right = left + 1
            var smallest = parent
            if left < storage.count, storage[left].cost < storage[smallest].cost {
                smallest = left
            }
            if right < storage.count, storage[right].cost < storage[smallest].cost {
                smallest = right
            }
            if smallest == parent { break }
            storage.swapAt(parent, smallest)
            parent = smallest
        }
    }
}
