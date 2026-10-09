import CoreGraphics
import Foundation
import Testing
@testable import RainShadowCore
@testable import RainShadowPersistence

@MainActor @Suite(.serialized)
struct LilaInteriorTests {
    @Test func lodgingLoopUsesBothFloorsAndSeparateStreetReturns() throws {
        let catalog = try AreaCatalogLoader.load(HarborpointAreas.shippedIDs)
        let street = try #require(catalog.area(for: HarborpointAreas.lilaStreet))
        let hall = CityInteriorAreaAdapter.area(for: .lilaHall)
        let rooms = CityInteriorAreaAdapter.area(for: .lilaRooms)
        #expect(hall.plateTextureName == "lila_hall_oct09")
        #expect(rooms.plateTextureName == "lila_rooms_oct09")
        #expect(street.travelRegions.first { $0.id == "portal.lilaRooms" }?.travel?.destination == hall.id)
        #expect(hall.travelRegions.contains { $0.travel?.destination == rooms.id })
        #expect(rooms.travelRegions.contains { $0.travel?.destination == hall.id })
        let escape = try #require(rooms.travelRegions.first { $0.id == "lila.backstairs" }?.travel)
        #expect(escape.destination == street.id)
        #expect(street.entrance(named: escape.entrance)?.point != street.entrance(named: "from.portal.lilaRooms")?.point)
        for area in [hall, rooms] {
            let map = area.makeNavigationMap()
            let start = try #require(area.spawnPoint(entrance: nil))
            let visible = map.searchMap.visibleCells(from: start, radiusInCells: SearchMapExplore.searchRadius(visualRangeInFogTiles: 14))
            let paintedExit = area.id == hall.id
                ? area.regions.first { $0.id == "lila.stairs.up" }
                : area.regions.first { $0.id == "lila.backstairs" }
            for point in try #require(paintedExit).polygon {
                #expect(visible.contains(map.searchMap.cell(for: point.cgPoint)),
                        "The painted stair/door must be visible, not just its floor approach")
            }
            for region in area.regions {
                let target = try #require(region.approachPoint?.cgPoint)
                var walker = Movable(map: map, identity: "lila.qa", position: start,
                                     circleSize: map.circleSize, blocksSearchMap: false)
                walker.walkTo(target, ticks: 1)
                for tick in 2..<12000 {
                    let step = walker.doStep(walkScale: MovableTestSupport.humanoidWalkScale, time: tick)
                    if step.arrived || step.abandoned || !walker.isMoving { break }
                }
                #expect(map.searchMap.cell(for: walker.position) == map.searchMap.cell(for: target),
                        "\(area.id): \(region.id) cannot be reached by the actual mover")
            }
            #expect(!area.makeWallStencil().isEmpty)
        }
        #expect(rooms.spawnPoint(entrance: nil) == CGPoint(x: SaveStore.lilaRoomsArrival.x,
                                                        y: SaveStore.lilaRoomsArrival.y))
    }

    @Test func oldLodgingSpatialStateMigratesOnceAndPreservesProgress() throws {
        let suite = "RainShadow.LilaQA.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        var old = SaveSnapshot(hasSeenOpening: true, hasCompletedOfficeCaseIntro: true,
                               walletPence: 317, carriedItems: [.init(id: "key", quantity: 1)],
                               groundPiles: ["RS0501": [.init(id: "letter", quantity: 2, x: 1390, y: 335)]],
                               caseFlags: ["retained"])
        old.lilaLayoutRevision = 0
        let data = try JSONEncoder().encode(old)
        defaults.set(data, forKey: "test")
        let store = SaveStore(defaults: defaults, key: "test", resetsOnLaunch: false)
        let current = store.load()
        #expect(current.walletPence == old.walletPence)
        #expect(current.carriedItems == old.carriedItems)
        #expect(current.caseFlags == old.caseFlags)
        #expect(current.groundPiles["RS0501"]?.first?.x == SaveStore.lilaRoomsArrival.x)
        #expect(current.groundPiles["RS0501"]?.first?.quantity == 2)
        #expect(current.lilaLayoutRevision == 1)
        #expect(defaults.data(forKey: "test.BeforeLilaInteriorsOct09") == data)
        #expect(store.load() == current)
    }
}
