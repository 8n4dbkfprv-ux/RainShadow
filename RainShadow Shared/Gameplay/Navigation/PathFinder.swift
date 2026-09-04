import CoreGraphics
import Foundation

/// Ground-space clearance used while planning a route.
///
/// The engine carries one integer, `personal_space`, read out of BG:EE's own
/// animation data, and derives every clearance from it: the stamp is a disc of
/// `personal_space - 1` cells, the test a disc of `personal_space - 2`. RainShadow
/// keeps that as `circleSize`.
///
/// `halfWidth` / `halfHeight` survive alongside it, but they no longer reach the
/// pathfinder. They are persisted in `AreaDefinition`, they derive `circleSize`
/// when one is not given, and QA still measures with them — routing asks the
/// raster and nothing else, which is the engine's arrangement. `SearchMap`
/// rasterises conservatively so the raster can carry that weight; see
/// `Documentation/PathfindingSystem.md`.
struct NavigationAgentProfile: Equatable, Sendable {
    let halfWidth: CGFloat
    let halfHeight: CGFloat
    /// `personal_space` in search-map cells (GemRB `Selectable::circleSize`).
    let circleSize: Int

    static let point = NavigationAgentProfile(halfWidth: 0, halfHeight: 0, circleSize: 1)
    /// City / open-world detective personal-space core.
    static let detective = NavigationAgentProfile(halfWidth: 16, halfHeight: 4)
    /// Office obstacle art already includes floor-contact clearance.
    static let officeDetective = NavigationAgentProfile(halfWidth: 3, halfHeight: 0)
    /// Client (Lila) uses the same office clearance as the detective.
    static let officeClient = NavigationAgentProfile(halfWidth: 3, halfHeight: 0)

    init(
        halfWidth: CGFloat,
        halfHeight: CGFloat,
        circleSize: Int? = nil
    ) {
        precondition(halfWidth >= 0 && halfHeight >= 0)
        self.halfWidth = halfWidth
        self.halfHeight = halfHeight
        self.circleSize = circleSize ?? Self.circleSize(forRadius: max(halfWidth, halfHeight))
        precondition(self.circleSize >= 1)
    }

    /// The engine `circleSize` whose clearance disc covers a world radius.
    ///
    /// `GetBlockedInRadiusTile` tests a disc of `size - 2` **cells**, so the
    /// smallest meaningful size is 2 (a single cell) and each further cell of
    /// reach costs one more.
    ///
    /// This is deliberately *not* `personalSpaceCells`. That number is derived
    /// for actor-vs-actor spacing and is carried on `OccupyingActor`; routing it
    /// into static clearance as well would replace a tuned 3-unit office
    /// footprint with a 32-unit disc and seal the room. BG can use one number
    /// for both because its solids are authored at cell resolution; ours are
    /// world-space rectangles an order of magnitude finer.
    static func circleSize(forRadius radius: CGFloat) -> Int {
        Int((radius / SearchMap.defaultCellSize.width).rounded()) + 2
    }

    /// Circle radius used for world-space geometry queries.
    var radius: CGFloat {
        max(halfWidth, halfHeight)
    }
}

struct NavigationRoute: Equatable, Sendable {
    let requestedDestination: CGPoint
    let resolvedDestination: CGPoint
    let waypoints: [CGPoint]
    /// Whether the search landed in a **different search cell** than the one
    /// asked for.
    ///
    /// A cell is the engine's resolution of a destination: `FindPath` terminates
    /// on the search node inside the goal cell (`nmptDest = nmptCurrent`), and
    /// that node carries the caller's own sub-cell offset rather than the
    /// requested point's. So a route that ends a few units off the click is not
    /// a snap — it is the grid. Only a different cell means the goal actually
    /// moved, which is what `AdjustPositionDirected` does.
    let destinationWasAdjusted: Bool
}

/// GemRB's pathfinding flags (`core/PathFinder.h`), values included.
struct PathFinderFlags: OptionSet, Sendable {
    let rawValue: Int

    /// Require line of sight when stopping short of a goal via `minDistance`.
    static let sight = PathFinderFlags(rawValue: 1)
    /// Let a creature walk backwards toward a destination behind it.
    static let backAway = PathFinderFlags(rawValue: 2)
    /// Other actors are hard obstacles rather than things to be bumped.
    static let actorsAreBlocking = PathFinderFlags(rawValue: 4)
}

/// What a straight line does when it meets a wall (`core/Map.h`, `GL_*`).
///
/// A line path is not a search result — it is a ruled line, used for wing
/// buffets, knockback and projectiles, and these say what happens at the end of
/// it. `normal` is the default: the line simply stops.
enum LinePathTermination: Int, Sendable {
    /// Stop at the wall.
    case normal = 0
    /// Carry on through it.
    case pass = 1
    /// Reflect the heading through the centre and keep going.
    case rebound = 2
}

