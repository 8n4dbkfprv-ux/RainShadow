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
        #expect(CityWorldMap.coordinate(for: .sableRow) == .init(col: 1, row: 1))
        #expect(CityWorldMap.coordinate(for: .wharfLadder) == .init(col: 0, row: 1))
        #expect(CityWorldMap.coordinate(for: .lilaStreet) == .init(col: 2, row: 1))
        #expect(CityWorldMap.coordinate(for: .civicRecords) == .init(col: 1, row: 2))
        #expect(CityWorldMap.coordinate(for: .riverside) == .init(col: 0, row: 0))
        #expect(CityWorldMap.coordinate(for: .harborpointPD) == .init(col: 1, row: 0))
    }

    @Test func districtWorldMapMarkersHaveNormalAndHoverNames() {
        for district in CityDistrictID.allCases {
            #expect(district.worldMapIconTextureName == "map_district_icon_\(district.slug)_v01")
            #expect(district.worldMapIconHoverTextureName == "map_district_icon_\(district.slug)_v01_hover")
        }
    }

    @Test func orthogonalNeighborsMatchBGCityAdjacency() {
        #expect(CityWorldMap.neighbor(of: .sableRow, toward: .west)?.districtID == .wharfLadder)
        #expect(CityWorldMap.neighbor(of: .sableRow, toward: .east)?.districtID == .lilaStreet)
        #expect(CityWorldMap.neighbor(of: .sableRow, toward: .north)?.districtID == .civicRecords)
        #expect(CityWorldMap.neighbor(of: .sableRow, toward: .south)?.districtID == .harborpointPD)
        #expect(CityWorldMap.neighbor(of: .wharfLadder, toward: .south)?.districtID == .riverside)
        #expect(CityWorldMap.neighbor(of: .riverside, toward: .east)?.districtID == .harborpointPD)
    }

    @Test func lockedWardsOccupyCornerCells() {
        #expect(CityWorldMap.neighbor(of: .civicRecords, toward: .west)?.isLocked == true)
        #expect(CityWorldMap.neighbor(of: .civicRecords, toward: .east)?.isLocked == true)
        #expect(CityWorldMap.neighbor(of: .harborpointPD, toward: .east)?.isLocked == true)
        #expect(CityWorldMap.neighbor(of: .lilaStreet, toward: .south)?.isLocked == true)
    }

    @Test func revealRuleMatchesBGVisitedOrAdjacent() {
        let visited: Set<CityDistrictID> = [.sableRow]
        #expect(CityWorldMap.isTravelable(.sableRow, visited: visited))
        #expect(CityWorldMap.isTravelable(.wharfLadder, visited: visited))
        #expect(CityWorldMap.isTravelable(.lilaStreet, visited: visited))
        #expect(CityWorldMap.isTravelable(.civicRecords, visited: visited))
        #expect(CityWorldMap.isTravelable(.harborpointPD, visited: visited))
        // Diagonal-only neighbor is not revealed from the hub alone.
        #expect(!CityWorldMap.isTravelable(.riverside, visited: visited))

        let afterWharf: Set<CityDistrictID> = [.sableRow, .wharfLadder]
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
        #expect(!CityWorldMap.isLockedWardRevealed("unmapped_se", visited: [.sableRow]))
    }

    @Test func arrivalEdgeIsOppositeOfExit() {
        #expect(CityWorldMap.arrivalEdge(leavingVia: .west) == .east)
        #expect(CityWorldMap.arrivalKey(leavingVia: .north) == "from.south")
        #expect(CityWorldMap.arrivalEdge(from: .sableRow, to: .wharfLadder) == .east)
        #expect(CityWorldMap.arrivalKey(from: .sableRow, to: .harborpointPD) == "from.north")
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
        let sableEdges = Set(CityWorldMap.travelableExitEdges(from: .sableRow))
        #expect(sableEdges == Set(CityMapEdge.allCases))

        let civicEdges = Set(CityWorldMap.travelableExitEdges(from: .civicRecords))
        #expect(civicEdges == [.south])

        let lilaEdges = Set(CityWorldMap.travelableExitEdges(from: .lilaStreet))
        #expect(lilaEdges == [.west])
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
