import CoreGraphics

/// Act I Harborpoint travel districts on the Baldur's Gate–style 3×3 ward grid.
enum CityDistrictID: String, CaseIterable, Equatable {
    case sableRow
    case wharfLadder
    case riverside
    case harborpointPD
    case lilaStreet
    case civicRecords

    var slug: String {
        switch self {
        case .sableRow: return "sable_row"
        case .wharfLadder: return "wharf_ladder"
        case .riverside: return "riverside"
        case .harborpointPD: return "harborpoint_pd"
        case .lilaStreet: return "lila_street"
        case .civicRecords: return "civic_records"
        }
    }

    /// BG-style regional world-map destination icon texture.
    var worldMapIconTextureName: String {
        "map_district_icon_\(slug)_v01"
    }

    /// Second line under the world-map icon label stack.
    var worldMapShortType: String {
        switch self {
        case .sableRow: return "Ward"
        case .wharfLadder: return "Docks"
        case .riverside: return "Riverfront"
        case .harborpointPD: return "Precinct"
        case .lilaStreet: return "Street"
        case .civicRecords: return "Archives"
        }
    }
}

enum CityTravelDestination: Equatable {
    case office
    case district(CityDistrictID)
    /// Walk-up inspect only (no scene change).
    case inspect
}

/// Geometry + art contract for one outdoor Act I district.
struct CityDistrictDefinition {
    struct VisualSprite: Equatable {
        let textureName: String
        let groundPoint: CGPoint
        let scale: CGFloat
        let anchorY: CGFloat
        let depthBias: CGFloat
    }

    struct PointOfInterest: Equatable {
        let label: String
        let worldPoint: CGPoint
        /// sRGB components for map markers (converted to SKColor at the UI layer).
        let colorRGBA: (CGFloat, CGFloat, CGFloat, CGFloat)

        static func == (lhs: PointOfInterest, rhs: PointOfInterest) -> Bool {
            lhs.label == rhs.label
                && lhs.worldPoint == rhs.worldPoint
                && lhs.colorRGBA == rhs.colorRGBA
        }
    }

    struct Portal: Equatable {
        let id: String
        let label: String
        let approachPoint: CGPoint
        let hitArea: CGRect
        let destination: CityTravelDestination
        /// When false, inspect line only until `GameSession.isCityTravelOpen`.
        let requiresCityOpen: Bool
        let lockedInspectLine: String
    }

    let id: CityDistrictID
    let locationName: String
    let arrivalHint: String
    let groundTextureName: String
    let mapTextureName: String
    let actorStart: CGPoint
    /// Spawn when arriving from a named portal / route key.
    let spawnByArrivalKey: [String: CGPoint]
    let visualSprites: [VisualSprite]
    let obstacles: [CGRect]
    let portals: [Portal]
    let pointsOfInterest: [PointOfInterest]

    static let sourceArtSize = CGSize(width: 2_048, height: 1_152)
    static let environmentScale: CGFloat = 1
    static let worldArtSize = CGSize(
        width: sourceArtSize.width * environmentScale,
        height: sourceArtSize.height * environmentScale
    )
    static let worldBounds = CGRect(origin: .zero, size: worldArtSize)
    /// Local reveal, held at ~0.8 of the camera half-height so the fog edge stays
    /// on screen. A flat 400 was tuned against the old ~1007-unit visible height;
    /// at the BG1 density (~541) it sat outside the viewport entirely, so the fog
    /// never read in play.
    static var fogRevealRadius: CGFloat { cameraVisibleHeight * 0.4 }
    static let standingAdultBodyHeight = OfficeInteriorScale.standingAdultBodyHeight

    /// Camera density uses the rendered adult body so city framing matches office.
    static var cameraVisibleHeight: CGFloat {
        DefaultPlayZoom.cameraVisibleHeight(
            standingBodyHeight: OfficeInteriorScale.renderedStandingDetectiveBodyHeight
        )
    }

    func spawnPoint(arrivalKey: String?) -> CGPoint {
        if let arrivalKey, let point = spawnByArrivalKey[arrivalKey] {
            return point
        }
        return actorStart
    }

