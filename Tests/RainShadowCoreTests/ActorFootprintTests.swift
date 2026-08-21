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
        // `SearchMapFlags.actor` is a two-bit mask and `OptionSet.contains` is a
        // superset test, so `contains(.actor)` asks "player AND npc on this cell",
        // which never happens. Every actor-blocking query read it that way, so
        // occupancy was stamped and never honoured. Guard the fix.
        let map = makeMap()
        let at = CGPoint(x: 320, y: 240)
        map.registerActor(id: "npc", kind: .npc, at: at, isMoving: false)

        let flags = map.searchMap.flags(at: at)
        #expect(flags.contains(.npcActor))
        #expect(map.searchMap.containsActor(flags))
        #expect(!map.searchMap.isPassable(at: at, treatActorsAsBlocking: true))
        #expect(map.searchMap.isPassable(at: at, treatActorsAsBlocking: false))
    }

    @Test func stampCoversACellDiscAndSkipsImpassableCells() {
        let wall = CGRect(x: 336, y: 200, width: 160, height: 160)
        let map = makeMap(obstacles: [wall])
        let at = CGPoint(x: 320, y: 240)
        let disc = map.searchMap.cellsInDisc(
            around: at,
            radiusInCells: ActorLocomotionPacing.personalSpaceCells - 1
        )
        map.registerActor(id: "npc", kind: .npc, at: at, isMoving: false)

        let painted = disc.filter { map.searchMap.containsActor(map.searchMap.flags(at: $0)) }
        // Some of the disc lands in the wall and must be skipped (PaintIfPassable),
        // but the free side must be claimed.
        #expect(painted.count > 0)
        #expect(painted.count < disc.count)
        #expect(painted.allSatisfy { map.searchMap.isTerrainPassable(map.searchMap.flags(at: $0)) })
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

    @Test func actorFootprintDoesNotChangeStaticReachability() {
        // Static clearance is deliberately left on the tuned world-unit profile,
        // so these counts must be byte-identical to the pre-change baseline.
        // The reference-faithful V12 office measures 1,610 reachable cells
        // after the records and personal furniture moved fully onto the floor.
        // Door state must not fragment that interior component.
        for doorBlocking in [true, false] {
            let map = OfficeNavigationLayout.makeGrid(entranceDoorBlocking: doorBlocking)
            #expect(
                reachableCells(
                    map,
                    from: OfficeNavigationLayout.actorStart,
                    radius: NavigationAgentProfile.officeDetective.radius
                ) == 1_610,
                "office reachability changed with entranceDoorBlocking: \(doorBlocking)"
            )
        }
    }

    /// Re-anchored when the districts moved onto the painted block lattice.
    ///
    /// The old baselines measured the `WardBlocks` 2x2 grid, which blocked four
    /// axis-aligned rects that matched nothing on any plate. Four districts now
    /// share a count because they share the lattice and differ only in what
    /// stands on it; Riverside is lower because the river takes its bottom
    /// strip, and Wharf Ladder is lower because the docks waterfront is a
    /// full-width fade rather than a corner puddle. What this test is for
    /// is unchanged: a move here that nobody intended means footprint or
    /// clearance work has leaked into geometry.
    @Test func cityFootprintDoesNotChangeStaticReachability() {
        let districtBaselines: [CityDistrictID: Int] = [
            .sableRow: 21_296,
            .wharfLadder: 18_629,
            .riverside: 18_961,
            .harborpointPD: 21_296,
            .lilaStreet: 21_296,
            .civicRecords: 21_296,
        ]
        for id in CityDistrictID.allCases {
            let district = CityDistrictCatalog.definition(for: id)
            let map = district.makeGrid()
            let reachable = reachableCells(
                map,
                from: district.actorStart,
                radius: NavigationAgentProfile.detective.radius
            )
            #expect(reachable == districtBaselines[id], "\(id) reachability moved to \(reachable)")
        }
    }

    @Test func occupiedOfficeStillReachesEveryApproach() {
        // With a body in the room, planning *around* it legitimately fails for
        // some approaches — BG bumps constantly indoors. What must never happen
        // is an approach becoming unreachable, because scenes issue them with
        // `requiresExactDestination` and refuse a snapped substitute.
        let map = OfficeNavigationLayout.makeGrid(entranceDoorBlocking: true)
        let start = OfficeNavigationLayout.actorStart
        for clientAt in OfficeNavigationLayout.clientArrivalPath.suffix(2) {
            map.unregisterActor(id: "client")
            map.registerActor(id: "client", kind: .npc, at: clientAt, isMoving: false)
            for (id, approach) in OfficeNavigationLayout.approachPoints {
                #expect(
                    map.path(from: start, to: approach) != nil,
                    "\(id) unreachable with the client standing at \(clientAt)"
                )
            }
        }
    }

    // MARK: - Helpers

    private func reachableCells(_ map: NavigationMap, from start: CGPoint, radius: CGFloat) -> Int {
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
                      search.isPassable(at: search.center(of: next), radius: radius)
                else { continue }
                visited.insert(next)
                queue.append(next)
            }
        }
        return visited.count
    }
}