/// Answers "is the actor standing here one I cannot push out of the way".
///
/// Stands in for GemRB's `TraversabilityCache` snapshot, which exists to keep
/// worker threads off live `Actor` pointers. We search synchronously, so the
/// live occupancy table answers directly.
protocol ActorTraversability: AnyObject {
    func isUnbumpableActor(at point: CGPoint, excluding identity: String?) -> Bool
}

/// Lazy Theta\* pathfinder, transliterated from GemRB `PathFinder::FindPath`
/// (`core/PathFinder.cpp`).
struct PathFinder {
    /// GemRB's `HEURISTIC_WEIGHT` — finds sub-optimal paths noticeably faster.
    static let heuristicWeight: CGFloat = 1.5
    /// `FindPathTimeThresholdMs`. The engine bounds the search by wall clock,
    /// not by a node count; it checks every `iterationsPerTimeoutCheck`
    /// expansions so the clock read is not the hot path.
    static let searchTimeThreshold: TimeInterval = 15
    static let iterationsPerTimeoutCheck = 25

    /// `RAND_DEGREES_OF_FREEDOM` — the sixteen headings a random walk or a
    /// run-away can take, one per orientation.
    static let randomDegreesOfFreedom = 16
    /// `SEARCHMAP_SQUARE_DIAGONAL` — `sqrt(16*16 + 12*12)`, the diagonal of one
    /// search cell in world units. Distances that the engine wants in *cells*
    /// are expressed as multiples of this.
    static let searchMapSquareDiagonal: CGFloat = 20

    /// `dxRand` / `dyRand` — cosine and sine per orientation, at the sixteen
    /// 22.5° bins.
    ///
    /// `dyRand` is negated against the engine's table because our world is
    /// y-up. In GemRB `dyRand[S] = +1`, since south is down the screen; here
    /// south is `-y`. `dxRand` is untouched: `dxRand[W] = -1` either way.
    static let dxRand: [CGFloat] = [
        0.000, -0.383, -0.707, -0.924, -1.000, -0.924, -0.707, -0.383,
        0.000, 0.383, 0.707, 0.924, 1.000, 0.924, 0.707, 0.383,
    ]
    static let dyRand: [CGFloat] = [
        -1.000, -0.924, -0.707, -0.383, 0.000, 0.383, 0.707, 0.924,
        1.000, 0.924, 0.707, 0.383, 0.000, -0.383, -0.707, -0.924,
    ]

    let searchMap: SearchMap
    /// Occupancy oracle for the bumpable test. `nil` means no actors are modelled.
    weak var traversability: (any ActorTraversability)?
    /// Identity excluded from the unbumpable test — the actor doing the walking.
    var identity: String?

    init(
        searchMap: SearchMap,
        traversability: (any ActorTraversability)? = nil,
        identity: String? = nil
    ) {
        self.searchMap = searchMap
        self.traversability = traversability
        self.identity = identity
    }

    // MARK: - Step arithmetic

    /// GemRB `PathFinder::NormalizeDeltas`.
    ///
    /// Squashes a delta to a step vector of length `STEP_RADIUS`, foreshortens
    /// the vertical component to 0.75, scales by `factor` (`StepTime / walkScale`),
    /// clamps so a step can never overshoot the node, and finally **rounds each
    /// axis up to a whole unit**.
    ///
    /// That last `ceil` is why the engine's real gait is not the 6.79 / 5.09 the
    /// arithmetic suggests but 7 and 6 units per tick — and why the effective
    /// vertical ratio is 6/7, not 0.75. Positions stay integral as a result,
    /// which is what makes `position == node.point` a sound arrival test.
    static func normalizeDeltas(
        _ dx: inout CGFloat,
        _ dy: inout CGFloat,
        factor: CGFloat = 1
    ) {
        let stepRadius: CGFloat = 2

        let xSign: CGFloat = dx < 0 ? -1 : 1
        let ySign: CGFloat = dy < 0 ? -1 : 1
        dx = abs(dx)
        dy = abs(dy)
        let dxOriginal = dx
        let dyOriginal = dy

        if dx == 0 {
            dy = stepRadius * 0.75
        } else if dy == 0 {
            dx = stepRadius
        } else {
            let q = stepRadius / hypot(dx, dy)
            dx = dx * q
            dy = dy * q * 0.75
        }

        dx = min(dx * factor, dxOriginal)
        dy = min(dy * factor, dyOriginal)
        dx = dx.rounded(.up) * xSign
        dy = dy.rounded(.up) * ySign
    }

    // MARK: - Search

