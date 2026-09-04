import CoreGraphics
import Foundation

/// One search-map cell, matching Infinity Engine / BG:EE search-map indexing.
struct SearchMapCell: Hashable, Sendable {
    let column: Int
    let row: Int
}

/// GemRB `PathMapFlags` (`core/TileProps.h`), bit for bit.
///
/// The bit values are the engine's, not a convenient re-encoding: `areaMask` is
/// the low nibble, so authored terrain can be preserved while door and actor
/// stamps in the high nibble are cleared and rewritten. Several of the engine's
/// own reads depend on that split (`NOTACTOR`, `NOTDOOR`, `NOTAREA`).
struct PathMapFlags: OptionSet, Hashable, Sendable {
    let rawValue: UInt8

    init(rawValue: UInt8) {
        self.rawValue = rawValue
    }

    /// `IMPASSABLE` and `UNMARKED` are both the empty set in the engine; they
    /// are spelled differently only to document intent at the call site.
    static let impassable = PathMapFlags([])
    static let unmarked = PathMapFlags([])

    /// Walkable terrain.
    static let passable = PathMapFlags(rawValue: 1)
    /// Stepping here hands the player to the world map (BG terrain index 14).
    static let travel = PathMapFlags(rawValue: 2)
    /// Sight does not enter this cell (BG terrain index 0).
    static let noSee = PathMapFlags(rawValue: 4)
    /// BG terrain index 10. A ray already running along sidewall stays visible;
    /// `DoStep` also refuses to walk into one, which is how the engine stops an
    /// actor short of a wall rather than letting it grind along it.
    static let sidewall = PathMapFlags(rawValue: 8)
    /// Authored terrain bits — everything that survives a door or actor restamp.
    static let areaMask = PathMapFlags(rawValue: 15)

    /// A closed door leaf that also stops sight.
    ///
    /// Separate from `doorImpassable` because the Infinity Engine keeps the two
    /// separate: a door's impeded cells stop movement, and door flag bit 9
    /// ("Don't block line of sight") decides independently whether sight passes.
    static let doorOpaque = PathMapFlags(rawValue: 16)
    /// Closed / blocking door leaf stamped at runtime.
    static let doorImpassable = PathMapFlags(rawValue: 32)
    /// Player character occupancy stamp.
    static let pc = PathMapFlags(rawValue: 64)
    /// NPC occupancy stamp.
    static let npc = PathMapFlags(rawValue: 128)

    static let actor: PathMapFlags = [.pc, .npc]
    static let door: PathMapFlags = [.doorOpaque, .doorImpassable]
    static let notArea: PathMapFlags = [.actor, .door]
    static let notDoor: PathMapFlags = [.actor, .areaMask]
    static let notActor: PathMapFlags = [.door, .areaMask]
}

/// A door leaf registered with the map, so it can be stamped and cleared in
/// place without rebuilding the grid.
///
/// The Infinity Engine gives a door two separate cell blocks — impeded when open
/// and impeded when closed — and a flag deciding whether it blocks line of sight.
/// `blocksSight` is IE's flag bit 9 inverted, so the default matches the engine
/// and an authored door has to opt *out*. Per-state cell lists, when present,
/// are the authority; otherwise the closed (or open) rect is rasterised.
struct DoorObstacle: Hashable, Sendable {
    var id: String
    var closedRect: CGRect
    var openRect: CGRect?
    var blocksSight: Bool
    var closedCells: [SearchMapCell]
    var openCells: [SearchMapCell]
    var isOpen: Bool

    /// Closed footprint. Existing call sites that only author a shut leaf use
    /// this, and AABB tests against a closed door still do.
    var rect: CGRect { closedRect }

    init(rect: CGRect, blocksSight: Bool = true) {
        self.init(id: "", closedRect: rect, blocksSight: blocksSight)
    }

    init(
        id: String,
        closedRect: CGRect,
        openRect: CGRect? = nil,
        blocksSight: Bool = true,
        closedCells: [SearchMapCell] = [],
        openCells: [SearchMapCell] = [],
        isOpen: Bool = false
    ) {
        self.id = id
        self.closedRect = closedRect.standardized
        self.openRect = openRect?.standardized
        self.blocksSight = blocksSight
        self.closedCells = closedCells
        self.openCells = openCells
        self.isOpen = isOpen
    }

    var standardized: DoorObstacle { self }

    /// The AABB the engine should treat as solid in the current state.
    var activeRect: CGRect? {
        isOpen ? openRect : closedRect
    }
}

/// BG:EE-style world-space search map: a byte-per-cell raster in screen/world
/// space (default 16×12 unit cells). Pathfinding expands on these cells;
/// movement follows any-angle waypoints in world space.
final class SearchMap {
    /// Infinity Engine search-map cell footprint in world units.
    static let defaultCellSize = CGSize(width: 16, height: 12)

    let origin: CGPoint
    let columns: Int
    let rows: Int
    let cellSize: CGSize
    let worldBounds: CGRect

    private var cells: [UInt8]

    /// Terrain written into open ground when the map is built from AABBs rather
    /// than from a painted search map.
    let defaultTerrain: SearchMapTerrain

    /// Baldur's Gate terrain index per cell, parallel to `cells`.
    ///
    /// Kept beside the flag byte rather than packed into it: the flag bits are
    /// read on every path expansion and every actor stamp, and widening that
    /// byte would have meant touching each of those call sites to mask. The
    /// `.passable` flag is *derived* from this array at rasterisation, so
    /// `PathFinder`, `ActorOccupancy` and door stamping keep working unchanged
    /// while the terrain answers the questions a single bit could not — sight,
    /// flight, projectiles, and what the ground sounds like underfoot.
    private var terrainIndices: [UInt8]

    /// Authored static obstacle AABBs used for line-of-sight segment tests at
    /// world resolution (Theta* shortcuts), independent of the coarse raster.
    private(set) var staticObstacles: [CGRect]

    /// Coarse spatial index for static obstacle queries. A literal 80×60-tile
    /// district has 102,400 search cells; scanning every authored building for
    /// every Lazy Theta* clearance sample makes an ordinary route take minutes.
    /// Eight search cells per bucket keeps the index small while limiting the
    /// usual point query to the handful of nearby solids.
    private var obstacleBucketSize: CGSize = .zero
    private var obstacleBucketColumns = 1
    private var obstacleBucketRows = 1
    private var staticObstacleBuckets: [[Int]] = []

