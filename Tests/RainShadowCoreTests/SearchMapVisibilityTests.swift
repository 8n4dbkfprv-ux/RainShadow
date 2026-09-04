import CoreGraphics
import Foundation
import Testing
@testable import RainShadowCore

/// Sight over the terrain table, which is what fog of war is filled from.
struct SearchMapVisibilityTests {
    /// A grid of `terrain` with the named cells replaced, one cell per entry.
    private func map(
        columns: Int,
        rows: Int,
        floor: SearchMapTerrain = .stone,
        blockers: [(column: Int, row: Int, terrain: SearchMapTerrain)] = []
    ) -> SearchMap {
        var indices = [UInt8](repeating: floor.rawValue, count: columns * rows)
        for blocker in blockers {
            indices[blocker.row * columns + blocker.column] = blocker.terrain.rawValue
        }
        let cell = SearchMap.defaultCellSize
        return SearchMap(
            worldBounds: CGRect(
                x: 0,
                y: 0,
                width: CGFloat(columns) * cell.width,
                height: CGFloat(rows) * cell.height
            ),
            terrainIndices: indices,
            columns: columns,
            rows: rows
        )
    }

    private func center(_ map: SearchMap, _ column: Int, _ row: Int) -> CGPoint {
        map.center(of: SearchMapCell(column: column, row: row))
    }

    /// Range is counted in search cells. GemRB walks a prefix of a midpoint
    /// circle precomputed at `MaxVisibility` 30, so a radius of 6 reaches 5
    /// cells from the origin (the last offset is `i = range - 1`). Cells are
    /// 16×12, so equal cell reach is a circle on the ground.
    @Test func rangeIsCountedInCellsSoTheLitGroundIsRound() {
        let map = map(columns: 21, rows: 21)
        let visible = map.visibleCells(from: center(map, 10, 10), radiusInCells: 6)

        #expect(visible.contains(SearchMapCell(column: 10, row: 10)))
        #expect(visible.contains(SearchMapCell(column: 15, row: 10)))
        #expect(!visible.contains(SearchMapCell(column: 16, row: 10)))
        #expect(visible.contains(SearchMapCell(column: 10, row: 15)))
        #expect(!visible.contains(SearchMapCell(column: 10, row: 16)))

        let across = map.center(of: SearchMapCell(column: 15, row: 10)).x
            - map.center(of: SearchMapCell(column: 10, row: 10)).x
        let into = map.center(of: SearchMapCell(column: 10, row: 15)).y
            - map.center(of: SearchMapCell(column: 10, row: 10)).y
        #expect(across / into == map.cellSize.width / map.cellSize.height)
    }

    /// The distinction the whole feature rests on: index 0 casts a shadow,
    /// index 8 does not, and both are equally unwalkable.
    @Test func aDeskIsSeenOverAndAWallIsNot() {
        let wall = map(
            columns: 21,
            rows: 21,
            blockers: (5...15).map { (column: 13, row: $0, terrain: SearchMapTerrain.obstacle) }
        )
        let desk = map(
            columns: 21,
            rows: 21,
            blockers: (5...15).map { (column: 13, row: $0, terrain: SearchMapTerrain.obstacleSeeThrough) }
        )

        let behind = SearchMapCell(column: 17, row: 10)
        #expect(!wall.visibleCells(from: center(wall, 10, 10), radiusInCells: 12).contains(behind))
        #expect(desk.visibleCells(from: center(desk, 10, 10), radiusInCells: 12).contains(behind))

        // Neither is walkable, so nothing about pathing changed.
        #expect(!SearchMapTerrain.obstacle.isWalkable)
        #expect(!SearchMapTerrain.obstacleSeeThrough.isWalkable)
    }

    /// A `NO_SEE` blocker is itself lit, and nothing behind it is.
    ///
    /// This is `Pass = 2` in GemRB's `Map::ExploreMapChunk`: a ray that meets a
    /// `NO_SEE` tile explores that tile, then breaks on the next blocked step.
    @Test func theBlockingCellIsLitAndNothingBehindItIs() {
        let map = map(
            columns: 21,
            rows: 21,
            blockers: [(column: 13, row: 10, terrain: .obstacle)]
        )
        let visible = map.visibleCells(from: center(map, 10, 10), radiusInCells: 12)

        #expect(visible.contains(SearchMapCell(column: 13, row: 10)))
        #expect(!visible.contains(SearchMapCell(column: 14, row: 10)))
    }

