import CoreGraphics

/// V11 Blender paintings and evaluated geometry own these two area records.
/// Keep the old enum raw values for save compatibility; public area IDs and
/// presentation use the fantasy setting's names.
enum LampWardAreas {
    static let exteriorID = AreaID("RS0400")
    static let interiorID = AreaID("RS0401")
    // Visible leaf below the transom: model z .530–2.725, camera 39.2645 WU/m.
    static let entranceLeafHeight: CGFloat = (2.725 - 0.530) * 39.2645

    static let exterior: AreaDefinition = load(exteriorID)
    static let interior: AreaDefinition = load(interiorID)

    private static func load(_ id: AreaID) -> AreaDefinition {
        do { return try AreaCatalogLoader.load(id) }
        catch { preconditionFailure("Missing Blender area \(id): \(error)") }
    }

    static var districtDefinition: CityDistrictDefinition {
        let area = exterior
        let portal = area.region(id: "portal.lamphouseEntrance")!
        return CityDistrictDefinition(
            id: .harborpointPD,
            locationName: area.displayName,
            arrivalHint: area.arrivalHint ?? "",
            groundTextureName: area.plateTextureName,
            mapTextureName: area.mapTextureName!,
            actorStart: area.spawnPoint(entrance: nil)!,
            spawnByArrivalKey: Dictionary(uniqueKeysWithValues: area.entrances
                .filter { $0.name != AreaEntrance.defaultName }
                .map { ($0.name, $0.point.cgPoint) }),
            visualSprites: [],
            obstacles: [],
            portals: [.init(id: portal.id, label: portal.label ?? "THE WATCH-HOUSE",
                            approachPoint: portal.approachPoint!.cgPoint,
                            hitArea: portal.boundingBox,
                            destination: .interior(.policeStation),
                            requiresCityOpen: false, lockedInspectLine: "")],
            pointsOfInterest: [.init(label: "THE WATCH-HOUSE",
                                    worldPoint: portal.approachPoint!.cgPoint,
                                    colorRGBA: (0.79, 0.55, 0.26, 1))]
        )
    }

    /// The Blender camera overscans the street mouths. Exits belong to those
    /// authored streets, not the retired ward's 5120×3840 bitmap border.
    static func exitApproach(for edge: CityMapEdge) -> CGPoint {
        exterior.entrance(named: edge.arrivalKey)!.point.cgPoint
    }

    static func exitHitArea(for edge: CityMapEdge) -> CGRect {
        let p = exitApproach(for: edge)
        return CGRect(x: p.x - 64, y: p.y - 48, width: 128, height: 96)
    }
}
