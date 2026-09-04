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
    /// `AREATYPE.IDS` bits for a ward. Every ward is Outdoor|City; Sable Row's
    /// IE outdoor rebuild also authors a night painting, which is Extended Night.
    static func areaType(for district: CityDistrictID) -> AreaType {
        var type: AreaType = [.outdoor, .city]
        if nightPlateTextureName(for: district) != nil {
            type.insert(.extendedNight)
        }
        return type
    }

    /// The authored night painting, where a ward has one. Extended Night is an
    /// area-type bit in the ARE, so this and `areaType(for:)` must agree.
    static func nightPlateTextureName(for district: CityDistrictID) -> String? {
        district == .sableRow ? "city_sable_row_night_placeholder_v01" : nil
    }

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
            // A ward is Outdoor *and* City. The pair is what keeps a closed
            // street door a hard sight stop rather than a shroud, and it is the
            // reason this is a set and not an enum.
            areaType: areaType(for: district),
            arrivalHint: definition.arrivalHint,
            worldSize: AreaSize(CityDistrictDefinition.worldArtSize),
            plateTextureName: definition.groundTextureName,
            nightPlateTextureName: nightPlateTextureName(for: district),
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
            // The V2 block texture is the complete pre-rendered area. Keep the
            // authoring sprites in `CityDistrictCatalog` for measured apertures,
            // but do not draw them a second time over the plate.
            props: definition.runtimeVisualSprites.map(prop),
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
            // Animations stay deferred until night art is authored per ward.
            animations: [],
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
        // Every enterable facade gets the named return entrance its interior
        // travel region references. The point is the same exact, unrounded
        // street-side approach used to enter it.
        for portal in definition.portals {
            guard case .interior(let interior) = portal.destination else { continue }
            entrances.append(
                AreaEntrance(
                    name: interior.exteriorEntranceName,
                    point: AreaPoint(portal.approachPoint)
                )
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
        case .interior(let id):
            AreaTravel(
                destination: id.areaID,
                entrance: CityInteriorAreaAdapter.streetEntrance
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

    /// City portals become ARE doors. The leaf is an `AreaDoorVisualRegistration`
    /// over the painted aperture (IE WED closed/open tiles); travel stays on the
    /// region. Closed obstacle sits inside the painted mass, never on the street.
    private static func doors(for definition: CityDistrictDefinition) -> [AreaDoor] {
        definition.portals.map { portal in
            let threshold = CityDoorPaintedAperture.threshold(for: portal.id)
                ?? portal.approachPoint
            let leaf = definition.visualSprites.first { sprite in
                sprite.textureName.hasPrefix("city_door") && portal.hitArea.contains(sprite.groundPoint)
            }
            return AreaDoor(
                id: portal.id,
                textureName: CityDoorPaintedAperture.visual(for: portal.id)?.closedTextureName
                    ?? leaf?.textureName,
                visual: CityDoorPaintedAperture.visual(for: portal.id),
                closedObstacle: closedDoorRect(
                    portal: portal,
                    definition: definition,
                    leafPoint: threshold
                ),
                startsClosed: true,
                blocksSight: true,
                openSound: "sfx_door_open",
                closeSound: "sfx_door_close",
                approachPoints: OfficeAreaAdapter.approachPair(from: portal.approachPoint),
                paintedApertureHeight: CityDoorPaintedAperture.height(for: portal.id),
                paintedAperture: CityDoorPaintedAperture.rect(for: portal.id)
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
        // Voss's V6 monolithic stoop is much lower in its tall hit region than
        // the retired facade anchor. Seat the fog/door stamp at the first solid
        // point behind the measured threshold; choosing hit.maxY puts the leaf
        // at the very edge of the actor's sight radius, leaving no shrouded
        // cells beyond it.
        if portal.id == "portal.office", let leafPoint {
            let firstMassPoint = stride(
                from: leafPoint.y + 6,
                through: hit.maxY,
                by: 6
            )
            .map { CGPoint(x: leafPoint.x, y: $0) }
            .first { point in
                definition.obstacles.contains { $0.contains(point) }
            }
            if let origin = firstMassPoint {
                return AreaRect(x: origin.x - 8, y: origin.y - 6, w: 16, h: 12)
            }
        }
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

/// Painted upright door heights measured by `qa_area_door_scale.py` against the
/// installed plates. Band is `CityDistrictLayout.Band.doorLeaf` (1.05…1.35× adult).
///
/// Thresholds are painted stoop contacts on the continuous district plates,
/// not the retired modular lot-crop registrations. The Voss record is measured
/// from the accepted IE Monolith V6 Sable Row master.
enum CityDoorPaintedAperture {
    private struct Record {
        var height: CGFloat
        var rect: AreaRect
        var closedTexture: String
        var midTexture: String
        var openTexture: String
        /// Leaf canvas after V04 normalize (already TARGET_DOOR_WU tall).
        var canvasSize: CGSize
        /// Closed leaf is painted into the district plate (IE primary tiles).
        var closedIsBakedIntoPlate: Bool = false
    }

    private static let records: [String: Record] = [
        "portal.office": Record(
            height: 84.4,
            rect: AreaRect(x: 2_580.75, y: 325, w: 38.5, h: 84.4),
            closedTexture: "city_door_voss_stoop",
            midTexture: "city_door_voss_stoop_mid",
            openTexture: "city_door_voss_stoop_open_tiles",
            canvasSize: CGSize(width: 256, height: 384),
            closedIsBakedIntoPlate: true
        ),
        "portal.shippingOffice": Record(
            height: 80.5,
            rect: AreaRect(x: 2_495.75, y: 851.5, w: 38.5, h: 80.5),
            closedTexture: "city_door_shipping_office",
            midTexture: "city_door_shipping_office_mid",
            openTexture: "city_door_shipping_office_open",
            canvasSize: CGSize(width: 256, height: 384)
        ),
        "portal.ironStairs": Record(
            height: 80.5,
            rect: AreaRect(x: 2_871.75, y: 423, w: 38.5, h: 80.5),
            closedTexture: "city_door_iron_stairs",
            midTexture: "city_door_iron_stairs_mid",
            openTexture: "city_door_iron_stairs_open",
            canvasSize: CGSize(width: 256, height: 384)
        ),
        "portal.pdEntrance": Record(
            height: 80.5,
            rect: AreaRect(x: 2_843.25, y: 907, w: 38.5, h: 80.5),
            closedTexture: "city_door_pd_station",
            midTexture: "city_door_pd_station_mid",
            openTexture: "city_door_pd_station_open",
            canvasSize: CGSize(width: 256, height: 384)
        ),
        "portal.lilaRooms": Record(
            height: 80.5,
            rect: AreaRect(x: 2_721.75, y: 852, w: 38.5, h: 80.5),
            closedTexture: "city_door_lila_rooms",
            midTexture: "city_door_lila_rooms_mid",
            openTexture: "city_door_lila_rooms_open",
            canvasSize: CGSize(width: 256, height: 384)
        ),
        "portal.recordsEntrance": Record(
            height: 80.5,
            rect: AreaRect(x: 2_796.25, y: 895.5, w: 38.5, h: 80.5),
            closedTexture: "city_door_records_annex",
            midTexture: "city_door_records_annex_mid",
            openTexture: "city_door_records_annex_open",
            canvasSize: CGSize(width: 256, height: 384)
        )
    ]

    static func height(for portalID: String) -> CGFloat? {
        records[portalID]?.height
    }

    static func rect(for portalID: String) -> AreaRect? {
        records[portalID]?.rect
    }

    /// Threshold (bottom centre) of the painted opening, y-up world.
    static func threshold(for portalID: String) -> CGPoint? {
        guard let rect = records[portalID]?.rect else { return nil }
        return CGPoint(x: rect.x + rect.w / 2, y: rect.y)
    }

    static func visual(for portalID: String) -> AreaDoorVisualRegistration? {
        guard let record = records[portalID] else { return nil }
        let threshold = CGPoint(x: record.rect.x + record.rect.w / 2, y: record.rect.y)
        // Opaque leaf is TARGET_DOOR_WU tall inside doorCanvas; SpriteKit scale
        // is door-anchored (≈0.5), not canvasH-normalized.
        let scale = CityDistrictLayout.DoorDisplayScale.standard
        return AreaDoorVisualRegistration(
            position: AreaPoint(threshold),
            canvasAnchor: AreaPoint(x: 0.5, y: CityDistrictLayout.doorLeafAnchorY),
            scale: scale,
            closedTextureName: record.closedTexture,
            midTextureName: record.midTexture,
            openTextureName: record.openTexture,
            closedIsBakedIntoPlate: record.closedIsBakedIntoPlate
        )
    }
}

/// Five ARE records sharing one neutral lobby painting.
///
/// They intentionally remain separate records: an Infinity Engine travel
/// region names a concrete destination area and a named entrance, and the
/// return region must retain which exterior door was used. Sharing art does not
/// collapse those transition identities.
enum CityInteriorAreaAdapter {
    static let worldSize = CGSize(width: 2_048, height: 1_152)
    static let streetEntrance = "from.street"
    static let playerPoint = AreaPoint(x: 1_390, y: 335)
    static let doorApproach = AreaPoint(x: 1_410, y: 300)
    static let returnRegion = AreaRect(x: 1_315, y: 180, w: 190, h: 150)
    static let closedDoor = AreaRect(x: 1_395, y: 205, w: 16, h: 12)

    static func interior(for areaID: AreaID) -> CityInteriorID? {
        CityInteriorID.allCases.first { $0.areaID == areaID }
    }

    static func area(for id: CityInteriorID) -> AreaDefinition {
        AreaDefinition(
            id: id.areaID,
            displayName: id.displayName,
            kind: .interior,
            areaType: [],
            arrivalHint: "The rain dims behind the frosted street door.",
            worldSize: AreaSize(worldSize),
            plateTextureName: "city_building_interior_v01",
            mapTextureName: "map_city_building_interior_v01",
            searchMapName: "city_building_interior_v01.sr",
            obstacles: [
                // Reception counter on the camera-far wall. The floor raster
                // owns the room envelope; this is the one internal solid.
                AreaRect(x: 930, y: 720, w: 500, h: 150)
            ],
            defaultTerrain: .stone,
            agentProfile: AreaAgentProfile(.detective),
            entrances: [
                AreaEntrance(name: AreaEntrance.defaultName, point: playerPoint),
                AreaEntrance(name: streetEntrance, point: playerPoint)
            ],
            regions: [
                AreaRegion(
                    id: "portal.return",
                    kind: .travel,
                    label: "STREET",
                    rect: returnRegion.cgRect,
                    approachPoint: doorApproach,
                    travel: AreaTravel(
                        destination: CityDistrictAreaAdapter.areaID(for: id.exteriorDistrict),
                        entrance: id.exteriorEntranceName
                    )
                )
            ],
            doors: [
                AreaDoor(
                    id: "portal.return",
                    closedObstacle: closedDoor,
                    startsClosed: true,
                    blocksSight: true,
                    openSound: "sfx_door_open",
                    closeSound: "sfx_door_close",
                    approachPoints: OfficeAreaAdapter.approachPair(from: doorApproach.cgPoint)
                )
            ],
            ambients: [
                AreaAmbient(
                    id: "amb.rain.outside",
                    assetName: "amb_rain_exterior",
                    point: AreaPoint(x: 1_410, y: 230),
                    radius: 620,
                    volume: 0.12,
                    isLooping: true,
                    isGlobal: false,
                    schedule: .night
                )
            ],
            // Five logical AREs share this one neutral lobby plate and its
            // support maps. Name the common LM explicitly; the default would
            // look for a different `<area-id>.lm` file for each doorway.
            lightMapName: "city_building_interior_v01.lm"
        )
    }

    static var allAreas: [AreaDefinition] {
        CityInteriorID.allCases.map(area(for:))
    }
}