    /// Door leaf AABBs that can be stamped/cleared without rebuilding the map.
    private var doorObstacles: [DoorObstacle] = []

    var cellCount: Int { columns * rows }

    var impassableCellCount: Int {
        var count = 0
        for flags in cells where !isTerrainPassable(PathMapFlags(rawValue: flags)) {
            count += 1
        }
        return count
    }

    init(
        worldBounds: CGRect,
        obstacles: [CGRect],
        cellSize: CGSize = SearchMap.defaultCellSize,
        doorObstacles: [DoorObstacle] = [],
        defaultTerrain: SearchMapTerrain = .stone
    ) {
        precondition(cellSize.width > 0 && cellSize.height > 0)
        let bounds = worldBounds.standardized
        precondition(!bounds.isNull && !bounds.isEmpty)
        self.worldBounds = bounds
        self.origin = bounds.origin
        self.cellSize = cellSize
        self.columns = max(1, Int(ceil(bounds.width / cellSize.width)))
        self.rows = max(1, Int(ceil(bounds.height / cellSize.height)))
        self.staticObstacles = obstacles.map(\.standardized)
        self.doorObstacles = doorObstacles.map(\.standardized)
        self.cells = Array(repeating: PathMapFlags.passable.rawValue, count: columns * rows)
        // An area built from AABBs has no painted terrain, so its open ground is
        // stone: the districts are paved and the office plate is boards, and the
        // office overrides this through `defaultTerrain`.
        self.terrainIndices = Array(
            repeating: defaultTerrain.rawValue,
            count: columns * rows
        )
        self.defaultTerrain = defaultTerrain
        rasterizeStaticObstacles()
        rebuildStaticObstacleBuckets()
        if !self.doorObstacles.isEmpty {
            restampDoors()
        }
    }

    /// Build from a painted search map: one terrain index per cell, row-major
    /// from the world's minimum corner.
    ///
    /// This is the Infinity Engine's own arrangement — an area ships an `SR.BMP`
    /// at one pixel per search cell — and it is the only way to describe ground
    /// that axis-aligned rectangles cannot. Harborpoint's streets run on the
    /// BG:EE ground axes, so a diagonal kerb is either eaten or over-claimed by
    /// any AABB approximation of it; and a painted map can distinguish a wooden
    /// floor from a wet cobble street, which a boolean cannot.
    ///
    /// `obstacles` and `doorObstacles` are burned into the raster on the way in,
    /// conservatively — see `rasterizeStaticObstacles`. The engine has exactly
    /// one authority on clearance, the search map, so a rectangle that is not in
    /// the raster does not exist as far as routing is concerned. RainShadow used
    /// to keep them out of it and test them separately at world resolution,
    /// which is the adaptation the literal port removes.
    ///
    /// The burn is a union, not a replacement: the painted map still decides
    /// terrain everywhere a rectangle does not sit, so authored roofs, water and
    /// world-map exits survive intact. That matters because the painted city
    /// rasters carry terrain classes this codebase has no rectangle for.
    init(
        worldBounds: CGRect,
        terrainIndices: [UInt8],
        columns: Int,
        rows: Int,
        cellSize: CGSize = SearchMap.defaultCellSize,
        obstacles: [CGRect] = [],
        sightPermeableObstacles: [CGRect] = [],
        doorObstacles: [DoorObstacle] = []
    ) {
        precondition(cellSize.width > 0 && cellSize.height > 0)
        precondition(columns > 0 && rows > 0)
        precondition(
            terrainIndices.count == columns * rows,
            "search map is \(terrainIndices.count) cells for a \(columns)x\(rows) grid"
        )
        let bounds = worldBounds.standardized
        precondition(!bounds.isNull && !bounds.isEmpty)
        self.worldBounds = bounds
        self.origin = bounds.origin
        self.cellSize = cellSize
        self.columns = columns
        self.rows = rows
        self.defaultTerrain = .stone
        self.staticObstacles = obstacles.map(\.standardized)
        self.doorObstacles = doorObstacles.map(\.standardized)
        self.terrainIndices = terrainIndices
        // `.passable` is derived, never authored: one source of truth for
        // whether a cell is floor, so a painted map and the flag byte cannot
        // disagree.
        self.cells = terrainIndices.map { raw in
            SearchMapTerrain.decode(raw).areaFlags.rawValue
        }
        burnStaticObstaclesIntoRaster(sightPermeable: sightPermeableObstacles)
        rebuildStaticObstacleBuckets()
        if !self.doorObstacles.isEmpty {
            restampDoors()
        }
    }

    // MARK: - Coordinate conversion

    func cell(for point: CGPoint) -> SearchMapCell {
        SearchMapCell(
            column: Int(floor((point.x - origin.x) / cellSize.width)),
            row: Int(floor((point.y - origin.y) / cellSize.height))
        )
    }

    func center(of cell: SearchMapCell) -> CGPoint {
        CGPoint(
            x: origin.x + (CGFloat(cell.column) + 0.5) * cellSize.width,
            y: origin.y + (CGFloat(cell.row) + 0.5) * cellSize.height
        )
    }

    /// The cell's own footprint in world space — what a fog mask paints, and
    /// what an obstacle is rasterised against.
    ///
    /// The raster is the engine's only authority on clearance, so what a cell
    /// *covers* has to be a real rectangle rather than just its centre — see
    /// `rasterizeStaticObstacles`.
    func rect(of cell: SearchMapCell) -> CGRect {
        CGRect(
            x: origin.x + CGFloat(cell.column) * cellSize.width,
            y: origin.y + CGFloat(cell.row) * cellSize.height,
            width: cellSize.width,
            height: cellSize.height
        )
    }

    func contains(_ cell: SearchMapCell) -> Bool {
        cell.column >= 0 && cell.column < columns && cell.row >= 0 && cell.row < rows
    }