    func makeGrid() -> NavigationMap {
        NavigationMap(
            worldBounds: Self.worldBounds,
            obstacles: obstacles,
            agentProfile: .detective,
            doorObstacles: [],
            entranceDoorBlocking: false,
            cellSize: SearchMap.defaultCellSize
        )
    }
}

enum CityDistrictCatalog {
    static func definition(for id: CityDistrictID) -> CityDistrictDefinition {
        switch id {
        case .sableRow: return sableRow
        case .wharfLadder: return wharfLadder
        case .riverside: return riverside
        case .harborpointPD: return harborpointPD
        case .lilaStreet: return lilaStreet
        case .civicRecords: return civicRecords
        }
    }

    // MARK: - Sable Row (center / lower ward)

    static let sableRow = CityDistrictDefinition(
        id: .sableRow,
        locationName: "SABLE ROW — LOWER WARD",
        arrivalHint: "SABLE ROW  •  Voss's apartment is on the southeast stoop. Walk the edges to leave the ward.",
        groundTextureName: "city_sable_row_ground_v02",
        mapTextureName: "map_city_sable_row_v02",
        actorStart: CGPoint(x: 1600, y: 90),
        spawnByArrivalKey: [
            "from.office": CGPoint(x: 1600, y: 90),
            "from.north": CGPoint(x: 968, y: 1134),
            "from.south": CGPoint(x: 1024, y: 140),
            "from.east": CGPoint(x: 1880, y: 585),
            "from.west": CGPoint(x: 150, y: 545)
        ],
        visualSprites: [
            // Buildings: empty doorway apertures; door-anchored openings clear Harlan Voss (~1.15× adult).
            .init(textureName: "city_building_tenement", groundPoint: CGPoint(x: 240, y: 810), scale: CityDistrictLayout.BuildingDisplayScale.tenement, anchorY: 0.12, depthBias: 0),
            .init(textureName: "city_building_storefront", groundPoint: CGPoint(x: 710, y: 830), scale: CityDistrictLayout.BuildingDisplayScale.storefront, anchorY: 0.12, depthBias: 0),
            .init(textureName: "city_building_rowhouse", groundPoint: CGPoint(x: 1225, y: 820), scale: CityDistrictLayout.BuildingDisplayScale.rowhouse, anchorY: 0.12, depthBias: 0),
            .init(textureName: "city_building_shop", groundPoint: CGPoint(x: 390, y: 410), scale: CityDistrictLayout.BuildingDisplayScale.shop, anchorY: 0.14, depthBias: 0),
            .init(textureName: "city_building_gatehouse", groundPoint: CGPoint(x: 840, y: 380), scale: CityDistrictLayout.BuildingDisplayScale.gatehouse, anchorY: 0.16, depthBias: 0),
            .init(textureName: "city_building_voss_stoop", groundPoint: CGPoint(x: 1700, y: 260), scale: CityDistrictLayout.BuildingDisplayScale.vossStoop, anchorY: 0.10, depthBias: 0),
            // Separate closed door leaves registered to openings (depthBias ahead of facade).
            .init(textureName: "city_door_tenement", groundPoint: CGPoint(x: 250, y: 780), scale: CityDistrictLayout.DoorDisplayScale.standard, anchorY: 0.08, depthBias: 1),
            .init(textureName: "city_door_storefront", groundPoint: CGPoint(x: 720, y: 800), scale: CityDistrictLayout.DoorDisplayScale.standard, anchorY: 0.08, depthBias: 1),
            .init(textureName: "city_door_rowhouse", groundPoint: CGPoint(x: 1235, y: 790), scale: CityDistrictLayout.DoorDisplayScale.standard, anchorY: 0.08, depthBias: 1),
            .init(textureName: "city_door_shop", groundPoint: CGPoint(x: 400, y: 390), scale: CityDistrictLayout.DoorDisplayScale.standard, anchorY: 0.08, depthBias: 1),
            .init(textureName: "city_door_gatehouse", groundPoint: CGPoint(x: 850, y: 360), scale: CityDistrictLayout.DoorDisplayScale.standard, anchorY: 0.08, depthBias: 1),
            .init(textureName: "city_door_voss_stoop", groundPoint: CGPoint(x: 1685, y: 175), scale: CityDistrictLayout.DoorDisplayScale.standard, anchorY: 0.08, depthBias: 1),
            .init(textureName: "city_door_voss_stoop_garage", groundPoint: CGPoint(x: 1620, y: 195), scale: CityDistrictLayout.DoorDisplayScale.wide, anchorY: 0.08, depthBias: 1),
            // Street props: cars stay near adult roof height (not scaled with facades).
            .init(textureName: "city_prop_statue", groundPoint: CGPoint(x: 525, y: 590), scale: CityDistrictLayout.PropDisplayScale.statue, anchorY: 0.10, depthBias: 3),
            .init(textureName: "city_prop_bench", groundPoint: CGPoint(x: 460, y: 540), scale: CityDistrictLayout.PropDisplayScale.bench, anchorY: 0.15, depthBias: 2),
            .init(textureName: "city_prop_bench", groundPoint: CGPoint(x: 610, y: 550), scale: CityDistrictLayout.PropDisplayScale.bench, anchorY: 0.15, depthBias: 2),
            .init(textureName: "city_prop_lamp", groundPoint: CGPoint(x: 280, y: 600), scale: CityDistrictLayout.PropDisplayScale.lampHub, anchorY: 0.12, depthBias: 1),
            .init(textureName: "city_prop_lamp", groundPoint: CGPoint(x: 650, y: 610), scale: CityDistrictLayout.PropDisplayScale.lampHub, anchorY: 0.12, depthBias: 1),
            .init(textureName: "city_prop_lamp", groundPoint: CGPoint(x: 1100, y: 600), scale: CityDistrictLayout.PropDisplayScale.lampHub, anchorY: 0.12, depthBias: 1),
            .init(textureName: "city_prop_lamp", groundPoint: CGPoint(x: 1550, y: 450), scale: CityDistrictLayout.PropDisplayScale.lampHub, anchorY: 0.12, depthBias: 1),
            .init(textureName: "city_prop_lamp", groundPoint: CGPoint(x: 950, y: 190), scale: CityDistrictLayout.PropDisplayScale.lampHub, anchorY: 0.12, depthBias: 1),
            .init(textureName: "city_prop_car_black", groundPoint: CGPoint(x: 740, y: 490), scale: CityDistrictLayout.PropDisplayScale.car, anchorY: 0.18, depthBias: 2),
            .init(textureName: "city_prop_car_olive", groundPoint: CGPoint(x: 1200, y: 430), scale: CityDistrictLayout.PropDisplayScale.car, anchorY: 0.18, depthBias: 2),
            .init(textureName: "city_prop_car_maroon", groundPoint: CGPoint(x: 1425, y: 190), scale: CityDistrictLayout.PropDisplayScale.car, anchorY: 0.18, depthBias: 2),
            .init(textureName: "city_prop_kiosk", groundPoint: CGPoint(x: 1025, y: 160), scale: CityDistrictLayout.PropDisplayScale.kiosk, anchorY: 0.20, depthBias: 2),
            .init(textureName: "city_prop_crates_mail", groundPoint: CGPoint(x: 1110, y: 140), scale: CityDistrictLayout.PropDisplayScale.crates, anchorY: 0.24, depthBias: 2),
            .init(textureName: "city_prop_gate", groundPoint: CGPoint(x: 525, y: 310), scale: CityDistrictLayout.PropDisplayScale.gate, anchorY: 0.22, depthBias: 2)
        ],
        // Building footprints leave a central cross of streets walkable (expanded for door-anchored scales).
        obstacles: [
            CGRect(x: 20, y: 640, width: 460, height: 480),
            CGRect(x: 480, y: 660, width: 480, height: 460),
            CGRect(x: 980, y: 660, width: 520, height: 460),
            CGRect(x: 40, y: 220, width: 460, height: 300),
            CGRect(x: 580, y: 200, width: 400, height: 280),
            CGRect(x: 1480, y: 140, width: 520, height: 420)
        ],
        portals: [
            .init(
                id: "portal.office",
                label: "VOSS APT",
                approachPoint: CGPoint(x: 1600, y: 90),
                hitArea: CGRect(x: 1460, y: 10, width: 320, height: 180),
                destination: .office,
                requiresCityOpen: false,
                lockedInspectLine: "The office door is locked from this side."
            )
        ],
        pointsOfInterest: [
            .init(label: "VOSS APT", worldPoint: CGPoint(x: 1600, y: 90), colorRGBA: (0.72, 0.22, 0.18, 1))
        ]
    )

