import CoreGraphics
import Foundation

/// One search-map cell, matching Infinity Engine / BG:EE search-map indexing.
struct SearchMapCell: Hashable, Sendable {
    let column: Int
    let row: Int
}

/// Per-cell flags mirroring GemRB `PathMapFlags` for the subset RainShadow needs.
struct SearchMapFlags: OptionSet, Hashable, Sendable {
    let rawValue: UInt8

    init(rawValue: UInt8) {
        self.rawValue = rawValue
    }

    /// Cell is walkable terrain (set at rasterization for open floor).
    static let passable = SearchMapFlags(rawValue: 1 << 0)
    /// Closed / blocking door leaf stamped at runtime.
    static let doorImpassable = SearchMapFlags(rawValue: 1 << 1)
    /// A closed door leaf that also stops sight.
    ///
    /// Separate from `doorImpassable` because the Infinity Engine keeps the two
    /// separate: a door's impeded cells stop movement, and door flag bit 9
    /// ("Don't block line of sight") decides independently whether sight passes.
    /// A beaded curtain stops neither, a portcullis stops feet only, and the
    /// default — what every RainShadow door is — stops both.
    static let doorSightBlocking = SearchMapFlags(rawValue: 1 << 4)
    /// Player character occupancy stamp.
    static let playerActor = SearchMapFlags(rawValue: 1 << 2)
    /// NPC occupancy stamp.
    static let npcActor = SearchMapFlags(rawValue: 1 << 3)

    static let actor: SearchMapFlags = [.playerActor, .npcActor]
    /// Area terrain bits that survive actor/door restamps.
    static let areaMask: SearchMapFlags = [.passable]
}

/// A door leaf registered with the map, so it can be stamped and cleared in
/// place without rebuilding the grid.
///
/// The Infinity Engine gives a door two separate cell blocks — impeded when open
/// and impeded when closed — and a flag deciding whether it blocks line of sight.
/// RainShadow's doors carry one rect and toggle it, which is the same mechanism
/// with the open block empty; `blocksSight` is IE's flag bit 9 inverted, so the
/// default matches the engine and an authored door has to opt *out*.
struct DoorObstacle: Hashable, Sendable {
    var rect: CGRect
    var blocksSight: Bool

    init(rect: CGRect, blocksSight: Bool = true) {
        self.rect = rect
        self.blocksSight = blocksSight
    }

