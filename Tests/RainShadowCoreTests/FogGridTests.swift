import CoreGraphics
import Foundation
import Testing
@testable import RainShadowCore

/// The fog grid is the Infinity Engine's explored bitmask, at the resolution the
/// engine keeps it: coarser than the search map sight is answered on.
struct FogGridTests {
    /// A 102×76 search map — the office — folds to 51×29 fog cells of 32×32.
    /// Horizontal 16×2 = 32; vertical 12 does not divide 32, so the row count
    /// is ceil(76×12 / 32), matching GemRB `FogPoint(SearchmapPoint)`.
    @Test func theGridIsThirtyTwoPixelScreenCells() {
        let grid = FogGrid(origin: .zero, searchColumns: 102, searchRows: 76)

        #expect(grid.columns == 51)
        #expect(grid.rows == 29)
        #expect(grid.cellSize == CGSize(width: 32, height: 32))
        #expect(FogGrid.cellPixelSize == 32)
    }

    /// An odd cell count rounds up. Rounding down would leave a strip of ground
    /// that no amount of walking could ever explore.
    @Test func anOddSearchMapStillHasEveryCellCovered() {
        let grid = FogGrid(origin: .zero, searchColumns: 101, searchRows: 75)

        #expect(grid.columns == 51)
        #expect(grid.rows == 29)
        #expect(grid.contains(grid.cell(for: SearchMapCell(column: 100, row: 74))))
    }