    // MARK: - Wharf Ladder (west)

    static let wharfLadder = CityDistrictDefinition(
        id: .wharfLadder,
        locationName: "WHARF LADDER — SHIPPING",
        arrivalHint: "WHARF LADDER  •  Lillian's shipping office faces the wet pier.",
        groundTextureName: "city_wharf_ladder_ground_v02",
        mapTextureName: "map_city_wharf_ladder_v02",
        actorStart: CGPoint(x: 1880, y: 420),
        spawnByArrivalKey: [
            "from.east": CGPoint(x: 1880, y: 420),
            "from.south": CGPoint(x: 1024, y: 140),
            "from.north": CGPoint(x: 1024, y: 980),
            "from.west": CGPoint(x: 140, y: 415)
        ],
        visualSprites: [
            .init(textureName: "city_building_shipping_office", groundPoint: CGPoint(x: 1100, y: 490), scale: CityDistrictLayout.BuildingDisplayScale.shippingOffice, anchorY: 0.10, depthBias: 0),
            .init(textureName: "city_building_warehouse", groundPoint: CGPoint(x: 550, y: 740), scale: CityDistrictLayout.BuildingDisplayScale.warehouse, anchorY: 0.10, depthBias: 0),
            .init(textureName: "city_building_boarding", groundPoint: CGPoint(x: 1600, y: 680), scale: CityDistrictLayout.BuildingDisplayScale.boarding, anchorY: 0.12, depthBias: 0),
            .init(textureName: "city_building_dock_shed", groundPoint: CGPoint(x: 430, y: 360), scale: CityDistrictLayout.BuildingDisplayScale.dockShed, anchorY: 0.16, depthBias: 0),
            .init(textureName: "city_door_shipping_office", groundPoint: CGPoint(x: 1085, y: 430), scale: CityDistrictLayout.DoorDisplayScale.standard, anchorY: 0.08, depthBias: 1),
            .init(textureName: "city_door_warehouse", groundPoint: CGPoint(x: 560, y: 710), scale: CityDistrictLayout.DoorDisplayScale.wide, anchorY: 0.08, depthBias: 1),
            .init(textureName: "city_door_boarding", groundPoint: CGPoint(x: 1610, y: 650), scale: CityDistrictLayout.DoorDisplayScale.standard, anchorY: 0.08, depthBias: 1),
            .init(textureName: "city_door_dock_shed", groundPoint: CGPoint(x: 440, y: 340), scale: CityDistrictLayout.DoorDisplayScale.standard, anchorY: 0.08, depthBias: 1),
            .init(textureName: "city_prop_lamp", groundPoint: CGPoint(x: 700, y: 450), scale: CityDistrictLayout.PropDisplayScale.lampSpoke, anchorY: 0.12, depthBias: 1),
            .init(textureName: "city_prop_lamp", groundPoint: CGPoint(x: 1300, y: 390), scale: CityDistrictLayout.PropDisplayScale.lampSpoke, anchorY: 0.12, depthBias: 1),
            .init(textureName: "city_prop_crates_mail", groundPoint: CGPoint(x: 840, y: 310), scale: CityDistrictLayout.PropDisplayScale.cratesSpoke, anchorY: 0.24, depthBias: 2),
            .init(textureName: "city_prop_car_black", groundPoint: CGPoint(x: 950, y: 240), scale: CityDistrictLayout.PropDisplayScale.carSpoke, anchorY: 0.18, depthBias: 2)
        ],
        obstacles: [
            CGRect(x: 160, y: 560, width: 780, height: 520),
            CGRect(x: 800, y: 300, width: 620, height: 520),
            CGRect(x: 1340, y: 500, width: 580, height: 520),
            CGRect(x: 160, y: 200, width: 460, height: 300)
        ],
        portals: [
            .init(
                id: "portal.shippingOffice",
                label: "SHIPPING",
                approachPoint: CGPoint(x: 1050, y: 280),
                hitArea: CGRect(x: 900, y: 320, width: 400, height: 300),
                destination: .inspect,
                requiresCityOpen: false,
                lockedInspectLine: "Lillian's shipping office. Ledgers and a late errand uptown — exterior only for now."
            )
        ],
        pointsOfInterest: [
            .init(label: "SHIPPING", worldPoint: CGPoint(x: 1100, y: 490), colorRGBA: (0.72, 0.22, 0.18, 1))
        ]
    )

