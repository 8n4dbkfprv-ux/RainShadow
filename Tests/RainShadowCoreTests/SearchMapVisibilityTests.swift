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

    /// Range is counted in cells, so the lit region is a circle on the *cell
    /// grid* — which, because the cells are 16×12 and 16:12 is this projection's
    /// ground foreshortening, is a circle on the ground and a 16:12 ellipse on
    /// screen. GemRB walks a midpoint circle over the same grid for the same
    /// reason. Measuring the radius in world units instead would put a circle on
    /// the screen and an ellipse on the ground: the pool would reach a third
    /// further "into" the scene than across it.
    @Test func rangeIsCountedInCellsSoTheLitGroundIsRound() {
        let map = map(columns: 21, rows: 21)
        let visible = map.visibleCells(from: center(map, 10, 10), radiusInCells: 5)

        #expect(visible.contains(SearchMapCell(column: 10, row: 10)))
        // Equal reach in cells on both axes...
        #expect(visible.contains(SearchMapCell(column: 15, row: 10)))
        #expect(!visible.contains(SearchMapCell(column: 16, row: 10)))
        #expect(visible.contains(SearchMapCell(column: 10, row: 15)))
        #expect(!visible.contains(SearchMapCell(column: 10, row: 16)))

        // ...which is unequal reach in world units, by exactly the cell aspect.
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

    /// A blocker is itself lit, and nothing behind it is.
    ///
    /// This is `Pass = 2` in GemRB's `Map::ExploreMapChunk`: a ray that meets a
    /// `NO_SEE` tile explores that tile, then breaks on the next one. It is what
    /// draws a room's own walls into the fog instead of leaving the outline
    /// dark, and it is the property most easily lost when swapping the traversal
    /// out — so it is asserted rather than assumed.
    @Test func theBlockingCellIsLitAndNothingBehindItIs() {
        let map = map(
            columns: 21,
            rows: 21,
            blockers: [(column: 13, row: 10, terrain: .wall)]
        )
        let visible = map.visibleCells(from: center(map, 10, 10), radiusInCells: 12)

        #expect(visible.contains(SearchMapCell(column: 13, row: 10)))
        #expect(!visible.contains(SearchMapCell(column: 14, row: 10)))
    }

    /// Sight is mutual. Asymmetric fields of view produce the artifact where a
    /// corner reveals itself from one side and not the other.
    @Test func sightIsSymmetricBetweenAnyTwoCells() {
        let map = map(
            columns: 25,
            rows: 25,
            blockers: [
                (column: 12, row: 12, terrain: .obstacle),
                (column: 12, row: 13, terrain: .obstacle),
                (column: 13, row: 12, terrain: .obstacle),
                (column: 8, row: 17, terrain: .wall),
                (column: 17, row: 8, terrain: .roof)
            ]
        )
        let radiusInCells = 15
        var asymmetric: [(SearchMapCell, SearchMapCell)] = []
        for row in stride(from: 4, to: 21, by: 3) {
            for column in stride(from: 4, to: 21, by: 3) {
                let a = SearchMapCell(column: column, row: row)
                for other in [SearchMapCell(column: 12, row: 8), SearchMapCell(column: 16, row: 16)] {
                    let aSeesOther = map.visibleCells(from: map.center(of: a), radiusInCells: radiusInCells).contains(other)
                    let otherSeesA = map.visibleCells(from: map.center(of: other), radiusInCells: radiusInCells).contains(a)
                    if aSeesOther != otherSeesA { asymmetric.append((a, other)) }
                }
            }
        }
        #expect(asymmetric.isEmpty, "asymmetric pairs: \(asymmetric)")
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
            rows: shipped.rows
        )

        let spawn = try #require(area.spawnPoint(entrance: AreaEntrance.defaultName))
        let radiusInCells = 33
        let seen = shipped.visibleCells(from: spawn, radiusInCells: radiusInCells).count
        let seenIfFurnitureWereWalls = everythingOpaque
            .visibleCells(from: spawn, radiusInCells: radiusInCells)
            .count

        #expect(seen > seenIfFurnitureWereWalls)
        #expect(
            Double(seen) / Double(seenIfFurnitureWereWalls) > 1.5,
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

    /// Lila's authored walk-in stays inside Voss's line of sight the whole way.
    ///
    /// The office gates creature drawing on visibility, so this is what stops
    /// the shipped intro playing to an empty room: if the search map, the fog
    /// radius or her path moves such that any step of it falls out of sight, she
    /// blinks out mid-entrance and the scripted beat plays with nobody in it.
    @Test func theClientsAuthoredEntranceStaysInSightThroughout() throws {
        let area = HarborpointAreas.requireArea(HarborpointAreas.office)
        let map = area.makeNavigationMap().searchMap
        // The cell radius `FogMaskRenderer.Style.office` resolves to.
        let seen = map.visibleCells(from: OfficeNavigationLayout.actorStart, radiusInCells: 39)

        let path = OfficeNavigationLayout.clientArrivalPath
        #expect(!path.isEmpty)
        let unseen = path.filter { !seen.contains(map.cell(for: $0)) }
        #expect(unseen.isEmpty, "the client walks out of sight at \(unseen)")
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
