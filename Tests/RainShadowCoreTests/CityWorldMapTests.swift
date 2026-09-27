import CoreGraphics
import Testing
@testable import RainShadowCore

struct CityWorldMapTests {
    @Test func harborpointUsesThreeByThreeGrid() {
        #expect(CityWorldMap.gridColumns == 3)
        #expect(CityWorldMap.gridRows == 3)
        #expect(CityWorldMap.cells.count == 3)
        #expect(CityWorldMap.cells.allSatisfy { $0.count == 3 })
    }

    @Test func districtCoordinatesMatchAuthoredLayout() {
        // Market Cross is the central district; Voss's Sable Row sits east of it.
        #expect(CityWorldMap.coordinate(for: .marketCross) == .init(col: 1, row: 1))
        #expect(CityWorldMap.coordinate(for: .wharfLadder) == .init(col: 0, row: 1))
        #expect(CityWorldMap.coordinate(for: .sableRow) == .init(col: 2, row: 1))
        #expect(CityWorldMap.coordinate(for: .civicRecords) == .init(col: 1, row: 2))
        #expect(CityWorldMap.coordinate(for: .riverside) == .init(col: 0, row: 0))
        #expect(CityWorldMap.coordinate(for: .lampWard) == .init(col: 1, row: 0))
    }

    @Test func centralDistrictStampCoversTwiceTheOfficeWard() {
        let centre = CityDistrictID.marketCross.worldMapFootprintScale
        let office = CityDistrictID.sableRow.worldMapFootprintScale
        #expect(abs(centre * centre - 2 * office * office) < 0.0001)
        #expect(CityDistrictID.marketCross.artSlug == "lila_street")
        #expect(CityDistrictAreaAdapter.sidecarStem(for: .marketCross) == "city_lila_street")
    }

    @Test func districtWorldMapMarkersHaveNormalAndHoverNames() {
        for district in CityDistrictID.allCases {
            #expect(district.worldMapIconTextureName == "map_district_icon_\(district.artSlug)_v01")
            #expect(district.worldMapIconHoverTextureName == "map_district_icon_\(district.artSlug)_v01_hover")
        }
    }

    @Test func orthogonalNeighborsMatchBGCityAdjacency() {
        #expect(CityWorldMap.neighbor(of: .marketCross, toward: .west)?.districtID == .wharfLadder)
        #expect(CityWorldMap.neighbor(of: .marketCross, toward: .east)?.districtID == .sableRow)
        #expect(CityWorldMap.neighbor(of: .marketCross, toward: .north)?.districtID == .civicRecords)
        #expect(CityWorldMap.neighbor(of: .marketCross, toward: .south)?.districtID == .lampWard)
        #expect(CityWorldMap.neighbor(of: .sableRow, toward: .west)?.districtID == .marketCross)
        #expect(CityWorldMap.neighbor(of: .wharfLadder, toward: .south)?.districtID == .riverside)
        #expect(CityWorldMap.neighbor(of: .riverside, toward: .east)?.districtID == .lampWard)
    }

    @Test func lockedWardsOccupyCornerCells() {
        #expect(CityWorldMap.neighbor(of: .civicRecords, toward: .west)?.isLocked == true)
        #expect(CityWorldMap.neighbor(of: .civicRecords, toward: .east)?.isLocked == true)
        #expect(CityWorldMap.neighbor(of: .lampWard, toward: .east)?.isLocked == true)
        #expect(CityWorldMap.neighbor(of: .sableRow, toward: .south)?.isLocked == true)
        #expect(CityWorldMap.neighbor(of: .sableRow, toward: .north)?.isLocked == true)
    }

    @Test func revealRuleMatchesBGVisitedOrAdjacent() {
        // From the office ward only the central district is open.
        let fromOffice: Set<CityDistrictID> = [.sableRow]
        #expect(CityWorldMap.isTravelable(.sableRow, visited: fromOffice))
        #expect(CityWorldMap.isTravelable(.marketCross, visited: fromOffice))
        #expect(!CityWorldMap.isTravelable(.wharfLadder, visited: fromOffice))
        #expect(!CityWorldMap.isTravelable(.civicRecords, visited: fromOffice))
        #expect(!CityWorldMap.isTravelable(.lampWard, visited: fromOffice))

        let visited: Set<CityDistrictID> = [.sableRow, .marketCross]
        #expect(CityWorldMap.isTravelable(.wharfLadder, visited: visited))
        #expect(CityWorldMap.isTravelable(.civicRecords, visited: visited))
        #expect(CityWorldMap.isTravelable(.lampWard, visited: visited))
        // Diagonal-only neighbor is not revealed from the hub alone.
        #expect(!CityWorldMap.isTravelable(.riverside, visited: visited))

        let afterWharf: Set<CityDistrictID> = [.sableRow, .marketCross, .wharfLadder]
        #expect(CityWorldMap.isTravelable(.riverside, visited: afterWharf))
    }