    // MARK: - Riverside (southwest)

    static let riverside = CityDistrictDefinition(
        id: .riverside,
        locationName: "RIVERSIDE — IRON STAIRS",
        arrivalHint: "RIVERSIDE  •  The old iron stairs drop to the coat stones.",
        groundTextureName: "city_riverside_ground_v02",
        mapTextureName: "map_city_riverside_v02",
        actorStart: CGPoint(x: 1880, y: 700),
        spawnByArrivalKey: [
            "from.east": CGPoint(x: 1880, y: 700),
            "from.north": CGPoint(x: 1024, y: 980),
            "from.south": CGPoint(x: 1024, y: 180),
            "from.west": CGPoint(x: 160, y: 520)
        ],
        visualSprites: [
            .init(textureName: "city_building_iron_stairs", groundPoint: CGPoint(x: 1200, y: 390), scale: CityDistrictLayout.BuildingDisplayScale.ironStairs, anchorY: 0.08, depthBias: 0),
            .init(textureName: "city_building_river_watch", groundPoint: CGPoint(x: 600, y: 680), scale: CityDistrictLayout.BuildingDisplayScale.riverWatch, anchorY: 0.14, depthBias: 0),
            .init(textureName: "city_building_rail_lamp", groundPoint: CGPoint(x: 900, y: 490), scale: CityDistrictLayout.BuildingDisplayScale.railLamp, anchorY: 0.14, depthBias: 1),
            .init(textureName: "city_building_abutment", groundPoint: CGPoint(x: 1550, y: 280), scale: CityDistrictLayout.BuildingDisplayScale.abutment, anchorY: 0.16, depthBias: 0),
            .init(textureName: "city_door_iron_stairs", groundPoint: CGPoint(x: 1185, y: 360), scale: CityDistrictLayout.DoorDisplayScale.standard, anchorY: 0.08, depthBias: 1),
            .init(textureName: "city_door_river_watch", groundPoint: CGPoint(x: 610, y: 655), scale: CityDistrictLayout.DoorDisplayScale.standard, anchorY: 0.08, depthBias: 1),
            .init(textureName: "city_prop_lamp", groundPoint: CGPoint(x: 525, y: 600), scale: CityDistrictLayout.PropDisplayScale.lampSpoke, anchorY: 0.12, depthBias: 1),
            .init(textureName: "city_prop_lamp", groundPoint: CGPoint(x: 1400, y: 450), scale: CityDistrictLayout.PropDisplayScale.lampSpoke, anchorY: 0.12, depthBias: 1)
        ],
        obstacles: [
            CGRect(x: 400, y: 500, width: 420, height: 420),
            CGRect(x: 900, y: 220, width: 620, height: 450),
            CGRect(x: 1300, y: 100, width: 560, height: 400),
            CGRect(x: 0, y: 0, width: 2048, height: 110)
        ],
        portals: [
            .init(
                id: "portal.ironStairs",
                label: "STAIRS",
                approachPoint: CGPoint(x: 1145, y: 200),
                hitArea: CGRect(x: 980, y: 220, width: 400, height: 300),
                destination: .inspect,
                requiresCityOpen: false,
                lockedInspectLine: "Wet iron and staged stones. The coat is already in police custody."
            )
        ],
        pointsOfInterest: [
            .init(label: "STAIRS", worldPoint: CGPoint(x: 1200, y: 390), colorRGBA: (0.32, 0.51, 0.66, 1))
        ]
    )

