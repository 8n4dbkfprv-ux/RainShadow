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
    static let environmentScale: CGFloat = 2
    static let worldArtSize = CGSize(
        width: sourceArtSize.width * environmentScale,
        height: sourceArtSize.height * environmentScale
    )
    static let worldBounds = CGRect(origin: .zero, size: worldArtSize)
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
        actorStart: CGPoint(x: 3_200, y: 180),
        spawnByArrivalKey: [
            "from.office": CGPoint(x: 3_200, y: 180),
            "from.wharfLadder": CGPoint(x: 900, y: 1_100),
            "from.riverside": CGPoint(x: 1_200, y: 200),
            "from.harborpointPD": CGPoint(x: 2_200, y: 1_100),
            "from.lilaStreet": CGPoint(x: 3_550, y: 1_200),
            "from.civicRecords": CGPoint(x: 1_700, y: 1_100)
        ],
        visualSprites: [
            .init(textureName: "city_building_tenement", groundPoint: CGPoint(x: 480, y: 1_620), scale: 1.55, anchorY: 0.12, depthBias: 0),
            .init(textureName: "city_building_storefront", groundPoint: CGPoint(x: 1_420, y: 1_660), scale: 1.45, anchorY: 0.12, depthBias: 0),
            .init(textureName: "city_building_rowhouse", groundPoint: CGPoint(x: 2_450, y: 1_640), scale: 1.50, anchorY: 0.12, depthBias: 0),
            .init(textureName: "city_building_shop", groundPoint: CGPoint(x: 780, y: 820), scale: 1.25, anchorY: 0.14, depthBias: 0),
            .init(textureName: "city_building_gatehouse", groundPoint: CGPoint(x: 1_680, y: 760), scale: 1.15, anchorY: 0.16, depthBias: 0),
            .init(textureName: "city_building_voss_stoop", groundPoint: CGPoint(x: 3_400, y: 520), scale: 1.55, anchorY: 0.10, depthBias: 0),
            .init(textureName: "city_prop_statue", groundPoint: CGPoint(x: 1_050, y: 1_180), scale: 0.55, anchorY: 0.10, depthBias: 3),
            .init(textureName: "city_prop_bench", groundPoint: CGPoint(x: 920, y: 1_080), scale: 0.42, anchorY: 0.15, depthBias: 2),
            .init(textureName: "city_prop_bench", groundPoint: CGPoint(x: 1_220, y: 1_100), scale: 0.40, anchorY: 0.15, depthBias: 2),
            .init(textureName: "city_prop_lamp", groundPoint: CGPoint(x: 560, y: 1_200), scale: 0.48, anchorY: 0.12, depthBias: 1),
            .init(textureName: "city_prop_lamp", groundPoint: CGPoint(x: 1_300, y: 1_220), scale: 0.48, anchorY: 0.12, depthBias: 1),
            .init(textureName: "city_prop_lamp", groundPoint: CGPoint(x: 2_200, y: 1_200), scale: 0.48, anchorY: 0.12, depthBias: 1),
            .init(textureName: "city_prop_lamp", groundPoint: CGPoint(x: 3_100, y: 900), scale: 0.48, anchorY: 0.12, depthBias: 1),
            .init(textureName: "city_prop_lamp", groundPoint: CGPoint(x: 1_900, y: 380), scale: 0.48, anchorY: 0.12, depthBias: 1),
            .init(textureName: "city_prop_car_black", groundPoint: CGPoint(x: 1_480, y: 980), scale: 0.45, anchorY: 0.18, depthBias: 2),
            .init(textureName: "city_prop_car_olive", groundPoint: CGPoint(x: 2_400, y: 860), scale: 0.45, anchorY: 0.18, depthBias: 2),
            .init(textureName: "city_prop_car_maroon", groundPoint: CGPoint(x: 2_850, y: 380), scale: 0.45, anchorY: 0.18, depthBias: 2),
            .init(textureName: "city_prop_kiosk", groundPoint: CGPoint(x: 2_050, y: 320), scale: 0.50, anchorY: 0.20, depthBias: 2),
            .init(textureName: "city_prop_crates_mail", groundPoint: CGPoint(x: 2_220, y: 280), scale: 0.48, anchorY: 0.24, depthBias: 2),
            .init(textureName: "city_prop_gate", groundPoint: CGPoint(x: 1_050, y: 620), scale: 0.50, anchorY: 0.22, depthBias: 2)
        ],
        // Building footprints leave a central cross of streets walkable.
        obstacles: [
            CGRect(x: 80, y: 1_380, width: 780, height: 820),
            CGRect(x: 1_040, y: 1_420, width: 780, height: 780),
            CGRect(x: 2_040, y: 1_400, width: 900, height: 800),
            CGRect(x: 120, y: 520, width: 820, height: 520),
            CGRect(x: 1_220, y: 480, width: 700, height: 480),
            CGRect(x: 3_050, y: 360, width: 900, height: 700)
        ],
        portals: [
            .init(
                id: "portal.office",
                label: "VOSS APT",
                approachPoint: CGPoint(x: 3_200, y: 180),
                hitArea: CGRect(x: 2_960, y: 40, width: 560, height: 300),
                destination: .office,
                requiresCityOpen: false,
                lockedInspectLine: "The office door is locked from this side."
            ),
            .init(
                id: "portal.wharfLadder",
                label: "WHARF",
                approachPoint: CGPoint(x: 900, y: 1_100),
                hitArea: CGRect(x: 680, y: 960, width: 440, height: 280),
                destination: .district(.wharfLadder),
                requiresCityOpen: true,
                lockedInspectLine: "The street toward Wharf Ladder stays closed until the case leaves the office."
            ),
            .init(
                id: "portal.riverside",
                label: "RIVER",
                approachPoint: CGPoint(x: 1_200, y: 200),
                hitArea: CGRect(x: 960, y: 40, width: 480, height: 260),
                destination: .district(.riverside),
                requiresCityOpen: true,
                lockedInspectLine: "The river stones can wait until the city opens."
            ),
            .init(
                id: "portal.harborpointPD",
                label: "PD",
                approachPoint: CGPoint(x: 2_200, y: 1_100),
                hitArea: CGRect(x: 1_960, y: 960, width: 480, height: 280),
                destination: .district(.harborpointPD),
                requiresCityOpen: true,
                lockedInspectLine: "Harborpoint PD will still be filing soft conclusions when you are ready."
            ),
            .init(
                id: "portal.lilaStreet",
                label: "LILA",
                approachPoint: CGPoint(x: 3_550, y: 1_200),
                hitArea: CGRect(x: 3_300, y: 1_060, width: 480, height: 280),
                destination: .district(.lilaStreet),
                requiresCityOpen: true,
                lockedInspectLine: "The street outside Lila's rooms opens with the city."
            ),
            .init(
                id: "portal.civicRecords",
                label: "RECORDS",
                approachPoint: CGPoint(x: 1_700, y: 1_100),
                hitArea: CGRect(x: 1_460, y: 960, width: 480, height: 280),
                destination: .district(.civicRecords),
                requiresCityOpen: true,
                lockedInspectLine: "Civic Records keeps dual ledgers behind a polite door."
            )
        ],
        pointsOfInterest: [
            .init(label: "VOSS APT", worldPoint: CGPoint(x: 3_200, y: 180), colorRGBA: (0.72, 0.22, 0.18, 1)),
            .init(label: "WHARF", worldPoint: CGPoint(x: 900, y: 1_100), colorRGBA: (0.32, 0.51, 0.66, 1)),
            .init(label: "RIVER", worldPoint: CGPoint(x: 1_200, y: 200), colorRGBA: (0.28, 0.45, 0.58, 1)),
            .init(label: "PD", worldPoint: CGPoint(x: 2_200, y: 1_100), colorRGBA: (0.79, 0.55, 0.26, 1)),
            .init(label: "LILA", worldPoint: CGPoint(x: 3_550, y: 1_200), colorRGBA: (0.58, 0.20, 0.48, 1)),
            .init(label: "RECORDS", worldPoint: CGPoint(x: 1_700, y: 1_100), colorRGBA: (0.55, 0.48, 0.32, 1))
        ]
    )

    // MARK: - Wharf Ladder

    static let wharfLadder = CityDistrictDefinition(
        id: .wharfLadder,
        locationName: "WHARF LADDER — SHIPPING",
        arrivalHint: "WHARF LADDER  •  Lillian's shipping office faces the wet pier.",
        groundTextureName: "city_wharf_ladder_ground_v02",
        mapTextureName: "map_city_wharf_ladder_v02",
        actorStart: CGPoint(x: 620, y: 420),
        spawnByArrivalKey: [
            "from.sableRow": CGPoint(x: 620, y: 420)
        ],
        visualSprites: [
            .init(textureName: "city_building_shipping_office", groundPoint: CGPoint(x: 2_200, y: 980), scale: 1.55, anchorY: 0.10, depthBias: 0),
            .init(textureName: "city_building_warehouse", groundPoint: CGPoint(x: 1_100, y: 1_480), scale: 1.65, anchorY: 0.10, depthBias: 0),
            .init(textureName: "city_building_boarding", groundPoint: CGPoint(x: 3_200, y: 1_360), scale: 1.40, anchorY: 0.12, depthBias: 0),
            .init(textureName: "city_building_dock_shed", groundPoint: CGPoint(x: 860, y: 720), scale: 1.20, anchorY: 0.16, depthBias: 0),
            .init(textureName: "city_prop_lamp", groundPoint: CGPoint(x: 1_400, y: 900), scale: 0.62, anchorY: 0.12, depthBias: 1),
            .init(textureName: "city_prop_lamp", groundPoint: CGPoint(x: 2_600, y: 780), scale: 0.62, anchorY: 0.12, depthBias: 1),
            .init(textureName: "city_prop_crates_mail", groundPoint: CGPoint(x: 1_680, y: 620), scale: 0.58, anchorY: 0.24, depthBias: 2),
            .init(textureName: "city_prop_car_black", groundPoint: CGPoint(x: 1_900, y: 480), scale: 0.48, anchorY: 0.18, depthBias: 2)
        ],
        obstacles: [
            CGRect(x: 400, y: 1_200, width: 1_400, height: 900),
            CGRect(x: 1_700, y: 700, width: 1_100, height: 900),
            CGRect(x: 2_800, y: 1_100, width: 1_000, height: 900),
            CGRect(x: 400, y: 480, width: 800, height: 520)
        ],
        portals: [
            .init(
                id: "portal.sableRow",
                label: "SABLE ROW",
                approachPoint: CGPoint(x: 620, y: 420),
                hitArea: CGRect(x: 360, y: 240, width: 520, height: 320),
                destination: .district(.sableRow),
                requiresCityOpen: false,
                lockedInspectLine: ""
            ),
            .init(
                id: "portal.shippingOffice",
                label: "SHIPPING",
                approachPoint: CGPoint(x: 2_100, y: 820),
                hitArea: CGRect(x: 1_850, y: 680, width: 700, height: 520),
                destination: .inspect,
                requiresCityOpen: false,
                lockedInspectLine: "Lillian's shipping office. Ledgers and a late errand uptown — exterior only for now."
            )
        ],
        pointsOfInterest: [
            .init(label: "SHIPPING", worldPoint: CGPoint(x: 2_200, y: 980), colorRGBA: (0.72, 0.22, 0.18, 1)),
            .init(label: "SABLE ROW", worldPoint: CGPoint(x: 620, y: 420), colorRGBA: (0.55, 0.48, 0.32, 1))
        ]
    )

    // MARK: - Riverside

    static let riverside = CityDistrictDefinition(
        id: .riverside,
        locationName: "RIVERSIDE — IRON STAIRS",
        arrivalHint: "RIVERSIDE  •  The old iron stairs drop to the coat stones.",
        groundTextureName: "city_riverside_ground_v02",
        mapTextureName: "map_city_riverside_v02",
        actorStart: CGPoint(x: 900, y: 1_400),
        spawnByArrivalKey: [
            "from.sableRow": CGPoint(x: 900, y: 1_400)
        ],
        visualSprites: [
            .init(textureName: "city_building_iron_stairs", groundPoint: CGPoint(x: 2_400, y: 780), scale: 1.45, anchorY: 0.08, depthBias: 0),
            .init(textureName: "city_building_river_watch", groundPoint: CGPoint(x: 1_200, y: 1_360), scale: 1.15, anchorY: 0.14, depthBias: 0),
            .init(textureName: "city_building_rail_lamp", groundPoint: CGPoint(x: 1_800, y: 980), scale: 1.05, anchorY: 0.14, depthBias: 1),
            .init(textureName: "city_building_abutment", groundPoint: CGPoint(x: 3_100, y: 560), scale: 1.25, anchorY: 0.16, depthBias: 0),
            .init(textureName: "city_prop_lamp", groundPoint: CGPoint(x: 1_050, y: 1_200), scale: 0.62, anchorY: 0.12, depthBias: 1),
            .init(textureName: "city_prop_lamp", groundPoint: CGPoint(x: 2_800, y: 900), scale: 0.62, anchorY: 0.12, depthBias: 1)
        ],
        obstacles: [
            CGRect(x: 900, y: 1_100, width: 700, height: 700),
            CGRect(x: 1_900, y: 520, width: 1_100, height: 780),
            CGRect(x: 2_700, y: 280, width: 1_000, height: 700),
            CGRect(x: 0, y: 0, width: 4_096, height: 220)
        ],
        portals: [
            .init(
                id: "portal.sableRow",
                label: "SABLE ROW",
                approachPoint: CGPoint(x: 900, y: 1_400),
                hitArea: CGRect(x: 640, y: 1_220, width: 520, height: 360),
                destination: .district(.sableRow),
                requiresCityOpen: false,
                lockedInspectLine: ""
            ),
            .init(
                id: "portal.ironStairs",
                label: "STAIRS",
                approachPoint: CGPoint(x: 2_300, y: 680),
                hitArea: CGRect(x: 2_000, y: 480, width: 700, height: 520),
                destination: .inspect,
                requiresCityOpen: false,
                lockedInspectLine: "Wet iron and staged stones. The coat is already in police custody."
            )
        ],
        pointsOfInterest: [
            .init(label: "STAIRS", worldPoint: CGPoint(x: 2_400, y: 780), colorRGBA: (0.32, 0.51, 0.66, 1)),
            .init(label: "SABLE ROW", worldPoint: CGPoint(x: 900, y: 1_400), colorRGBA: (0.55, 0.48, 0.32, 1))
        ]
    )

    // MARK: - Harborpoint PD

    static let harborpointPD = CityDistrictDefinition(
        id: .harborpointPD,
        locationName: "HARBORPOINT PD",
        arrivalHint: "HARBORPOINT PD  •  Soft files cool faster than the rain.",
        groundTextureName: "city_harborpoint_pd_ground_v02",
        mapTextureName: "map_city_harborpoint_pd_v02",
        actorStart: CGPoint(x: 780, y: 520),
        spawnByArrivalKey: [
            "from.sableRow": CGPoint(x: 780, y: 520)
        ],
        visualSprites: [
            .init(textureName: "city_building_pd_station", groundPoint: CGPoint(x: 2_300, y: 1_200), scale: 1.70, anchorY: 0.10, depthBias: 0),
            .init(textureName: "city_building_pd_annex", groundPoint: CGPoint(x: 3_300, y: 1_000), scale: 1.35, anchorY: 0.12, depthBias: 0),
            .init(textureName: "city_building_pd_alley", groundPoint: CGPoint(x: 1_100, y: 1_400), scale: 1.20, anchorY: 0.14, depthBias: 0),
            .init(textureName: "city_building_pd_plaza_wall", groundPoint: CGPoint(x: 1_600, y: 700), scale: 1.00, anchorY: 0.18, depthBias: 1),
            .init(textureName: "city_prop_lamp", groundPoint: CGPoint(x: 1_400, y: 900), scale: 0.62, anchorY: 0.12, depthBias: 1),
            .init(textureName: "city_prop_lamp", groundPoint: CGPoint(x: 2_700, y: 820), scale: 0.62, anchorY: 0.12, depthBias: 1),
            .init(textureName: "city_prop_car_black", groundPoint: CGPoint(x: 1_700, y: 560), scale: 0.48, anchorY: 0.18, depthBias: 2)
        ],
        obstacles: [
            CGRect(x: 1_700, y: 860, width: 1_400, height: 1_100),
            CGRect(x: 2_900, y: 700, width: 1_000, height: 900),
            CGRect(x: 700, y: 1_150, width: 800, height: 800),
            CGRect(x: 1_300, y: 500, width: 700, height: 420)
        ],
        portals: [
            .init(
                id: "portal.sableRow",
                label: "SABLE ROW",
                approachPoint: CGPoint(x: 780, y: 520),
                hitArea: CGRect(x: 520, y: 340, width: 520, height: 320),
                destination: .district(.sableRow),
                requiresCityOpen: false,
                lockedInspectLine: ""
            ),
            .init(
                id: "portal.pdEntrance",
                label: "STATION",
                approachPoint: CGPoint(x: 2_200, y: 980),
                hitArea: CGRect(x: 1_900, y: 800, width: 800, height: 600),
                destination: .inspect,
                requiresCityOpen: false,
                lockedInspectLine: "The desk sergeant keeps soft conclusions behind glass. Exterior only for now."
            )
        ],
        pointsOfInterest: [
            .init(label: "STATION", worldPoint: CGPoint(x: 2_300, y: 1_200), colorRGBA: (0.79, 0.55, 0.26, 1)),
            .init(label: "SABLE ROW", worldPoint: CGPoint(x: 780, y: 520), colorRGBA: (0.55, 0.48, 0.32, 1))
        ]
    )

    // MARK: - Lila Street

    static let lilaStreet = CityDistrictDefinition(
        id: .lilaStreet,
        locationName: "LILA'S STREET",
        arrivalHint: "LILA'S STREET  •  Doorway posts remember the Gray Man.",
        groundTextureName: "city_lila_street_ground_v02",
        mapTextureName: "map_city_lila_street_v02",
        actorStart: CGPoint(x: 700, y: 500),
        spawnByArrivalKey: [
            "from.sableRow": CGPoint(x: 700, y: 500)
        ],
        visualSprites: [
            .init(textureName: "city_building_lila_rooms", groundPoint: CGPoint(x: 2_500, y: 1_100), scale: 1.55, anchorY: 0.10, depthBias: 0),
            .init(textureName: "city_building_lila_neighbor", groundPoint: CGPoint(x: 1_400, y: 1_360), scale: 1.40, anchorY: 0.12, depthBias: 0),
            .init(textureName: "city_building_lila_opposite", groundPoint: CGPoint(x: 3_300, y: 1_280), scale: 1.35, anchorY: 0.12, depthBias: 0),
            .init(textureName: "city_building_lila_alcove", groundPoint: CGPoint(x: 1_900, y: 700), scale: 1.10, anchorY: 0.16, depthBias: 1),
            .init(textureName: "city_prop_lamp", groundPoint: CGPoint(x: 1_200, y: 900), scale: 0.62, anchorY: 0.12, depthBias: 1),
            .init(textureName: "city_prop_lamp", groundPoint: CGPoint(x: 2_800, y: 820), scale: 0.62, anchorY: 0.12, depthBias: 1),
            .init(textureName: "city_prop_car_olive", groundPoint: CGPoint(x: 1_600, y: 520), scale: 0.48, anchorY: 0.18, depthBias: 2),
            .init(textureName: "city_prop_bench", groundPoint: CGPoint(x: 2_100, y: 780), scale: 0.58, anchorY: 0.15, depthBias: 2)
        ],
        obstacles: [
            CGRect(x: 1_000, y: 1_100, width: 900, height: 900),
            CGRect(x: 2_000, y: 820, width: 1_100, height: 1_000),
            CGRect(x: 2_900, y: 1_000, width: 900, height: 900),
            CGRect(x: 1_600, y: 520, width: 600, height: 420)
        ],
        portals: [
            .init(
                id: "portal.sableRow",
                label: "SABLE ROW",
                approachPoint: CGPoint(x: 700, y: 500),
                hitArea: CGRect(x: 440, y: 320, width: 520, height: 320),
                destination: .district(.sableRow),
                requiresCityOpen: false,
                lockedInspectLine: ""
            ),
            .init(
                id: "portal.lilaRooms",
                label: "ROOMS",
                approachPoint: CGPoint(x: 2_400, y: 920),
                hitArea: CGRect(x: 2_100, y: 740, width: 700, height: 560),
                destination: .inspect,
                requiresCityOpen: false,
                lockedInspectLine: "Lila's rooms stay private. Watch the doorway posts instead."
            )
        ],
        pointsOfInterest: [
            .init(label: "ROOMS", worldPoint: CGPoint(x: 2_500, y: 1_100), colorRGBA: (0.58, 0.20, 0.48, 1)),
            .init(label: "SABLE ROW", worldPoint: CGPoint(x: 700, y: 500), colorRGBA: (0.55, 0.48, 0.32, 1))
        ]
    )

    // MARK: - Civic Records

    static let civicRecords = CityDistrictDefinition(
        id: .civicRecords,
        locationName: "CIVIC RECORDS ANNEX",
        arrivalHint: "CIVIC RECORDS  •  Marble that still looks clean in the rain.",
        groundTextureName: "city_civic_records_ground_v02",
        mapTextureName: "map_city_civic_records_v02",
        actorStart: CGPoint(x: 760, y: 480),
        spawnByArrivalKey: [
            "from.sableRow": CGPoint(x: 760, y: 480)
        ],
        visualSprites: [
            .init(textureName: "city_building_records_annex", groundPoint: CGPoint(x: 2_400, y: 1_180), scale: 1.70, anchorY: 0.10, depthBias: 0),
            .init(textureName: "city_building_records_wing", groundPoint: CGPoint(x: 3_300, y: 980), scale: 1.40, anchorY: 0.12, depthBias: 0),
            .init(textureName: "city_building_records_colonnade", groundPoint: CGPoint(x: 1_200, y: 1_360), scale: 1.30, anchorY: 0.12, depthBias: 0),
            .init(textureName: "city_building_records_plaza", groundPoint: CGPoint(x: 1_700, y: 700), scale: 1.05, anchorY: 0.18, depthBias: 1),
            .init(textureName: "city_prop_lamp", groundPoint: CGPoint(x: 1_350, y: 880), scale: 0.62, anchorY: 0.12, depthBias: 1),
            .init(textureName: "city_prop_lamp", groundPoint: CGPoint(x: 2_700, y: 800), scale: 0.62, anchorY: 0.12, depthBias: 1),
            .init(textureName: "city_prop_statue", groundPoint: CGPoint(x: 1_900, y: 900), scale: 0.70, anchorY: 0.10, depthBias: 3)
        ],
        obstacles: [
            CGRect(x: 1_800, y: 860, width: 1_400, height: 1_100),
            CGRect(x: 2_900, y: 700, width: 1_000, height: 900),
            CGRect(x: 800, y: 1_100, width: 900, height: 900),
            CGRect(x: 1_400, y: 500, width: 700, height: 420)
        ],
        portals: [
            .init(
                id: "portal.sableRow",
                label: "SABLE ROW",
                approachPoint: CGPoint(x: 760, y: 480),
                hitArea: CGRect(x: 500, y: 300, width: 520, height: 320),
                destination: .district(.sableRow),
                requiresCityOpen: false,
                lockedInspectLine: ""
            ),
            .init(
                id: "portal.recordsEntrance",
                label: "ANNEX",
                approachPoint: CGPoint(x: 2_280, y: 980),
                hitArea: CGRect(x: 1_960, y: 780, width: 800, height: 600),
                destination: .inspect,
                requiresCityOpen: false,
                lockedInspectLine: "Dual ledgers wait behind polite glass. Exterior only for now."
            )
        ],
        pointsOfInterest: [
            .init(label: "ANNEX", worldPoint: CGPoint(x: 2_400, y: 1_180), colorRGBA: (0.55, 0.48, 0.32, 1)),
            .init(label: "SABLE ROW", worldPoint: CGPoint(x: 760, y: 480), colorRGBA: (0.72, 0.22, 0.18, 1))
        ]
    )
}