    @Test func searchCellsFoldIntoFogCellsWithoutGoingThroughWorldSpace() {
        let grid = FogGrid(origin: CGPoint(x: -320, y: 96), searchColumns: 20, searchRows: 20)

        // 16 px search cells / 32 px fog: columns 0–1 → fog 0, 2–3 → fog 1.
        #expect(grid.cell(for: SearchMapCell(column: 0, row: 0)) == FogCell(column: 0, row: 0))
        #expect(grid.cell(for: SearchMapCell(column: 1, row: 0)) == FogCell(column: 0, row: 0))
        #expect(grid.cell(for: SearchMapCell(column: 2, row: 0)) == FogCell(column: 1, row: 0))
        // 12 px search rows / 32 px fog: rows 0–2 → fog 0, row 3 → fog 1.
        #expect(grid.cell(for: SearchMapCell(column: 0, row: 2)) == FogCell(column: 0, row: 0))
        #expect(grid.cell(for: SearchMapCell(column: 0, row: 3)) == FogCell(column: 0, row: 1))

        // A 12 px search row starting at y=24 straddles fog rows 0 (0–31) and
        // 1 (32–63). Drawing from the centre alone left the 32×32 wall holes.
        let straddling = SearchMapCell(column: 0, row: 2)
        #expect(grid.cellsOverlapping(straddling) == [
            FogCell(column: 0, row: 0),
            FogCell(column: 0, row: 1)
        ])

        // And the two routes agree: folding a search cell must land where the
        // search cell's own centre lands.
        let searchMap = SearchMap(
            worldBounds: CGRect(x: -320, y: 96, width: 320, height: 240),
            obstacles: []
        )
        for column in 0..<20 {
            for row in 0..<20 {
                let searchCell = SearchMapCell(column: column, row: row)
                #expect(grid.cell(for: searchCell) == grid.cell(for: searchMap.center(of: searchCell)))
            }
        }
    }

    /// Three levels, and exactly GemRB's three values — 255 opaque, 128
    /// `HALFTRANS`, 0 clear.
    @Test func theMaskHoldsExactlyThreeLevels() {
        let grid = FogGrid(origin: .zero, searchColumns: 8, searchRows: 8)

        let mask = grid.mask(
            explored: [FogCell(column: 0, row: 0), FogCell(column: 1, row: 0)],
            visible: [FogCell(column: 1, row: 0)]
        )

        #expect(Set(mask) == [255, 128, 0])
        #expect(mask.filter { $0 == 0 }.count == 1)
        #expect(mask.filter { $0 == 128 }.count == 1)
        #expect(FogGrid.unexploredLevel == 255)
        #expect(FogGrid.rememberedLevel == 128)
        #expect(FogGrid.visibleLevel == 0)
    }

    /// Sight wins wherever the two bitmaps disagree, and neither is required to
    /// contain the other — sight that has run ahead of memory is still lit.
    @Test func sightCutsThroughMemoryRatherThanBeingBoundedByIt() {
        let grid = FogGrid(origin: .zero, searchColumns: 16, searchRows: 16)
        let ahead = FogCell(column: 3, row: 3)

        let mask = grid.mask(explored: [], visible: [ahead])

        #expect(mask[maskIndex(grid, ahead)] == FogGrid.visibleLevel)
    }

    /// Row 0 of the buffer is the top of the image, because that is the row order
    /// `CGImage` reads. A flip here would put the fog upside down over the area.
    @Test func theMaskIsWrittenTopRowFirst() {
        let grid = FogGrid(origin: .zero, searchColumns: 4, searchRows: 4)
        let bottomLeft = FogCell(column: 0, row: 0)

        let mask = grid.mask(explored: [], visible: [bottomLeft])

        // Bottom-left in world space is the *last* row of the image buffer.
        #expect(mask[(grid.rows - 1) * grid.maskWidth] == FogGrid.visibleLevel)
        #expect(mask[0] == FogGrid.unexploredLevel)
        #expect(grid.rows >= 1)
        #expect(grid.columns >= 1)
    }

    /// Cell interiors are one byte. Edge stamps live on the display mask, not
    /// on a 4-texel upsample that linear filtering used to smear.
    @Test func cellInteriorsAreOneByteAndFlat() {
        let grid = FogGrid(origin: .zero, searchColumns: 8, searchRows: 8)
        let lit = FogCell(column: 1, row: 1)

        let mask = grid.mask(explored: [], visible: [lit])

        #expect(grid.maskWidth == grid.columns)
        #expect(grid.maskHeight == grid.rows)
        #expect(mask.filter { $0 == FogGrid.visibleLevel }.count == 1)
    }

    /// The office never un-explores, so the only operation memory needs is union
    /// — but the mask must not quietly re-blacken a cell that is in both sets.
    @Test func aRememberedCellNeverReturnsToOpaque() {
        let grid = FogGrid(origin: .zero, searchColumns: 8, searchRows: 8)
        let walked = FogCell(column: 2, row: 2)

        let lit = grid.mask(explored: [walked], visible: [walked])
        let lookedAway = grid.mask(explored: [walked], visible: [])

        #expect(lit[maskIndex(grid, walked)] == FogGrid.visibleLevel)
        #expect(lookedAway[maskIndex(grid, walked)] == FogGrid.rememberedLevel)
        #expect(lookedAway[maskIndex(grid, walked)] != FogGrid.unexploredLevel)
    }

    /// What a save stores: one bit per cell, the way the `.ARE` field does.
    @Test func theBitmaskRoundTrips() {
        let grid = FogGrid(origin: .zero, searchColumns: 102, searchRows: 76)
        var cells: Set<FogCell> = []
        for column in stride(from: 0, to: grid.columns, by: 3) {
            for row in stride(from: 0, to: grid.rows, by: 5) {
                cells.insert(FogCell(column: column, row: row))
            }
        }

        let packed = grid.packed(cells)

        #expect(packed.count == (grid.columns * grid.rows + 7) / 8)
        #expect(grid.unpacked(packed) == cells)
    }

    /// A save written against a differently sized area loses the ground that no
    /// longer exists rather than smearing it onto the edge.
    @Test func packingDropsCellsOutsideTheGrid() {
        let grid = FogGrid(origin: .zero, searchColumns: 8, searchRows: 8)
        let outside: Set<FogCell> = [
            FogCell(column: -1, row: 0),
            FogCell(column: 0, row: 99),
            FogCell(column: grid.columns, row: 0)
        ]

        #expect(grid.packed(outside).allSatisfy { $0 == 0 })
        #expect(grid.unpacked([]) == [])
        // A short buffer reads as far as it goes rather than trapping.
        #expect(grid.unpacked([0xFF]).count == 8)
    }

    private func maskIndex(_ grid: FogGrid, _ cell: FogCell) -> Int {
        (grid.rows - 1 - cell.row) * grid.maskWidth + cell.column
    }
}