    /// `PathFinder::FindPath`. An empty `Path` is failure *and* "already there";
    /// the engine does not distinguish them, and neither does anything reading
    /// this, because both mean "do not start walking".
    func findPath(
        from source: CGPoint,
        to destination: CGPoint,
        circleSize: Int,
        minDistance: CGFloat = 0,
        flags: PathFinderFlags = [.sight]
    ) -> Path {
        let actorsAreBlocking = flags.contains(.actorsAreBlocking)

        let navSource = source.rounded
        // Deliberately *not* rounded. Positions must be integral for the step
        // arithmetic, and node points are built from `navSource`, so the source
        // is snapped — but rounding a coordinate that ends in .5 crosses a cell
        // boundary, which moves the goal a whole cell without anything saying so.
        var navDest = destination
        let originalDestCell = searchMap.cell(for: navDest)

        // A blocked goal is relocated here, inside the search — callers never
        // have to opt in, and never see a goal they cannot reach. The test is
        // the engine's, on `PASSABLE` alone: a cell an actor is standing on
        // loses that bit, so a destination occupied by a body gets relocated
        // rather than walked to and bumped for.
        if !searchMap.blockedInRadiusTile(at: originalDestCell, size: circleSize)
            .contains(.passable) {
            let direction = ActorFacing.orient(from: navDest, to: navSource)
            navDest = adjustPositionDirected(
                goal: navDest,
                direction: direction,
                startingRadius: circleSize,
                minDistance: minDistance
            )
        }

        if navDest == navSource { return Path() }

        let sourceCell = searchMap.cell(for: navSource)
        var destCell = searchMap.cell(for: navDest)

        if CGFloat(circleSize) > minDistance,
           searchMap.blockedInRadiusTile(at: destCell, size: circleSize)
            .isDisjoint(with: [.passable, .actor]) {
            return Path()
        }
        guard searchMap.contains(sourceCell) else { return Path() }

        let columns = searchMap.columns
        let cellCount = searchMap.cellCount
        // Point(0,0) is the engine's "no parent" sentinel. Ours has to be a
        // value no real node can hold, and the world origin is a real point, so
        // parents are tracked as optionals over an explicit self-parent instead.
        var parents = [CGPoint?](repeating: nil, count: cellCount)
        var distFromStart = [UInt16](repeating: .max, count: cellCount)
        var isClosed = [Bool](repeating: false, count: cellCount)

        func index(_ cell: SearchMapCell) -> Int { cell.row * columns + cell.column }

        distFromStart[index(sourceCell)] = 0
        parents[index(sourceCell)] = navSource

        var open = BucketPriorityQueue()
        open.push(navSource, cost: 0)

        var foundPath = false
        let squaredMinDist = minDistance * minDistance
        let dxCross = destCell.column - sourceCell.column
        let dyCross = destCell.row - sourceCell.row

        let stepX = searchMap.cellSize.width
        let stepY = searchMap.cellSize.height
        let adjacent: [(Int, Int)] = [(1, 0), (0, 1), (-1, 0), (0, -1)]

        let startedAt = Date()
        var iterationCounter = 0

        while let navCurrent = open.pop() {
            iterationCounter += 1
            if iterationCounter >= Self.iterationsPerTimeoutCheck {
                iterationCounter = 0
                if Date().timeIntervalSince(startedAt) > Self.searchTimeThreshold {
                    return Path()
                }
            }

            let currentCell = searchMap.cell(for: navCurrent)
            guard searchMap.contains(currentCell) else { continue }
            let currentIndex = index(currentCell)
            guard let navParentOfCurrent = parents[currentIndex] else { continue }

            if currentCell == destCell {
                // Accepted outright. A cell is the engine's resolution of truth
                // — `SearchMap` rasterises conservatively so nothing finer can
                // be in the way — and the node carries the caller's own sub-cell
                // offset, which is why a route can end a few units off the click.
                navDest = navCurrent
                foundPath = true
                break
            }

            if minDistance > 0,
               navParentOfCurrent != navCurrent,
               squaredDistance(navCurrent, navDest) < squaredMinDist,
               !flags.contains(.sight)
                   || isVisibleLOS(from: currentCell, to: originalDestCell, circleSize: circleSize) {
                destCell = currentCell
                navDest = navCurrent
                foundPath = true
                break
            }

            isClosed[currentIndex] = true

            for (dx, dy) in adjacent {
                let navChild = CGPoint(
                    x: navCurrent.x + stepX * CGFloat(dx),
                    y: navCurrent.y + stepY * CGFloat(dy)
                )
                let childCell = searchMap.cell(for: navChild)
                guard searchMap.contains(childCell) else { continue }
                let childIndex = index(childCell)
                if isClosed[childIndex] { continue }

                let childBlockStatus = searchMap.blockedInRadiusTile(
                    at: childCell,
                    size: circleSize
                )
                if childBlockStatus.isDisjoint(with: [.passable, .actor]) { continue }

                // An actor standing here only stops the search if it cannot be
                // pushed aside — planning through a bumpable body is the default.
                if let traversability,
                   traversability.isUnbumpableActor(at: navChild, excluding: identity)
                    || (actorsAreBlocking && !childBlockStatus.isDisjoint(with: .actor)) {
                    continue
                }

                let navParent = navParentOfCurrent
                let parentCell = searchMap.cell(for: navParent)
                guard searchMap.contains(parentCell) else { continue }
                let parentIndex = index(parentCell)
                let oldDist = distFromStart[childIndex]

                // Lazy Theta*: relink to the grandparent optimistically, and only
                // then check whether the shortcut is actually walkable.
                let newDist = saturatingSum(
                    distFromStart[parentIndex],
                    cellDistance(parentCell, childCell)
                )
                if newDist < oldDist {
                    parents[childIndex] = navParent
                    distFromStart[childIndex] = newDist
                }

                guard distFromStart[childIndex] < oldDist else { continue }

                if !isWalkableTo(
                    navParent,
                    navChild,
                    circleSize: circleSize,
                    actorsAreBlocking: actorsAreBlocking
                ) {
                    // Fall back to A*: the closed neighbour with the shortest
                    // path-from-start plus hop.
                    distFromStart[childIndex] = .max
                    for (ndx, ndy) in adjacent {
                        let navVis = CGPoint(
                            x: navChild.x + stepX * CGFloat(ndx),
                            y: navChild.y + stepY * CGFloat(ndy)
                        )
                        let visCell = searchMap.cell(for: navVis)
                        guard searchMap.contains(visCell) else { continue }
                        let visIndex = index(visCell)
                        guard isClosed[visIndex] else { continue }
                        let candidate = saturatingSum(
                            distFromStart[visIndex],
                            cellDistance(visCell, childCell)
                        )
                        if candidate < distFromStart[childIndex] {
                            parents[childIndex] = navVis
                            distFromStart[childIndex] = candidate
                        }
                    }
                    if distFromStart[childIndex] >= oldDist { continue }
                }

                let heuristic = weightedHeuristic(
                    from: childCell,
                    to: destCell,
                    dxCross: dxCross,
                    dyCross: dyCross
                )
                open.push(navChild, cost: CGFloat(distFromStart[childIndex]) + heuristic)
            }
        }

        guard foundPath else { return Path() }

        // Walk parents back to the self-parented source, which is itself left
        // out — a path holds the nodes still to be reached.
        var result = Path()
        var navCurrent = navDest
        var guardCounter = 0
        while guardCounter <= cellCount {
            guardCounter += 1
            let cell = searchMap.cell(for: navCurrent)
            guard searchMap.contains(cell), let navParent = parents[index(cell)] else { break }
            if !result.isEmpty && navCurrent == navParent { break }

            var orient = ActorFacing.orient(from: navParent, to: navCurrent)
            // Movement allows walking backwards when the destination is behind
            // the creature and not far off. Approximated, as the engine does,
            // with a relaxed collinearity test that skips the first step.
            if flags.contains(.backAway),
               let first = result.step(at: 0),
               abs(area2(navCurrent, first.point, navParent)) < 300 {
                orient = ActorFacing.orient(from: navCurrent, to: navParent)
            }
            result.prependStep(PathNode(point: navCurrent, orient: orient))
            navCurrent = navParent
        }

        return result
    }

