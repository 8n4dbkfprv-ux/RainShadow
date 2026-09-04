import CoreGraphics
import Testing
@testable import RainShadowCore

/// BG:EE personal space: a cell-space footprint that is painted wider than it is
/// tested against. See `SearchMap.stampActor` for the engine sources.
struct ActorFootprintTests {
    /// One BG screen at the engine's own cell size — big enough for two bodies.
    private func makeMap(obstacles: [CGRect] = []) -> NavigationMap {
        NavigationMap(
            origin: .zero,
            columns: 40,
            rows: 40,
            cellSize: SearchMap.defaultCellSize,
            obstacles: obstacles
        )
    }

    // MARK: - Derivation

    @Test func personalSpaceIsDerivedFromBodyHeightNotCopiedLiterally() {
        // BG's own value is 3 cells against a ~50px adult. Our cells are the same
        // 16×12 but the adult is ~70 units, so the radius scales by ~1.4.
        #expect(ActorLocomotionPacing.infinityEnginePersonalSpaceCells == 3)
        #expect(ActorLocomotionPacing.personalSpaceCells == 4)

        // The point of deriving it: separation stays near BG's 0.96 body heights.
        let separationCells = (ActorLocomotionPacing.personalSpaceCells - 2)
            + (ActorLocomotionPacing.personalSpaceCells - 1)
        let separationUnits = CGFloat(separationCells) * SearchMap.defaultCellSize.width
        let inBodyHeights = separationUnits / OfficeInteriorScale.standingAdultBodyHeight
        #expect(inBodyHeights > 0.9 && inBodyHeights < 1.3)
    }

    // MARK: - The mask bug this class exists to prevent recurring

    @Test func aSingleActorStampIsReadableAsOccupancy() {
        // `PathMapFlags.actor` is a two-bit mask and `OptionSet.contains` is a
        // superset test, so `contains(.actor)` asks "player AND npc on this cell",
        // which never happens. Every actor-blocking query read it that way, so
        // occupancy was stamped and never honoured. Guard the fix.
        let map = makeMap()
        let at = CGPoint(x: 320, y: 240)
        map.registerActor(id: "npc", kind: .npc, at: at, isMoving: false)

        let flags = map.searchMap.flags(at: at)
        #expect(flags.contains(.npc))
        #expect(map.searchMap.containsActor(flags))
        #expect(!map.searchMap.isPassable(at: at, treatActorsAsBlocking: true))
        #expect(map.searchMap.isPassable(at: at, treatActorsAsBlocking: false))
    }

    @Test func stampCoversACellDiscAndSkipsImpassableCells() {
        let wall = CGRect(x: 336, y: 200, width: 160, height: 160)
        let map = makeMap(obstacles: [wall])
        let at = CGPoint(x: 320, y: 240)
        // `TileProps::PaintSearchMap` fills a Bresenham circle of radius
        // `personal_space - 1` in scanline pairs; the disc is what it would touch
        // if nothing were in the way.
        let disc = Set(
            SearchMap.plotCircle(
                origin: map.searchMap.cell(for: at),
                radius: ActorLocomotionPacing.personalSpaceCells - 1
            )
        )
        map.registerActor(id: "npc", kind: .npc, at: at, isMoving: false)

        let painted = disc.filter { map.searchMap.containsActor(map.searchMap.flags(at: $0)) }
        // Some of the disc lands in the wall and must be skipped — the engine's
        // `PaintIfPassable` guard, which exists so a circle spilling onto a wall
        // cannot punch an actor-shaped hole in it.
        #expect(painted.count > 0)
        #expect(painted.count < disc.count)
        #expect(painted.allSatisfy { map.searchMap.isTerrainPassable(map.searchMap.flags(at: $0)) })
    }

    /// `PlotCircle` emits octant order, and both consumers depend on it:
    /// consecutive pairs are the right and left endpoints of one scanline.
    @Test func plotCircleEmitsScanlinePairs() {
        let origin = SearchMapCell(column: 20, row: 20)
        let points = SearchMap.plotCircle(origin: origin, radius: 3)
        #expect(points.count % 2 == 0)
        var index = 0
        while index + 1 < points.count {
            #expect(points[index].row == points[index + 1].row)
            #expect(points[index + 1].column <= points[index].column)
            index += 2
        }
        // Radius zero degenerates to the origin rather than spilling.
        #expect(SearchMap.plotCircle(origin: origin, radius: 0).allSatisfy { $0 == origin })
    }

    // MARK: - The asymmetry itself

    @Test func anActorMayStandCloserToAWallThanToAnotherActor() {
        // GemRB: paint radius is size-1, clearance test is size-2, and the engine
        // comments that this is why wall proximity beats body proximity.
        let space = ActorLocomotionPacing.personalSpaceCells
        let cell = SearchMap.defaultCellSize.width

        // Wall on the right; static clearance is the world-unit profile, untouched
        // by the footprint work, so a body can hug it.
        let wall = CGRect(x: 400, y: 0, width: 80, height: 480)
        let map = makeMap(obstacles: [wall])
        let hugging = CGPoint(x: 400 - NavigationAgentProfile.officeDetective.radius - 1, y: 240)
        #expect(map.searchMap.isPassable(at: hugging, radius: NavigationAgentProfile.officeDetective.radius))

        // Another body at the same distance is not allowed.
        let other = CGPoint(x: 200, y: 240)
        map.registerActor(id: "other", kind: .npc, at: other, isMoving: false)
        let sameGapAsWall = CGPoint(x: other.x + NavigationAgentProfile.officeDetective.radius + 1, y: 240)
        #expect(!map.searchMap.isClearOfActors(at: sameGapAsWall, personalSpaceCells: space))

        // Clear only once the two discs stop overlapping: test(size-2) + paint(size-1).
        let separated = CGPoint(x: other.x + CGFloat((space - 2) + (space - 1) + 1) * cell, y: 240)
        #expect(map.searchMap.isClearOfActors(at: separated, personalSpaceCells: space))
    }