    func contains(_ point: CGPoint) -> Bool {
        let epsilon: CGFloat = 0.001
        return point.x >= worldBounds.minX - epsilon
            && point.x <= worldBounds.maxX + epsilon
            && point.y >= worldBounds.minY - epsilon
            && point.y <= worldBounds.maxY + epsilon
    }

    // MARK: - Queries

    func flags(at cell: SearchMapCell) -> PathMapFlags {
        guard contains(cell) else { return [] }
        return PathMapFlags(rawValue: cells[index(of: cell)])
    }

    func flags(at point: CGPoint) -> PathMapFlags {
        flags(at: cell(for: point))
    }

    /// Terrain index at a cell. Out of bounds reads as solid, matching the
    /// engine's treatment of the area boundary.
    func terrain(at cell: SearchMapCell) -> SearchMapTerrain {
        guard contains(cell) else { return .obstacle }
        return SearchMapTerrain.decode(terrainIndices[index(of: cell)])
    }

    func terrain(at point: CGPoint) -> SearchMapTerrain {
        terrain(at: cell(for: point))
    }

    /// What the ground sounds like here. `nil` where nothing walks.
    func surface(at point: CGPoint) -> SearchMapSurface? {
        let surface = terrain(at: point).surface
        return surface == .silent ? nil : surface
    }

    /// Whether sight crosses the cell — the query fog of war wants, in place of
    /// a radius around the player. A closed sight-blocking door counts as solid
    /// here for the same reason it does in `visibleCells`.
    func isSeeThrough(at point: CGPoint) -> Bool {
        let cell = cell(for: point)
        return terrain(at: cell).isSeeThrough && !doorBlocksSight(at: cell)
    }

    /// Every terrain index present, for QA and tests.
    var terrainHistogram: [SearchMapTerrain: Int] {
        var histogram: [SearchMapTerrain: Int] = [:]
        for raw in terrainIndices {
            histogram[SearchMapTerrain.decode(raw), default: 0] += 1
        }
        return histogram
    }

    /// True when the cell's terrain allows walking (ignores actor stamps).
    func isTerrainPassable(_ flags: PathMapFlags) -> Bool {
        flags.contains(.passable)
            && flags.isDisjoint(with: [.doorImpassable, .sidewall])
    }

    /// True when *either* occupancy bit is set.
    ///
    /// `PathMapFlags.actor` is a two-bit mask, and `OptionSet.contains` is a
    /// superset test — so `flags.contains(.actor)` only answers "is this cell
    /// occupied by a player **and** an NPC simultaneously", which never happens.
    /// Every actor-blocking query in this file used that test, which meant actor
    /// occupancy was stamped but never read: `treatActorsAsBlocking` was inert
    /// and the two-tier "plan around actors first" search always came back with
    /// the actor-ignoring answer. Membership has to be a disjointness test.
    func containsActor(_ flags: PathMapFlags) -> Bool {
        !flags.isDisjoint(with: .actor)
    }

    /// Point query with optional actor radius (BG circle-size clearance).
    func blocked(
        at point: CGPoint,
        radius: CGFloat = 0,
        treatActorsAsBlocking: Bool = false
    ) -> PathMapFlags {
        if radius <= 0 {
            var flags = flags(at: point)
            if !contains(point) {
                return []
            }
            if !treatActorsAsBlocking {
                flags.subtract(.actor)
            }
            return flags
        }
        return blockedInRadius(
            at: point,
            radius: radius,
            treatActorsAsBlocking: treatActorsAsBlocking
        )
    }

    func isPassable(
        at point: CGPoint,
        radius: CGFloat = 0,
        treatActorsAsBlocking: Bool = false
    ) -> Bool {
        guard contains(point) else { return false }
        // Search-map boundary is solid, matching BG / prior NavigationGrid.
        if radius > 0 {
            let inset = worldBounds.insetBy(dx: radius, dy: radius)
            if inset.isNull || inset.isEmpty || !inset.contains(point) {
                return false
            }
        }
        if discOverlapsObstacle(at: point, radius: radius) {
            return false
        }
        let flags = blocked(
            at: point,
            radius: radius,
            treatActorsAsBlocking: treatActorsAsBlocking
        )
        guard isTerrainPassable(flags) else { return false }
        if treatActorsAsBlocking, containsActor(flags) {
            return false
        }
        return true
    }

    /// True when a disc of `radius` (or the point itself) overlaps a static or
    /// door obstacle AABB — BG circle-size clearance against painted solids.
    func discOverlapsObstacle(at point: CGPoint, radius: CGFloat) -> Bool {
        if radius <= 0 {
            return staticObstacleIndices(near: point, radius: 0).contains {
                staticObstacles[$0].contains(point)
            }
                || doorObstacles.contains(where: { $0.activeRect?.contains(point) == true })
        }
        let probe = CGRect(
            x: point.x - radius,
            y: point.y - radius,
            width: radius * 2,
            height: radius * 2
        )
        for index in staticObstacleIndices(near: point, radius: radius) {
            let obstacle = staticObstacles[index]
            if obstacle.intersects(probe) {
                // Refine the axis-aligned probe with a true circle test against
                // the obstacle's closest point so diagonal clearance stays fair.
                let closest = CGPoint(
                    x: min(max(point.x, obstacle.minX), obstacle.maxX),
                    y: min(max(point.y, obstacle.minY), obstacle.maxY)
                )
                let dx = closest.x - point.x
                let dy = closest.y - point.y
                if dx * dx + dy * dy <= radius * radius {
                    return true
                }
            }
        }
        for obstacle in doorObstacles.compactMap(\.activeRect) where obstacle.intersects(probe) {
            let closest = CGPoint(
                x: min(max(point.x, obstacle.minX), obstacle.maxX),
                y: min(max(point.y, obstacle.minY), obstacle.maxY)
            )
            let dx = closest.x - point.x
            let dy = closest.y - point.y
            if dx * dx + dy * dy <= radius * radius {
                return true
            }
        }
        return false
    }

    func isPassable(
        cell: SearchMapCell,
        radius: CGFloat = 0,
        treatActorsAsBlocking: Bool = false
    ) -> Bool {
        guard contains(cell) else { return false }
        return isPassable(
            at: center(of: cell),
            radius: radius,
            treatActorsAsBlocking: treatActorsAsBlocking
        )
    }