    // MARK: - Ruled lines and wandering

    /// `PathFinder::CalculateRunAwayPoint` — somewhere to flee to, directly away
    /// from `threat`, as far as `maxPathLength` cells.
    ///
    /// `nil` means the actor is too slow to flee or the deltas came out too
    /// small to be a direction. Backed into a corner it gives up after sixteen
    /// random reflections and returns the best spot it reached; the engine's own
    /// comment weighs returning nothing instead and settles on this, because the
    /// strict version left iwd's beetles unable to move at all.
    static func calculateRunAwayPoint(
        on searchMap: SearchMap,
        from source: CGPoint,
        threat: CGPoint,
        maxPathLength: Int,
        walkScale: CGFloat,
        circleSize: Int
    ) -> CGPoint? {
        guard walkScale > 0 else { return nil }
        var point = source
        var dx = source.x - threat.x
        var dy = source.y - threat.y
        normalizeDeltas(&dx, &dy, factor: ActorLocomotionPacing.infinityEngineStepTime / walkScale)
        if abs(dx) <= 0.333 && abs(dy) <= 0.333 { return nil }

        var xSign: CGFloat = 1
        var ySign: CGFloat = 1
        var tries = 0
        let reach = CGFloat(maxPathLength) * searchMapSquareDiagonal
        let reachSquared = reach * reach

        while squaredDistance(point, source) < reachSquared {
            let candidate = CGPoint(
                x: (point.x + 3 * xSign * dx).rounded(),
                y: (point.y + 3 * ySign * dy).rounded()
            )
            if !searchMap.blockedInRadiusTile(at: candidate, size: circleSize).contains(.passable) {
                tries += 1
                if tries > randomDegreesOfFreedom { break }
                xSign = Bool.random() ? -1 : 1
                ySign = Bool.random() ? -1 : 1
                continue
            }
            point = candidate
        }
        return point
    }