    // MARK: - Scene-scale consequences (the A1 adoption gate)

    /// Rebaselined for the literal port. Two things moved the numbers and both
    /// were intended: clearance is now `circleSize` against the raster rather
    /// than a world-unit disc, and `SearchMap` rasterises conservatively, so a
    /// solid claims every cell it touches instead of only the cells whose
    /// centres it covers. Opening the leaf still adds exactly the threshold
    /// cells the closed AABB sealed, which is the IE contract this really pins.
    @Test func officeReachabilityIsWhatTheRasterSays() {
        let expected = [true: 1_000, false: 1_020]
        for doorBlocking in [true, false] {
            let map = OfficeNavigationLayout.makeGrid(entranceDoorBlocking: doorBlocking)
            #expect(
                reachableCells(map, from: OfficeNavigationLayout.actorStart)
                    == expected[doorBlocking],
                "office reachability changed with entranceDoorBlocking: \(doorBlocking)"
            )
        }
    }

    /// Pin the runtime SR map, not the rectangle fallback. The painted map is
    /// where IE terrain indices classify roofs, water and world-map exits.
    @Test func cityReachabilityIsWhatTheRasterSays() throws {
        // Rebaselined for the literal port, same two causes as the office: the
        // flood measures `circleSize` clearance rather than a world-unit disc,
        // and the authored rectangles are now burned into the painted raster
        // conservatively instead of being tested separately at world resolution.
        // Sable Row's V15 authority relocates and refits only the office
        // aperture keep-out to its painted door; the measured raster gains
        // four reachable cells.
        let districtBaselines: [CityDistrictID: Int] = [
            .sableRow: 53_855,
            .wharfLadder: 51_472,
            .riverside: 51_490,
            .harborpointPD: 53_857,
            .lilaStreet: 53_849,
            .civicRecords: 53_857,
        ]
        for id in CityDistrictID.allCases {
            let area = try AreaCatalogLoader.load(CityDistrictAreaAdapter.areaID(for: id))
            let map = area.makeNavigationMap()
            let start = try #require(area.spawnPoint(entrance: nil))
            let reachable = reachableCells(map, from: start)
            #expect(reachable == districtBaselines[id], "\(id) reachability moved to \(reachable)")
        }
    }

    /// With a body in the room, every approach still yields a route, and it
    /// ends on the approach or in a cell touching it.
    ///
    /// It is no longer *exact*, and that is the engine. `FindPath` relocates a
    /// goal whose clearance disc reads blocked, and `GetBlockedInRadiusTile`
    /// clears `PASSABLE` wherever an actor is stamped — so a destination with
    /// somebody standing on it moves aside rather than being walked onto and
    /// bumped for. RainShadow used to tolerate an `ACTOR`-occupied goal here,
    /// which was a deliberate deviation; the literal port drops it.
    ///
    /// In practice only the shared desk/phone approach is affected, and only
    /// while the client is stamped over it: the walk ends one cell short, 17-21
    /// world units off, which is inside arm's reach. `DialogueApproach` picks
    /// from a ring of candidates and simply takes another one.
    @Test func occupiedOfficeStillReachesEveryApproach() {
        let map = OfficeNavigationLayout.makeGrid(entranceDoorBlocking: true)
        let start = OfficeNavigationLayout.actorStart
        for clientAt in OfficeNavigationLayout.clientArrivalPath.suffix(2) {
            map.unregisterActor(id: "client")
            map.registerActor(id: "client", kind: .npc, at: clientAt, isMoving: false)
            for (id, approach) in OfficeNavigationLayout.approachPoints {
                let landed = map.path(from: start, to: approach).destination
                    ?? OfficeNavigationLayout.actorStart
                let goal = map.searchMap.cell(for: approach)
                let end = map.searchMap.cell(for: landed)
                let message = "\(id) landed at \(end), not on or beside \(goal), with the client standing at \(clientAt)"
                #expect(
                    abs(end.column - goal.column) <= 1 && abs(end.row - goal.row) <= 1,
                    "\(message)"
                )
            }
        }
    }

    // MARK: - Helpers

    /// Flood the map on the clearance the engine actually uses.
    ///
    /// This used to sample a world-unit disc (`isPassable(at:radius:)`), which
    /// was the adaptation the literal port removed. `GetBlockedInRadiusTile` on
    /// `circleSize` is the only clearance question the engine asks, so it is the
    /// one this measures with.
    private func reachableCells(_ map: NavigationMap, from start: CGPoint) -> Int {
        let search = map.searchMap
        var visited = Set<SearchMapCell>()
        var queue = [search.cell(for: start)]
        visited.insert(queue[0])
        var index = 0
        while index < queue.count {
            let cell = queue[index]
            index += 1
            for (dx, dy) in [(1, 0), (0, 1), (-1, 0), (0, -1)] {
                let next = SearchMapCell(column: cell.column + dx, row: cell.row + dy)
                guard search.contains(next), !visited.contains(next),
                      search.blockedInRadiusTile(at: next, size: map.circleSize)
                          .contains(.passable)
                else { continue }
                visited.insert(next)
                queue.append(next)
            }
        }
        return visited.count
    }
}