    /// Samples a disc of `radius` world units for any non-passable / actor cell.
    func blockedInRadius(
        at point: CGPoint,
        radius: CGFloat,
        treatActorsAsBlocking: Bool = false
    ) -> PathMapFlags {
        guard radius > 0 else {
            return blocked(at: point, radius: 0, treatActorsAsBlocking: treatActorsAsBlocking)
        }

        let minCell = cell(for: CGPoint(x: point.x - radius, y: point.y - radius))
        let maxCell = cell(for: CGPoint(x: point.x + radius, y: point.y + radius))
        var combined: PathMapFlags = [.passable]
        var sawImpassable = false
        let radiusSquared = radius * radius

        for column in minCell.column...maxCell.column {
            for row in minCell.row...maxCell.row {
                let candidate = SearchMapCell(column: column, row: row)
                guard contains(candidate) else {
                    sawImpassable = true
                    continue
                }
                let center = center(of: candidate)
                let dx = center.x - point.x
                let dy = center.y - point.y
                guard dx * dx + dy * dy <= radiusSquared else { continue }

                var flags = flags(at: candidate)
                if !treatActorsAsBlocking {
                    flags.subtract(.actor)
                }
                if !isTerrainPassable(flags) || (treatActorsAsBlocking && containsActor(flags)) {
                    sawImpassable = true
                }
                combined.formUnion(flags)
            }
        }

        if sawImpassable {
            combined.remove(.passable)
        }
        return combined
    }

    /// Bresenham / supercover line test used by Theta* LOS and walkability.
    func blockedInLine(
        from start: CGPoint,
        to end: CGPoint,
        radius: CGFloat = 0,
        treatActorsAsBlocking: Bool = false,
        stopOnImpassable: Bool = true
    ) -> PathMapFlags {
        guard contains(start), contains(end) else { return [] }

        // World-resolution obstacle segment test (navmap fidelity).
        if segmentCrossesStaticObstacle(from: start, to: end) {
            return []
        }
        if doorObstacles.contains(where: { door in
            guard let rect = door.activeRect else { return false }
            return segmentIntersectsInterior(from: start, to: end, of: rect)
        }) {
            return []
        }

        let length = hypot(end.x - start.x, end.y - start.y)
        let step = max(1, min(cellSize.width, cellSize.height) * 0.25)
        let samples = max(1, Int(ceil(length / step)))
        var combined: PathMapFlags = [.passable]

        for sample in 0...samples {
            let t = CGFloat(sample) / CGFloat(samples)
            let point = CGPoint(
                x: start.x + (end.x - start.x) * t,
                y: start.y + (end.y - start.y) * t
            )
            let flags = blocked(
                at: point,
                radius: radius,
                treatActorsAsBlocking: treatActorsAsBlocking
            )
            if !isTerrainPassable(flags) || (treatActorsAsBlocking && containsActor(flags)) {
                if stopOnImpassable {
                    return flags.subtracting(.passable)
                }
            }
            combined.formUnion(flags)
        }
        return combined
    }

    func isWalkableLine(
        from start: CGPoint,
        to end: CGPoint,
        radius: CGFloat = 0,
        treatActorsAsBlocking: Bool = false
    ) -> Bool {
        // `blockedInLine` already samples the same actor-radius disc against
        // both static and door obstacles. Repeating that pass here doubled the
        // dominant cost of every Lazy Theta* visibility check.
        let flags = blockedInLine(
            from: start,
            to: end,
            radius: radius,
            treatActorsAsBlocking: treatActorsAsBlocking,
            stopOnImpassable: true
        )
        return isTerrainPassable(flags) && !(treatActorsAsBlocking && containsActor(flags))
    }

    /// World-resolution solid test, static rectangles and active door leaves.
    ///
    /// Not a GemRB concept — BG areas are authored against the raster, so cell
    /// tests suffice there. Our solids are finer than a cell, so every line
    /// query runs this first.
    func segmentCrossesObstacle(from start: CGPoint, to end: CGPoint) -> Bool {
        if segmentCrossesStaticObstacle(from: start, to: end) {
            return true
        }
        return doorObstacles.contains { door in
            guard let rect = door.activeRect else { return false }
            return segmentIntersectsInterior(from: start, to: end, of: rect)
        }
    }

    /// GemRB `PathFinder::GetBlockedInLine` — the same `LineStepper`, walked in
    /// **world units** rather than in cells.
    ///
    /// The only difference from the tile-space sibling is the factor: `StepTime
    /// / walkScale`, without the further divide by the cell width. That is what
    /// makes this one sample every cell the line crosses. The tile-space walk
    /// advances a whole cell per step and ceils each axis independently, so a
    /// diagonal run goes corner to corner and never looks at the two cells
    /// between — harmless for line of sight, where the engine uses it, and not
    /// harmless for `IsWalkableTo`, where the cell it steps over is a desk.
    ///
    /// The start cell is skipped for the whole walk, not just on the first
    /// step: an actor standing on a spot is not an obstacle to leaving it.
    ///
    /// GemRB factors the walk itself into a `LineStepper` template shared with
    /// the tile-space sibling below. Both copies are inlined here instead: they
    /// run once per Theta\* child expansion, and in a `-Onone` test build the
    /// extra call frame per world step costs more than the duplication does.
    func blockedInLine(
        from start: CGPoint,
        to end: CGPoint,
        size: Int,
        stopOnImpassable: Bool = true,
        walkScale: CGFloat = ActorLocomotionPacing.infinityEngineWalkScale
    ) -> PathMapFlags {
        var ret: PathMapFlags = .impassable
        let startCell = cell(for: start)
        let factor = walkScale > 0
            ? ActorLocomotionPacing.infinityEngineStepTime / walkScale
            : 1

        var current = start.rounded
        let target = end.rounded
        var lastProbed = startCell
        // Bounded so a degenerate factor cannot spin: each step advances at
        // least one whole unit on the longer axis.
        let limit = Int(max(abs(target.x - current.x), abs(target.y - current.y))) + 2
        var steps = 0

        while current != target && steps <= limit {
            steps += 1
            var dx = target.x - current.x
            var dy = target.y - current.y
            PathFinder.normalizeDeltas(&dx, &dy, factor: factor)
            if dx == 0 && dy == 0 { break }
            current = CGPoint(x: current.x + dx, y: current.y + dy)

            let probe = cell(for: current)
            // One engine step is a few world units and a cell is 16x12, so
            // consecutive steps usually land in the same cell. Re-reading it
            // changes nothing — the accumulate is a union and the impassable
            // test is a pure function of the cell — and it is most of the work.
            if probe == startCell || probe == lastProbed { continue }
            lastProbed = probe
            // A wider check for bigger actors; `blockedInRadiusTile` clamps the
            // size to 2, so for a small body this is the plain single-cell read.
            let blockStatus = stopOnImpassable
                ? blockedInRadiusTile(at: probe, size: size)
                : blockedTile(at: probe)
            if stopOnImpassable, blockStatus == .impassable {
                return .impassable
            }
            ret.formUnion(blockStatus)
        }

        if !ret.isDisjoint(with: [.doorImpassable, .actor, .sidewall]) {
            ret.remove(.passable)
        }
        if ret.contains(.doorOpaque) {
            ret = .sidewall
        }
        return ret
    }