    /// `PathFinder::CalculateRandomWalkPoint` — a spot to wander to within
    /// `radius` cells, and the facing to wear on the way.
    ///
    /// `nil` when the actor is too slow, or when sixteen random headings all ran
    /// into something. The walk-back at the end is the engine's: having stepped
    /// until it left the radius, it reverses until the next step would be
    /// standable again, so the answer is inside the walkable region rather than
    /// one step past its edge.
    static func calculateRandomWalkPoint(
        on searchMap: SearchMap,
        from source: CGPoint,
        circleSize: Int,
        radius: Int,
        walkScale: CGFloat
    ) -> PathNode? {
        guard walkScale > 0 else { return nil }
        let factor = ActorLocomotionPacing.infinityEngineStepTime / walkScale
        var point = source
        var index = Int.random(in: 0..<randomDegreesOfFreedom)
        var dx = 3 * dxRand[index]
        var dy = 3 * dyRand[index]
        normalizeDeltas(&dx, &dy, factor: factor)

        var tries = 0
        let reach = CGFloat(radius) * searchMapSquareDiagonal
        let reachSquared = reach * reach

        while squaredDistance(point, source) < reachSquared {
            let ahead = CGPoint(x: point.x + dx, y: point.y + dy)
            if !searchMap.blockedInRadiusTile(at: ahead, size: circleSize).contains(.passable) {
                tries += 1
                if tries > randomDegreesOfFreedom { return nil }
                index = Int.random(in: 0..<randomDegreesOfFreedom)
                dx = 3 * dxRand[index]
                dy = 3 * dyRand[index]
                normalizeDeltas(&dx, &dy, factor: factor)
                point = source
            } else {
                point = CGPoint(x: point.x + dx, y: point.y + dy)
            }
        }

        // An actor standing on the spot is not a reason to stop short of it —
        // it is something to bump on arrival — so `ACTOR` counts as reachable.
        var guardCounter = 0
        while guardCounter <= 4_096,
              searchMap.blockedInRadiusTile(
                  at: CGPoint(x: point.x + dx, y: point.y + dy),
                  size: circleSize
              ).isDisjoint(with: [.passable, .actor]) {
            guardCounter += 1
            point = CGPoint(x: point.x - dx, y: point.y - dy)
        }

        let bounds = searchMap.worldBounds
        let clamped = CGPoint(
            x: min(max(point.x, bounds.minX + 1), bounds.maxX - searchMap.cellSize.width),
            y: min(max(point.y, bounds.minY + 1), bounds.maxY - searchMap.cellSize.height)
        ).rounded
        return PathNode(point: clamped, orient: ActorFacing.orient(from: source, to: clamped))
    }

    /// `PathFinder::CalculateLinePath` — a ruled line from `start` to `dest`,
    /// emitting a node every `speed` units walked.
    ///
    /// Not a search: this is the path a wing buffet or a knockback follows, and
    /// it holds its orientation for the whole line rather than deriving one per
    /// node. `termination` says what a wall does to it.
    static func calculateLinePath(
        on searchMap: SearchMap,
        start: CGPoint,
        dest: CGPoint,
        speed: Int,
        orientation: ActorFacing,
        termination: LinePathTermination = .normal
    ) -> Path {
        var facing = orientation
        var path = Path()
        path.appendStep(PathNode(point: start.rounded, orient: facing))

        let max = Int(hypot(dest.x - start.x, dest.y - start.y))
        guard max > 0 else { return path }
        let diff = CGPoint(x: dest.x - start.x, y: dest.y - start.y)

        var count = 0
        var lastIndex = path.nodes.count - 1

        for steps in 0..<max {
            let point = CGPoint(
                x: (start.x + diff.x * CGFloat(steps) / CGFloat(max)).rounded(),
                y: (start.y + diff.y * CGFloat(steps) / CGFloat(max)).rounded()
            )
            // The engine's guard against running off the map, which it added to
            // stop projectiles crashing. Ours is the same test in world space.
            guard searchMap.contains(point) else { return path }

            if count == 0 {
                path.appendStep(PathNode(point: point, orient: facing))
                lastIndex = path.nodes.count - 1
                count = speed
            } else {
                count -= 1
                path.nodes[lastIndex].point = point
                path.nodes[lastIndex].orient = facing
            }

            let wall = !searchMap.blockedTile(at: searchMap.cell(for: point))
                .isDisjoint(with: [.doorImpassable, .sidewall])
            if wall {
                switch termination {
                case .rebound:
                    // The engine leaves `dest` unmirrored here with a TODO, so
                    // the rebound turns the *facing* and keeps walking the
                    // original line. Reproduced rather than corrected.
                    facing = facing.reflected
                case .pass:
                    break
                case .normal:
                    return path
                }
            }
        }
        return path
    }

