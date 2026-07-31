import CoreGraphics

/// Act I Harborpoint travel districts. Hub is Sable Row; spokes are case leads.
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
    /// Wider local reveal so streets read at human scale (was 260 at 2× world).
    static let fogRevealRadius: CGFloat = 400
    static let standingAdultBodyHeight = OfficeInteriorScale.standingAdultBodyHeight

    static var cameraVisibleHeight: CGFloat {
        DefaultPlayZoom.cameraVisibleHeight(standingBodyHeight: standingAdultBodyHeight)
    }

    func spawnPoint(arrivalKey: String?) -> CGPoint {
        if let arrivalKey, let point = spawnByArrivalKey[arrivalKey] {
            return point
        }
        return actorStart
    }

    func makeGrid() -> NavigationGrid {
        NavigationGrid(
            origin: .zero,
            columns: Int(ceil(Self.worldArtSize.width / 64)),
            rows: Int(ceil(Self.worldArtSize.height / 64)),
            cellSize: CGSize(width: 64, height: 64),
            obstacles: obstacles,
            agentProfile: .detective,
            worldBounds: Self.worldBounds
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

    // MARK: - Sable Row (hub)

    static let sableRow = CityDistrictDefinition(
        id: .sableRow,
        locationName: "SABLE ROW — LOWER WARD",
        arrivalHint: "SABLE ROW  •  Voss's apartment is on the southeast stoop. Case streets open from here.",
        groundTextureName: "city_sable_row_ground_v02",
        mapTextureName: "map_city_sable_row_v02",
        actorStart: CGPoint(x: 1600, y: 90),
        spawnByArrivalKey: [
            "from.office": CGPoint(x: 1600, y: 90),
            "from.wharfLadder": CGPoint(x: 450, y: 550),
            "from.riverside": CGPoint(x: 600, y: 100),
            "from.harborpointPD": CGPoint(x: 1100, y: 550),
            "from.lilaStreet": CGPoint(x: 1775, y: 600),
            "from.civicRecords": CGPoint(x: 850, y: 550)
        ],
        visualSprites: [
            .init(textureName: "city_building_tenement", groundPoint: CGPoint(x: 240, y: 810), scale: 0.81, anchorY: 0.12, depthBias: 0),
            .init(textureName: "city_building_storefront", groundPoint: CGPoint(x: 710, y: 830), scale: 0.75, anchorY: 0.12, depthBias: 0),
            .init(textureName: "city_building_rowhouse", groundPoint: CGPoint(x: 1225, y: 820), scale: 0.78, anchorY: 0.12, depthBias: 0),
            .init(textureName: "city_building_shop", groundPoint: CGPoint(x: 390, y: 410), scale: 0.80, anchorY: 0.14, depthBias: 0),
            .init(textureName: "city_building_gatehouse", groundPoint: CGPoint(x: 840, y: 380), scale: 0.85, anchorY: 0.16, depthBias: 0),
            .init(textureName: "city_building_voss_stoop", groundPoint: CGPoint(x: 1700, y: 260), scale: 0.81, anchorY: 0.10, depthBias: 0),
            .init(textureName: "city_prop_statue", groundPoint: CGPoint(x: 525, y: 590), scale: 0.4, anchorY: 0.10, depthBias: 3),
            .init(textureName: "city_prop_bench", groundPoint: CGPoint(x: 460, y: 540), scale: 0.3, anchorY: 0.15, depthBias: 2),
            .init(textureName: "city_prop_bench", groundPoint: CGPoint(x: 610, y: 550), scale: 0.29, anchorY: 0.15, depthBias: 2),
            .init(textureName: "city_prop_lamp", groundPoint: CGPoint(x: 280, y: 600), scale: 0.35, anchorY: 0.12, depthBias: 1),
            .init(textureName: "city_prop_lamp", groundPoint: CGPoint(x: 650, y: 610), scale: 0.35, anchorY: 0.12, depthBias: 1),
            .init(textureName: "city_prop_lamp", groundPoint: CGPoint(x: 1100, y: 600), scale: 0.35, anchorY: 0.12, depthBias: 1),
            .init(textureName: "city_prop_lamp", groundPoint: CGPoint(x: 1550, y: 450), scale: 0.35, anchorY: 0.12, depthBias: 1),
            .init(textureName: "city_prop_lamp", groundPoint: CGPoint(x: 950, y: 190), scale: 0.35, anchorY: 0.12, depthBias: 1),
            .init(textureName: "city_prop_car_black", groundPoint: CGPoint(x: 740, y: 490), scale: 0.32, anchorY: 0.18, depthBias: 2),
            .init(textureName: "city_prop_car_olive", groundPoint: CGPoint(x: 1200, y: 430), scale: 0.32, anchorY: 0.18, depthBias: 2),
            .init(textureName: "city_prop_car_maroon", groundPoint: CGPoint(x: 1425, y: 190), scale: 0.32, anchorY: 0.18, depthBias: 2),
            .init(textureName: "city_prop_kiosk", groundPoint: CGPoint(x: 1025, y: 160), scale: 0.36, anchorY: 0.20, depthBias: 2),
            .init(textureName: "city_prop_crates_mail", groundPoint: CGPoint(x: 1110, y: 140), scale: 0.35, anchorY: 0.24, depthBias: 2),
            .init(textureName: "city_prop_gate", groundPoint: CGPoint(x: 525, y: 310), scale: 0.36, anchorY: 0.22, depthBias: 2)
        ],
        // Building footprints leave a central cross of streets walkable.
        obstacles: [
            CGRect(x: 40, y: 690, width: 390, height: 410),
            CGRect(x: 520, y: 710, width: 390, height: 390),
            CGRect(x: 1020, y: 700, width: 450, height: 400),
            CGRect(x: 60, y: 260, width: 410, height: 260),
            CGRect(x: 610, y: 240, width: 350, height: 240),
            CGRect(x: 1525, y: 180, width: 450, height: 350)
        ],
        portals: [
            .init(
                id: "portal.office",
                label: "VOSS APT",
                approachPoint: CGPoint(x: 1600, y: 90),
                hitArea: CGRect(x: 1480, y: 20, width: 280, height: 150),
                destination: .office,
                requiresCityOpen: false,
                lockedInspectLine: "The office door is locked from this side."
            ),
            .init(
                id: "portal.wharfLadder",
                label: "WHARF",
                approachPoint: CGPoint(x: 450, y: 550),
                hitArea: CGRect(x: 340, y: 480, width: 220, height: 140),
                destination: .district(.wharfLadder),
                requiresCityOpen: true,
                lockedInspectLine: "The street toward Wharf Ladder stays closed until the case leaves the office."
            ),
            .init(
                id: "portal.riverside",
                label: "RIVER",
                approachPoint: CGPoint(x: 600, y: 100),
                hitArea: CGRect(x: 480, y: 20, width: 240, height: 130),
                destination: .district(.riverside),
                requiresCityOpen: true,
                lockedInspectLine: "The river stones can wait until the city opens."
            ),
            .init(
                id: "portal.harborpointPD",
                label: "PD",
                approachPoint: CGPoint(x: 1100, y: 550),
                hitArea: CGRect(x: 980, y: 480, width: 240, height: 140),
                destination: .district(.harborpointPD),
                requiresCityOpen: true,
                lockedInspectLine: "Harborpoint PD will still be filing soft conclusions when you are ready."
            ),
            .init(
                id: "portal.lilaStreet",
                label: "LILA",
                approachPoint: CGPoint(x: 1775, y: 600),
                hitArea: CGRect(x: 1650, y: 530, width: 240, height: 140),
                destination: .district(.lilaStreet),
                requiresCityOpen: true,
                lockedInspectLine: "The street outside Lila's rooms opens with the city."
            ),
            .init(
                id: "portal.civicRecords",
                label: "RECORDS",
                approachPoint: CGPoint(x: 850, y: 550),
                hitArea: CGRect(x: 730, y: 480, width: 240, height: 140),
                destination: .district(.civicRecords),
                requiresCityOpen: true,
                lockedInspectLine: "Civic Records keeps dual ledgers behind a polite door."
            )
        ],
        pointsOfInterest: [
            .init(label: "VOSS APT", worldPoint: CGPoint(x: 1600, y: 90), colorRGBA: (0.72, 0.22, 0.18, 1)),
            .init(label: "WHARF", worldPoint: CGPoint(x: 450, y: 550), colorRGBA: (0.32, 0.51, 0.66, 1)),
            .init(label: "RIVER", worldPoint: CGPoint(x: 600, y: 100), colorRGBA: (0.28, 0.45, 0.58, 1)),
            .init(label: "PD", worldPoint: CGPoint(x: 1100, y: 550), colorRGBA: (0.79, 0.55, 0.26, 1)),
            .init(label: "LILA", worldPoint: CGPoint(x: 1775, y: 600), colorRGBA: (0.58, 0.20, 0.48, 1)),
            .init(label: "RECORDS", worldPoint: CGPoint(x: 850, y: 550), colorRGBA: (0.55, 0.48, 0.32, 1))
        ]
    )

    // MARK: - Wharf Ladder

    static let wharfLadder = CityDistrictDefinition(
        id: .wharfLadder,
        locationName: "WHARF LADDER — SHIPPING",
        arrivalHint: "WHARF LADDER  •  Lillian's shipping office faces the wet pier.",
        groundTextureName: "city_wharf_ladder_ground_v02",
        mapTextureName: "map_city_wharf_ladder_v02",
        actorStart: CGPoint(x: 310, y: 210),
        spawnByArrivalKey: [
            "from.sableRow": CGPoint(x: 310, y: 210)
        ],
        visualSprites: [
            .init(textureName: "city_building_shipping_office", groundPoint: CGPoint(x: 1100, y: 490), scale: 0.81, anchorY: 0.10, depthBias: 0),
            .init(textureName: "city_building_warehouse", groundPoint: CGPoint(x: 550, y: 740), scale: 0.86, anchorY: 0.10, depthBias: 0),
            .init(textureName: "city_building_boarding", groundPoint: CGPoint(x: 1600, y: 680), scale: 0.73, anchorY: 0.12, depthBias: 0),
            .init(textureName: "city_building_dock_shed", groundPoint: CGPoint(x: 430, y: 360), scale: 0.62, anchorY: 0.16, depthBias: 0),
            .init(textureName: "city_prop_lamp", groundPoint: CGPoint(x: 700, y: 450), scale: 0.45, anchorY: 0.12, depthBias: 1),
            .init(textureName: "city_prop_lamp", groundPoint: CGPoint(x: 1300, y: 390), scale: 0.45, anchorY: 0.12, depthBias: 1),
            .init(textureName: "city_prop_crates_mail", groundPoint: CGPoint(x: 840, y: 310), scale: 0.42, anchorY: 0.24, depthBias: 2),
            .init(textureName: "city_prop_car_black", groundPoint: CGPoint(x: 950, y: 240), scale: 0.35, anchorY: 0.18, depthBias: 2)
        ],
        obstacles: [
            CGRect(x: 200, y: 600, width: 700, height: 450),
            CGRect(x: 850, y: 350, width: 550, height: 450),
            CGRect(x: 1400, y: 550, width: 500, height: 450),
            CGRect(x: 200, y: 240, width: 400, height: 260)
        ],
        portals: [
            .init(
                id: "portal.sableRow",
                label: "SABLE ROW",
                approachPoint: CGPoint(x: 310, y: 210),
                hitArea: CGRect(x: 180, y: 120, width: 260, height: 160),
                destination: .district(.sableRow),
                requiresCityOpen: false,
                lockedInspectLine: ""
            ),
            .init(
                id: "portal.shippingOffice",
                label: "SHIPPING",
                approachPoint: CGPoint(x: 1050, y: 410),
                hitArea: CGRect(x: 925, y: 340, width: 350, height: 260),
                destination: .inspect,
                requiresCityOpen: false,
                lockedInspectLine: "Lillian's shipping office. Ledgers and a late errand uptown — exterior only for now."
            )
        ],
        pointsOfInterest: [
            .init(label: "SHIPPING", worldPoint: CGPoint(x: 1100, y: 490), colorRGBA: (0.72, 0.22, 0.18, 1)),
            .init(label: "SABLE ROW", worldPoint: CGPoint(x: 310, y: 210), colorRGBA: (0.55, 0.48, 0.32, 1))
        ]
    )

    // MARK: - Riverside

    static let riverside = CityDistrictDefinition(
        id: .riverside,
        locationName: "RIVERSIDE — IRON STAIRS",
        arrivalHint: "RIVERSIDE  •  The old iron stairs drop to the coat stones.",
        groundTextureName: "city_riverside_ground_v02",
        mapTextureName: "map_city_riverside_v02",
        actorStart: CGPoint(x: 450, y: 700),
        spawnByArrivalKey: [
            "from.sableRow": CGPoint(x: 450, y: 700)
        ],
        visualSprites: [
            .init(textureName: "city_building_iron_stairs", groundPoint: CGPoint(x: 1200, y: 390), scale: 0.75, anchorY: 0.08, depthBias: 0),
            .init(textureName: "city_building_river_watch", groundPoint: CGPoint(x: 600, y: 680), scale: 0.6, anchorY: 0.14, depthBias: 0),
            .init(textureName: "city_building_rail_lamp", groundPoint: CGPoint(x: 900, y: 490), scale: 0.55, anchorY: 0.14, depthBias: 1),
            .init(textureName: "city_building_abutment", groundPoint: CGPoint(x: 1550, y: 280), scale: 0.65, anchorY: 0.16, depthBias: 0),
            .init(textureName: "city_prop_lamp", groundPoint: CGPoint(x: 525, y: 600), scale: 0.45, anchorY: 0.12, depthBias: 1),
            .init(textureName: "city_prop_lamp", groundPoint: CGPoint(x: 1400, y: 450), scale: 0.45, anchorY: 0.12, depthBias: 1)
        ],
        obstacles: [
            CGRect(x: 450, y: 550, width: 350, height: 350),
            CGRect(x: 950, y: 260, width: 550, height: 390),
            CGRect(x: 1350, y: 140, width: 500, height: 350),
            CGRect(x: 0, y: 0, width: 2048, height: 110)
        ],
        portals: [
            .init(
                id: "portal.sableRow",
                label: "SABLE ROW",
                approachPoint: CGPoint(x: 450, y: 700),
                hitArea: CGRect(x: 320, y: 610, width: 260, height: 180),
                destination: .district(.sableRow),
                requiresCityOpen: false,
                lockedInspectLine: ""
            ),
            .init(
                id: "portal.ironStairs",
                label: "STAIRS",
                approachPoint: CGPoint(x: 1150, y: 340),
                hitArea: CGRect(x: 1000, y: 240, width: 350, height: 260),
                destination: .inspect,
                requiresCityOpen: false,
                lockedInspectLine: "Wet iron and staged stones. The coat is already in police custody."
            )
        ],
        pointsOfInterest: [
            .init(label: "STAIRS", worldPoint: CGPoint(x: 1200, y: 390), colorRGBA: (0.32, 0.51, 0.66, 1)),
            .init(label: "SABLE ROW", worldPoint: CGPoint(x: 450, y: 700), colorRGBA: (0.55, 0.48, 0.32, 1))
        ]
    )

    // MARK: - Harborpoint PD

    static let harborpointPD = CityDistrictDefinition(
        id: .harborpointPD,
        locationName: "HARBORPOINT PD",
        arrivalHint: "HARBORPOINT PD  •  Soft files cool faster than the rain.",
        groundTextureName: "city_harborpoint_pd_ground_v02",
        mapTextureName: "map_city_harborpoint_pd_v02",
        actorStart: CGPoint(x: 390, y: 260),
        spawnByArrivalKey: [
            "from.sableRow": CGPoint(x: 390, y: 260)
        ],
        visualSprites: [
            .init(textureName: "city_building_pd_station", groundPoint: CGPoint(x: 1150, y: 600), scale: 0.88, anchorY: 0.10, depthBias: 0),
            .init(textureName: "city_building_pd_annex", groundPoint: CGPoint(x: 1650, y: 500), scale: 0.7, anchorY: 0.12, depthBias: 0),
            .init(textureName: "city_building_pd_alley", groundPoint: CGPoint(x: 550, y: 700), scale: 0.62, anchorY: 0.14, depthBias: 0),
            .init(textureName: "city_building_pd_plaza_wall", groundPoint: CGPoint(x: 800, y: 350), scale: 0.52, anchorY: 0.18, depthBias: 1),
            .init(textureName: "city_prop_lamp", groundPoint: CGPoint(x: 700, y: 450), scale: 0.45, anchorY: 0.12, depthBias: 1),
            .init(textureName: "city_prop_lamp", groundPoint: CGPoint(x: 1350, y: 410), scale: 0.45, anchorY: 0.12, depthBias: 1),
            .init(textureName: "city_prop_car_black", groundPoint: CGPoint(x: 850, y: 280), scale: 0.35, anchorY: 0.18, depthBias: 2)
        ],
        obstacles: [
            CGRect(x: 850, y: 430, width: 700, height: 550),
            CGRect(x: 1450, y: 350, width: 500, height: 450),
            CGRect(x: 350, y: 575, width: 400, height: 400),
            CGRect(x: 650, y: 250, width: 350, height: 210)
        ],
        portals: [
            .init(
                id: "portal.sableRow",
                label: "SABLE ROW",
                approachPoint: CGPoint(x: 390, y: 260),
                hitArea: CGRect(x: 260, y: 170, width: 260, height: 160),
                destination: .district(.sableRow),
                requiresCityOpen: false,
                lockedInspectLine: ""
            ),
            .init(
                id: "portal.pdEntrance",
                label: "STATION",
                approachPoint: CGPoint(x: 1100, y: 490),
                hitArea: CGRect(x: 950, y: 400, width: 400, height: 300),
                destination: .inspect,
                requiresCityOpen: false,
                lockedInspectLine: "The desk sergeant keeps soft conclusions behind glass. Exterior only for now."
            )
        ],
        pointsOfInterest: [
            .init(label: "STATION", worldPoint: CGPoint(x: 1150, y: 600), colorRGBA: (0.79, 0.55, 0.26, 1)),
            .init(label: "SABLE ROW", worldPoint: CGPoint(x: 390, y: 260), colorRGBA: (0.55, 0.48, 0.32, 1))
        ]
    )

    // MARK: - Lila Street

    static let lilaStreet = CityDistrictDefinition(
        id: .lilaStreet,
        locationName: "LILA'S STREET",
        arrivalHint: "LILA'S STREET  •  Doorway posts remember the Gray Man.",
        groundTextureName: "city_lila_street_ground_v02",
        mapTextureName: "map_city_lila_street_v02",
        actorStart: CGPoint(x: 350, y: 250),
        spawnByArrivalKey: [
            "from.sableRow": CGPoint(x: 350, y: 250)
        ],
        visualSprites: [
            .init(textureName: "city_building_lila_rooms", groundPoint: CGPoint(x: 1250, y: 550), scale: 0.81, anchorY: 0.10, depthBias: 0),
            .init(textureName: "city_building_lila_neighbor", groundPoint: CGPoint(x: 700, y: 680), scale: 0.73, anchorY: 0.12, depthBias: 0),
            .init(textureName: "city_building_lila_opposite", groundPoint: CGPoint(x: 1650, y: 640), scale: 0.7, anchorY: 0.12, depthBias: 0),
            .init(textureName: "city_building_lila_alcove", groundPoint: CGPoint(x: 950, y: 350), scale: 0.57, anchorY: 0.16, depthBias: 1),
            .init(textureName: "city_prop_lamp", groundPoint: CGPoint(x: 600, y: 450), scale: 0.45, anchorY: 0.12, depthBias: 1),
            .init(textureName: "city_prop_lamp", groundPoint: CGPoint(x: 1400, y: 410), scale: 0.45, anchorY: 0.12, depthBias: 1),
            .init(textureName: "city_prop_car_olive", groundPoint: CGPoint(x: 800, y: 260), scale: 0.35, anchorY: 0.18, depthBias: 2),
            .init(textureName: "city_prop_bench", groundPoint: CGPoint(x: 1050, y: 390), scale: 0.42, anchorY: 0.15, depthBias: 2)
        ],
        obstacles: [
            CGRect(x: 500, y: 550, width: 450, height: 450),
            CGRect(x: 1000, y: 410, width: 550, height: 500),
            CGRect(x: 1450, y: 500, width: 450, height: 450),
            CGRect(x: 800, y: 260, width: 300, height: 210)
        ],
        portals: [
            .init(
                id: "portal.sableRow",
                label: "SABLE ROW",
                approachPoint: CGPoint(x: 350, y: 250),
                hitArea: CGRect(x: 220, y: 160, width: 260, height: 160),
                destination: .district(.sableRow),
                requiresCityOpen: false,
                lockedInspectLine: ""
            ),
            .init(
                id: "portal.lilaRooms",
                label: "ROOMS",
                approachPoint: CGPoint(x: 1200, y: 460),
                hitArea: CGRect(x: 1050, y: 370, width: 350, height: 280),
                destination: .inspect,
                requiresCityOpen: false,
                lockedInspectLine: "Lila's rooms stay private. Watch the doorway posts instead."
            )
        ],
        pointsOfInterest: [
            .init(label: "ROOMS", worldPoint: CGPoint(x: 1250, y: 550), colorRGBA: (0.58, 0.20, 0.48, 1)),
            .init(label: "SABLE ROW", worldPoint: CGPoint(x: 350, y: 250), colorRGBA: (0.55, 0.48, 0.32, 1))
        ]
    )

    // MARK: - Civic Records

    static let civicRecords = CityDistrictDefinition(
        id: .civicRecords,
        locationName: "CIVIC RECORDS ANNEX",
        arrivalHint: "CIVIC RECORDS  •  Marble that still looks clean in the rain.",
        groundTextureName: "city_civic_records_ground_v02",
        mapTextureName: "map_city_civic_records_v02",
        actorStart: CGPoint(x: 380, y: 240),
        spawnByArrivalKey: [
            "from.sableRow": CGPoint(x: 380, y: 240)
        ],
        visualSprites: [
            .init(textureName: "city_building_records_annex", groundPoint: CGPoint(x: 1200, y: 590), scale: 0.88, anchorY: 0.10, depthBias: 0),
            .init(textureName: "city_building_records_wing", groundPoint: CGPoint(x: 1650, y: 490), scale: 0.73, anchorY: 0.12, depthBias: 0),
            .init(textureName: "city_building_records_colonnade", groundPoint: CGPoint(x: 600, y: 680), scale: 0.68, anchorY: 0.12, depthBias: 0),
            .init(textureName: "city_building_records_plaza", groundPoint: CGPoint(x: 850, y: 350), scale: 0.55, anchorY: 0.18, depthBias: 1),
            .init(textureName: "city_prop_lamp", groundPoint: CGPoint(x: 675, y: 440), scale: 0.45, anchorY: 0.12, depthBias: 1),
            .init(textureName: "city_prop_lamp", groundPoint: CGPoint(x: 1350, y: 400), scale: 0.45, anchorY: 0.12, depthBias: 1),
            .init(textureName: "city_prop_statue", groundPoint: CGPoint(x: 950, y: 450), scale: 0.5, anchorY: 0.10, depthBias: 3)
        ],
        obstacles: [
            CGRect(x: 900, y: 430, width: 700, height: 550),
            CGRect(x: 1450, y: 350, width: 500, height: 450),
            CGRect(x: 400, y: 550, width: 450, height: 450),
            CGRect(x: 700, y: 250, width: 350, height: 210)
        ],
        portals: [
            .init(
                id: "portal.sableRow",
                label: "SABLE ROW",
                approachPoint: CGPoint(x: 380, y: 240),
                hitArea: CGRect(x: 250, y: 150, width: 260, height: 160),
                destination: .district(.sableRow),
                requiresCityOpen: false,
                lockedInspectLine: ""
            ),
            .init(
                id: "portal.recordsEntrance",
                label: "ANNEX",
                approachPoint: CGPoint(x: 1140, y: 490),
                hitArea: CGRect(x: 980, y: 390, width: 400, height: 300),
                destination: .inspect,
                requiresCityOpen: false,
                lockedInspectLine: "Dual ledgers wait behind polite glass. Exterior only for now."
            )
        ],
        pointsOfInterest: [
            .init(label: "ANNEX", worldPoint: CGPoint(x: 1200, y: 590), colorRGBA: (0.55, 0.48, 0.32, 1)),
            .init(label: "SABLE ROW", worldPoint: CGPoint(x: 380, y: 240), colorRGBA: (0.72, 0.22, 0.18, 1))
        ]
    )
}
