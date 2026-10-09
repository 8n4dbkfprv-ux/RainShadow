import CoreGraphics

/// Reviewed Blender bundles are the authority for art, collision and travel.
/// Stable district/interior IDs keep the world map and existing saves connected.
enum RebuiltCityAreas {
    static let districts: Set<CityDistrictID> = [.sableRow, .wharfLadder, .riverside]
    static let interiors: Set<CityInteriorID> = [.shippingOffice, .ironStairs, .lilaRooms, .lilaHall]
    private static let records: [AreaID: AreaDefinition] = {
        let ids = ["city_sable_row", "city_wharf_ladder", "city_riverside",
                   "interior_shipping_office", "interior_iron_stairs",
                   "interior_lila_rooms", "interior_lila_hall"]
        return Dictionary(uniqueKeysWithValues: ids.map { name in
            let id = AreaID(name)
            do { return (id, try AreaCatalogLoader.load(id)) }
            catch { preconditionFailure("Missing rebuilt area \(id): \(error)") }
        })
    }()

    static func area(_ id: AreaID) -> AreaDefinition { records[id]! }

    static func definition(_ district: CityDistrictID) -> CityDistrictDefinition {
        let area = area(CityDistrictAreaAdapter.areaID(for: district))
        let portals: [CityDistrictDefinition.Portal] = area.travelRegions.map { r in
            let destination: CityTravelDestination
            if r.travel!.destination == HarborpointAreas.office { destination = .office }
            else { destination = .interior(CityInteriorAreaAdapter.interior(for: r.travel!.destination)!) }
            return .init(id: r.id, label: r.label ?? "Enter", approachPoint: r.approachPoint!.cgPoint,
                         hitArea: r.boundingBox, destination: destination,
                         requiresCityOpen: false, lockedInspectLine: "")
        }
        return CityDistrictDefinition(
            id: district, locationName: area.displayName, arrivalHint: area.arrivalHint ?? "",
            groundTextureName: area.plateTextureName, mapTextureName: area.mapTextureName!,
            actorStart: area.spawnPoint(entrance: nil)!,
            spawnByArrivalKey: Dictionary(uniqueKeysWithValues: area.entrances
                .filter { $0.name != AreaEntrance.defaultName }.map { ($0.name, $0.point.cgPoint) }),
            visualSprites: [], obstacles: [], portals: portals,
            pointsOfInterest: portals.map { .init(label: $0.label, worldPoint: $0.approachPoint,
                                                  colorRGBA: (0.79, 0.55, 0.26, 1)) })
    }

    static func exitApproach(_ district: CityDistrictID, _ edge: CityMapEdge) -> CGPoint {
        area(CityDistrictAreaAdapter.areaID(for: district)).entrance(named: edge.arrivalKey)!.point.cgPoint
    }

    static func exitHitArea(_ district: CityDistrictID, _ edge: CityMapEdge) -> CGRect {
        let p = exitApproach(district, edge)
        return CGRect(x: p.x - 64, y: p.y - 48, width: 128, height: 96)
    }
}
