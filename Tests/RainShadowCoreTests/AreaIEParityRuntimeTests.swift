import CoreGraphics
import Foundation
import Testing
@testable import RainShadowCore

struct GameClockTests {
    @Test func thePinnedNightHourActivatesTheNightMask() {
        let clock = GameClock.pinnedNight
        #expect(clock.hour == GameClock.pinnedNightHour)
        #expect(clock.isActive(.night))
        #expect(clock.isActive(.always))
        #expect(!clock.isActive(HourSchedule(rawValue: 0b1 << 12)))
    }

    @Test func wrappingADayKeepsTheHourInRange() {
        let clock = GameClock(secondsAfterMidnight: -60)
        #expect(clock.secondsAfterMidnight == GameClock.secondsPerDay - 60)
    }
}

struct AreaAmbientPlaybackTests {
    @Test func aGlobalBedIgnoresListenerDistance() {
        let ambient = AreaAmbient(id: "rain", assetName: "amb", volume: 0.4, isGlobal: true)
        #expect(AreaAmbientPlayback.gain(ambient: ambient, listener: .zero) == 1)
        let volume = AreaAmbientPlayback.volume(
            ambient: ambient, listener: CGPoint(x: 9_000, y: 9_000), clock: .pinnedNight
        )
        #expect(abs(volume - 0.4) < 0.001)
    }

    @Test func aLocalAmbientFallsOffToSilenceAtItsRadius() {
        let ambient = AreaAmbient(
            id: "drip",
            assetName: "amb",
            point: AreaPoint(x: 0, y: 0),
            radius: 100,
            volume: 1,
            isGlobal: false,
            schedule: .night
        )
        #expect(AreaAmbientPlayback.gain(ambient: ambient, listener: .zero) == 1)
        #expect(AreaAmbientPlayback.gain(ambient: ambient, listener: CGPoint(x: 50, y: 0)) == 0.5)
        #expect(AreaAmbientPlayback.gain(ambient: ambient, listener: CGPoint(x: 100, y: 0)) == 0)
        #expect(
            AreaAmbientPlayback.volume(
                ambient: ambient, listener: .zero, clock: GameClock(secondsAfterMidnight: 12 * 3600)
            ) == 0
        )
    }

    @Test func sequentialAndRandomSelectionStayInsideThePool() {
        let ambient = AreaAmbient(
            id: "pool",
            assetName: "a",
            sounds: ["a", "b", "c"],
            selection: .sequential
        )
        let first = AreaAmbientPlayback.pickSound(ambient: ambient, sequenceIndex: 0, roll: 0)
        let second = AreaAmbientPlayback.pickSound(ambient: ambient, sequenceIndex: first.nextIndex, roll: 0)
        #expect(first.name == "a")
        #expect(second.name == "b")

        var random = ambient
        random.selection = .random
        let picked = AreaAmbientPlayback.pickSound(ambient: random, sequenceIndex: 0, roll: 0.99)
        #expect(["a", "b", "c"].contains(picked.name))
    }

    @Test func intervalJitterStaysWithinDeviation() {
        let ambient = AreaAmbient(
            id: "oneshot",
            assetName: "tick",
            isLooping: false,
            interval: 10,
            intervalDeviation: 2
        )
        #expect(AreaAmbientPlayback.nextDelay(ambient: ambient, roll: 0.5) == 10)
        #expect(AreaAmbientPlayback.nextDelay(ambient: ambient, roll: 0) == 8)
        #expect(AreaAmbientPlayback.nextDelay(ambient: ambient, roll: 1) == 12)
    }
}

struct AreaTriggerTrackerTests {
    @Test func aTriggerFiresOnEntryAndNotAgainUnlessItResets() {
        let region = AreaRegion(
            id: "trap",
            kind: .trigger,
            polygon: [
                AreaPoint(x: 0, y: 0), AreaPoint(x: 10, y: 0),
                AreaPoint(x: 10, y: 10), AreaPoint(x: 0, y: 10)
            ]
        )
        var tracker = AreaTriggerTracker()
        #expect(tracker.evaluate(regions: [region], at: CGPoint(x: 5, y: 5)).map(\.id) == ["trap"])
        #expect(tracker.evaluate(regions: [region], at: CGPoint(x: 5, y: 5)).isEmpty)
        _ = tracker.evaluate(regions: [region], at: CGPoint(x: 50, y: 50))
        #expect(tracker.evaluate(regions: [region], at: CGPoint(x: 5, y: 5)).isEmpty)

        var resetting = region
        resetting.resets = true
        var resetTracker = AreaTriggerTracker()
        #expect(resetTracker.evaluate(regions: [resetting], at: CGPoint(x: 5, y: 5)).count == 1)
        _ = resetTracker.evaluate(regions: [resetting], at: CGPoint(x: 50, y: 50))
        #expect(resetTracker.evaluate(regions: [resetting], at: CGPoint(x: 5, y: 5)).count == 1)
    }