    /// GemRB `PathFinder::LineStepper` in search-cell space.
    ///
    /// The line is not rasterised with Bresenham; it is *walked* with the same
    /// `NormalizeDeltas` the actor walks with, re-normalised each step. The
    /// `factor` is what makes the stride one cell: `StepTime / walkScale`
    /// converts to units per tick, and dividing by the cell width converts that
    /// to cells.
    func blockedInLineTile(
        from start: SearchMapCell,
        to end: SearchMapCell,
        size: Int,
        stopOnImpassable: Bool = true,
        walkScale: CGFloat = ActorLocomotionPacing.infinityEngineWalkScale
    ) -> PathMapFlags {
        var ret: PathMapFlags = .impassable
        let factor = walkScale > 0
            ? ActorLocomotionPacing.infinityEngineStepTime / walkScale / cellSize.width
            : 1

        var current = start
        // Bounded so a degenerate factor cannot spin: the walk covers at most
        // the Chebyshev span, one cell at a time.
        let limit = max(
            abs(end.column - start.column),
            abs(end.row - start.row)
        ) + 2
        var steps = 0

        while current != end && steps <= limit {
            steps += 1
            var dx = CGFloat(end.column - current.column)
            var dy = CGFloat(end.row - current.row)
            PathFinder.normalizeDeltas(&dx, &dy, factor: factor)
            if dx == 0 && dy == 0 { break }
            current = SearchMapCell(
                column: current.column + Int(dx),
                row: current.row + Int(dy)
            )
            if current == start { continue }

            // A wider check for bigger actors; for circleSize <= 2 this is the
            // plain single-cell read. Never used for line of sight.
            let blockStatus = (stopOnImpassable && size > 2)
                ? blockedInRadiusTile(at: current, size: size)
                : blockedTile(at: current)
            if stopOnImpassable, blockStatus == .impassable {
                return .impassable
            }
            ret.formUnion(blockStatus)
        }

        if !ret.isDisjoint(with: [.doorImpassable, .actor, .sidewall]) {
            ret.remove(.passable)
        }
        if ret.contains(.doorOpaque) {
            ret = .sidewall
        }
        return ret
    }

    // MARK: - Stamping

    /// Stamp or clear door cells for the registered door obstacles.
    ///
    /// Sight is stamped with the leaf rather than baked into the painted terrain,
    /// which is the whole point: a door baked as a solid would block sight while
    /// standing open, and a door baked as floor would never block it at all.
    func stampDoors(blocking: Bool) {
        for index in doorObstacles.indices {
            doorObstacles[index].isOpen = !blocking
        }
        restampDoors()
    }

    func setDoorObstacles(_ doors: [DoorObstacle], blocking: Bool) {
        clearDoorFlags()
        doorObstacles = doors.map(\.standardized)
        stampDoors(blocking: blocking)
    }

    /// Open or shut one door by id and restamp only that leaf's cells.
    func setDoor(id: String, open: Bool) {
        guard let index = doorObstacles.firstIndex(where: { $0.id == id }) else { return }
        doorObstacles[index].isOpen = open
        restampDoors()
    }

    func restampDoors() {
        clearDoorFlags()
        for door in doorObstacles {
            stampDoor(door)
        }
    }

    /// Whether a closed door stops sight at this cell.
    func doorBlocksSight(at cell: SearchMapCell) -> Bool {
        flags(at: cell).contains(.doorOpaque)
    }

    /// GemRB `PathMapFlags::DOOR_IMPASSABLE`. A closed door always blocks
    /// movement; whether it also blocks sight is a separate authored flag.
    func doorBlocksMovement(at cell: SearchMapCell) -> Bool {
        flags(at: cell).contains(.doorImpassable)
    }


    func clearActorFlags() {
        for index in cells.indices {
            cells[index] &= ~PathMapFlags.actor.rawValue
        }
    }

    // MARK: - Private

    private func index(of cell: SearchMapCell) -> Int {
        cell.row * columns + cell.column
    }

    private func clearDoorFlags() {
        let mask = ~(PathMapFlags.doorImpassable.rawValue | PathMapFlags.doorOpaque.rawValue)
        for index in cells.indices {
            cells[index] &= mask
        }
    }

    private func stampDoor(_ door: DoorObstacle) {
        let cells = door.isOpen ? door.openCells : door.closedCells
        let blockSight = !door.isOpen && door.blocksSight
        if cells.isEmpty {
            if let rect = door.activeRect {
                stamp(rect: rect, flag: .doorImpassable, set: true)
                if blockSight {
                    stamp(rect: rect, flag: .doorOpaque, set: true)
                }
            }
            return
        }
        for cell in cells {
            stamp(cell: cell, flag: .doorImpassable, set: true)
            if blockSight {
                stamp(cell: cell, flag: .doorOpaque, set: true)
            }
        }
    }

    private func stamp(cell: SearchMapCell, flag: PathMapFlags, set: Bool) {
        guard contains(cell) else { return }
        let idx = index(of: cell)
        if set {
            cells[idx] |= flag.rawValue
        } else {
            cells[idx] &= ~flag.rawValue
        }
    }