/// The stored explored bitmask — what the `.ARE` keeps, and what lets an area
/// you have walked still be drawn when you come back to it.
struct FogBitmaskTests {
    @Test func aBitmaskCarriesTheWidthItsRowsWereCountedAt() {
        let grid = FogGrid(origin: .zero, searchColumns: 102, searchRows: 76)
        let cells: Set<FogCell> = [
            FogCell(column: 0, row: 0),
            FogCell(column: 50, row: 28),
            FogCell(column: 7, row: 11)
        ]

        let stored = grid.bitmask(of: cells)

        #expect(stored.columns == grid.columns)
        #expect(stored.rows == grid.rows)
        #expect(grid.cells(from: stored) == cells)
        #expect(!stored.isEmpty)
    }

    @Test func anEmptyBitmaskReadsAsNothingExplored() {
        let grid = FogGrid(origin: .zero, searchColumns: 8, searchRows: 8)
        let stored = grid.bitmask(of: [])

        #expect(stored.isEmpty)
        #expect(grid.cells(from: stored).isEmpty)
    }

    /// A save written against a differently sized area loses the ground that no
    /// longer exists rather than shearing every row of what is left.
    @Test func aBitmaskFromAResizedAreaIsClippedNotSheared() {
        let old = FogGrid(origin: .zero, searchColumns: 40, searchRows: 40)
        let new = FogGrid(origin: .zero, searchColumns: 20, searchRows: 40)
        let kept = FogCell(column: 3, row: 4)
        let lost = FogCell(column: 17, row: 4)

        let stored = old.bitmask(of: [kept, lost])
        let read = new.cells(from: stored)

        // Read at its own width, so the surviving cell is still where it was.
        #expect(read.contains(kept))
        #expect(!read.contains(lost))
        #expect(read.allSatisfy(new.contains))
    }

    /// Union is the only operation memory needs, and it must survive the trip
    /// through storage.
    @Test func rememberingMoreGroundNeverLosesTheOldGround() {
        let grid = FogGrid(origin: .zero, searchColumns: 30, searchRows: 30)
        let first: Set<FogCell> = [FogCell(column: 1, row: 1), FogCell(column: 2, row: 2)]
        let second: Set<FogCell> = [FogCell(column: 9, row: 9)]

        let stored = grid.bitmask(of: first)
        let grown = grid.bitmask(of: grid.cells(from: stored).union(second))

        #expect(grid.cells(from: grown) == first.union(second))
    }
}

/// FOGOWAR-role stamps: interiors stay flat, the outer rim of a visible cell
/// toward unexplored ground darkens, and linear filtering is not the edge.
struct FogEdgeMaskTests {
    @Test func aVisibleIslandKeepsAClearInteriorAndADarkRim() {
        let grid = FogGrid(origin: .zero, searchColumns: 16, searchRows: 16)
        let lit = FogCell(column: 2, row: 2)
        let display = grid.displayMask(explored: [], visible: [lit])
        let side = FogGrid.cellPixelSize
        let width = grid.columns * side
        let imageRow = (grid.rows - 1 - lit.row) * side
        let x0 = lit.column * side

        func sample(_ dx: Int, _ dy: Int) -> UInt8 {
            display[(imageRow + dy) * width + x0 + dx]
        }

        #expect(sample(side / 2, side / 2) == FogGrid.visibleLevel)
        #expect(sample(side / 2, 0) > FogGrid.rememberedLevel)
        #expect(sample(0, side / 2) > FogGrid.rememberedLevel)
        #expect(sample(side / 2, 1) >= sample(side / 2, 4))
    }

    @Test func rememberedGroundStaysHalfTransAndDoesNotReblacken() {
        let grid = FogGrid(origin: .zero, searchColumns: 16, searchRows: 16)
        let walked = FogCell(column: 2, row: 2)
        let display = grid.displayMask(explored: [walked], visible: [])
        let side = FogGrid.cellPixelSize
        let width = grid.columns * side
        let imageRow = (grid.rows - 1 - walked.row) * side
        let x0 = walked.column * side
        let interior = display[(imageRow + side / 2) * width + x0 + side / 2]

        #expect(interior == FogGrid.rememberedLevel)
    }

    @Test func displayMaskIsThirtyTwoPixelsPerCell() {
        let grid = FogGrid(origin: .zero, searchColumns: 8, searchRows: 8)
        let display = grid.displayMask(explored: [], visible: [])
        #expect(display.count == grid.columns * FogGrid.cellPixelSize * grid.rows * FogGrid.cellPixelSize)
        #expect(Set(display) == [FogGrid.unexploredLevel])
    }
}