    /// Index 10 is sidewall: the run stays visible, then the first cell after
    /// it starts the `Pass = 2` stop.
    @Test func aSidewallRunIsVisibleThenBlocksOnLeaving() {
        let map = map(
            columns: 21,
            rows: 21,
            blockers: [
                (column: 12, row: 10, terrain: .wall),
                (column: 13, row: 10, terrain: .wall)
            ]
        )
        let visible = map.visibleCells(from: center(map, 10, 10), radiusInCells: 12)

        #expect(visible.contains(SearchMapCell(column: 12, row: 10)))
        #expect(visible.contains(SearchMapCell(column: 13, row: 10)))
        #expect(visible.contains(SearchMapCell(column: 14, row: 10)))
        #expect(!visible.contains(SearchMapCell(column: 15, row: 10)))
    }

    /// A roof does not stop sight.
    @Test func aRoofDoesNotBlockSight() {
        let map = map(
            columns: 21,
            rows: 21,
            blockers: [(column: 13, row: 10, terrain: .roof)]
        )
        let visible = map.visibleCells(from: center(map, 10, 10), radiusInCells: 12)
        #expect(visible.contains(SearchMapCell(column: 17, row: 10)))
    }

    /// Outdoors outside a city, a closed door shrouds ground beyond instead of
    /// leaving it unexplored.
    ///
    /// The leaf is transparent, because that is what an outdoor door is: GemRB
    /// takes "outdoor doors are automatically transparent (DOOR_TRANSPARENT)" as
    /// its heuristic, and the shroud branch is reached only by a door that
    /// blocks movement without blocking sight. A sight-blocking leaf is `NO_SEE`
    /// and stops the ray outright — see the companion test below.
    @Test func anOutdoorDoorShroudsBeyondWithoutLightingIt() {
        let bounds = CGRect(x: 0, y: 0, width: 320, height: 240)
        let leaf = CGRect(x: 144, y: 0, width: 32, height: 240)
        let viewpoint = CGPoint(x: 16, y: 120)
        let map = SearchMap(
            worldBounds: bounds,
            obstacles: [],
            doorObstacles: [DoorObstacle(rect: leaf, blocksSight: false)]
        )
        let city = map.exploreMapChunk(from: viewpoint, radiusInCells: 15, outdoorDoorShroud: false)
        let wilds = map.exploreMapChunk(from: viewpoint, radiusInCells: 15, outdoorDoorShroud: true)

        #expect(city.exploredOnly.isEmpty)
        #expect(!wilds.exploredOnly.isEmpty)
        #expect(wilds.exploredOnly.isDisjoint(with: wilds.visible))
        #expect(wilds.visible.union(wilds.exploredOnly).count >= city.visible.count)
    }

    /// A door that blocks sight stops the ray whatever the area type. The shroud
    /// keys off `DOOR_IMPASSABLE`, not off the sight flag, so an opaque leaf
    /// never reaches it — which is why the two flags have to stay separate.
    @Test func aSightBlockingDoorStopsSightEvenInTheWilds() {
        let bounds = CGRect(x: 0, y: 0, width: 320, height: 240)
        let leaf = CGRect(x: 144, y: 0, width: 32, height: 240)
        let viewpoint = CGPoint(x: 16, y: 120)
        let map = SearchMap(
            worldBounds: bounds,
            obstacles: [],
            doorObstacles: [DoorObstacle(rect: leaf, blocksSight: true)]
        )
        let wilds = map.exploreMapChunk(from: viewpoint, radiusInCells: 15, outdoorDoorShroud: true)
        #expect(wilds.exploredOnly.isEmpty, "an opaque leaf blocks rather than shrouds")
    }

    /// Sight stops at the boundary rather than escaping through it, because a
    /// cell outside the map reads as solid.
    @Test func sightDoesNotLeaveTheMap() {
        let map = map(columns: 9, rows: 9)
        let visible = map.visibleCells(from: center(map, 4, 4), radiusInCells: 250)

        #expect(visible.count == map.cellCount)
        #expect(visible.allSatisfy { map.contains($0) })
    }

    @Test func aCellRectCoversExactlyOneCellAtItsWorldPosition() {
        let map = map(columns: 5, rows: 5)
        let cell = SearchMapCell(column: 2, row: 3)
        let rect = map.rect(of: cell)

        #expect(rect.size == map.cellSize)
        #expect(rect.contains(map.center(of: cell)))
        #expect(map.cell(for: CGPoint(x: rect.midX, y: rect.midY)) == cell)
    }