    // MARK: - Harborpoint PD (south)

    static let harborpointPD = CityDistrictDefinition(
        id: .harborpointPD,
        locationName: "HARBORPOINT PD",
        arrivalHint: "HARBORPOINT PD  •  Soft files cool faster than the rain.",
        groundTextureName: "city_harborpoint_pd_ground_v02",
        mapTextureName: "map_city_harborpoint_pd_v02",
        actorStart: CGPoint(x: 1015, y: 1060),
        spawnByArrivalKey: [
            "from.north": CGPoint(x: 1015, y: 1060),
            "from.west": CGPoint(x: 160, y: 420),
            "from.east": CGPoint(x: 1976, y: 414),
            "from.south": CGPoint(x: 1024, y: 140)
        ],
        visualSprites: [
            .init(textureName: "city_building_pd_station", groundPoint: CGPoint(x: 1150, y: 600), scale: CityDistrictLayout.BuildingDisplayScale.pdStation, anchorY: 0.10, depthBias: 0),
            .init(textureName: "city_building_pd_annex", groundPoint: CGPoint(x: 1650, y: 500), scale: CityDistrictLayout.BuildingDisplayScale.pdAnnex, anchorY: 0.12, depthBias: 0),
            .init(textureName: "city_building_pd_alley", groundPoint: CGPoint(x: 550, y: 700), scale: CityDistrictLayout.BuildingDisplayScale.pdAlley, anchorY: 0.14, depthBias: 0),
            .init(textureName: "city_building_pd_plaza_wall", groundPoint: CGPoint(x: 800, y: 350), scale: CityDistrictLayout.BuildingDisplayScale.pdPlazaWall, anchorY: 0.18, depthBias: 1),
            .init(textureName: "city_door_pd_station", groundPoint: CGPoint(x: 1140, y: 520), scale: CityDistrictLayout.DoorDisplayScale.standard, anchorY: 0.08, depthBias: 1),
            .init(textureName: "city_door_pd_annex", groundPoint: CGPoint(x: 1660, y: 470), scale: CityDistrictLayout.DoorDisplayScale.standard, anchorY: 0.08, depthBias: 1),
            .init(textureName: "city_door_pd_alley", groundPoint: CGPoint(x: 560, y: 670), scale: CityDistrictLayout.DoorDisplayScale.wide, anchorY: 0.08, depthBias: 1),
            .init(textureName: "city_prop_lamp", groundPoint: CGPoint(x: 700, y: 450), scale: CityDistrictLayout.PropDisplayScale.lampSpoke, anchorY: 0.12, depthBias: 1),
            .init(textureName: "city_prop_lamp", groundPoint: CGPoint(x: 1350, y: 410), scale: CityDistrictLayout.PropDisplayScale.lampSpoke, anchorY: 0.12, depthBias: 1),
            .init(textureName: "city_prop_car_black", groundPoint: CGPoint(x: 850, y: 280), scale: CityDistrictLayout.PropDisplayScale.carSpoke, anchorY: 0.18, depthBias: 2)
        ],
        obstacles: [
            CGRect(x: 780, y: 360, width: 820, height: 680),
            CGRect(x: 1400, y: 300, width: 560, height: 520),
            CGRect(x: 300, y: 520, width: 480, height: 480),
            CGRect(x: 600, y: 200, width: 420, height: 280)
        ],
        portals: [
            .init(
                id: "portal.pdEntrance",
                label: "STATION",
                approachPoint: CGPoint(x: 1095, y: 340),
                hitArea: CGRect(x: 920, y: 360, width: 460, height: 360),
                destination: .inspect,
                requiresCityOpen: false,
                lockedInspectLine: "The desk sergeant keeps soft conclusions behind glass. Exterior only for now."
            )
        ],
        pointsOfInterest: [
            .init(label: "STATION", worldPoint: CGPoint(x: 1150, y: 600), colorRGBA: (0.79, 0.55, 0.26, 1))
        ]
    )