    /// `PathFinder::CalculateLineEnd` — where a line of `steps` cells in
    /// `orient` ends up, clamped inside the map.
    static func calculateLineEnd(
        on searchMap: SearchMap,
        from point: CGPoint,
        steps: Int,
        orient: ActorFacing
    ) -> PathNode {
        let reach = CGFloat(steps) * searchMapSquareDiagonal
        let bounds = searchMap.worldBounds
        let end = CGPoint(
            x: min(
                max(point.x + reach * dxRand[orient.rawValue], bounds.minX + 1),
                bounds.maxX - searchMap.cellSize.width
            ),
            y: min(
                max(point.y + reach * dyRand[orient.rawValue], bounds.minY + 1),
                bounds.maxY - searchMap.cellSize.height
            )
        ).rounded
        return PathNode(point: end, orient: ActorFacing.orient(from: point, to: end))
    }

    // MARK: - Destination adjustment

    /// `PathFinder::AdjustPositionDirected` — a sparse cone cast back toward the
    /// caller.
    ///
    /// Five orientations are tried (the direction itself, then ±1 and ±2 bins)
    /// at increasing radius, and every passable hit is ranked by how close it
    /// lands to the requested goal. The closest candidate that still respects
    /// `minDistance` wins; if all of them are further out, the furthest is taken
    /// rather than failing.
    func adjustPositionDirected(
        goal: CGPoint,
        direction: ActorFacing,
        startingRadius: Int,
        minDistance: CGFloat
    ) -> CGPoint {
        var goalCell = searchMap.cell(for: goal)
        goalCell = SearchMapCell(
            column: min(goalCell.column, searchMap.columns),
            row: min(goalCell.row, searchMap.rows)
        )

        let orients: [ActorFacing] = [
            direction,
            direction.next(2),
            direction.previous(2),
            direction.next(),
            direction.previous(),
        ]
        // OrientedOffset only offsets in 8 directions, so there are duplicates.
        var baseOffsets: [(dx: Int, dy: Int)] = []
        for orient in orients {
            let offset = orient.offset(1)
            if !baseOffsets.contains(where: { $0 == offset }) {
                baseOffsets.append(offset)
            }
        }

        // Ranked by squared distance to the goal, cell-centre corrected.
        var candidates: [(range: CGFloat, cell: SearchMapCell)] = []
        let adjustedGoal = CGPoint(
            x: goal.x - searchMap.cellSize.width / 2,
            y: goal.y - searchMap.cellSize.height / 2
        )
        var radius = startingRadius - 1
        while radius < 2 * startingRadius {
            for offset in baseOffsets {
                let candidate = SearchMapCell(
                    column: goalCell.column + offset.dx * radius,
                    row: goalCell.row + offset.dy * radius
                )
                guard searchMap.contains(candidate) else { continue }
                guard searchMap.blockedInRadiusTile(at: candidate, size: startingRadius)
                    .contains(.passable) else { continue }
                let range = squaredDistance(searchMap.center(of: candidate), adjustedGoal)
                if !candidates.contains(where: { $0.cell == candidate }) {
                    candidates.append((range, candidate))
                }
            }
            radius += 1
        }

        if candidates.isEmpty {
            // The engine's fallback takes `AdjustPosition`'s defaults: no
            // starting radius, and `size = -1`, which asks `GetBlockedTile`
            // about the cell alone rather than a clearance disc. A cone cast
            // that found nothing is already the hard case; widening the question
            // here would fail it outright.
            goalCell = adjustPosition(goal: goalCell)
        } else {
            // The engine keeps these in a map ordered by `std::greater`, and
            // that ordering is the algorithm: it walks from the *furthest*
            // candidate inward, taking the first that is within the range the
            // caller needs, and falls back to `crbegin()` — the **closest** —
            // when none is. Sorting the other way and taking the last element
            // picks the furthest instead, which relocates a goal clear across
            // the map.
            candidates.sort { $0.range > $1.range }
            let minDist2 = minDistance * minDistance
            goalCell = candidates.first { $0.range <= minDist2 }?.cell
                ?? candidates[candidates.count - 1].cell
        }

        return searchMap.center(of: goalCell)
    }