    /// The shipped office is the reason `sightPermeableObstacles` exists.
    ///
    /// Rebaking the same room with index 8 collapsed back to index 0 is the
    /// before-picture: every rectangle opaque, and standing at the door lit a
    /// ragged sliver of the room instead of the room.
    @Test func theShippedOfficeSeesOverItsFurnitureButNotThroughItsWalls() throws {
        let area = HarborpointAreas.requireArea(HarborpointAreas.office)
        let shipped = area.makeNavigationMap().searchMap
        #expect(
            (shipped.terrainHistogram[.obstacleSeeThrough] ?? 0) > 0,
            "the office bakes no see-through furniture"
        )

        let everythingOpaque = SearchMap(
            worldBounds: shipped.worldBounds,
            terrainIndices: (0..<shipped.cellCount).map { index in
                let cell = SearchMapCell(
                    column: index % shipped.columns,
                    row: index / shipped.columns
                )
                let terrain = shipped.terrain(at: cell)
                return terrain == .obstacleSeeThrough
                    ? SearchMapTerrain.obstacle.rawValue
                    : terrain.rawValue
            },
            columns: shipped.columns,
            rows: shipped.rows,
            // The door is registered in both maps or neither. It is not
            // furniture and not a wall — it is a runtime stamp — and leaving it
            // out of one side would measure the door instead of the furniture.
            doorObstacles: area.doors.map(\.searchMapObstacle)
        )

        let spawn = try #require(area.spawnPoint(entrance: AreaEntrance.defaultName))
        let radiusInCells = 33
        let seen = shipped.visibleCells(from: spawn, radiusInCells: radiusInCells).count
        let seenIfFurnitureWereWalls = everythingOpaque
            .visibleCells(from: spawn, radiusInCells: radiusInCells)
            .count