    /// Burn the authored solids into the raster **conservatively**: a cell is
    /// impassable when an obstacle overlaps it at all, not when it happens to
    /// cover the cell's centre.
    ///
    /// This is what makes a literal GemRB port safe. A BG `SR` bitmap is
    /// authored *at* cell resolution — a painter marks every cell a wall touches
    /// — so the engine can afford to ask nothing finer than `GetBlockedTile`.
    /// Centre sampling under-covers every solid by up to half a cell, and a
    /// solid narrower than 16x12 that misses the centres marks nothing at all.
    /// RainShadow used to paper over that with a world-space AABB test layered
    /// on top of each cell query; the raster now carries the truth by itself,
    /// which is the engine's own arrangement.
    ///
    /// The cost is that solids fatten by up to a cell. That is a rect-authoring
    /// constraint, not something to compensate for downstream.
    private func rasterizeStaticObstacles() {
        for column in 0..<columns {
            for row in 0..<rows {
                let cell = SearchMapCell(column: column, row: row)
                let idx = index(of: cell)
                // Cells past the world bounds exist only because the raster is
                // rounded up to whole cells; the boundary is solid.
                if !contains(center(of: cell)) {
                    cells[idx] = 0
                    terrainIndices[idx] = SearchMapTerrain.obstacle.rawValue
                } else {
                    cells[idx] = PathMapFlags.passable.rawValue
                    terrainIndices[idx] = defaultTerrain.rawValue
                }
            }
        }

        for obstacle in staticObstacles {
            forEachCell(overlapping: obstacle) { cell in
                let idx = index(of: cell)
                cells[idx] = 0
                terrainIndices[idx] = SearchMapTerrain.obstacle.rawValue
            }
        }
    }

    /// Mark the authored solids over a raster that already carries painted
    /// terrain, without disturbing the terrain anywhere else.
    ///
    /// `rasterizeStaticObstacles` builds a raster from nothing; this one folds
    /// rectangles into a raster somebody painted. Both mark the same cells.
    /// A rectangle listed as sight-permeable bakes as index 8 rather than index
    /// 0 — it stops a body and passes a look, which is what furniture does. The
    /// office is why the distinction exists: bake its desks opaque and standing
    /// in the doorway lights a ragged sliver of the room instead of the room.
    ///
    /// A cell the painted map already calls unwalkable keeps the class it was
    /// painted with. The burn only ever *adds* blocking, so authored roofs,
    /// water and world-map exits — terrain classes no rectangle can express —
    /// survive a rectangle drawn across them.
    private func burnStaticObstaclesIntoRaster(sightPermeable: [CGRect]) {
        let permeable = sightPermeable.map(\.standardized)
        for obstacle in staticObstacles {
            let isPermeable = permeable.contains { rectsApproximatelyEqual($0, obstacle) }
            let terrain: SearchMapTerrain = isPermeable ? .obstacleSeeThrough : .obstacle
            forEachCell(overlapping: obstacle) { cell in
                let idx = index(of: cell)
                guard SearchMapTerrain.decode(terrainIndices[idx]).isWalkable else { return }
                terrainIndices[idx] = terrain.rawValue
                cells[idx] = terrain.areaFlags.rawValue
            }
        }
    }

    /// Every cell whose footprint overlaps `rect` with positive area.
    ///
    /// Edge contact does not count: `CGRect.intersects` is false for a
    /// zero-area intersection, so a solid ending exactly on a cell boundary
    /// does not claim the cell beyond it.
    private func forEachCell(overlapping rect: CGRect, _ body: (SearchMapCell) -> Void) {
        let bounds = rect.standardized
        guard !bounds.isNull, bounds.width > 0, bounds.height > 0 else { return }

        let minCell = cell(for: CGPoint(x: bounds.minX, y: bounds.minY))
        let maxCell = cell(for: CGPoint(x: bounds.maxX, y: bounds.maxY))
        let firstColumn = max(0, minCell.column)
        let lastColumn = min(columns - 1, maxCell.column)
        let firstRow = max(0, minCell.row)
        let lastRow = min(rows - 1, maxCell.row)
        guard firstColumn <= lastColumn, firstRow <= lastRow else { return }

        for column in firstColumn...lastColumn {
            for row in firstRow...lastRow {
                let candidate = SearchMapCell(column: column, row: row)
                guard self.rect(of: candidate).intersects(bounds) else { continue }
                body(candidate)
            }
        }
    }

    /// Stamp a door leaf, conservatively — see `rasterizeStaticObstacles`.
    ///
    /// Centre sampling here meant a closed leaf thinner than a cell stamped
    /// nothing at all, so the door read as open to every cell query.
    private func stamp(rect: CGRect, flag: PathMapFlags, set: Bool) {
        forEachCell(overlapping: rect) { candidate in
            let idx = index(of: candidate)
            if set {
                cells[idx] |= flag.rawValue
            } else {
                cells[idx] &= ~flag.rawValue
            }
        }
    }

    private func stamp(circleAt point: CGPoint, radius: CGFloat, flag: PathMapFlags, set: Bool) {
        let minCell = cell(for: CGPoint(x: point.x - radius, y: point.y - radius))
        let maxCell = cell(for: CGPoint(x: point.x + radius, y: point.y + radius))
        let radiusSquared = radius * radius
        for column in minCell.column...maxCell.column {
            for row in minCell.row...maxCell.row {
                let candidate = SearchMapCell(column: column, row: row)
                guard contains(candidate) else { continue }
                let center = center(of: candidate)
                let dx = center.x - point.x
                let dy = center.y - point.y
                guard dx * dx + dy * dy <= radiusSquared else { continue }
                let idx = index(of: candidate)
                if set {
                    cells[idx] |= flag.rawValue
                } else {
                    cells[idx] &= ~flag.rawValue
                }
            }
        }
    }

    private func segmentCrossesStaticObstacle(from start: CGPoint, to end: CGPoint) -> Bool {
        let bounds = CGRect(
            x: min(start.x, end.x),
            y: min(start.y, end.y),
            width: max(abs(end.x - start.x), 0.001),
            height: max(abs(end.y - start.y), 0.001)
        )
        return staticObstacleIndices(intersecting: bounds).contains {
            segmentIntersectsInterior(from: start, to: end, of: staticObstacles[$0])
        }
    }