    /// `PathFinder::AdjustPosition` — the undirected fallback: expand a
    /// rectangular ring until a passable cell shows up on one of its edges.
    ///
    /// The engine flips a coin over which axis to scan first so that a crowd
    /// spawning on the same blocked point does not stack into a line.
    /// `size` is the engine's: `-1` asks `GetBlockedTile` about the cell alone,
    /// anything else asks `GetBlockedInRadiusTile` for a body of that circle
    /// size. Both callers in the engine take the `-1` default.
    func adjustPosition(
        goal: SearchMapCell,
        startingRadius: SearchMapCell = SearchMapCell(column: 0, row: 0),
        size: Int = -1
    ) -> SearchMapCell {
        var result = SearchMapCell(
            column: min(goal.column, searchMap.columns),
            row: min(goal.row, searchMap.rows)
        )
        var radiusW = startingRadius.column
        var radiusH = startingRadius.row

        while radiusW < searchMap.columns || radiusH < searchMap.rows {
            if Bool.random() {
                if let hit = adjustPositionX(result, radiusW, radiusH, size) { return hit }
                if let hit = adjustPositionY(result, radiusW, radiusH, size) { return hit }
            } else {
                if let hit = adjustPositionY(result, radiusW, radiusH, size) { return hit }
                if let hit = adjustPositionX(result, radiusW, radiusH, size) { return hit }
            }
            if radiusW < searchMap.columns { radiusW += 1 }
            if radiusH < searchMap.rows { radiusH += 1 }
        }
        _ = result
        result = goal
        return result
    }

    /// `PathFinder::GetBlockedTile(tileProps, p, size)` — the size-dispatching
    /// overload the `AdjustPosition` scans are written against.
    private func blockedTile(at cell: SearchMapCell, size: Int) -> PathMapFlags {
        size == -1
            ? searchMap.blockedTile(at: cell)
            : searchMap.blockedInRadiusTile(at: cell, size: size)
    }

    private func adjustPositionX(
        _ goal: SearchMapCell,
        _ radiusW: Int,
        _ radiusH: Int,
        _ size: Int
    ) -> SearchMapCell? {
        let minX = goal.column > radiusW ? goal.column - radiusW : 0
        let maxX = min(goal.column + radiusW + 1, searchMap.columns)
        guard minX < maxX else { return nil }
        for scanX in minX..<maxX {
            if goal.row >= radiusH {
                let probe = SearchMapCell(column: scanX, row: goal.row - radiusH)
                if blockedTile(at: probe, size: size).contains(.passable) {
                    return probe
                }
            }
            if goal.row + radiusH < searchMap.rows {
                let probe = SearchMapCell(column: scanX, row: goal.row + radiusH)
                if blockedTile(at: probe, size: size).contains(.passable) {
                    return probe
                }
            }
        }
        return nil
    }

    private func adjustPositionY(
        _ goal: SearchMapCell,
        _ radiusW: Int,
        _ radiusH: Int,
        _ size: Int
    ) -> SearchMapCell? {
        let minY = goal.row > radiusH ? goal.row - radiusH : 0
        let maxY = min(goal.row + radiusH + 1, searchMap.rows)
        guard minY < maxY else { return nil }
        for scanY in minY..<maxY {
            if goal.column >= radiusW {
                let probe = SearchMapCell(column: goal.column - radiusW, row: scanY)
                if blockedTile(at: probe, size: size).contains(.passable) {
                    return probe
                }
            }
            if goal.column + radiusW < searchMap.columns {
                let probe = SearchMapCell(column: goal.column + radiusW, row: scanY)
                if blockedTile(at: probe, size: size).contains(.passable) {
                    return probe
                }
            }
        }
        return nil
    }

    /// Snap an arbitrary point onto standable floor (`Map::AdjustPositionNavmap`).
    ///
    /// The engine asks for a *cell* here, not for room to stand: `AdjustPosition`
    /// is called with its default `size = -1`. That is what `BumpAway` wants —
    /// somewhere to step so a mover can get past, with `BumpBack` reclaiming the
    /// spot afterwards — and asking for full clearance would send a shoved actor
    /// much further than a sidestep.
    func adjustPositionNavmap(_ point: CGPoint) -> CGPoint {
        searchMap.center(of: adjustPosition(goal: searchMap.cell(for: point)))
    }

    // MARK: - Line queries

    /// `PathFinder::IsWalkableTo`.
    ///
    /// The engine walks this line in **navmap** space (`GetBlockedInLine`), not
    /// in cells. That is load-bearing for a Theta\* shortcut: the tile-space
    /// walk steps diagonally a whole cell at a time and skips the cells either
    /// side of the diagonal, so a shortcut that clips the corner of a desk is
    /// approved. `IsVisibleLOS` keeps the tile-space walk, as the engine does.
    func isWalkableTo(
        _ start: CGPoint,
        _ end: CGPoint,
        circleSize: Int,
        actorsAreBlocking: Bool
    ) -> Bool {
        let accumulated = searchMap.blockedInLine(
            from: start,
            to: end,
            size: circleSize,
            stopOnImpassable: true
        )
        return Self.isLineWalkable(accumulated, actorsAreBlocking: actorsAreBlocking)
    }