    var standardized: DoorObstacle {
        DoorObstacle(rect: rect.standardized, blocksSight: blocksSight)
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

    /// Door leaf AABBs that can be stamped/cleared without rebuilding the map.
    private var doorObstacles: [DoorObstacle] = []

    var cellCount: Int { columns * rows }

    var impassableCellCount: Int {
        var count = 0
        for flags in cells where !isTerrainPassable(SearchMapFlags(rawValue: flags)) {
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
        self.cells = Array(repeating: SearchMapFlags.passable.rawValue, count: columns * rows)
        // An area built from AABBs has no painted terrain, so its open ground is
        // stone: the districts are paved and the office plate is boards, and the
        // office overrides this through `defaultTerrain`.
        self.terrainIndices = Array(
            repeating: defaultTerrain.rawValue,
            count: columns * rows
        )
        self.defaultTerrain = defaultTerrain
        rasterizeStaticObstacles()
        if !self.doorObstacles.isEmpty {
            stampDoors(blocking: true)
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
    /// `obstacles` and `doorObstacles` are still accepted and still honoured:
    /// Theta* line-of-sight tests them at world resolution rather than at cell
    /// resolution, and doors stamp in place. The painted map decides terrain;
    /// the rectangles remain the fine-grained solids.
    init(
        worldBounds: CGRect,
        terrainIndices: [UInt8],
        columns: Int,
        rows: Int,
        cellSize: CGSize = SearchMap.defaultCellSize,
        obstacles: [CGRect] = [],
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
            SearchMapTerrain.decode(raw).isWalkable ? SearchMapFlags.passable.rawValue : 0
        }
        if !self.doorObstacles.isEmpty {
            stampDoors(blocking: true)
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

    func flags(at cell: SearchMapCell) -> SearchMapFlags {
        guard contains(cell) else { return [] }
        return SearchMapFlags(rawValue: cells[index(of: cell)])
    }

    func flags(at point: CGPoint) -> SearchMapFlags {
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
    func isTerrainPassable(_ flags: SearchMapFlags) -> Bool {
        flags.contains(.passable) && !flags.contains(.doorImpassable)
    }

    /// True when *either* occupancy bit is set.
    ///
    /// `SearchMapFlags.actor` is a two-bit mask, and `OptionSet.contains` is a
    /// superset test — so `flags.contains(.actor)` only answers "is this cell
    /// occupied by a player **and** an NPC simultaneously", which never happens.
    /// Every actor-blocking query in this file used that test, which meant actor
    /// occupancy was stamped but never read: `treatActorsAsBlocking` was inert
    /// and the two-tier "plan around actors first" search always came back with
    /// the actor-ignoring answer. Membership has to be a disjointness test.
    func containsActor(_ flags: SearchMapFlags) -> Bool {
        !flags.isDisjoint(with: .actor)
    }

    /// Point query with optional actor radius (BG circle-size clearance).
    func blocked(
        at point: CGPoint,
        radius: CGFloat = 0,
        treatActorsAsBlocking: Bool = false
    ) -> SearchMapFlags {
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
            return staticObstacles.contains(where: { $0.contains(point) })
                || doorObstacles.contains(where: { $0.rect.contains(point) })
        }
        let probe = CGRect(
            x: point.x - radius,
            y: point.y - radius,
            width: radius * 2,
            height: radius * 2
        )
        for obstacle in staticObstacles + doorObstacles.map(\.rect) {
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
    ) -> SearchMapFlags {
        guard radius > 0 else {
            return blocked(at: point, radius: 0, treatActorsAsBlocking: treatActorsAsBlocking)
        }

        let minCell = cell(for: CGPoint(x: point.x - radius, y: point.y - radius))
        let maxCell = cell(for: CGPoint(x: point.x + radius, y: point.y + radius))
        var combined: SearchMapFlags = [.passable]
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
    ) -> SearchMapFlags {
        guard contains(start), contains(end) else { return [] }

        // World-resolution obstacle segment test (navmap fidelity).
        if segmentCrossesStaticObstacle(from: start, to: end) {
            return []
        }
        if doorObstacles.contains(where: {
            segmentIntersectsInterior(from: start, to: end, of: $0.rect)
        }) {
            return []
        }

        let length = hypot(end.x - start.x, end.y - start.y)
        let step = max(1, min(cellSize.width, cellSize.height) * 0.25)
        let samples = max(1, Int(ceil(length / step)))
        var combined: SearchMapFlags = [.passable]

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
        let length = hypot(end.x - start.x, end.y - start.y)
        let step = max(1, min(cellSize.width, cellSize.height) * 0.25)
        let samples = max(1, Int(ceil(length / step)))
        for sample in 0...samples {
            let t = CGFloat(sample) / CGFloat(samples)
            let point = CGPoint(
                x: start.x + (end.x - start.x) * t,
                y: start.y + (end.y - start.y) * t
            )
            if discOverlapsObstacle(at: point, radius: radius) {
                return false
            }
        }
        let flags = blockedInLine(
            from: start,
            to: end,
            radius: radius,
            treatActorsAsBlocking: treatActorsAsBlocking,
            stopOnImpassable: true
        )
        return isTerrainPassable(flags) && !(treatActorsAsBlocking && containsActor(flags))
    }

    // MARK: - Stamping

    /// Stamp or clear door cells for the registered door obstacles.
    ///
    /// Sight is stamped with the leaf rather than baked into the painted terrain,
    /// which is the whole point: a door baked as a solid would block sight while
    /// standing open, and a door baked as floor would never block it at all.
    func stampDoors(blocking: Bool) {
        for door in doorObstacles {
            stamp(rect: door.rect, flag: .doorImpassable, set: blocking)
            if door.blocksSight {
                stamp(rect: door.rect, flag: .doorSightBlocking, set: blocking)
            }
        }
    }

    func setDoorObstacles(_ doors: [DoorObstacle], blocking: Bool) {
        // Clear previous door stamps first.
        stampDoors(blocking: false)
        doorObstacles = doors.map(\.standardized)
        stampDoors(blocking: blocking)
    }

    /// Whether a closed door stops sight at this cell.
    func doorBlocksSight(at cell: SearchMapCell) -> Bool {
        flags(at: cell).contains(.doorSightBlocking)
    }

    func stampActor(
        at point: CGPoint,
        radius: CGFloat,
        flag: SearchMapFlags,
        set: Bool
    ) {
        precondition(flag == .playerActor || flag == .npcActor)
        stamp(circleAt: point, radius: max(radius, 1), flag: flag, set: set)
    }

    func clearActorFlags() {
        for index in cells.indices {
            cells[index] &= ~SearchMapFlags.actor.rawValue
        }
    }

    // MARK: - Private

    private func index(of cell: SearchMapCell) -> Int {
        cell.row * columns + cell.column
    }

    private func rasterizeStaticObstacles() {
        for column in 0..<columns {
            for row in 0..<rows {
                let cell = SearchMapCell(column: column, row: row)
                let point = center(of: cell)
                let idx = index(of: cell)
                if !contains(point) || staticObstacles.contains(where: { $0.contains(point) }) {
                    cells[idx] = 0
                    terrainIndices[idx] = SearchMapTerrain.obstacle.rawValue
                } else {
                    cells[idx] = SearchMapFlags.passable.rawValue
                    terrainIndices[idx] = defaultTerrain.rawValue
                }
            }
        }
    }

    private func stamp(rect: CGRect, flag: SearchMapFlags, set: Bool) {
        let bounds = rect.standardized
        let minCell = cell(for: CGPoint(x: bounds.minX, y: bounds.minY))
        let maxCell = cell(for: CGPoint(x: bounds.maxX, y: bounds.maxY))
        for column in minCell.column...maxCell.column {
            for row in minCell.row...maxCell.row {
                let candidate = SearchMapCell(column: column, row: row)
                guard contains(candidate) else { continue }
                let center = center(of: candidate)
                guard bounds.contains(center) else { continue }
                let idx = index(of: candidate)
                if set {
                    cells[idx] |= flag.rawValue
                } else {
                    cells[idx] &= ~flag.rawValue
                }
            }
        }
    }

    private func stamp(circleAt point: CGPoint, radius: CGFloat, flag: SearchMapFlags, set: Bool) {
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
        staticObstacles.contains {
            segmentIntersectsInterior(from: start, to: end, of: $0)
        }
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
    /// Cells inside a filled disc of `radiusInCells` around `point`, clipped to
    /// the map. Radius 0 is the single cell containing `point`.
    func cellsInDisc(around point: CGPoint, radiusInCells: Int) -> [SearchMapCell] {
        let origin = cell(for: point)
        guard radiusInCells > 0 else {
            return contains(origin) ? [origin] : []
        }
        var result: [SearchMapCell] = []
        result.reserveCapacity((radiusInCells * 2 + 1) * (radiusInCells * 2 + 1))
        let radiusSquared = radiusInCells * radiusInCells
        for dx in -radiusInCells...radiusInCells {
            for dy in -radiusInCells...radiusInCells {
                guard dx * dx + dy * dy <= radiusSquared else { continue }
                let candidate = SearchMapCell(column: origin.column + dx, row: origin.row + dy)
                guard contains(candidate) else { continue }
                result.append(candidate)
            }
        }
        return result
    }

    /// Paint (or lift) an actor's occupancy over a cell-space disc of radius
    /// `personalSpaceCells - 1`.
    ///
    /// Impassable cells are skipped, mirroring the engine's `PaintIfPassable`:
    /// occupancy is a claim on walkable floor, and painting it into a wall would
    /// leave an actor bit behind on a cell no one can stand in anyway.
    func stampActor(
        at point: CGPoint,
        personalSpaceCells: Int,
        flag: SearchMapFlags,
        set: Bool
    ) {
        precondition(flag == .playerActor || flag == .npcActor)
        let radius = max(0, personalSpaceCells - 1)
        for candidate in cellsInDisc(around: point, radiusInCells: radius) {
            guard isTerrainPassable(flags(at: candidate)) else { continue }
            let idx = index(of: candidate)
            if set {
                cells[idx] |= flag.rawValue
            } else {
                cells[idx] &= ~flag.rawValue
            }
        }
    }

    /// True when no *other* actor's stamp overlaps a cell-space disc of radius
    /// `personalSpaceCells - 2` around `point`.
    ///
    /// The smaller radius is what lets two bodies stand a believable distance
    /// apart rather than a full footprint apart: this disc meeting a neighbour's
    /// painted disc puts their centres `(personalSpace - 2) + (personalSpace - 1)`
    /// cells away, which for a BG humanoid is 3 cells — 48px, or 0.96 body
    /// heights.
    func isClearOfActors(at point: CGPoint, personalSpaceCells: Int) -> Bool {
        let radius = max(0, personalSpaceCells - 2)
        for candidate in cellsInDisc(around: point, radiusInCells: radius) {
            if containsActor(flags(at: candidate)) {
                return false
            }
        }
        return true
    }
}
