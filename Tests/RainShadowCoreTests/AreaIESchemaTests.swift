import CoreGraphics
import Foundation
import Testing
@testable import RainShadowCore

/// Phase 1 of Infinity Engine area parity: the ARE+WED-shaped schema decodes
/// from files that predate it, and the new sections round-trip.
struct AreaIESchemaTests {

    private func decode(_ json: String) throws -> AreaDefinition {
        try AreaCatalogLoader.decodeArea(Data(json.utf8))
    }

    private func headerJSON(extra: String = "") -> String {
        """
        {
          "schemaVersion": 1,
          "area": {
            "id": "probe",
            "displayName": "Probe",
            "kind": "interior",
            "worldSize": { "w": 100, "h": 80 },
            "plateTextureName": "probe_plate",
            "agentProfile": { "halfWidth": 0, "halfHeight": 0 },
            "entrances": [{ "name": "default", "point": { "x": 5, "y": 5 } }]
            \(extra.isEmpty ? "" : ",\(extra)")
          }
        }
        """
    }

    // MARK: - Backward compatibility

    @Test func shippedAreasKeepOptionalIESlotsEmptyAndNightPinned() throws {
        for id in HarborpointAreas.shippedIDs {
            let area = try AreaCatalogLoader.load(id)
            #expect(area.variables.isEmpty, "'\(id)' unexpectedly authored variables")
            #expect(area.songs.isEmpty, "'\(id)' unexpectedly authored songs")
            let isSharedInterior = CityInteriorAreaAdapter.interior(for: id) != nil
            #expect(
                area.lightMapName == (isSharedInterior ? "city_building_interior_v01.lm" : nil)
            )
            #expect(area.heightMapName == nil)
            #expect(
                area.resolvedLightMapName
                    == (isSharedInterior ? "city_building_interior_v01.lm" : "\(id.rawValue).lm")
            )
            #expect(area.resolvedHeightMapName == "\(id.rawValue).ht")
            for region in area.regions {
                #expect(region.isDetectable)
                #expect(!region.isDeactivated)
                #expect(!region.partyOnly)
                #expect(!region.resets)
            }
            for door in area.doors {
                #expect(!door.isLocked)
                #expect(!door.cannotClose)
                #expect(!door.isSecret)
            }
        }

        let exterior = try AreaCatalogLoader.load(HarborpointAreas.openingExterior)
        #expect(exterior.wallPolygons.isEmpty)
        #expect(exterior.animations.isEmpty)
        #expect(exterior.doors.isEmpty)

        let office = try AreaCatalogLoader.load(HarborpointAreas.office)
        #expect(office.wallPolygons.contains { $0.id == "office.bookshelf" })
        #expect(office.doors.contains { $0.id == "office.door" && $0.approachPoints.count == 2 })
        #expect(office.ambients.contains { $0.schedule == .night })
        #expect(!office.animations.isEmpty)

        for id in CityDistrictID.allCases {
            let area = try AreaCatalogLoader.load(CityDistrictAreaAdapter.areaID(for: id))
            #expect(area.wallPolygons.count == CityStreetPlan.all.count)
            #expect(area.doors.count == CityDistrictCatalog.definition(for: id).portals.count)
            #expect(area.ambients.contains { $0.id == "amb.rain" && $0.schedule == .night })
        }
    }

    @Test func aLegacyRegionWithoutFlagsStillDecodesAsAnInfoPoint() throws {
        let area = try decode(headerJSON(extra: """
            "regions": [{
              "id": "probe.info",
              "kind": "info",
              "polygon": [
                { "x": 0, "y": 0 }, { "x": 10, "y": 0 },
                { "x": 10, "y": 10 }, { "x": 0, "y": 10 }
              ]
            }]
            """))
        let region = try #require(area.regions.first)
        #expect(region.isDetectable)
        #expect(!region.isDeactivated)
        #expect(region.resolvedCursor == .info)
    }

    @Test func aLegacyDoorWithoutTheContractStillBlocksSightAndIsUnlocked() throws {
        let area = try decode(headerJSON(extra: """
            "doors": [{
              "id": "probe.door",
              "closedObstacle": { "x": 10, "y": 10, "w": 4, "h": 8 },
              "startsClosed": true
            }]
            """))
        let door = try #require(area.doors.first)
        #expect(door.blocksSight)
        #expect(!door.isLocked)
        #expect(door.keyItem == nil)
        #expect(door.nearestApproach(to: CGPoint(x: 0, y: 0)) == nil)
    }

    // MARK: - New sections round-trip

    @Test func hourScheduleMasksMatchTheEngineOffset() {
        #expect(HourSchedule.always.isActive(atHour: 0))
        #expect(HourSchedule.always.isActive(atHour: 23))
        #expect(HourSchedule.night.isActive(atHour: 20))
        #expect(HourSchedule.night.isActive(atHour: 5))
        #expect(!HourSchedule.night.isActive(atHour: 12))
        // 00:00 is still the previous hour's slot under the 30-minute offset:
        // 00:00 + 30 min = 00:30, which is bit 0.
        #expect(HourSchedule.night.isActive(atSecondsAfterMidnight: 0))
        // 06:00 + 30 min = 06:30, bit 6, which night does not set.
        #expect(!HourSchedule.night.isActive(atSecondsAfterMidnight: 6 * 3600))
        // 19:30 + 30 min = 20:00, bit 20, which night does set.
        #expect(HourSchedule.night.isActive(atSecondsAfterMidnight: 19 * 3600 + 30 * 60))
    }

    @Test func aFullDoorContractRoundTrips() throws {
        let door = AreaDoor(
            id: "probe.door",
            closedObstacle: AreaRect(x: 10, y: 10, w: 4, h: 8),
            isLocked: true,
            isSecret: true,
            keyItem: "office.brass-key",
            lockedLine: "Locked.",
            openSound: "sfx_door_open",
            closeSound: "sfx_door_close",
            approachPoints: [
                AreaPoint(x: 8, y: 12),
                AreaPoint(x: 18, y: 12)
            ],
            closedOutline: [
                AreaPoint(x: 10, y: 10), AreaPoint(x: 14, y: 10),
                AreaPoint(x: 14, y: 18), AreaPoint(x: 10, y: 18)
            ],
            closedImpededCells: [AreaSearchCell(column: 3, row: 2)]
        )
        let area = AreaDefinition(
            id: AreaID("probe"),
            displayName: "Probe",
            kind: .interior,
            worldSize: AreaSize(w: 100, h: 80),
            plateTextureName: "probe_plate",
            agentProfile: AreaAgentProfile(.point),
            entrances: [AreaEntrance(name: "default", point: AreaPoint(x: 5, y: 5))],
            doors: [door]
        )
        let encoded = try JSONEncoder().encode(AreaDocument(area: area))
        let decoded = try AreaCatalogLoader.decodeArea(encoded)
        let loaded = try #require(decoded.doors.first)
        #expect(loaded == door)
        #expect(loaded.nearestApproach(to: CGPoint(x: 7, y: 12))?.x == 8)
        #expect(loaded.nearestApproach(to: CGPoint(x: 19, y: 12))?.x == 18)
    }

    @Test func aPositionalAmbientAndAnAnimationRoundTripWithSchedule() throws {
        let ambient = AreaAmbient(
            id: "amb.neon",
            assetName: "sfx_neon_buzz",
            sounds: ["sfx_neon_buzz", "sfx_neon_crackle"],
            selection: .random,
            point: AreaPoint(x: 40, y: 20),
            radius: 120,
            volume: 0.4,
            isLooping: false,
            interval: 8,
            intervalDeviation: 3,
            isGlobal: false,
            schedule: .night
        )
        let animation = AreaAnimation(
            id: "anim.neon",
            point: AreaPoint(x: 40, y: 28),
            textureName: "fx_neon_flicker",
            frameCount: 6,
            frameRate: 12,
            loopChance: 1,
            randomStartFrame: true,
            isSelfIlluminated: true,
            wallHides: true,
            schedule: .night,
            blend: .add
        )
        let area = AreaDefinition(
            id: AreaID("probe"),
            displayName: "Probe",
            kind: .exterior,
            worldSize: AreaSize(w: 100, h: 80),
            plateTextureName: "probe_plate",
            agentProfile: AreaAgentProfile(.point),
            entrances: [AreaEntrance(name: "default", point: AreaPoint(x: 5, y: 5))],
            wallPolygons: [
                AreaWallPolygon(
                    id: "facade",
                    rect: CGRect(x: 0, y: 40, width: 80, height: 20),
                    height: 72
                )
            ],
            ambients: [ambient],
            animations: [animation],
            variables: ["SEEN": .flag(true)],
            songs: AreaSongs(night: "mus_harbor_night", battle: nil),
            lightMapName: "probe.lm",
            heightMapName: "probe.ht"
        )
        let encoded = try JSONEncoder().encode(AreaDocument(area: area))
        let decoded = try AreaCatalogLoader.decodeArea(encoded)
        #expect(decoded.ambients == [ambient])
        #expect(decoded.animations == [animation])
        #expect(decoded.variables["SEEN"]?.isSet == true)
        #expect(decoded.songs.night == "mus_harbor_night")
        #expect(decoded.songs.day == nil)
        #expect(decoded.lightMapName == "probe.lm")
        #expect(decoded.heightMapName == "probe.ht")
        #expect(decoded.wallPolygons.first?.height == 72)
        #expect(decoded.ambients.first?.soundPool.count == 2)
        #expect(!decoded.ambients.first!.isGlobal)
    }

    @Test func aTriggerRegionCarriesIEFlagsAndAScriptHook() throws {
        let region = AreaRegion(
            id: "probe.trigger",
            kind: .trigger,
            rect: CGRect(x: 0, y: 0, width: 20, height: 20),
            scriptBlock: "on.enter.probe",
            isDetectable: false,
            partyOnly: true,
            resets: true,
            cursor: .hidden
        )
        let area = AreaDefinition(
            id: AreaID("probe"),
            displayName: "Probe",
            kind: .interior,
            worldSize: AreaSize(w: 100, h: 80),
            plateTextureName: "probe_plate",
            agentProfile: AreaAgentProfile(.point),
            entrances: [AreaEntrance(name: "default", point: AreaPoint(x: 5, y: 5))],
            regions: [region]
        )
        let encoded = try JSONEncoder().encode(AreaDocument(area: area))
        let decoded = try AreaCatalogLoader.decodeArea(encoded)
        let loaded = try #require(decoded.regions.first)
        #expect(loaded.kind == .trigger)
        #expect(loaded.scriptBlock == "on.enter.probe")
        #expect(!loaded.isDetectable)
        #expect(loaded.partyOnly)
        #expect(loaded.resets)
        #expect(loaded.resolvedCursor == .hidden)
    }

    @Test func duplicateDoorAndAnimationIdsAreRejected() {
        let entrance = AreaEntrance(name: "default", point: AreaPoint(x: 1, y: 1))
        let door = AreaDoor(
            id: "same",
            closedObstacle: AreaRect(x: 0, y: 0, w: 1, h: 1)
        )
        let doors = AreaDefinition(
            id: AreaID("probe"),
            displayName: "Probe",
            kind: .interior,
            worldSize: AreaSize(w: 10, h: 10),
            plateTextureName: "p",
            agentProfile: AreaAgentProfile(.point),
            entrances: [entrance],
            doors: [door, door]
        )
        #expect(throws: AreaCatalogError.duplicateDoorID(area: AreaID("probe"), doorID: "same")) {
            _ = try AreaCatalogLoader.validate([doors])
        }

        let animation = AreaAnimation(
            id: "same",
            point: AreaPoint(x: 0, y: 0),
            textureName: "fx"
        )
        let animations = AreaDefinition(
            id: AreaID("probe"),
            displayName: "Probe",
            kind: .interior,
            worldSize: AreaSize(w: 10, h: 10),
            plateTextureName: "p",
            agentProfile: AreaAgentProfile(.point),
            entrances: [entrance],
            animations: [animation, animation]
        )
        #expect(throws: AreaCatalogError.duplicateAnimationID(
            area: AreaID("probe"),
            animationID: "same"
        )) {
            _ = try AreaCatalogLoader.validate([animations])
        }
    }
}
