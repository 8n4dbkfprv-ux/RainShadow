import CoreGraphics
import Foundation

/// Projects the Swift district catalog onto the `AreaDefinition` record.
///
/// **Transitional.** This exists so the six districts can become area files
/// without being retyped by hand: `AreaExportTests` runs the projection and
/// writes `Resources/Areas/city_*.area.json`, and `AreaParityTests` asserts the
/// written record still matches the catalog field for field. Once the runtime
/// reads areas directly (Phase 5), `CityDistrictCatalog` stops being a runtime
/// type and this adapter goes with it — the catalog stays only as the offline
/// authoring DSL that generates the JSON.
///
/// The projection is deliberately total and lossless for the fields the record
/// has: anything the district authors and the area cannot yet hold would be a
/// silent content loss at export, so those gaps are called out in comments
/// rather than dropped quietly.
enum CityDistrictAreaAdapter {

    /// `sableRow` → `city_sable_row`. The slug is already the art-asset key, so
    /// one name serves the plate, the map crop and the area file.
    static func areaID(for district: CityDistrictID) -> AreaID {
        AreaID("city_\(district.slug)")
    }

    /// Reverse lookup, for routing an area back onto the scene that still needs
    /// a `CityDistrictID`. Returns `nil` for the office and the exterior, which
    /// are not districts.
    static func district(for areaID: AreaID) -> CityDistrictID? {
        CityDistrictID.allCases.first { self.areaID(for: $0) == areaID }
    }

    /// Case flag standing in for `GameSession.isCityTravelOpen` until Phase 6
    /// moves session state into area variables.
    static let cityTravelOpenFlag = "city.travel.open"

    /// Entrance named by a door leading in from the office.
    static let officeArrivalEntrance = "from.city"

    static func area(for district: CityDistrictID) -> AreaDefinition {
        let definition = CityDistrictCatalog.definition(for: district)
        return AreaDefinition(
            id: areaID(for: district),
            displayName: definition.locationName,
            kind: .exterior,
            arrivalHint: definition.arrivalHint,
            worldSize: AreaSize(CityDistrictDefinition.worldArtSize),
            plateTextureName: definition.groundTextureName,
            mapTextureName: definition.mapTextureName,
            searchMapName: "\(areaID(for: district).rawValue).sr",
            // Kept alongside the painted map: Theta* tests these at world
            // resolution for line of sight, which is finer than the cell grid.
            obstacles: definition.obstacles.map(AreaRect.init),
            // Harborpoint is paved kerb to kerb.
            defaultTerrain: .stone,
            agentProfile: AreaAgentProfile(.detective),
            entrances: entrances(for: definition),
            regions: regions(for: definition),
            props: definition.visualSprites.map(prop),
            wallPolygons: AreaCoverAuthoring.districtWallPolygons(),
            // Districts place no NPCs yet, and the player arrives at an
            // entrance rather than being an area actor — BG models the party
            // the same way.
            actors: [],
            containers: [],
            doors: doors(for: definition),
            notes: definition.pointsOfInterest.map(note),
            ambients: [
                AreaAmbient(
                    id: "amb.rain",
                    assetName: "amb_rain_exterior",
                    volume: 0.34,
                    isLooping: true,
                    isGlobal: true,
                    schedule: .night
                ),
                AreaAmbient(
                    id: "amb.street",
                    assetName: "amb_rain_exterior",
                    sounds: ["amb_rain_exterior"],
                    selection: .random,
                    point: AreaPoint(definition.actorStart),
                    radius: 640,
                    volume: 0.12,
                    isLooping: false,
                    interval: 9,
                    intervalDeviation: 4,
                    isGlobal: false,
                    schedule: .night
                ),
                AreaAmbient(
                    id: "amb.foghorn",
                    assetName: "amb_rain_exterior",
                    sounds: ["amb_rain_exterior"],
                    selection: .random,
                    point: AreaPoint(x: 840, y: 414),
                    radius: 1_200,
                    volume: 0.08,
                    isLooping: false,
                    interval: 28,
                    intervalDeviation: 10,
                    isGlobal: false,
                    schedule: .night
                )
            ],
            animations: animations(for: district, definition: definition),
            script: nil
        )
    }

    static var allDistrictAreas: [AreaDefinition] {
        CityDistrictID.allCases.map(area(for:))
    }

    // MARK: - Sections

    private static func entrances(for definition: CityDistrictDefinition) -> [AreaEntrance] {
        // `spawnByArrivalKey` is already BG's entrance table under another name;
        // sorted so an export is byte-stable across runs.
        var entrances = definition.spawnByArrivalKey
            .sorted { $0.key < $1.key }
            .map { AreaEntrance(name: $0.key, point: AreaPoint($0.value)) }

        // `actorStart` is the arrival used when a transition names no entrance.
        // Authored as a real entrance rather than a fallback field so every
        // arrival in the game goes through one lookup.
        if !entrances.contains(where: { $0.name == AreaEntrance.defaultName }) {
            entrances.insert(
                AreaEntrance(
                    name: AreaEntrance.defaultName,
                    point: AreaPoint(definition.actorStart)
                ),
                at: 0
            )
        }
        return entrances
    }