    @Test func lockedWardsAreNeverTravelable() {
        let allVisited = Set(CityDistrictID.allCases)
        for edge in CityMapEdge.allCases {
            if case .lockedWard = CityWorldMap.neighbor(of: .civicRecords, toward: edge) {
                // Locked cells have no district ID and cannot appear in travelableDistricts.
                break
            }
        }
        #expect(CityWorldMap.travelableDistricts(visited: allVisited) == allVisited)
        #expect(CityWorldMap.isLockedWardRevealed("unmapped_nw", visited: [.civicRecords]))
        #expect(CityWorldMap.isLockedWardRevealed("unmapped_se", visited: [.sableRow]))
        #expect(!CityWorldMap.isLockedWardRevealed("unmapped_se", visited: [.marketCross]))
    }

    @Test func arrivalEdgeIsOppositeOfExit() {
        #expect(CityWorldMap.arrivalEdge(leavingVia: .west) == .east)
        #expect(CityWorldMap.arrivalKey(leavingVia: .north) == "from.south")
        #expect(CityWorldMap.arrivalEdge(from: .marketCross, to: .wharfLadder) == .east)
        #expect(CityWorldMap.arrivalKey(from: .marketCross, to: .lampWard) == "from.north")
        #expect(CityWorldMap.arrivalKey(from: .sableRow, to: .marketCross) == "from.east")
        #expect(CityWorldMap.arrivalKey(from: .wharfLadder, to: .riverside) == "from.north")
    }

    @Test func everyTravelableExitHasCatalogSpawnOnDestination() {
        for origin in CityDistrictID.allCases {
            for edge in CityWorldMap.travelableExitEdges(from: origin) {
                guard let neighbor = CityWorldMap.neighbor(of: origin, toward: edge),
                      let destinationID = neighbor.districtID else {
                    Issue.record("Missing playable neighbor for \(origin) \(edge)")
                    continue
                }
                let arrivalKey = CityWorldMap.arrivalKey(leavingVia: edge)
                let destination = CityDistrictCatalog.definition(for: destinationID)
                #expect(
                    destination.spawnByArrivalKey[arrivalKey] != nil,
                    "\(destinationID) missing spawn for \(arrivalKey) from \(origin)"
                )
            }
        }
    }

    @Test func catalogNoLongerUsesDistrictPortals() {
        for id in CityDistrictID.allCases {
            let portals = CityDistrictCatalog.definition(for: id).portals
            #expect(portals.allSatisfy { portal in
                if case .district = portal.destination { return false }
                return true
            }, "District \(id) still has a district portal")
        }
        #expect(CityDistrictCatalog.sableRow.portals.contains(where: {
            if case .office = $0.destination { return true }
            return false
        }))
    }

    @Test func travelableExitEdgesExcludeLockedBorders() {
        let centreEdges = Set(CityWorldMap.travelableExitEdges(from: .marketCross))
        #expect(centreEdges == Set(CityMapEdge.allCases))

        let civicEdges = Set(CityWorldMap.travelableExitEdges(from: .civicRecords))
        #expect(civicEdges == [.south])

        let sableEdges = Set(CityWorldMap.travelableExitEdges(from: .sableRow))
        #expect(sableEdges == [.west])
    }

    @Test func edgeExitHitAreasSitInsideWorldBounds() {
        let bounds = CityDistrictDefinition.worldBounds
        for edge in CityMapEdge.allCases {
            let area = CityWorldMap.exitHitArea(for: edge, worldBounds: bounds)
            #expect(bounds.contains(CGPoint(x: area.midX, y: area.midY)))
            #expect(area.width > 0 && area.height > 0)
        }
    }
}
