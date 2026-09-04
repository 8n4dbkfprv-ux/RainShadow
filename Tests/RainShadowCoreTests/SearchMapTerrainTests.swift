import CoreGraphics
import Foundation
import Testing
@testable import RainShadowCore

/// The BG2 terrain table, and the painted search maps built from it.
struct SearchMapTerrainTests {

    // MARK: - The table

    /// Transcribed from the Infinity Engine documentation. Kept as a literal
    /// table rather than derived from the enum, so a typo in `SearchMapTerrain`
    /// fails here instead of being confirmed by its own definition.
    ///
    /// index, walkable, see-through, flyable, projectiles, BG walk sound
    static let bg2Table: [(UInt8, Bool, Bool, Bool, Bool, String?)] = [
        (0, false, false, false, false, nil),        // obstacle
        (1, true, true, true, true, "WAL_04"),       // sand
        (2, true, true, true, true, "WAL_MT"),       // wood
        (3, true, true, true, true, "WAL_02"),       // wood creaking
        (4, true, true, true, true, "WAL_05"),       // stone echoey
        (5, true, true, true, true, "WAL_06"),       // grass
        (6, true, true, true, true, "WAL_01"),       // water
        (7, true, true, true, true, "WAL_03"),       // stone
        (8, false, true, true, true, nil),           // obstacle, see-through
        (9, true, true, true, true, "WAL_02"),       // wood creaking
        (10, false, true, false, false, nil),       // wall / sidewall
        (11, true, true, true, true, "WAL_01"),      // water
        (12, false, true, true, true, nil),          // water, impassable
        (13, false, true, false, false, nil),        // roof (sight passes)
        (14, false, true, true, true, nil),          // worldmap exit
        (15, true, true, true, true, "WAL_04")       // grass
    ]

    @Test func theTableMatchesTheInfinityEngineDocumentation() throws {
        #expect(SearchMapTerrain.allCases.count == 16)
        for (raw, walkable, seeThrough, flyable, projectiles, sound) in Self.bg2Table {
            let terrain = try #require(SearchMapTerrain(rawValue: raw))
            #expect(terrain.isWalkable == walkable, "index \(raw) walkable")
            #expect(terrain.isSeeThrough == seeThrough, "index \(raw) see-through")
            #expect(terrain.isFlyable == flyable, "index \(raw) flyable")
            #expect(terrain.allowsProjectiles == projectiles, "index \(raw) projectiles")
            #expect(terrain.infinityEngineWalkSound == sound, "index \(raw) walk sound")
        }
    }

    /// The one asymmetry worth naming: index 8 blocks feet but not sight, and
    /// index 12 blocks feet but not projectiles. A single passable bit could
    /// represent neither.
    @Test func blockingMovementIsNotTheSameAsBlockingSight() {
        #expect(!SearchMapTerrain.obstacleSeeThrough.isWalkable)
        #expect(SearchMapTerrain.obstacleSeeThrough.isSeeThrough)
        #expect(SearchMapTerrain.waterImpassable.isWalkable == false)
        #expect(SearchMapTerrain.waterImpassable.allowsProjectiles)
        #expect(SearchMapTerrain.wall.isSightSidewall)
        #expect(SearchMapTerrain.wall.isSeeThrough)
        #expect(SearchMapTerrain.roof.isSeeThrough)
        #expect(!SearchMapTerrain.obstacle.isSeeThrough)
        #expect(!SearchMapTerrain.roof.isSightSidewall)
    }

    @Test func anUnknownByteReadsAsSolidRatherThanAsFloor() {
        #expect(SearchMapTerrain.decode(200) == .obstacle)
        #expect(SearchMapTerrain.decode(16) == .obstacle)
        #expect(SearchMapTerrain.decode(7) == .stone)
    }

    @Test func terrainNamesRoundTripThroughJSON() throws {
        for terrain in SearchMapTerrain.allCases {
            let data = try JSONEncoder().encode(terrain)
            #expect(String(data: data, encoding: .utf8) == "\"\(terrain.name)\"")
            #expect(try JSONDecoder().decode(SearchMapTerrain.self, from: data) == terrain)
        }
    }

    @Test func surfacesCollapseOntoWhatTheGameHasBakedAudioFor() {
        #expect(SearchMapTerrain.wood.surface == .wood)
        #expect(SearchMapTerrain.woodCreaking.surface == .wood)
        #expect(SearchMapTerrain.stone.surface == .stone)
        #expect(SearchMapTerrain.stoneEchoey.surface == .stone)
        #expect(SearchMapTerrain.obstacle.surface == .silent)
        #expect(SearchMapTerrain.roof.surface == .silent)
    }

    // MARK: - Raster orientation