    @Test func aDeactivatedTriggerNeverFires() {
        let region = AreaRegion(
            id: "off",
            kind: .trigger,
            polygon: [
                AreaPoint(x: 0, y: 0), AreaPoint(x: 10, y: 0),
                AreaPoint(x: 10, y: 10), AreaPoint(x: 0, y: 10)
            ],
            isDeactivated: true
        )
        var tracker = AreaTriggerTracker()
        #expect(tracker.evaluate(regions: [region], at: CGPoint(x: 5, y: 5)).isEmpty)
    }
}

struct AreaDoorContractTests {
    @Test func perStateImpededCellsStampAndClearIndependentlyOfTheRect() {
        let closed = SearchMapCell(column: 2, row: 2)
        let open = SearchMapCell(column: 4, row: 2)
        let door = DoorObstacle(
            id: "probe.door",
            closedRect: CGRect(x: 1000, y: 1000, width: 4, height: 4),
            blocksSight: true,
            closedCells: [closed],
            openCells: [open],
            isOpen: false
        )
        let map = SearchMap(
            worldBounds: CGRect(x: 0, y: 0, width: 160, height: 120),
            obstacles: [],
            doorObstacles: [door]
        )
        #expect(map.flags(at: closed).contains(.doorImpassable))
        #expect(map.doorBlocksSight(at: closed))
        #expect(!map.flags(at: open).contains(.doorImpassable))

        map.setDoor(id: "probe.door", open: true)
        #expect(!map.flags(at: closed).contains(.doorImpassable))
        #expect(!map.doorBlocksSight(at: closed))
        #expect(map.flags(at: open).contains(.doorImpassable))
        #expect(!map.doorBlocksSight(at: open))
    }

    @Test func aLockedDoorNeedsItsKeyAndASecretDoorNeedsToBeFound() {
        let locked = AreaDoor(
            id: "a",
            closedObstacle: AreaRect(x: 0, y: 0, w: 4, h: 4),
            isLocked: true,
            keyItem: "brass-key"
        )
        #expect(!locked.canOpen(holdingKey: { _ in false }))
        #expect(locked.canOpen(holdingKey: { $0 == "brass-key" }))

        let secret = AreaDoor(
            id: "b",
            closedObstacle: AreaRect(x: 0, y: 0, w: 4, h: 4),
            isSecret: true
        )
        #expect(!secret.canOpen(holdingKey: { _ in true }))
        var found = secret
        found.isFound = true
        #expect(found.canOpen(holdingKey: { _ in true }))
    }

    @Test func theOfficeDoorAuthorsAnApproachPairAndSounds() throws {
        let office = OfficeAreaAdapter.area()
        let door = try #require(office.doors.first { $0.id == "office.door" })
        #expect(door.blocksSight)
        #expect(door.approachPoints.count == 2)
        #expect(door.openSound == "sfx_door_open")
        #expect(door.closeSound == "sfx_door_close")
        let first = try #require(door.approachPoints.first)
        #expect(door.nearestApproach(to: first.cgPoint) == first)
    }