    private func rebuildStaticObstacleBuckets() {
        obstacleBucketSize = CGSize(
            width: cellSize.width * 8,
            height: cellSize.height * 8
        )
        obstacleBucketColumns = max(
            1, Int(ceil(worldBounds.width / obstacleBucketSize.width))
        )
        obstacleBucketRows = max(
            1, Int(ceil(worldBounds.height / obstacleBucketSize.height))
        )
        staticObstacleBuckets = Array(
            repeating: [],
            count: obstacleBucketColumns * obstacleBucketRows
        )
        for (index, obstacle) in staticObstacles.enumerated() {
            for bucket in obstacleBucketIndices(intersecting: obstacle) {
                staticObstacleBuckets[bucket].append(index)
            }
        }
    }

    private func staticObstacleIndices(near point: CGPoint, radius: CGFloat) -> [Int] {
        staticObstacleIndices(
            intersecting: CGRect(
                x: point.x - radius,
                y: point.y - radius,
                width: max(radius * 2, 0.001),
                height: max(radius * 2, 0.001)
            )
        )
    }

    private func staticObstacleIndices(intersecting rect: CGRect) -> [Int] {
        let buckets = obstacleBucketIndices(intersecting: rect)
        if buckets.count == 1 {
            return staticObstacleBuckets[buckets[0]]
        }
        var result: [Int] = []
        var seen = Set<Int>()
        for bucket in buckets {
            for index in staticObstacleBuckets[bucket] where seen.insert(index).inserted {
                result.append(index)
            }
        }
        return result
    }

    private func obstacleBucketIndices(intersecting rect: CGRect) -> [Int] {
        guard obstacleBucketSize.width > 0, obstacleBucketSize.height > 0 else { return [] }
        let bounds = rect.standardized
        let minColumn = min(
            obstacleBucketColumns - 1,
            max(0, Int(floor((bounds.minX - origin.x) / obstacleBucketSize.width)))
        )
        let maxColumn = min(
            obstacleBucketColumns - 1,
            max(0, Int(floor((bounds.maxX - origin.x) / obstacleBucketSize.width)))
        )
        let minRow = min(
            obstacleBucketRows - 1,
            max(0, Int(floor((bounds.minY - origin.y) / obstacleBucketSize.height)))
        )
        let maxRow = min(
            obstacleBucketRows - 1,
            max(0, Int(floor((bounds.maxY - origin.y) / obstacleBucketSize.height)))
        )
        var result: [Int] = []
        result.reserveCapacity((maxColumn - minColumn + 1) * (maxRow - minRow + 1))
        for row in minRow...maxRow {
            for column in minColumn...maxColumn {
                result.append(row * obstacleBucketColumns + column)
            }
        }
        return result
    }

    /// Exact segment/rectangle clipping. A tiny inset keeps merely touching an
    /// authored obstacle edge legal (same rule as the prior NavigationGrid).
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
}

// MARK: - Cell-space actor footprints (BG:EE personal space)

/// BG:EE keeps two different sizes for one body and the gap between them is
/// deliberate. `TileProps::PaintSearchMap` marks a filled disc of radius
/// `personalSpace - 1` **search-map cells**, while `Map::GetBlockedInRadiusTile`
/// only tests `personalSpace - 2`, with the engine's own comment explaining why:
///
/// > Note: this is a larger circle than the one tested in GetBlocked. This means
/// > that an actor can get closer to a wall than to another actor. This matches
/// > the behaviour of the original BG2.
///
/// That asymmetry is the mechanical reason BG characters brush along walls but
/// keep a wide berth around each other, and it is the half of the footprint
/// model RainShadow was missing — a single radius gave walls and bodies the same
/// clearance.
///
/// Both discs are plotted in **cell** space, not world space, so a 16×12 cell
/// makes the footprint a 4:3 ellipse on screen. That is BG's shape too, and it
/// matters here: a body is wider than it is deep in a dimetric view, so a
/// world-space circle over-reserves depth and under-reserves width.
///
/// Static clearance against painted obstacle geometry is deliberately *not*
/// routed through here — it stays on the tuned world-unit
/// `NavigationAgentProfile` radius. See `Documentation/PathfindingSystem.md`.
extension SearchMap {
    /// `MAX_CIRCLESIZE` (`core/TileProps.h`).
    static let maxCircleSize = 8

    /// GemRB `PlotCircle` (`core/Geometry.cpp`) — second-order Bresenham,
    /// emitting points in octant order.
    ///
    /// The order is the contract: consecutive pairs are the right and left
    /// endpoints of one scanline, which is what lets the callers below fill a
    /// disc by scanning `p2.x ... p1.x` at `p1.y`. Rows repeat across
    /// iterations; every consumer is idempotent or OR-accumulating, so that is
    /// harmless.
    /// `plotCircle` about the origin, memoised.
    ///
    /// Every clearance query walks one of these discs, and the Theta* line walk
    /// runs one clearance query per world step, so building the scanline list
    /// per call was the pathfinder's dominant allocation. The radius is bounded
    /// by `maxCircleSize`, so the whole table is a handful of small arrays.
    static func circleOffsets(radius: Int) -> [SearchMapCell] {
        precondition(radius >= 0)
        if radius < offsetCache.count { return offsetCache[radius] }
        return plotCircle(origin: SearchMapCell(column: 0, row: 0), radius: radius)
    }

    private static let offsetCache: [[SearchMapCell]] = (0...maxCircleSize).map { radius in
        plotCircle(origin: SearchMapCell(column: 0, row: 0), radius: radius)
    }