    /// PNG rows run top-down and world rows run bottom-up. Getting the flip
    /// wrong is silent — a mirrored office still has a plausible amount of floor
    /// in it — so this pins it with a raster that is solid along its *bottom*
    /// world row and open everywhere else.
    @Test func rowZeroOfTheRasterIsTheBottomOfTheWorld() {
        let columns = 4
        let rows = 3
        var indices = [UInt8](repeating: SearchMapTerrain.stone.rawValue, count: columns * rows)
        for column in 0..<columns {
            indices[column] = SearchMapTerrain.obstacle.rawValue   // world row 0
        }
        let map = SearchMap(
            worldBounds: CGRect(x: 0, y: 0, width: 64, height: 36),
            terrainIndices: indices,
            columns: columns,
            rows: rows
        )
        #expect(map.terrain(at: SearchMapCell(column: 0, row: 0)) == .obstacle)
        #expect(map.terrain(at: SearchMapCell(column: 3, row: 0)) == .obstacle)
        #expect(map.terrain(at: SearchMapCell(column: 0, row: 1)) == .stone)
        #expect(map.terrain(at: SearchMapCell(column: 0, row: 2)) == .stone)
        // And in world coordinates: low y is the solid row.
        #expect(!map.isPassable(at: CGPoint(x: 8, y: 6)))
        #expect(map.isPassable(at: CGPoint(x: 8, y: 18)))
    }

    @Test func passableIsDerivedFromTerrainRatherThanAuthoredSeparately() {
        let indices: [UInt8] = [
            SearchMapTerrain.stone.rawValue,
            SearchMapTerrain.wall.rawValue,
            SearchMapTerrain.water.rawValue,
            SearchMapTerrain.roof.rawValue
        ]
        let map = SearchMap(
            worldBounds: CGRect(x: 0, y: 0, width: 64, height: 12),
            terrainIndices: indices,
            columns: 4,
            rows: 1
        )
        #expect(map.flags(at: SearchMapCell(column: 0, row: 0)).contains(.passable))
        #expect(!map.flags(at: SearchMapCell(column: 1, row: 0)).contains(.passable))
        #expect(map.flags(at: SearchMapCell(column: 2, row: 0)).contains(.passable))
        #expect(!map.flags(at: SearchMapCell(column: 3, row: 0)).contains(.passable))
    }

    // MARK: - Shipped rasters

    /// An authored SR bitmap is the runtime authority. It may be richer than
    /// the AABB fallback, but it must match the area's IE cell grid and contain
    /// only the sixteen documented terrain indices.
    @Test(arguments: AreaReachabilityTests.navigableIDs)
    func thePaintedMapMatchesTheAreaGridAndIETerrainTable(_ id: AreaID) throws {
        let area = try AreaCatalogLoader.load(id)
        let searchMapName = try #require(area.searchMapName)
        let raster = try AreaSearchMapLoader.load(named: searchMapName)

        let grid = area.searchMapGridSize
        #expect(raster.columns == grid.columns, "\(id) raster width")
        #expect(raster.rows == grid.rows, "\(id) raster height")
        #expect(raster.terrainIndices.allSatisfy { $0 < SearchMapTerrain.allCases.count })
    }

    /// What the change buys: the ground now says what it is made of, instead of
    /// each scene asserting a footstep surface as a constant.
    @Test func theOfficeSoundsLikeBoardsAndTheStreetsLikeStone() throws {
        let office = try AreaCatalogLoader.load(HarborpointAreas.office)
        let officeMap = office.makeNavigationMap()
        let start = try #require(office.spawnPoint(entrance: nil))
        #expect(officeMap.searchMap.terrain(at: start) == .wood)
        #expect(officeMap.searchMap.surface(at: start) == .wood)

        let sableRow = try AreaCatalogLoader.load(HarborpointAreas.sableRow)
        let streetMap = sableRow.makeNavigationMap()
        let street = try #require(sableRow.spawnPoint(entrance: nil))
        #expect(streetMap.searchMap.terrain(at: street) == .stone)
        #expect(streetMap.searchMap.surface(at: street) == .stone)
    }

    @Test func aSolidCellReportsNoSurfaceRatherThanASilentOne() throws {
        let area = try AreaCatalogLoader.load(HarborpointAreas.sableRow)
        let map = area.makeNavigationMap()
        // A building interior: blocked, and nothing to hear.
        let histogram = map.searchMap.terrainHistogram
        #expect(histogram[.obstacle, default: 0] > 0, "no solid cells were baked")
        #expect(histogram[.stone, default: 0] > 0, "no paved cells were baked")
        #expect(histogram[.roof, default: 0] > 0, "building roofs are not classified")
        #expect(histogram[.worldMapExit, default: 0] > 0, "street edges are not classified")
        for terrain in histogram.keys where !terrain.isWalkable {
            #expect(terrain.surface == .silent, "\(terrain) should not play footsteps")
        }
    }

    /// The office is 91.6% walkable because its obstacle set does not model the
    /// walls — the same permissiveness that let an entrance land on the wall
    /// crown and read as standable. Recorded here so the number is visible and
    /// so fitting a real floor diamond shows up as this test failing.
    @Test func theOfficeRasterStillHasNoWallsAndThatIsKnown() throws {
        let office = try AreaCatalogLoader.load(HarborpointAreas.office)
        let map = office.makeNavigationMap()
        let histogram = map.searchMap.terrainHistogram
        let total = map.searchMap.columns * map.searchMap.rows
        let walkable = Double(histogram[.wood, default: 0]) / Double(total)
        #expect(
            walkable > 0.85,
            "the office is now \(walkable) walkable — if a floor diamond landed, update this"
        )
    }
}