    private static func regions(for definition: CityDistrictDefinition) -> [AreaRegion] {
        definition.portals.map { portal in
            AreaRegion(
                id: portal.id,
                kind: portal.destination == .inspect ? .info : .travel,
                label: portal.label,
                rect: portal.hitArea,
                // Already authored on the walkable side the door faces, from
                // `nearestWalkablePoint` unrounded. Do not tidy these numbers.
                approachPoint: AreaPoint(portal.approachPoint),
                travel: travel(for: portal.destination),
                observation: portal.destination == .inspect
                    ? portal.lockedInspectLine
                    : nil,
                requiresFlag: portal.requiresCityOpen ? cityTravelOpenFlag : nil,
                lockedLine: portal.lockedInspectLine
            )
        }
    }

    private static func travel(for destination: CityTravelDestination) -> AreaTravel? {
        switch destination {
        case .office:
            AreaTravel(
                destination: HarborpointAreas.office,
                entrance: officeArrivalEntrance
            )
        case .district(let id):
            AreaTravel(
                destination: areaID(for: id),
                entrance: AreaEntrance.defaultName
            )
        case .inspect:
            nil
        }
    }

    private static func prop(_ sprite: CityDistrictDefinition.VisualSprite) -> AreaProp {
        AreaProp(
            textureName: sprite.textureName,
            groundPoint: AreaPoint(sprite.groundPoint),
            scale: sprite.scale,
            anchorY: sprite.anchorY,
            depthBias: sprite.depthBias,
            worldSize: sprite.worldSize.map(AreaSize.init),
            depthSliceWidth: sprite.depthSliceWidth,
            depthSortLot: sprite.depthSortLot
        )
    }

    private static func note(_ poi: CityDistrictDefinition.PointOfInterest) -> AreaNote {
        AreaNote(
            label: poi.label,
            point: AreaPoint(poi.worldPoint),
            colorRGBA: [poi.colorRGBA.0, poi.colorRGBA.1, poi.colorRGBA.2, poi.colorRGBA.3]
        )
    }

    /// City portals become ARE doors. The leaf is already a prop on the facade,
    /// so `visual` stays nil until open/closed art exists; the same texture name
    /// is recorded so a later art pass can fill both states without a schema bump.
    private static func doors(for definition: CityDistrictDefinition) -> [AreaDoor] {
        definition.portals.map { portal in
            let leaf = definition.visualSprites.first { sprite in
                sprite.textureName.hasPrefix("city_door") && portal.hitArea.contains(sprite.groundPoint)
            }
            return AreaDoor(
                id: portal.id,
                textureName: leaf?.textureName,
                closedObstacle: closedDoorRect(
                    portal: portal,
                    definition: definition,
                    leafPoint: leaf?.groundPoint
                ),
                startsClosed: true,
                blocksSight: true,
                openSound: "sfx_door_open",
                closeSound: "sfx_door_close",
                approachPoints: OfficeAreaAdapter.approachPair(from: portal.approachPoint)
            )
        }
    }

    /// Stamp inside the painted mass, never on the street. A 16×12 cell at the
    /// leaf foot would bite the pavement the approach sits on.
    private static func closedDoorRect(
        portal: CityDistrictDefinition.Portal,
        definition: CityDistrictDefinition,
        leafPoint: CGPoint?
    ) -> AreaRect {
        let hit = portal.hitArea
        var candidates: [CGPoint] = [
            CGPoint(x: hit.midX, y: hit.maxY - 6),
            CGPoint(x: hit.midX, y: hit.midY),
            CGPoint(x: hit.midX, y: hit.maxY)
        ]
        if let leafPoint {
            candidates.append(CGPoint(x: leafPoint.x, y: leafPoint.y + 18))
        }
        let origin = candidates.first { point in
            definition.obstacles.contains { $0.contains(point) }
        } ?? CGPoint(x: hit.midX, y: hit.maxY)
        return AreaRect(x: origin.x - 8, y: origin.y - 6, w: 16, h: 12)
    }

    private static func animations(
        for district: CityDistrictID,
        definition: CityDistrictDefinition
    ) -> [AreaAnimation] {
        var animations: [AreaAnimation] = []
        if let lamp = definition.visualSprites.first(where: { $0.textureName.contains("lamp") }) {
            animations.append(
                AreaAnimation(
                    id: "neon.lamp",
                    point: AreaPoint(lamp.groundPoint),
                    textureName: "city_neon_flicker",
                    frameCount: 1,
                    alpha: 0.45,
                    isSelfIlluminated: true,
                    schedule: .night,
                    blend: .add,
                    scale: 1
                )
            )
        }
        if district == .riverside {
            animations.append(
                AreaAnimation(
                    id: "water.shimmer",
                    point: AreaPoint(x: 2_048, y: 280),
                    textureName: "city_water_shimmer",
                    frameCount: 1,
                    alpha: 0.22,
                    isSelfIlluminated: true,
                    wallHides: false,
                    schedule: .night,
                    blend: .add,
                    scale: 1
                )
            )
        }
        if district == .wharfLadder {
            animations.append(
                AreaAnimation(
                    id: "steam.vent",
                    point: AreaPoint(definition.actorStart),
                    textureName: "city_steam_vent",
                    frameCount: 1,
                    alpha: 0.2,
                    wallHides: true,
                    schedule: .night,
                    blend: .alpha,
                    scale: 1
                )
            )
        }
        return animations
    }
}