    @Test func everyCityPortalIsAlsoADoor() throws {
        for id in CityDistrictID.allCases {
            let area = CityDistrictAreaAdapter.area(for: id)
            let definition = CityDistrictCatalog.definition(for: id)
            #expect(area.doors.count == definition.portals.count, "'\(id.slug)' door count drifted")
            for portal in definition.portals {
                let door = try #require(area.doors.first { $0.id == portal.id })
                #expect(door.blocksSight)
                #expect(door.approachPoints.count == 2)
                #expect(door.startsClosed)
                let closed = door.closedObstacle.cgRect
                let centre = CGPoint(x: closed.midX, y: closed.midY)
                #expect(
                    definition.obstacles.contains { $0.contains(centre) },
                    "'\(id.slug)' '\(portal.id)' closed leaf sits on the street"
                )
            }
        }
    }

    /// Exterior landmark doors follow the same two-record contract as IE:
    /// the door chooses the nearer use point and changes search-map state; the
    /// travel region separately names an area and an entrance in that area.
    @Test func everyLandmarkDoorEntersAnInteriorAndCanReturnToItsOwnThreshold() throws {
        for id in CityInteriorID.allCases {
            let exterior = CityDistrictAreaAdapter.area(for: id.exteriorDistrict)
            let region = try #require(exterior.region(id: id.exteriorPortalID))
            let door = try #require(exterior.doors.first { $0.id == region.id })
            let travel = try #require(region.travel)

            #expect(travel.destination == id.areaID)
            #expect(travel.entrance == CityInteriorAreaAdapter.streetEntrance)
            #expect(door.approachPoints.count == 2)
            let regionApproach = try #require(region.approachPoint)
            #expect(door.nearestApproach(to: regionApproach.cgPoint) != nil)

            let interior = CityInteriorAreaAdapter.area(for: id)
            let returnRegion = try #require(interior.region(id: "portal.return"))
            let returnTravel = try #require(returnRegion.travel)
            #expect(returnTravel.destination == exterior.id)
            #expect(returnTravel.entrance == id.exteriorEntranceName)
            #expect(exterior.entrance(named: id.exteriorEntranceName) != nil)
            #expect(interior.doors.contains { $0.id == returnRegion.id })
        }
    }
}

struct AreaLightMapTests {
    @Test func bilinearSamplingInterpolatesNeighborCells() {
        let map = AreaLightMap(
            columns: 2,
            rows: 2,
            samples: [
                AreaLightSample(red: 0, green: 0, blue: 0),
                AreaLightSample(red: 1, green: 0, blue: 0),
                AreaLightSample(red: 0, green: 1, blue: 0),
                AreaLightSample(red: 0, green: 0, blue: 1)
            ]
        )
        let mid = map.sample(
            at: CGPoint(x: 16, y: 12),
            origin: .zero,
            cellSize: SearchMap.defaultCellSize
        )
        #expect(abs(mid.red - 0.25) < 0.05)
    }

    @Test func aFlatHeightMapOffsetsNothing() {
        let raster = AreaSearchMapLoader.Raster(
            columns: 2,
            rows: 2,
            terrainIndices: [128, 128, 128, 128]
        )
        let offset = AreaHeightMap.offset(
            from: raster,
            at: CGPoint(x: 8, y: 6),
            origin: .zero,
            cellSize: SearchMap.defaultCellSize
        )
        #expect(abs(offset) < 0.05)
    }

    @Test func shippedPlayableAreasLoadANightLightMapMatchingTheSearchGrid() throws {
        for id in HarborpointAreas.shippedIDs where id != HarborpointAreas.openingExterior {
            let area = try AreaCatalogLoader.load(id)
            let map = try #require(
                AreaLightMapLoader.loadIfPresent(named: area.resolvedLightMapName),
                "'\(id)' is missing \(area.resolvedLightMapName).png"
            )
            let search = area.makeNavigationMap().searchMap
            #expect(map.columns == search.columns, "'\(id)' light map width drifted")
            #expect(map.rows == search.rows, "'\(id)' light map height drifted")
        }
    }

    @Test func theOfficeHeightMapIsFlat() throws {
        let raster = try #require(AreaHeightMap.loadIfPresent(named: "office_suite.ht"))
        #expect(raster.terrainIndices.allSatisfy { abs(Int($0) - 128) < 2 })
    }

    @Test func regionInsideDrivesAScriptBlock() {
        let script = AreaScript(id: "s", blocks: [
            AreaScriptBlock(
                id: "on.trap",
                when: .regionInside("trap"),
                do: [.setVariable("SEEN", .integer(1))]
            )
        ])
        let idle = AreaScriptContext(
            area: AreaID("probe"),
            variables: AreaVariables(),
            dialogue: DialogueRuntimeContext(
                caseState: CaseState(caseID: "c"),
                dialogueState: DialogueState(graphID: "s")
            )
        )
        #expect(!AreaScriptRunner.tick(script, in: idle).didFire)
        let inside = AreaScriptContext(
            area: AreaID("probe"),
            variables: AreaVariables(),
            dialogue: DialogueRuntimeContext(
                caseState: CaseState(caseID: "c"),
                dialogueState: DialogueState(graphID: "s")
            ),
            insideRegionIDs: ["trap"]
        )
        let outcome = AreaScriptRunner.tick(script, in: inside)
        #expect(outcome.blockID == "on.trap")
        #expect(outcome.variables.integer("SEEN", in: AreaID("probe")) == 1)
    }
}
