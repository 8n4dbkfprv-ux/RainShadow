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
            // Phase 3 replaces this with an indexed search-map bitmap. Until
            // then the area rasterises the same AABBs `makeGrid()` does.
            searchMapName: nil,
            obstacles: definition.obstacles.map(AreaRect.init),
            agentProfile: AreaAgentProfile(.detective),
            entrances: entrances(for: definition),
            regions: regions(for: definition),
            props: definition.visualSprites.map(prop),
            // Districts place no NPCs yet, and the player arrives at an
            // entrance rather than being an area actor — BG models the party
            // the same way.
            actors: [],
            containers: [],
            // City door leaves are painted on the facade and gated by a portal
            // region; none of them stamps the search map today, so there is no
            // door section to carry over.
            doors: [],
            notes: definition.pointsOfInterest.map(note),
            ambients: [
                AreaAmbient(
                    id: "amb.rain",
                    assetName: "amb_rain_exterior",
                    volume: 0.34,
                    isLooping: true
                )
            ],
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
}
