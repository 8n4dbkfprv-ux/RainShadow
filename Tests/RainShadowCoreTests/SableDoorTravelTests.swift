import CoreGraphics
import Testing
@testable import RainShadowCore

struct SableDoorTravelTests {
    @Test func apartmentRoundTripNamesReachableEntrancesWithoutChangingTheStoryWard() throws {
        let exterior = try AreaCatalogLoader.load(SableBlenderPlaytest.exteriorID)
        let originalOffice = HarborpointAreas.requireArea(HarborpointAreas.office)
        let office = SableBlenderPlaytest.office(from: originalOffice)
        let catalog = try AreaCatalogLoader.validate([exterior, office])
        let entry = try #require(exterior.region(id: SableBlenderPlaytest.apartmentRegionID))
        let outbound = try #require(entry.travel)
        #expect(outbound.destination == office.id)
        let returnRegion = try #require(office.region(id: "office.door"))
        let inbound = try #require(returnRegion.travel)
        #expect(inbound.destination == exterior.id)
        #expect(inbound.entrance == SableBlenderPlaytest.returnEntrance)
        #expect(originalOffice.region(id: "office.door")?.travel?.destination == HarborpointAreas.sableRow)
        #expect(office.wallPolygons == originalOffice.wallPolygons)
        #expect(office.entrances == originalOffice.entrances)

        // Exercise both real search maps, not a nonempty path that could have
        // snapped a bad approach to nearby floor.
        for (source, region) in [(exterior, entry), (office, returnRegion)] {
            let navigation = source.makeNavigationMap()
            let start = try #require(source.spawnPoint(entrance: nil))
            let approach = try #require(region.approachPoint).cgPoint
            #expect(navigation.reachesExactly(from: start, to: approach))
            let link = try #require(region.travel)
            let destination = try catalog.require(link.destination)
            let arrival = try #require(destination.entrance(named: link.entrance)).point.cgPoint
            let destinationNavigation = destination.makeNavigationMap()
            #expect(destinationNavigation.isOrderableFloor(arrival))
        }
    }

    @Test func openedLeafAndTravelOpeningHaveSeparateTargets() throws {
        let area = try AreaCatalogLoader.load(SableBlenderPlaytest.exteriorID)
        let door = try #require(area.doors.first)
        var objects = CityHighlightOutlines.objects(in: area)
        let index = try #require(objects.firstIndex { $0.id == door.id })
        #expect(objects[index].closedPolygon != objects[index].openPolygon)
        objects[index].isOpen = true
        let leaf = CGPoint(x: 520, y: 1916)
        let opening = CGPoint(x: 537, y: 1864)
        #expect(HighlightableObject.hit(at: leaf, among: objects)?.id == door.id)
        let result = HighlightResolver.resolve(hoverPoint: opening, revealAll: false,
                                               worldInteractionBlocked: false, objects: objects)
        #expect(result.hoverID == nil)
        #expect(result.outlines.isEmpty)
        #expect(area.region(at: opening)?.travel != nil)
        #expect(objects[index].polygon == door.openOutline.map(\.cgPoint))
        objects[index].isOpen = false
        #expect(objects[index].polygon == door.closedOutline.map(\.cgPoint))
    }

    @Test func thePaintedDoorHighlightsAndOffersTravelEvenThoughItsPixelsAreOnTheFacade() throws {
        let area = try AreaCatalogLoader.load(SableBlenderPlaytest.exteriorID)
        let glass = CGPoint(x: 519, y: 1899)
        let region = try #require(area.region(at: glass))
        let objects = CityHighlightOutlines.objects(in: area)
        let result = HighlightResolver.resolve(hoverPoint: glass, revealAll: false,
                                              worldInteractionBlocked: false, objects: objects)
        #expect(result.hoverID == region.id)
        #expect(result.outlines.contains { $0.id == region.id && $0.color == HighlightPalette.hoverDoor })
        #expect(WorldCursorState.resolve(isPassable: false, isTravel: region.kind == .travel).cursor == .travel)
        let cleared = HighlightResolver.resolve(hoverPoint: nil, revealAll: false,
                                               worldInteractionBlocked: false, objects: objects)
        #expect(cleared.outlines.isEmpty)
    }
}