    static func plotCircle(origin: SearchMapCell, radius: Int) -> [SearchMapCell] {
        var points: [SearchMapCell] = []
        points.reserveCapacity(max(8, 6 * radius))

        func generateOctants(_ x: Int, _ y: Int) {
            points.append(SearchMapCell(column: origin.column + y, row: origin.row + x))
            points.append(SearchMapCell(column: origin.column - y, row: origin.row + x))
            points.append(SearchMapCell(column: origin.column + x, row: origin.row + y))
            points.append(SearchMapCell(column: origin.column - x, row: origin.row + y))
            points.append(SearchMapCell(column: origin.column + x, row: origin.row - y))
            points.append(SearchMapCell(column: origin.column - x, row: origin.row - y))
            points.append(SearchMapCell(column: origin.column + y, row: origin.row - x))
            points.append(SearchMapCell(column: origin.column - y, row: origin.row - x))
        }

        var x = 0
        var y = radius
        var fm = 1 - radius
        var de = 3
        var dse = -2 * radius + 5

        generateOctants(x, y)
        while x < y {
            if fm <= 0 {
                fm += de
            } else {
                fm += dse
                dse += 2
                y -= 1
            }
            de += 2
            dse += 2
            x += 1
            generateOctants(x, y)
        }
        return points
    }

    /// GemRB `PathFinder::GetBlockedTile` — the single-cell read every other
    /// blocking query is built on.
    ///
    /// Note the order: `TRAVEL` implies passable (an area-transition cell is
    /// floor you can step onto), a door or an actor takes passability away, and
    /// an opaque door collapses the whole answer to `SIDEWALL`.
    func blockedTile(at cell: SearchMapCell) -> PathMapFlags {
        var ret = flags(at: cell)
        if ret.contains(.travel) {
            ret.insert(.passable)
        }
        if !ret.isDisjoint(with: [.doorImpassable, .actor]) {
            ret.remove(.passable)
        }
        if ret.contains(.doorOpaque) {
            ret = .sidewall
        }
        return ret
    }

    /// GemRB `PathFinder::GetBlockedInRadiusTile` — clearance over a disc of
    /// radius `size - 2` search cells.
    ///
    /// The radius is deliberately two smaller than the one `paintSearchMap`
    /// stamps. The engine explains itself: *"this is a larger circle than the
    /// one tested in GetBlocked. This means that an actor can get closer to a
    /// wall than to another actor. This matches the behaviour of the original
    /// BG2."* That asymmetry is why BG characters brush along walls but keep a
    /// wide berth around each other.
    func blockedInRadiusTile(
        at cell: SearchMapCell,
        size: Int,
        stopOnImpassable: Bool = true
    ) -> PathMapFlags {
        var ret: PathMapFlags = .impassable
        let clamped = min(max(size, 2), Self.maxCircleSize)
        let radius = clamped - 2

        // r == 0 would emit sixteen copies of one point; the engine short-cuts
        // it, and so does this — the disc is the single cell. Worth spelling out
        // rather than folding into the loop below: it is the common case, it is
        // on the Theta* line walk, and the loop form allocates.
        if radius == 0 {
            let flags = blockedTile(at: cell)
            if stopOnImpassable, flags == .impassable {
                return .impassable
            }
            ret = flags
        } else {
            let offsets = Self.circleOffsets(radius: radius)
            var index = 0
            while index + 1 < offsets.count {
                let right = offsets[index]
                let left = offsets[index + 1]
                index += 2
                guard left.column <= right.column else { continue }
                let row = cell.row + right.row
                for column in (cell.column + left.column)...(cell.column + right.column) {
                    let flags = blockedTile(at: SearchMapCell(column: column, row: row))
                    if stopOnImpassable, flags == .impassable {
                        return .impassable
                    }
                    ret.formUnion(flags)
                }
            }
        }

        if !ret.isDisjoint(with: [.doorImpassable, .actor, .sidewall]) {
            ret.remove(.passable)
        }
        if ret.contains(.doorOpaque) {
            ret = .sidewall
        }
        return ret
    }

    /// GemRB `TileProps::PaintSearchMap` — stamp an actor over a disc of radius
    /// `blockSize - 1` search cells. Passing an empty `value` lifts the stamp,
    /// which is how the engine's `ClearSearchMapFor` works.
    ///
    /// Only walkable terrain can carry an actor mark. The engine's reasoning:
    /// marking a wall as occupied is wrong and buys nothing, and a reader that
    /// accepts a tile on its `ACTOR` bit would then see a hole in the wall
    /// wherever the circle spilled onto it.
    func paintSearchMap(at cell: SearchMapCell, blockSize: Int, value: PathMapFlags) {
        let clamped = min(max(blockSize, 1), Self.maxCircleSize)
        let radius = clamped - 1
        let points = Self.plotCircle(origin: cell, radius: radius)

        var index = 0
        while index + 1 < points.count {
            let right = points[index]
            let left = points[index + 1]
            index += 2
            guard left.column <= right.column else { continue }
            for column in left.column...right.column {
                let probe = SearchMapCell(column: column, row: right.row)
                guard contains(probe) else { continue }
                let idx = self.index(of: probe)
                let current = PathMapFlags(rawValue: cells[idx])
                guard !current.isDisjoint(with: [.passable, .travel]) else { continue }
                cells[idx] = (current.intersection(.notActor).union(value)).rawValue
            }
        }
    }

    /// Convenience wrappers in world space, for callers that hold a point.
    func paintSearchMap(at point: CGPoint, blockSize: Int, value: PathMapFlags) {
        paintSearchMap(at: cell(for: point), blockSize: blockSize, value: value)
    }

    func blockedInRadiusTile(
        at point: CGPoint,
        size: Int,
        stopOnImpassable: Bool = true
    ) -> PathMapFlags {
        blockedInRadiusTile(at: cell(for: point), size: size, stopOnImpassable: stopOnImpassable)
    }

    /// True when no actor's stamp overlaps the clearance disc around `point`.
    func isClearOfActors(at point: CGPoint, personalSpaceCells: Int) -> Bool {
        blockedInRadiusTile(
            at: point,
            size: personalSpaceCells,
            stopOnImpassable: false
        ).isDisjoint(with: .actor)
    }
}

/// Authored rectangles are matched by value, the way the bake matches them:
/// `sightPermeableObstacles` repeats the rectangle rather than referencing it.
private func rectsApproximatelyEqual(_ a: CGRect, _ b: CGRect) -> Bool {
    abs(a.origin.x - b.origin.x) < 0.001
        && abs(a.origin.y - b.origin.y) < 0.001
        && abs(a.size.width - b.size.width) < 0.001
        && abs(a.size.height - b.size.height) < 0.001
}