        #expect(seen > seenIfFurnitureWereWalls)
        #expect(
            // The exact AR0809 envelope increases the wall-limited visible
            // ground behind the same furniture. V17's locked baseline is
            // 1651 / 1152 = 1.433; keep a small regression margin below it.
            Double(seen) / Double(seenIfFurnitureWereWalls) > 1.4,
            "furniture shadows still dominate: \(seenIfFurnitureWereWalls) -> \(seen)"
        )

        // The room's walls still stop sight, or the fog would be pointless: the
        // office plate is far larger than the radius and the far corners must
        // stay dark.
        #expect(Double(seen) / Double(shipped.cellCount) < 0.5)

        // Walkability is untouched by any of this: index 8 and index 0 are both
        // outside `isWalkable`, so only sight changed.
        let walkableCells = { (map: SearchMap) in
            (0..<map.cellCount).filter { index in
                map.terrain(
                    at: SearchMapCell(column: index % map.columns, row: index / map.columns)
                ).isWalkable
            }.count
        }
        #expect(walkableCells(shipped) == walkableCells(everythingOpaque))
    }

    /// Lila's authored walk-in resolves out of the gloom once and stays resolved.
    ///
    /// The office gates creature drawing on visibility, so this is what stops the
    /// shipped intro playing to an empty room. It used to assert her whole path
    /// was visible from the desk, which only held because sight reached 39 cells
    /// — nearly three times a creature's. At the engine's range she starts the
    /// walk beyond it, which is correct: a woman in a doorway twenty cells off is
    /// not visible, and her stepping into view *is* the beat.
    ///
    /// What must never happen is the second transition. Appearing and then
    /// blinking back out is the failure this guards, and it is the property that
    /// survives any retuning of the stat.
    @Test func theClientsAuthoredEntranceResolvesOnceAndStaysVisible() throws {
        let area = HarborpointAreas.requireArea(HarborpointAreas.office)
        let navigation = area.makeNavigationMap()
        // She walks in through the door, so the door is open — which is what the
        // scene does before releasing her.
        navigation.setEntranceDoorBlocking(false)
        let map = navigation.searchMap
        let seen = map.visibleCells(
            from: OfficeNavigationLayout.actorStart,
            radiusInCells: SearchMapExplore.searchRadius(
                visualRangeInFogTiles: area.agentProfile.visualRangeInCells
            )
        )

        let path = OfficeNavigationLayout.clientArrivalPath
        #expect(!path.isEmpty)
        let visibility = path.map { seen.contains(map.cell(for: $0)) }

        let arrival = try #require(
            visibility.firstIndex(of: true),
            "the client is never visible anywhere on her authored entrance"
        )
        #expect(
            visibility[arrival...].allSatisfy { $0 },
            "the client blinks back out after arriving: \(visibility)"
        )
        // She must finish the walk in sight, or the scripted beat lands on an
        // empty room however good the middle of it looked.
        #expect(visibility.last == true)
    }

    /// The door is the one occluder the painted terrain cannot answer, so it gets
    /// its own test: shut, it takes ground away from sight; open, it gives it
    /// back; and a door authored not to block sight never takes anything.
    @Test func aClosedDoorStopsSightAndOpeningItGivesTheGroundBack() throws {
        let area = HarborpointAreas.requireArea(HarborpointAreas.office)
        let navigation = area.makeNavigationMap()
        let map = navigation.searchMap
        let doorway = try #require(area.doors.first).closedObstacle.cgRect
        let range = SearchMapExplore.searchRadius(
            visualRangeInFogTiles: area.agentProfile.visualRangeInCells
        )
        // Use the registered V13 interaction stand, which is the exact clear
        // interior cell facing this oblique doorway. Subtracting three cells
        // from the leaf's axis-aligned minX landed on the rebuilt wall/furniture
        // band after the projection refit and was never a stable door-relative
        // position.
        let viewpoint = try #require(OfficeNavigationLayout.approachPoints["office.door"])
        #expect(map.terrain(at: viewpoint).isWalkable)

        navigation.setEntranceDoorBlocking(true)
        let shut = map.visibleCells(from: viewpoint, radiusInCells: range)
        navigation.setEntranceDoorBlocking(false)
        let open = map.visibleCells(from: viewpoint, radiusInCells: range)

        #expect(shut.isSubset(of: open), "opening the door hid ground it should reveal")
        #expect(shut.count < open.count, "the shut door took no ground away from sight")
        // What it gives back is the doorway and what lies beyond it, not cells
        // scattered around the room.
        let gained = open.subtracting(shut)
        #expect(!gained.isEmpty)
        #expect(
            gained.allSatisfy { map.center(of: $0).x >= doorway.minX - map.cellSize.width },
            "opening the door revealed ground on the wrong side of it"
        )
    }

    /// A door that says it does not block sight never stamps the flag, which is
    /// the engine's flag bit 9 and the reason a portcullis reads differently
    /// from a slab of oak.
    @Test func aDoorAuthoredNotToBlockSightNeverStopsIt() throws {
        let bounds = CGRect(x: 0, y: 0, width: 320, height: 240)
        let leaf = CGRect(x: 144, y: 0, width: 32, height: 240)
        let viewpoint = CGPoint(x: 16, y: 120)

        let opaque = SearchMap(
            worldBounds: bounds,
            obstacles: [],
            doorObstacles: [DoorObstacle(rect: leaf)]
        )
        let grille = SearchMap(
            worldBounds: bounds,
            obstacles: [],
            doorObstacles: [DoorObstacle(rect: leaf, blocksSight: false)]
        )

        let throughOpaque = opaque.visibleCells(from: viewpoint, radiusInCells: 15)
        let throughGrille = grille.visibleCells(from: viewpoint, radiusInCells: 15)

        #expect(throughOpaque.count < throughGrille.count)
        // Both still stop feet: sight and movement are separate answers.
        #expect(opaque.impassableCellCount == grille.impassableCellCount)
    }

    /// Indoor fill: a room lights to its walls, a closed door keeps the next
    /// enclosure black, furniture does not split the room.
    @Test func enclosedFloorFillsTheRoomAndStopsAtWallsAndDoors() {
        let wallColumn = 10
        let map = map(
            columns: 21,
            rows: 15,
            blockers: (0..<15).map { (column: wallColumn, row: $0, terrain: SearchMapTerrain.wall) }
                + [(column: 4, row: 7, terrain: .obstacleSeeThrough)]
        )
        let west = SearchMapCell(column: 3, row: 7)
        let east = SearchMapCell(column: 16, row: 7)
        let filled = map.enclosedFloor(touching: [west])

        #expect(filled.contains(west))
        #expect(filled.contains(SearchMapCell(column: 4, row: 7)), "a desk must not split the room")
        #expect(filled.contains(SearchMapCell(column: wallColumn, row: 7)), "the wall itself lights")
        #expect(!filled.contains(east), "a wall must not leak into the next room")
        #expect(filled.count > 20)
    }

    @Test func enclosedFloorFollowsLOSThroughAnOpenDoorway() {
        var blockers = (0..<15).map { (column: 10, row: $0, terrain: SearchMapTerrain.wall) }
        blockers.removeAll { $0.row == 7 }
        let map = map(columns: 21, rows: 15, blockers: blockers)
        let west = SearchMapCell(column: 3, row: 7)
        let east = SearchMapCell(column: 16, row: 7)
        let filled = map.enclosedFloor(touching: [west])

        #expect(filled.contains(west))
        #expect(filled.contains(east), "an opening must light the room beyond")
    }

    @Test func coveringAnEnclosedRoomLightsPaintedWallsWithoutTheNextRoom() {
        let map = map(
            columns: 21,
            rows: 20,
            blockers: (0..<20).flatMap { row in
                (8...12).map { column in
                    (column: column, row: row, terrain: SearchMapTerrain.wall)
                }
            }
        )
        let west = SearchMapCell(column: 3, row: 7)
        let east = SearchMapCell(column: 16, row: 7)
        let enclosed = map.enclosedFloor(touching: [west])
        let grid = FogGrid(searchMap: map)
        let fog = grid.cellsCoveringEnclosedRoom(enclosed, on: map)

        let westFloor = grid.cellsOverlapping(west)
        let eastFloor = grid.cellsOverlapping(east)
        let deepWall = grid.cellsOverlapping(SearchMapCell(column: 11, row: 7))
        #expect(westFloor.isSubset(of: fog))
        #expect(eastFloor.isDisjoint(with: fog), "the next room's floor must stay black")
        #expect(!deepWall.isDisjoint(with: fog), "painted wall thickness must not punch 32×32 holes")
    }

    @Test func enclosedFloorFromTheOfficeDeskCoversMoreThanVisualRange() throws {
        let area = HarborpointAreas.requireArea(HarborpointAreas.office)
        let navigation = area.makeNavigationMap()
        navigation.setEntranceDoorBlocking(false)
        let map = navigation.searchMap
        let range = SearchMapExplore.searchRadius(
            visualRangeInFogTiles: area.agentProfile.visualRangeInCells
        )
        let los = map.visibleCells(
            from: OfficeNavigationLayout.actorStart,
            radiusInCells: range
        )
        let room = map.enclosedFloor(touching: los)

        #expect(room.isSuperset(of: los))
        #expect(room.count > los.count, "the office must not remain a 14-cell spotlight")
    }

}