    /// `PathFinder::IsLineWalkable`.
    static func isLineWalkable(
        _ accumulatedFlags: PathMapFlags,
        actorsAreBlocking: Bool
    ) -> Bool {
        // Geometry first. `accumulatedFlags` is OR-accumulated over the whole
        // line, so one tile carrying ACTOR sets it for all of it; ignoring
        // actors without this guard would ignore any wall on the line too.
        if !accumulatedFlags.isDisjoint(with: [.sidewall, .doorImpassable]) {
            return false
        }
        let mask: PathMapFlags = actorsAreBlocking
            ? .passable
            : [.passable, .actor]
        return !accumulatedFlags.isDisjoint(with: mask)
    }

    /// `PathFinder::IsVisibleLOS` — one test, on `SIDEWALL` alone, over a line
    /// walked to the end rather than abandoned at the first impassable cell.
    ///
    /// Both details are the engine's and both were wrong here. Stopping early
    /// turns "there is a wall in the way" and "there is a desk in the way" into
    /// the same answer, and `NO_SEE` is not part of the test: `blockedInLineTile`
    /// already folds an opaque door into `SIDEWALL`, and index 0 — the only
    /// terrain GemRB's `AREImporter` marks `NO_SEE` — blocks sight by being
    /// solid, not by being listed here.
    func isVisibleLOS(from start: SearchMapCell, to end: SearchMapCell, circleSize: Int) -> Bool {
        let accumulated = searchMap.blockedInLineTile(
            from: start,
            to: end,
            size: circleSize,
            stopOnImpassable: false
        )
        return accumulated.isDisjoint(with: .sidewall)
    }

    // MARK: - Private

    private func cellDistance(_ a: SearchMapCell, _ b: SearchMapCell) -> UInt16 {
        let distance = hypot(
            CGFloat(a.column - b.column),
            CGFloat(a.row - b.row)
        )
        return UInt16(min(distance.rounded(), CGFloat(UInt16.max)))
    }

    private func saturatingSum(_ a: UInt16, _ b: UInt16) -> UInt16 {
        let (sum, overflow) = a.addingReportingOverflow(b)
        return overflow ? .max : sum
    }

    /// The engine's heuristic works in **cell** units, and shifts the cross
    /// product right by three rather than dividing — both are load-bearing for
    /// which of two equal-cost frontiers gets expanded first.
    private func weightedHeuristic(
        from cell: SearchMapCell,
        to goal: SearchMapCell,
        dxCross: Int,
        dyCross: Int
    ) -> CGFloat {
        let xDist = cell.column - goal.column
        let yDist = cell.row - goal.row
        let crossProduct = abs(xDist * dyCross - yDist * dxCross) >> 3
        let distance = hypot(CGFloat(xDist), CGFloat(yDist))
        return Self.heuristicWeight * (distance + CGFloat(crossProduct))
    }

    static func squaredDistance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        let dx = a.x - b.x
        let dy = a.y - b.y
        return dx * dx + dy * dy
    }

    private func squaredDistance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        Self.squaredDistance(a, b)
    }

    /// Twice the signed area of triangle a, b, c (GemRB `area2`).
    private func area2(_ a: CGPoint, _ b: CGPoint, _ c: CGPoint) -> CGFloat {
        (b.x - a.x) * (c.y - a.y) - (c.x - a.x) * (b.y - a.y)
    }
}

extension CGPoint {
    /// The engine's positions are integral, and `NormalizeDeltas`' `ceil` keeps
    /// them that way. Snapping at the search boundary is what makes reaching a
    /// node an exact equality rather than a tolerance.
    var rounded: CGPoint {
        CGPoint(x: x.rounded(), y: y.rounded())
    }
}

/// GemRB's open set is a bucket queue rather than a binary heap: costs are
/// quantised into integer buckets, and ties come back in insertion order. That
/// ordering shows up in which of two equal-cost routes is returned, so a heap
/// would quietly change paths that the engine considers settled.
private struct BucketPriorityQueue {
    private var buckets: [Int: [CGPoint]] = [:]
    private var minBucket: Int?

    mutating func push(_ point: CGPoint, cost: CGFloat) {
        let bucket = max(0, Int(cost))
        buckets[bucket, default: []].append(point)
        if let current = minBucket {
            minBucket = min(current, bucket)
        } else {
            minBucket = bucket
        }
    }

    mutating func pop() -> CGPoint? {
        guard var bucket = minBucket else { return nil }
        while buckets[bucket]?.isEmpty ?? true {
            buckets[bucket] = nil
            guard let next = buckets.keys.min() else {
                minBucket = nil
                return nil
            }
            bucket = next
        }
        minBucket = bucket
        let point = buckets[bucket]!.removeFirst()
        if buckets[bucket]!.isEmpty {
            buckets[bucket] = nil
            minBucket = buckets.keys.min()
        }
        return point
    }
}