    // MARK: - Lila Street (east)

    static let lilaStreet = CityDistrictDefinition(
        id: .lilaStreet,
        locationName: "LILA'S STREET",
        arrivalHint: "LILA'S STREET  •  Doorway posts remember the Gray Man.",
        groundTextureName: "city_lila_street_ground_v02",
        mapTextureName: "map_city_lila_street_v02",
        actorStart: CGPoint(x: 160, y: 420),
        spawnByArrivalKey: [
            "from.west": CGPoint(x: 160, y: 420),
            "from.north": CGPoint(x: 1024, y: 980),
            "from.south": CGPoint(x: 1024, y: 140),
            "from.east": CGPoint(x: 1880, y: 420)
        ],
        visualSprites: [
            .init(textureName: "city_building_lila_rooms", groundPoint: CGPoint(x: 1250, y: 550), scale: CityDistrictLayout.BuildingDisplayScale.lilaRooms, anchorY: 0.10, depthBias: 0),
            .init(textureName: "city_building_lila_neighbor", groundPoint: CGPoint(x: 700, y: 680), scale: CityDistrictLayout.BuildingDisplayScale.lilaNeighbor, anchorY: 0.12, depthBias: 0),
            .init(textureName: "city_building_lila_opposite", groundPoint: CGPoint(x: 1650, y: 640), scale: CityDistrictLayout.BuildingDisplayScale.lilaOpposite, anchorY: 0.12, depthBias: 0),
            .init(textureName: "city_building_lila_alcove", groundPoint: CGPoint(x: 950, y: 350), scale: CityDistrictLayout.BuildingDisplayScale.lilaAlcove, anchorY: 0.16, depthBias: 1),
            .init(textureName: "city_door_lila_rooms", groundPoint: CGPoint(x: 1270, y: 495), scale: CityDistrictLayout.DoorDisplayScale.standard, anchorY: 0.08, depthBias: 2),
            .init(textureName: "city_door_lila_rooms_b", groundPoint: CGPoint(x: 1225, y: 495), scale: CityDistrictLayout.DoorDisplayScale.standard, anchorY: 0.08, depthBias: 2),
            .init(textureName: "city_door_lila_neighbor", groundPoint: CGPoint(x: 710, y: 650), scale: CityDistrictLayout.DoorDisplayScale.standard, anchorY: 0.08, depthBias: 2),
            .init(textureName: "city_door_lila_opposite", groundPoint: CGPoint(x: 1660, y: 610), scale: CityDistrictLayout.DoorDisplayScale.standard, anchorY: 0.08, depthBias: 2),
            .init(textureName: "city_door_lila_alcove", groundPoint: CGPoint(x: 960, y: 330), scale: CityDistrictLayout.DoorDisplayScale.standard, anchorY: 0.08, depthBias: 2),
            .init(textureName: "city_prop_lamp", groundPoint: CGPoint(x: 600, y: 450), scale: CityDistrictLayout.PropDisplayScale.lampSpoke, anchorY: 0.12, depthBias: 1),
            .init(textureName: "city_prop_lamp", groundPoint: CGPoint(x: 1400, y: 410), scale: CityDistrictLayout.PropDisplayScale.lampSpoke, anchorY: 0.12, depthBias: 1),
            .init(textureName: "city_prop_car_olive", groundPoint: CGPoint(x: 800, y: 260), scale: CityDistrictLayout.PropDisplayScale.carSpoke, anchorY: 0.18, depthBias: 2),
            .init(textureName: "city_prop_bench", groundPoint: CGPoint(x: 1050, y: 390), scale: CityDistrictLayout.PropDisplayScale.benchSpoke, anchorY: 0.15, depthBias: 2)
        ],
        obstacles: [
            CGRect(x: 450, y: 500, width: 520, height: 520),
            CGRect(x: 960, y: 360, width: 620, height: 560),
            CGRect(x: 1400, y: 460, width: 520, height: 520),
            CGRect(x: 760, y: 220, width: 360, height: 260)
        ],
        portals: [
            .init(
                id: "portal.lilaRooms",
                label: "ROOMS",
                approachPoint: CGPoint(x: 1190, y: 340),
                hitArea: CGRect(x: 1020, y: 350, width: 400, height: 320),
                destination: .inspect,
                requiresCityOpen: false,
                lockedInspectLine: "Lila's rooms stay private. Watch the doorway posts instead."
            )
        ],
        pointsOfInterest: [
            .init(label: "ROOMS", worldPoint: CGPoint(x: 1250, y: 550), colorRGBA: (0.58, 0.20, 0.48, 1))
        ]
    )

