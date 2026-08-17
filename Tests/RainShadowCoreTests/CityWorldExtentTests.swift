import CoreGraphics
import Testing
@testable import RainShadowCore

/// World-scale and GemRB-lock gates for Act I Harborpoint districts.
///
/// Extent must sit in the Infinity Engine outdoor-area band (roughly 32–100
/// standing adults across). Runtime pathing constants stay exactly GemRB's:
/// 16×12 search cells, 16:12 ground ellipse, `NormalizeDeltas` × 0.75.
/// Reachability is `path` + flood-fill of the shipped search map — never `route`.
struct CityWorldExtentTests {
    /// Today's 2048-wide plate is 29.1 adults; IE outdoor areas start ~32.
    private static let retiredAdultsAcross: CGFloat = 29
    private static let infinityEngineOutdoorAdultBand: ClosedRange<CGFloat> = 32...100

    @Test func cityWorldExtentIsAnInfinityEngineOutdoorArea() {
        let adult = CityDistrictDefinition.standingAdultBodyHeight
        #expect(adult == OfficeInteriorScale.standingAdultBodyHeight)
        #expect(adult > 0)

        let adultsAcross = CityDistrictDefinition.worldArtSize.width / adult
        let adultsTall = CityDistrictDefinition.worldArtSize.height / adult
        #expect(
            adultsAcross > Self.retiredAdultsAcross,
            "world width \(CityDistrictDefinition.worldArtSize.width) is still \(adultsAcross) adults"
        )
        #expect(
            Self.infinityEngineOutdoorAdultBand.contains(adultsAcross),
            "adults across \(adultsAcross) outside the IE outdoor band \(Self.infinityEngineOutdoorAdultBand)"
        )
        #expect(adultsTall > 16, "district is still a single junction in depth (\(adultsTall) adults)")
        #expect(CityDistrictDefinition.environmentScale == 1)
        #expect(CityDistrictDefinition.worldBounds.size == CityDistrictDefinition.worldArtSize)
        #expect(CityDistrictDefinition.worldArtSize.width.truncatingRemainder(dividingBy: 16) == 0)
        #expect(CityDistrictDefinition.worldArtSize.height.truncatingRemainder(dividingBy: 12) == 0)
    }

    @Test func gemRBSearchMapAndProjectionConstantsAreUnchanged() {
        #expect(SearchMap.defaultCellSize.width == 16)
        #expect(SearchMap.defaultCellSize.height == 12)
        #expect(ActorLocomotionPacing.verticalProjectionScale == 0.75)
        #expect(
            SearchMap.defaultCellSize.height / SearchMap.defaultCellSize.width
                == ActorLocomotionPacing.verticalProjectionScale
        )
        // Ground circle is the same 16:12 ellipse GemRB uses for search cells.
        let ellipseRatio = SearchMap.defaultCellSize.width / SearchMap.defaultCellSize.height
        #expect(abs(ellipseRatio - 16.0 / 12.0) < 0.0001)
        #expect(abs(ellipseRatio - 1.0 / 0.75) < 0.0001)
    }

    @Test func citySearchMapUsesGemRBCellSize() {
        for id in CityDistrictID.allCases {
            let map = CityDistrictCatalog.definition(for: id).makeGrid()
            #expect(map.searchMap.cellSize == SearchMap.defaultCellSize)
            #expect(map.searchMap.columns == Int(CityDistrictDefinition.worldArtSize.width / 16))
            #expect(map.searchMap.rows == Int(CityDistrictDefinition.worldArtSize.height / 12))
        }
    }

    @Test func objectScaleBandsStayHuman() {
        let door = CityDistrictLayout.doorBodyMultiple(
            doorLeafHeight: CityDistrictLayout.SourceSeparateDoorLeafHeight.standard,
            textureName: "city_door_voss_stoop"
        )
        let car = CityDistrictLayout.bodyMultiple(
            contentHeight: CityDistrictLayout.SourceContentHeight.carBlack,
            textureName: "city_prop_car_black"
        )
        let lamp = CityDistrictLayout.bodyMultiple(
            contentHeight: CityDistrictLayout.SourceContentHeight.lamp,
            textureName: "city_prop_lamp"
        )
        let bench = CityDistrictLayout.bodyMultiple(
            contentHeight: CityDistrictLayout.SourceContentHeight.bench,
            scale: CityDistrictLayout.PropDisplayScale.bench
        )
        let kiosk = CityDistrictLayout.bodyMultiple(
            contentHeight: CityDistrictLayout.SourceContentHeight.kiosk,
            textureName: "city_prop_kiosk"
        )
        #expect(door != nil && CityDistrictLayout.Band.doorLeaf.contains(door!))
        #expect(car != nil && CityDistrictLayout.Band.car.contains(car!))
        #expect(lamp != nil && CityDistrictLayout.Band.streetLamp.contains(lamp!))
        #expect(CityDistrictLayout.Band.bench.contains(bench))
        #expect(kiosk != nil && CityDistrictLayout.Band.kiosk.contains(kiosk!))
        let terrace = CityDistrictLayout.TerraceSpec.worldHeight
            / CityDistrictLayout.standingAdultBodyHeight
        #expect(CityDistrictLayout.Band.multiStoryBuilding.contains(terrace))
    }

    @Test func everySpawnAndPortalHasAnExactPathOnTheShippedSearchMap() {
        let radius = NavigationAgentProfile.detective.radius
        for id in CityDistrictID.allCases {
            let district = CityDistrictCatalog.definition(for: id)
            let map = district.makeGrid()
            let start = district.actorStart
            #expect(
                map.searchMap.isPassable(at: start, radius: radius),
                "\(id) actorStart \(start) is not standable"
            )

            let flood = Self.reachableCells(map, from: start, radius: radius)
            #expect(
                flood.count > 8_000,
                "\(id) outdoor floor is still a sealed pocket (\(flood.count) cells)"
            )

            var points: [(String, CGPoint)] = [("actorStart", start)]
            for (key, spawn) in district.spawnByArrivalKey {
                points.append((key, spawn))
            }
            for portal in district.portals {
                points.append((portal.id, portal.approachPoint))
            }

            for (name, point) in points {
                #expect(
                    map.searchMap.isPassable(at: point, radius: radius),
                    "\(id) \(name) \(point) is not standable"
                )
                #expect(
                    flood.contains(map.searchMap.cell(for: point)),
                    "\(id) \(name) \(point) is not on the outdoor flood from actorStart"
                )
                #expect(
                    map.path(from: start, to: point) != nil,
                    "\(id) \(name) \(point) has no exact path from actorStart"
                )
            }
        }
    }

    @Test func cityDoesNotUseRouteToHideSealedGeometry() {
        // Drive the shipped `path` entry point. `route` snaps and would pass
        // from inside a building.
        for id in CityDistrictID.allCases {
            let district = CityDistrictCatalog.definition(for: id)
            let map = district.makeGrid()
            for portal in district.portals {
                let exact = map.path(from: district.actorStart, to: portal.approachPoint)
                #expect(exact != nil, "\(id) \(portal.id) exact path is nil")
                if let route = map.route(from: district.actorStart, to: portal.approachPoint) {
                    #expect(route.destinationWasAdjusted == false)
                    #expect(route.resolvedDestination == portal.approachPoint)
                }
            }
        }
    }

    private static func reachableCells(
        _ map: NavigationMap,
        from start: CGPoint,
        radius: CGFloat
    ) -> Set<SearchMapCell> {
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
                guard search.contains(next),
                      !visited.contains(next),
                      search.isPassable(at: search.center(of: next), radius: radius)
                else { continue }
                visited.insert(next)
                queue.append(next)
            }
        }
        return visited
    }
}
