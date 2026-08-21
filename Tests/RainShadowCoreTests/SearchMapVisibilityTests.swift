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

    @Test func anEmptyRoomIsVisibleToTheEdgeOfTheRadius() {
        let map = map(columns: 21, rows: 21)
        let visible = map.visibleCells(from: center(map, 10, 10), radius: 80)

        #expect(visible.contains(SearchMapCell(column: 10, row: 10)))
        // 80 units is five 16-wide columns and six 12-tall rows, so the lit
        // region is a circle in world space rather than a square in cells.
        #expect(visible.contains(SearchMapCell(column: 15, row: 10)))
        #expect(!visible.contains(SearchMapCell(column: 16, row: 10)))
        #expect(visible.contains(SearchMapCell(column: 10, row: 16)))
        #expect(!visible.contains(SearchMapCell(column: 10, row: 17)))
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
        #expect(!wall.visibleCells(from: center(wall, 10, 10), radius: 200).contains(behind))
        #expect(desk.visibleCells(from: center(desk, 10, 10), radius: 200).contains(behind))

        // Neither is walkable, so nothing about pathing changed.
        #expect(!SearchMapTerrain.obstacle.isWalkable)
        #expect(!SearchMapTerrain.obstacleSeeThrough.isWalkable)
    }

    /// A blocker is itself lit — you see the wall you cannot see past, which is
    /// what draws the room's outline into the fog.
    @Test func theBlockingCellIsItselfVisible() {
        let map = map(
            columns: 21,
            rows: 21,
            blockers: [(column: 13, row: 10, terrain: .wall)]
        )
        let visible = map.visibleCells(from: center(map, 10, 10), radius: 200)

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
        let radius: CGFloat = 240
        var asymmetric: [(SearchMapCell, SearchMapCell)] = []
        for row in stride(from: 4, to: 21, by: 3) {
            for column in stride(from: 4, to: 21, by: 3) {
                let a = SearchMapCell(column: column, row: row)
                for other in [SearchMapCell(column: 12, row: 8), SearchMapCell(column: 16, row: 16)] {
                    let aSeesOther = map.visibleCells(from: map.center(of: a), radius: radius).contains(other)
                    let otherSeesA = map.visibleCells(from: map.center(of: other), radius: radius).contains(a)
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
        let visible = map.visibleCells(from: center(map, 4, 4), radius: 4_000)

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
        let radius: CGFloat = 390
        let seen = shipped.visibleCells(from: spawn, radius: radius).count
        let seenIfFurnitureWereWalls = everythingOpaque
            .visibleCells(from: spawn, radius: radius)
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
            map.visibleCells(from: CGPoint(x: 100 + 190, y: 200 + 140), radius: 130)
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