    // MARK: - Civic Records (north)

    static let civicRecords = CityDistrictDefinition(
        id: .civicRecords,
        locationName: "CIVIC RECORDS ANNEX",
        arrivalHint: "CIVIC RECORDS  •  Marble that still looks clean in the rain.",
        groundTextureName: "city_civic_records_ground_v02",
        mapTextureName: "map_city_civic_records_v02",
        actorStart: CGPoint(x: 1024, y: 140),
        spawnByArrivalKey: [
            "from.south": CGPoint(x: 1024, y: 140),
            "from.west": CGPoint(x: 160, y: 420),
            "from.east": CGPoint(x: 1976, y: 414),
            "from.north": CGPoint(x: 1015, y: 1025)
        ],
        visualSprites: [
            .init(textureName: "city_building_records_annex", groundPoint: CGPoint(x: 1200, y: 590), scale: CityDistrictLayout.BuildingDisplayScale.recordsAnnex, anchorY: 0.10, depthBias: 0),
            .init(textureName: "city_building_records_wing", groundPoint: CGPoint(x: 1650, y: 490), scale: CityDistrictLayout.BuildingDisplayScale.recordsWing, anchorY: 0.12, depthBias: 0),
            .init(textureName: "city_building_records_colonnade", groundPoint: CGPoint(x: 600, y: 680), scale: CityDistrictLayout.BuildingDisplayScale.recordsColonnade, anchorY: 0.12, depthBias: 0),
            .init(textureName: "city_building_records_plaza", groundPoint: CGPoint(x: 850, y: 350), scale: CityDistrictLayout.BuildingDisplayScale.recordsPlaza, anchorY: 0.18, depthBias: 1),
            .init(textureName: "city_door_records_annex", groundPoint: CGPoint(x: 1190, y: 520), scale: CityDistrictLayout.DoorDisplayScale.standard, anchorY: 0.08, depthBias: 1),
            .init(textureName: "city_door_records_wing", groundPoint: CGPoint(x: 1660, y: 460), scale: CityDistrictLayout.DoorDisplayScale.standard, anchorY: 0.08, depthBias: 1),
            .init(textureName: "city_door_records_colonnade", groundPoint: CGPoint(x: 610, y: 650), scale: CityDistrictLayout.DoorDisplayScale.standard, anchorY: 0.08, depthBias: 1),
            .init(textureName: "city_prop_lamp", groundPoint: CGPoint(x: 675, y: 440), scale: CityDistrictLayout.PropDisplayScale.lampSpoke, anchorY: 0.12, depthBias: 1),
            .init(textureName: "city_prop_lamp", groundPoint: CGPoint(x: 1350, y: 400), scale: CityDistrictLayout.PropDisplayScale.lampSpoke, anchorY: 0.12, depthBias: 1),
            .init(textureName: "city_prop_statue", groundPoint: CGPoint(x: 950, y: 450), scale: CityDistrictLayout.PropDisplayScale.statueSpoke, anchorY: 0.10, depthBias: 3)
        ],
        obstacles: [
            CGRect(x: 860, y: 380, width: 780, height: 620),
            CGRect(x: 1400, y: 300, width: 560, height: 520),
            CGRect(x: 360, y: 500, width: 520, height: 520),
            CGRect(x: 660, y: 200, width: 400, height: 280)
        ],
        portals: [
            .init(
                id: "portal.recordsEntrance",
                label: "ANNEX",
                approachPoint: CGPoint(x: 1145, y: 355),
                hitArea: CGRect(x: 960, y: 360, width: 440, height: 340),
                destination: .inspect,
                requiresCityOpen: false,
                lockedInspectLine: "Dual ledgers wait behind polite glass. Exterior only for now."
            )
        ],
        pointsOfInterest: [
            .init(label: "ANNEX", worldPoint: CGPoint(x: 1200, y: 590), colorRGBA: (0.55, 0.48, 0.32, 1))
        ]
    )
}