/// Merging a visible cell set into clip rectangles.
struct SearchMapVisibilityRunTests {
    private func map(columns: Int, rows: Int) -> SearchMap {
        let cell = SearchMap.defaultCellSize
        return SearchMap(
            worldBounds: CGRect(
                x: 100,
                y: 200,
                width: CGFloat(columns) * cell.width,
                height: CGFloat(rows) * cell.height
            ),
            terrainIndices: [UInt8](repeating: SearchMapTerrain.stone.rawValue, count: columns * rows),
            columns: columns,
            rows: rows
        )
    }

    @Test func adjacentCellsInARowBecomeOneRectangle() {
        let map = map(columns: 10, rows: 10)
        let rects = map.mergedRects(of: [
            SearchMapCell(column: 2, row: 5),
            SearchMapCell(column: 3, row: 5),
            SearchMapCell(column: 4, row: 5)
        ])

        #expect(rects.count == 1)
        #expect(rects[0] == CGRect(x: 100 + 32, y: 200 + 60, width: 48, height: 12))
    }

    @Test func aGapSplitsTheRunAndRowsStaySeparate() {
        let map = map(columns: 10, rows: 10)
        let rects = map.mergedRects(of: [
            SearchMapCell(column: 1, row: 0),
            SearchMapCell(column: 2, row: 0),
            SearchMapCell(column: 5, row: 0),
            SearchMapCell(column: 1, row: 1)
        ])

        #expect(rects.count == 3)
        #expect(rects.map(\.width).sorted() == [16, 16, 32])
    }

    /// The merged rectangles must cover exactly the cells they were built from —
    /// a fog pool clipped to them would otherwise leak or be cut short.
    @Test func mergedRectanglesCoverTheSameGroundAsTheCells() {
        let map = map(columns: 24, rows: 24)
        let cells = Set(
            map.visibleCells(from: CGPoint(x: 100 + 190, y: 200 + 140), radiusInCells: 8)
        )
        let rects = map.mergedRects(of: cells)

        for cell in cells {
            let center = map.center(of: cell)
            #expect(rects.contains { $0.contains(center) }, "run rects miss \(cell)")
        }
        let covered = (0..<map.cellCount).filter { index in
            let center = map.center(of: SearchMapCell(
                column: index % map.columns,
                row: index / map.columns
            ))
            return rects.contains { $0.contains(center) }
        }
        #expect(covered.count == cells.count)
    }

    @Test func anEmptySetMergesToNothing() {
        #expect(map(columns: 4, rows: 4).mergedRects(of: []).isEmpty)
    }
}
