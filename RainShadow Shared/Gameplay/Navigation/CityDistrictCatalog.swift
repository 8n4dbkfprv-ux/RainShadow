import CoreGraphics

/// Act I Harborpoint travel districts on the Baldur's Gate–style 3×3 ward grid.
///
/// District plates must match the Baldur's Gate: EE orthographic camera lock
/// (`ArtSource/Prompts/city_perspective_lock_v03.md`). After regenerating
/// masters, re-derive door/portal approach points on the street side from
/// `nearestWalkablePoint` (unrounded) and flood-fill every spawn — never validate
/// with `route`.
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

    var worldMapIconHoverTextureName: String {
        "\(worldMapIconTextureName)_hover"
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
        /// When set, the scene draws with `SKSpriteNode(texture:size:)` at this
        /// world size instead of `setScale`. Aperture mapping uses
        /// `worldSize / canvas` so the leaf lands on the painted hole.
        let worldSize: CGSize?
        /// Vertical strip width in world units. Near-side houses slice along
        /// `depthSortLot`'s street-facing kerb so Voss walks in front on the road.
        let depthSliceWidth: CGFloat?
        /// `CityDistrictLayout.IsoLot.rawValue` used as the north-kerb sort key.
        let depthSortLot: String?

        init(
            textureName: String,
            groundPoint: CGPoint,
            scale: CGFloat,
            anchorY: CGFloat,
            depthBias: CGFloat,
            worldSize: CGSize? = nil,
            depthSliceWidth: CGFloat? = nil,
            depthSortLot: String? = nil
        ) {
            self.textureName = textureName
            self.groundPoint = groundPoint
            self.scale = scale
            self.anchorY = anchorY
            self.depthBias = depthBias
            self.worldSize = worldSize
            self.depthSliceWidth = depthSliceWidth
            self.depthSortLot = depthSortLot
        }
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

    /// Authored play space in world units. 4096 / standingAdultBodyHeight ≈ 58.3
    /// adults across — a typical Infinity Engine outdoor ARE (32–100). Grown by
    /// adding street, not by shrinking the adult or changing play zoom.
    static let sourceArtSize = CGSize(width: 4_096, height: 2_304)
    static let environmentScale: CGFloat = 1
    static let worldArtSize = CGSize(
        width: sourceArtSize.width * environmentScale,
        height: sourceArtSize.height * environmentScale
    )
    static let worldBounds = CGRect(origin: .zero, size: worldArtSize)
    /// Local reveal, sized so the whole screen is lit at the default zoom.
    ///
    /// This was 0.4 — deliberately inside the viewport, so the fog edge would be
    /// visible. The cost was that only 45% of the screen width was ever lit, and
    /// arriving in a district showed a keyhole of pavement with no building,
    /// lamp or vehicle in frame. With nothing to give it scale the paving read as
    /// oversized, which is what "the streets look too big" turned out to be —
    /// not the module, which measures 0.12 m, nor the plate, which is on the
    /// density floor.
    ///
    /// 1.05 puts the radius at 568 units against a 551.6-unit screen corner at
    /// 100%, so the immediate surroundings are fully lit and the boundary only
    /// appears once the player zooms out — which is how BG:EE reads: you see the
    /// whole screen, and fog covers the parts of the area you have not walked.
    /// Deliberately a fixed world radius rather than one tracking the zoomed
    /// height, so zooming out cannot be used to see through the fog.
    static var fogRevealRadius: CGFloat { cameraVisibleHeight * 1.05 }
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

    /// The painted blocks, as nav obstacles.
    ///
    /// This replaced `WardBlocks` — four axis-aligned rects on a 2×2 grid that
    /// matched nothing on any plate. Voss was blocked standing in open street
    /// and walked straight through painted blocks, and the buildings were
    /// authored to that phantom grid rather than to the art.
    ///
    /// `.tiered` leaves the +0.75 street family at its full painted width and
    /// pulls the −0.75 family onto the kerb, so a district has two street
    /// widths instead of one. Measures ~41 % walkable against Baldur's Gate's
    /// 30–45 %.
    static let wardObstacles: [CGRect] = CityBlockGrid.all
        .flatMap { $0.obstacleBands(.tiered) }

    /// The river Riverside's plate fades to below y = 130.
    static let riverWater = CGRect(x: 0, y: 0, width: 4_096, height: 140)
    /// Wharf Ladder waterfront. Matches the V5 ground fade (`y < 180`); the
    /// rect is the walkable cut, so it sits inside the fade. The quay street
    /// through `(840, 414)` / `(2520, 414)` stays dry.
    static let wharfWater = CGRect(x: 0, y: 0, width: 4_096, height: 160)

    // MARK: - Shared street furniture

    /// Four kerb lamps around a road crossing, on the ±0.75 ground axes.
    ///
    /// Was `sableCrossingLamps`, private to one district while the other five
    /// repeated the same seven hand-typed axis-aligned points — the same ring
    /// in four different districts, most of it standing in the middle of
    /// painted blocks. Lamps belong on kerbs, and the kerbs are on the axes.
    static func crossingLamps(
        at origin: CGPoint,
        scale: CGFloat = CityDistrictLayout.PropDisplayScale.lampHub,
        distance: CGFloat = 80
    ) -> [CityDistrictDefinition.VisualSprite] {
        let slopes: [CGFloat] = [0.75, 0.75, -0.75, -0.75]
        let distances: [CGFloat] = [distance, -distance, distance, -distance]
        return zip(slopes, distances).map { slope, step in
            .init(
                textureName: "city_prop_lamp",
                groundPoint: CityDistrictLayout.StreetCrossing.along(
                    from: origin, slope: slope, distance: step
                ),
                scale: scale,
                anchorY: 0.12,
                depthBias: 1
            )
        }
    }

    /// A prop parked in the carriageway, offset from a crossing along the road
    /// it sits on rather than along a screen axis.
    static func kerbProp(
        _ textureName: String,
        at origin: CGPoint,
        slope: CGFloat,
        distance: CGFloat,
        scale: CGFloat,
        anchorY: CGFloat,
        depthBias: CGFloat = 2
    ) -> CityDistrictDefinition.VisualSprite {
        .init(
            textureName: textureName,
            groundPoint: CityDistrictLayout.StreetCrossing.along(
                from: origin, slope: slope, distance: distance
            ),
            scale: scale,
            anchorY: anchorY,
            depthBias: depthBias
        )
    }

    /// One terrace rank on a block edge.
    ///
    /// `nearLeft`/`farRight` carry the kerb outset because those are the edges
    /// facing the −0.75 street family, which `wardObstacles` pulls in to make
    /// the district's narrow cross streets. Wall line and obstacle line have to
    /// be the same line, or you get pavement you cannot stand on and buildings
    /// you can walk through.
    static func districtRow(
        _ i: Int, _ j: Int,
        _ edge: CityBlockGrid.Edge,
        _ modules: [CityDistrictLayout.FrontageModule]
    ) -> [CityDistrictDefinition.VisualSprite] {
        CityDistrictLayout.frontage(
            on: CityBlockGrid.block(i: i, j: j),
            facing: edge,
            outset: CityBlockGrid.EdgeOutsets.tiered[edge],
            modules
        )
    }

    /// Kerb lamps on every painted crossing, at spoke-district scale.
    ///
    /// Replaced a seven-point axis-aligned ring that four districts each
    /// carried a verbatim copy of, most of whose lamps stood in the middle of
    /// a block.
    static func spokeCrossingLamps() -> [CityDistrictDefinition.VisualSprite] {
        CityBlockGrid.crossings.flatMap {
            crossingLamps(
                at: $0,
                scale: CityDistrictLayout.PropDisplayScale.lampSpoke,
                distance: 190
            )
        }
    }

    // MARK: - Sable Row (center / lower ward)

    private static func sableLotSprite(_ textureName: String) -> CityDistrictDefinition.VisualSprite {
        sableAreaLots.first { $0.textureName == textureName }!
    }

    private static let sableVossDoor = CityDistrictLayout.doorLeaf(
        textureName: "city_door_voss_stoop",
        on: sableLotSprite("city_sable_lot_harborVoss"),
        aperture: .lotSableVossStoop
    )
    private static let sableOfficeApproach = CityDistrictLayout.portalApproach(
        forLeaf: sableVossDoor,
        clearOf: wardObstacles
    )

    /// Occlusion crops from `bake_sable_area_plate.py`. Furniture lives in the
    /// streets plate; these are the punched building pixels, one diamond each.
    private static func sableLot(
        _ name: String,
        ground: CGPoint,
        size: CGSize,
        depthSliceWidth: CGFloat? = nil,
        depthSortLot: CityDistrictLayout.IsoLot? = nil
    ) -> CityDistrictDefinition.VisualSprite {
        .init(
            textureName: name,
            groundPoint: ground,
            scale: 1,
            anchorY: 0,
            depthBias: 0,
            worldSize: size,
            depthSliceWidth: depthSliceWidth,
            depthSortLot: depthSortLot?.rawValue
        )
    }

    private static let sableAreaLots: [CityDistrictDefinition.VisualSprite] = [
        // Feet and sizes from `sable_area_bake.json` after diamond-AABB bake
        // (full-pad frontage 1168 wu). Do not round — nav and door probes pin these.
        sableLot("city_sable_lot_harborWest", ground: CGPoint(x: 840, y: 606), size: CGSize(width: 1_168, height: 1_263)),
        sableLot("city_sable_lot_harborVoss", ground: CGPoint(x: 2_520, y: 606), size: CGSize(width: 1_168, height: 1_263)),
        sableLot("city_sable_lot_upperWest", ground: CGPoint(x: 1_680, y: 1_236), size: CGSize(width: 1_168, height: 1_068)),
        sableLot("city_sable_lot_upperEast", ground: CGPoint(x: 3_360, y: 1_235), size: CGSize(width: 1_168, height: 1_069)),
        sableLot("city_sable_lot_southWest", ground: CGPoint(x: 1_680, y: 0), size: CGSize(width: 1_168, height: 1_239), depthSliceWidth: 64, depthSortLot: .southWest),
        sableLot("city_sable_lot_southEast", ground: CGPoint(x: 3_360, y: 0), size: CGSize(width: 1_168, height: 1_239), depthSliceWidth: 64, depthSortLot: .southEast),
        sableLot("city_sable_lot_skylineWest", ground: CGPoint(x: 840, y: 1_866), size: CGSize(width: 1_168, height: 438)),
        sableLot("city_sable_lot_skylineEast", ground: CGPoint(x: 2_520, y: 1_866), size: CGSize(width: 1_168, height: 438)),
        sableLot("city_sable_lot_edge_1_1", ground: CGPoint(x: 292, y: 0), size: CGSize(width: 584, height: 1_239)),
        sableLot("city_sable_lot_edge_0_0", ground: CGPoint(x: 292, y: 1_236), size: CGSize(width: 584, height: 1_068)),
        sableLot("city_sable_lot_edge_3_-2", ground: CGPoint(x: 3_856, y: 606), size: CGSize(width: 480, height: 1_263)),
        sableLot("city_sable_lot_edge_2_-3", ground: CGPoint(x: 3_856, y: 1_866), size: CGSize(width: 480, height: 438))
    ]

    static let sableRow = CityDistrictDefinition(
        id: .sableRow,
        locationName: "SABLE ROW — LOWER WARD",
        arrivalHint: "SABLE ROW  •  Harbor Street below, Ward Plaza up the cross. Voss's stoop is on the southeast lot.",
        groundTextureName: "city_sable_row_area_streets_v01",
        mapTextureName: "map_city_sable_row_v02",
        actorStart: sableOfficeApproach,
        spawnByArrivalKey: [
            "from.office": sableOfficeApproach,
            "from.north": CityBlockGrid.arrivalPoint(from: .north),
            "from.south": CityBlockGrid.arrivalPoint(from: .south),
            "from.east": CityBlockGrid.arrivalPoint(from: .east),
            "from.west": CityBlockGrid.arrivalPoint(from: .west)
        ],
        visualSprites: sableAreaLots + [
            CityDistrictLayout.doorLeaf(
                textureName: "city_door_tenement",
                on: sableLotSprite("city_sable_lot_harborWest"),
                aperture: .lotSableTenement
            ),
            CityDistrictLayout.doorLeaf(
                textureName: "city_door_shop",
                on: sableLotSprite("city_sable_lot_harborWest"),
                aperture: .lotSableShop
            ),
            CityDistrictLayout.doorLeaf(
                textureName: "city_door_gatehouse",
                on: sableLotSprite("city_sable_lot_harborVoss"),
                aperture: .lotSableGatehouse
            ),
            sableVossDoor,
            CityDistrictLayout.doorLeaf(
                textureName: "city_door_voss_stoop_garage",
                on: sableLotSprite("city_sable_lot_harborVoss"),
                aperture: .lotSableVossGarage,
                scale: CityDistrictLayout.DoorDisplayScale.wide
            ),
            CityDistrictLayout.doorLeaf(
                textureName: "city_door_storefront",
                on: sableLotSprite("city_sable_lot_upperWest"),
                aperture: .lotSableStorefront
            ),
            CityDistrictLayout.doorLeaf(
                textureName: "city_door_rowhouse",
                on: sableLotSprite("city_sable_lot_upperEast"),
                aperture: .lotSableRowhouse
            )
        ],
        obstacles: wardObstacles,
        portals: [
            .init(
                id: "portal.office",
                label: "VOSS APT",
                approachPoint: sableOfficeApproach,
                hitArea: CityDistrictLayout.portalHitArea(forLeaf: sableVossDoor),
                destination: .office,
                requiresCityOpen: false,
                lockedInspectLine: "The office door is locked from this side."
            )
        ],
        pointsOfInterest: [
            .init(label: "VOSS APT", worldPoint: sableOfficeApproach, colorRGBA: (0.72, 0.22, 0.18, 1)),
            .init(label: "WARD PLAZA", worldPoint: CityDistrictLayout.StreetCrossing.midWard, colorRGBA: (0.55, 0.48, 0.32, 1))
        ]
    )

    // MARK: - Wharf Ladder (west)

    /// Dock quarter. Warehouse ranks front The Quay; Lillian's shipping office
    /// is the one detached building, seated on the lot that faces The Ladder
    /// with a forecourt toward the wet — Baldur's Gate marks a landmark by
    /// detaching it, walling it, or giving it a forecourt.
    private static let wharfOfficeBlock = CityBlockGrid.block(i: 2, j: -1)

    private static let wharfShippingOffice = CityDistrictLayout.landmark(
        "city_building_shipping_office",
        on: wharfOfficeBlock,
        scale: CityDistrictLayout.BuildingDisplayScale.shippingOffice,
        anchorY: 0.10,
        offset: CGPoint(x: 80, y: 180)
    )
    private static let wharfWarehouse = CityDistrictDefinition.VisualSprite(
        textureName: "city_building_warehouse",
        groundPoint: CityBlockGrid.block(i: 1, j: 0).point(on: .nearRight, at: 0.58),
        scale: CityDistrictLayout.BuildingDisplayScale.warehouse, anchorY: 0.10, depthBias: 0
    )
    private static let wharfBoarding = CityDistrictDefinition.VisualSprite(
        textureName: "city_building_boarding",
        groundPoint: CityBlockGrid.block(i: 1, j: -1).point(on: .nearRight, at: 0.58),
        scale: CityDistrictLayout.BuildingDisplayScale.boarding, anchorY: 0.12, depthBias: 0
    )
    private static let wharfDockShed = CityDistrictDefinition.VisualSprite(
        textureName: "city_building_dock_shed",
        groundPoint: CityBlockGrid.block(i: 2, j: 0).point(on: .nearLeft, at: 0.32, outset: CityBlockGrid.pavementBand),
        scale: CityDistrictLayout.BuildingDisplayScale.dockShed, anchorY: 0.16, depthBias: 0
    )

    private static let wharfShippingDoor = CityDistrictLayout.doorLeaf(
        textureName: "city_door_shipping_office",
        on: wharfShippingOffice,
        aperture: .buildingShippingOffice
    )

    /// Quay ranks, Bond Street boarding, far-rank yard fill.
    ///
    /// Near-left rows carry the −0.75 family's kerb outset so the wall line
    /// and the obstacle line stay the same line. The office lot leaves its
    /// near-right edge open — that gap is the forecourt.
    private static let wharfFrontage: [CityDistrictDefinition.VisualSprite] =
        // The Quay — south wall (camera-near, feet in the water fade).
        districtRow(1, 1, .nearRight, [.warehouse(at: 0.40), .dockShed(at: 0.82)])
        + districtRow(2, 0, .nearLeft, [.warehouse(at: 0.70)])
        + districtRow(2, 0, .nearRight, [.warehouse(at: 0.36), .dockShed(at: 0.78)])
        + districtRow(3, -1, .nearLeft, [.warehouse(at: 0.34), .dockShed(at: 0.74)])
        + districtRow(3, -1, .nearRight, [.dockShed(at: 0.40), .warehouse(at: 0.82)])
        // The Quay — north wall.
        + districtRow(1, 0, .nearLeft, [.warehouse(at: 0.30), .dockShed(at: 0.68)])
        + districtRow(1, 0, .nearRight, [.dockShed(at: 0.28)])
        + districtRow(2, -1, .nearLeft, [.warehouse(at: 0.26), .dockShed(at: 0.70)])
        // (2, −1) nearRight left open for the shipping-office forecourt.
        + districtRow(3, -2, .nearLeft, [.warehouse(at: 0.38), .boarding(at: 0.78)])
        // Bond Street / The Ladder inland.
        + districtRow(0, 0, .nearRight, [.boarding(at: 0.46), .tenement(at: 0.86)])
        + districtRow(1, -1, .nearLeft, [.warehouse(at: 0.30), .boarding(at: 0.70)])
        + districtRow(1, -1, .nearRight, [.dockShed(at: 0.26), .rowCorner(at: 0.88)])
        + districtRow(2, -2, .nearLeft, [.warehouse(at: 0.40), .dockShed(at: 0.80)])
        + districtRow(2, -2, .nearRight, [.boarding(at: 0.36), .warehouse(at: 0.88)])
        // North Yard.
        + districtRow(0, -1, .nearRight, [.warehouse(at: 0.50), .dockShed(at: 0.90)])
        + districtRow(1, -2, .nearLeft, [.dockShed(at: 0.38), .boarding(at: 0.78)])
        + districtRow(1, -2, .nearRight, [.warehouse(at: 0.44), .tenement(at: 0.86)])
        + districtRow(2, -3, .nearLeft, [.warehouse(at: 0.44), .dockShed(at: 0.84)])
        // Far ranks — the second storey line that stops a diamond reading as a yard.
        + districtRow(1, 1, .farRight, [.boarding(at: 0.55)])
        + districtRow(2, 0, .farLeft, [.warehouse(at: 0.45)])
        + districtRow(2, 0, .farRight, [.boarding(at: 0.55)])
        + districtRow(3, -1, .farLeft, [.warehouse(at: 0.50)])
        + districtRow(3, -1, .farRight, [.dockShed(at: 0.58)])
        + districtRow(1, 0, .farLeft, [.boarding(at: 0.48)])
        + districtRow(1, 0, .farRight, [.warehouse(at: 0.58)])
        + districtRow(2, -1, .farLeft, [.tenement(at: 0.44)])
        + districtRow(2, -1, .farRight, [.warehouse(at: 0.62)])
        + districtRow(3, -2, .farRight, [.warehouse(at: 0.55)])
        + districtRow(0, 0, .farRight, [.warehouse(at: 0.60)])
        + districtRow(1, -1, .farLeft, [.tenement(at: 0.46)])
        + districtRow(1, -1, .farRight, [.warehouse(at: 0.58)])
        + districtRow(2, -2, .farLeft, [.boarding(at: 0.50)])
        + districtRow(2, -2, .farRight, [.warehouse(at: 0.62)])
        + districtRow(0, -1, .farRight, [.boarding(at: 0.55)])
        + districtRow(1, -2, .farLeft, [.warehouse(at: 0.48)])
        + districtRow(1, -2, .farRight, [.dockShed(at: 0.58)])

    static let wharfLadder = CityDistrictDefinition(
        id: .wharfLadder,
        locationName: "WHARF LADDER — SHIPPING",
        arrivalHint: "WHARF LADDER  •  Lillian's shipping office faces the wet pier.",
        groundTextureName: "city_wharf_ladder_ground_v02",
        mapTextureName: "map_city_wharf_ladder_v02",
        actorStart: CityBlockGrid.arrivalPoint(from: .east),
        spawnByArrivalKey: [
            "from.east": CityBlockGrid.arrivalPoint(from: .east),
            "from.south": CityBlockGrid.arrivalPoint(from: .south),
            "from.north": CityBlockGrid.arrivalPoint(from: .north),
            "from.west": CityBlockGrid.arrivalPoint(from: .west)
        ],
        visualSprites: wharfFrontage + [
            wharfShippingOffice,
            wharfWarehouse,
            wharfBoarding,
            wharfDockShed,
            wharfShippingDoor,
            CityDistrictLayout.doorLeaf(
                textureName: "city_door_warehouse",
                on: wharfWarehouse,
                aperture: .buildingWarehouse,
                scale: CityDistrictLayout.DoorDisplayScale.wide
            ),
            CityDistrictLayout.doorLeaf(
                textureName: "city_door_boarding",
                on: wharfBoarding,
                aperture: .buildingBoarding
            ),
            CityDistrictLayout.doorLeaf(
                textureName: "city_door_dock_shed",
                on: wharfDockShed,
                aperture: .buildingDockShed
            )
        ]
        + spokeCrossingLamps()
        + [
            // Mid-quay lamps, on the carriageway, not in a warehouse.
            .init(
                textureName: "city_prop_lamp",
                groundPoint: CityDistrictLayout.StreetCrossing.along(
                    from: CityDistrictLayout.StreetCrossing.harborWest, slope: -0.75, distance: 180
                ),
                scale: CityDistrictLayout.PropDisplayScale.lampSpoke, anchorY: 0.12, depthBias: 1
            ),
            .init(
                textureName: "city_prop_lamp",
                groundPoint: CityDistrictLayout.StreetCrossing.along(
                    from: CityDistrictLayout.StreetCrossing.harborVoss, slope: -0.75, distance: -180
                ),
                scale: CityDistrictLayout.PropDisplayScale.lampSpoke, anchorY: 0.12, depthBias: 1
            ),
            // Cargo on The Quay kerb.
            kerbProp("city_prop_crates_mail", at: CityDistrictLayout.StreetCrossing.harborWest, slope: 0.75, distance: 150, scale: CityDistrictLayout.PropDisplayScale.cratesSpoke, anchorY: 0.24),
            kerbProp("city_prop_crates_mail", at: CityDistrictLayout.StreetCrossing.harborVoss, slope: 0.75, distance: 160, scale: CityDistrictLayout.PropDisplayScale.cratesSpoke, anchorY: 0.24),
            kerbProp("city_prop_crates_mail", at: CityDistrictLayout.StreetCrossing.harborVoss, slope: -0.75, distance: 140, scale: CityDistrictLayout.PropDisplayScale.cratesSpoke, anchorY: 0.24),
            // Two cars inland — docks are cargo, not a car park.
            kerbProp("city_prop_car_black", at: CityDistrictLayout.StreetCrossing.midWard, slope: 0.75, distance: 190, scale: CityDistrictLayout.PropDisplayScale.carSpoke, anchorY: 0.18),
            kerbProp("city_prop_car_olive", at: CityDistrictLayout.StreetCrossing.midEast, slope: -0.75, distance: -180, scale: CityDistrictLayout.PropDisplayScale.carSpoke, anchorY: 0.18),
            kerbProp("city_prop_gate", at: CityDistrictLayout.StreetCrossing.harborVoss, slope: 0.75, distance: 80, scale: CityDistrictLayout.PropDisplayScale.gate, anchorY: 0.22)
        ],
        obstacles: wardObstacles + [wharfWater],
        portals: [
            .init(
                id: "portal.shippingOffice",
                label: "SHIPPING",
                approachPoint: CityDistrictLayout.portalApproach(forLeaf: wharfShippingDoor, clearOf: wardObstacles + [wharfWater]),
                hitArea: CityDistrictLayout.portalHitArea(forLeaf: wharfShippingDoor),
                destination: .inspect,
                requiresCityOpen: false,
                lockedInspectLine: "Lillian's shipping office. Ledgers and a late errand uptown — exterior only for now."
            )
        ],
        pointsOfInterest: [
            .init(label: "SHIPPING", worldPoint: wharfShippingOffice.groundPoint, colorRGBA: (0.72, 0.22, 0.18, 1))
        ]
    )


    // MARK: - Riverside (southwest)

    /// Embankment quarter. The river runs along the camera-near edge, so the
    /// bottom row of blocks is a waterfront: abutments and rail lamps face the
    /// water, and the old iron stairs stand detached on the south-east corner
    /// where the coat was staged. Everything behind it is ordinary terrace.
    private static let riversideStairsBlock = CityBlockGrid.block(i: 3, j: -1)

    private static let riversideIronStairs = CityDistrictDefinition.VisualSprite(
        textureName: "city_building_iron_stairs",
        // Well along the embankment rather than on the block's near tip: that
        // tip sits under the painted river, and a landmark whose front is
        // water has nowhere to walk up to.
        groundPoint: riversideStairsBlock.point(on: .nearLeft, at: 0.72, outset: CityBlockGrid.pavementBand),
        scale: CityDistrictLayout.BuildingDisplayScale.ironStairs, anchorY: 0.08, depthBias: 0
    )
    private static let riversideRiverWatch = CityDistrictDefinition.VisualSprite(
        textureName: "city_building_river_watch",
        groundPoint: CityBlockGrid.block(i: 1, j: 0).point(on: .nearRight, at: 0.56),
        scale: CityDistrictLayout.BuildingDisplayScale.riverWatch, anchorY: 0.14, depthBias: 0
    )
    private static let riversideStairsDoor = CityDistrictLayout.doorLeaf(
        textureName: "city_door_iron_stairs",
        on: riversideIronStairs,
        aperture: .buildingIronStairs
    )

    private static let riversideFrontage: [CityDistrictDefinition.VisualSprite] = {
        return districtRow(1, 1, .nearRight, [.abutment(at: 0.44), .railLamp(at: 0.88)])
            + districtRow(2, 0, .nearLeft, [.abutment(at: 0.36), .riverWatch(at: 0.78)])
            + districtRow(2, 0, .nearRight, [.railLamp(at: 0.32), .storefront(at: 0.66), .abutment(at: 0.96)])
            + districtRow(3, -1, .nearLeft, [.abutment(at: 0.36)])
            + districtRow(3, -1, .nearRight, [.abutment(at: 0.40), .riverWatch(at: 0.84)])
            + districtRow(1, 0, .nearLeft, [.rowhouse(at: 0.32), .rowCorner(at: 0.74)])
            + districtRow(1, 0, .nearRight, [.tenement(at: 0.26), .storefront(at: 0.92)])
            + districtRow(2, -1, .nearLeft, [.riverWatch(at: 0.30), .rowhouse(at: 0.68), .tenement(at: 0.96)])
            + districtRow(2, -1, .nearRight, [.storefront(at: 0.30), .riverWatch(at: 0.92)])
            + districtRow(3, -2, .nearLeft, [.rowhouse(at: 0.38), .tenement(at: 0.78)])
            + districtRow(0, 0, .nearRight, [.tenement(at: 0.50), .rowhouse(at: 0.90)])
            + districtRow(1, -1, .nearLeft, [.storefront(at: 0.32), .riverWatch(at: 0.72)])
            + districtRow(1, -1, .nearRight, [.rowhouse(at: 0.28), .rowCorner(at: 0.62), .tenement(at: 0.94)])
            + districtRow(2, -2, .nearLeft, [.tenement(at: 0.42), .storefront(at: 0.82)])
            + districtRow(2, -2, .nearRight, [.riverWatch(at: 0.44), .rowhouse(at: 0.88)])
            + districtRow(0, -1, .nearRight, [.rowhouse(at: 0.52), .tenement(at: 0.92)])
            + districtRow(1, -2, .nearLeft, [.storefront(at: 0.40), .rowhouse(at: 0.80)])
            + districtRow(1, -2, .nearRight, [.tenement(at: 0.46), .riverWatch(at: 0.88)])
            + districtRow(2, -3, .nearLeft, [.rowhouse(at: 0.44), .storefront(at: 0.84)])
            + districtRow(1, 1, .farRight, [.rowhouse(at: 0.55)])
            + districtRow(2, 0, .farLeft, [.tenement(at: 0.45)])
            + districtRow(2, 0, .farRight, [.storefront(at: 0.55)])
            + districtRow(3, -1, .farLeft, [.rowhouse(at: 0.50)])
            + districtRow(1, 0, .farLeft, [.tenement(at: 0.48)])
            + districtRow(1, 0, .farRight, [.rowhouse(at: 0.58)])
            + districtRow(2, -1, .farLeft, [.storefront(at: 0.44)])
            + districtRow(2, -1, .farRight, [.tenement(at: 0.60)])
            + districtRow(1, -1, .farLeft, [.rowhouse(at: 0.46)])
            + districtRow(1, -1, .farRight, [.storefront(at: 0.58)])
            + districtRow(2, -2, .farLeft, [.tenement(at: 0.50)])
    }()

    static let riverside = CityDistrictDefinition(
        id: .riverside,
        locationName: "RIVERSIDE — IRON STAIRS",
        arrivalHint: "RIVERSIDE  •  The old iron stairs drop to the coat stones.",
        groundTextureName: "city_riverside_ground_v02",
        mapTextureName: "map_city_riverside_v02",
        actorStart: CityBlockGrid.arrivalPoint(from: .east),
        spawnByArrivalKey: [
            "from.east": CityBlockGrid.arrivalPoint(from: .east),
            "from.north": CityBlockGrid.arrivalPoint(from: .north),
            "from.south": CityBlockGrid.arrivalPoint(from: .south),
            "from.west": CityBlockGrid.arrivalPoint(from: .west)
        ],
        visualSprites: riversideFrontage + [
            riversideIronStairs,
            riversideRiverWatch,
            riversideStairsDoor,
            CityDistrictLayout.doorLeaf(
                textureName: "city_door_river_watch",
                on: riversideRiverWatch,
                aperture: .buildingRiverWatch
            )
        ]
        + spokeCrossingLamps()
        + [
            kerbProp("city_prop_crates_mail", at: CityDistrictLayout.StreetCrossing.harborWest, slope: -0.75, distance: -150, scale: CityDistrictLayout.PropDisplayScale.cratesSpoke, anchorY: 0.24),
            kerbProp("city_prop_crates_mail", at: CityDistrictLayout.StreetCrossing.upperWest, slope: 0.75, distance: 150, scale: CityDistrictLayout.PropDisplayScale.cratesSpoke, anchorY: 0.24),
            kerbProp("city_prop_car_black", at: CityDistrictLayout.StreetCrossing.midWard, slope: 0.75, distance: 190, scale: CityDistrictLayout.PropDisplayScale.carSpoke, anchorY: 0.18),
            kerbProp("city_prop_car_maroon", at: CityDistrictLayout.StreetCrossing.upperEast, slope: -0.75, distance: -190, scale: CityDistrictLayout.PropDisplayScale.carSpoke, anchorY: 0.18),
            kerbProp("city_prop_bench", at: CityDistrictLayout.StreetCrossing.midEast, slope: 0.75, distance: 150, scale: CityDistrictLayout.PropDisplayScale.benchSpoke, anchorY: 0.15)
        ],
        obstacles: wardObstacles + [riverWater],
        portals: [
            .init(
                id: "portal.ironStairs",
                label: "STAIRS",
                approachPoint: CityDistrictLayout.portalApproach(forLeaf: riversideStairsDoor, clearOf: wardObstacles + [riverWater]),
                hitArea: CityDistrictLayout.portalHitArea(forLeaf: riversideStairsDoor),
                destination: .inspect,
                requiresCityOpen: false,
                lockedInspectLine: "Wet iron and staged stones. The coat is already in police custody."
            )
        ],
        pointsOfInterest: [
            .init(label: "STAIRS", worldPoint: riversideIronStairs.groundPoint, colorRGBA: (0.32, 0.51, 0.66, 1))
        ]
    )

    // MARK: - Harborpoint PD (south)

    /// Precinct. The station is the landmark and it is *walled*: `pd_plaza_wall`
    /// closes the low frontage of its block, and the station stands back behind
    /// a forecourt with the squad cars ranked in the carriageway outside. A
    /// wall is one of the three cues Baldur's Gate allows a landmark, and it is
    /// the one a police station should get.
    private static let pdBlock = CityBlockGrid.block(i: 2, j: -1)

    private static let pdStation = CityDistrictDefinition.VisualSprite(
        textureName: "city_building_pd_station",
        groundPoint: pdBlock.point(on: .nearRight, at: 0.60),
        scale: CityDistrictLayout.BuildingDisplayScale.pdStation, anchorY: 0.10, depthBias: 0
    )
    private static let pdAnnex = CityDistrictDefinition.VisualSprite(
        textureName: "city_building_pd_annex",
        groundPoint: CityBlockGrid.block(i: 2, j: -2).point(on: .nearLeft, at: 0.46, outset: CityBlockGrid.pavementBand),
        scale: CityDistrictLayout.BuildingDisplayScale.pdAnnex, anchorY: 0.12, depthBias: 0
    )
    private static let pdAlley = CityDistrictDefinition.VisualSprite(
        textureName: "city_building_pd_alley",
        groundPoint: CityBlockGrid.block(i: 1, j: 0).point(on: .nearLeft, at: 0.52, outset: CityBlockGrid.pavementBand),
        scale: CityDistrictLayout.BuildingDisplayScale.pdAlley, anchorY: 0.14, depthBias: 0
    )
    private static let pdStationDoor = CityDistrictLayout.doorLeaf(
        textureName: "city_door_pd_station",
        on: pdStation,
        aperture: .buildingPDStation
    )

    private static let pdFrontage: [CityDistrictDefinition.VisualSprite] = {
        return districtRow(1, 1, .nearRight, [.tenement(at: 0.46), .pdAlley(at: 0.88)])
            + districtRow(2, 0, .nearLeft, [.storefront(at: 0.34), .tenement(at: 0.76)])
            + districtRow(2, 0, .nearRight, [.pdAlley(at: 0.30), .rowhouse(at: 0.64), .storefront(at: 0.94)])
            + districtRow(3, -1, .nearLeft, [.tenement(at: 0.34), .rowCorner(at: 0.74)])
            + districtRow(3, -1, .nearRight, [.rowhouse(at: 0.42), .pdAlley(at: 0.84)])
            + districtRow(1, 0, .nearLeft, [.rowhouse(at: 0.30), .storefront(at: 0.76)])
            + districtRow(1, 0, .nearRight, [.tenement(at: 0.26), .pdAnnex(at: 0.92)])
            + districtRow(2, -1, .nearLeft, [.pdAnnex(at: 0.30), .tenement(at: 0.70), .rowhouse(at: 0.96)])
            // The wall, low on the station's own frontage — the forecourt is
            // the gap between it and the station set back at t = 0.60.
            + districtRow(2, -1, .nearRight, [.pdPlazaWall(at: 0.18)])
            + districtRow(3, -2, .nearLeft, [.storefront(at: 0.38), .tenement(at: 0.78)])
            + districtRow(0, 0, .nearRight, [.rowhouse(at: 0.50), .tenement(at: 0.90)])
            + districtRow(1, -1, .nearLeft, [.tenement(at: 0.32), .pdAlley(at: 0.72)])
            + districtRow(1, -1, .nearRight, [.storefront(at: 0.28), .rowCorner(at: 0.62), .rowhouse(at: 0.94)])
            + districtRow(2, -2, .nearLeft, [.rowhouse(at: 0.80)])
            + districtRow(2, -2, .nearRight, [.tenement(at: 0.44), .storefront(at: 0.88)])
            + districtRow(0, -1, .nearRight, [.storefront(at: 0.52), .rowhouse(at: 0.92)])
            + districtRow(1, -2, .nearLeft, [.tenement(at: 0.40), .storefront(at: 0.80)])
            + districtRow(1, -2, .nearRight, [.rowhouse(at: 0.46), .tenement(at: 0.88)])
            + districtRow(2, -3, .nearLeft, [.storefront(at: 0.44), .rowhouse(at: 0.84)])
            + districtRow(1, 1, .farRight, [.rowhouse(at: 0.55)])
            + districtRow(2, 0, .farLeft, [.tenement(at: 0.45)])
            + districtRow(2, 0, .farRight, [.storefront(at: 0.55)])
            + districtRow(3, -1, .farLeft, [.rowhouse(at: 0.50)])
            + districtRow(1, 0, .farLeft, [.storefront(at: 0.48)])
            + districtRow(1, 0, .farRight, [.tenement(at: 0.58)])
            + districtRow(2, -1, .farLeft, [.rowhouse(at: 0.44)])
            + districtRow(2, -1, .farRight, [.storefront(at: 0.60)])
            + districtRow(1, -1, .farLeft, [.tenement(at: 0.46)])
            + districtRow(1, -1, .farRight, [.rowhouse(at: 0.58)])
            + districtRow(2, -2, .farLeft, [.storefront(at: 0.50)])
    }()

    static let harborpointPD = CityDistrictDefinition(
        id: .harborpointPD,
        locationName: "HARBORPOINT PD",
        arrivalHint: "HARBORPOINT PD  •  Soft files cool faster than the rain.",
        groundTextureName: "city_harborpoint_pd_ground_v02",
        mapTextureName: "map_city_harborpoint_pd_v02",
        actorStart: CityBlockGrid.arrivalPoint(from: .north),
        spawnByArrivalKey: [
            "from.north": CityBlockGrid.arrivalPoint(from: .north),
            "from.west": CityBlockGrid.arrivalPoint(from: .west),
            "from.east": CityBlockGrid.arrivalPoint(from: .east),
            "from.south": CityBlockGrid.arrivalPoint(from: .south)
        ],
        visualSprites: pdFrontage + [
            pdStation,
            pdAnnex,
            pdAlley,
            pdStationDoor,
            CityDistrictLayout.doorLeaf(textureName: "city_door_pd_annex", on: pdAnnex, aperture: .buildingPDAnnex),
            CityDistrictLayout.doorLeaf(
                textureName: "city_door_pd_alley",
                on: pdAlley,
                aperture: .buildingPDAlley,
                scale: CityDistrictLayout.DoorDisplayScale.wide
            )
        ]
        + spokeCrossingLamps()
        + [
            // Squad cars ranked along the kerb outside the station wall.
            kerbProp("city_prop_car_black", at: CityDistrictLayout.StreetCrossing.midWard, slope: 0.75, distance: 170, scale: CityDistrictLayout.PropDisplayScale.carSpoke, anchorY: 0.18),
            kerbProp("city_prop_car_black", at: CityDistrictLayout.StreetCrossing.midWard, slope: 0.75, distance: 320, scale: CityDistrictLayout.PropDisplayScale.carSpoke, anchorY: 0.18),
            kerbProp("city_prop_car_olive", at: CityDistrictLayout.StreetCrossing.midEast, slope: -0.75, distance: -180, scale: CityDistrictLayout.PropDisplayScale.carSpoke, anchorY: 0.18),
            kerbProp("city_prop_crates_mail", at: CityDistrictLayout.StreetCrossing.harborVoss, slope: 0.75, distance: 160, scale: CityDistrictLayout.PropDisplayScale.cratesSpoke, anchorY: 0.24),
            kerbProp("city_prop_bench", at: CityDistrictLayout.StreetCrossing.upperWest, slope: -0.75, distance: -150, scale: CityDistrictLayout.PropDisplayScale.benchSpoke, anchorY: 0.15)
        ],
        obstacles: wardObstacles,
        portals: [
            .init(
                id: "portal.pdEntrance",
                label: "STATION",
                approachPoint: CityDistrictLayout.portalApproach(forLeaf: pdStationDoor, clearOf: wardObstacles),
                hitArea: CityDistrictLayout.portalHitArea(forLeaf: pdStationDoor),
                destination: .inspect,
                requiresCityOpen: false,
                lockedInspectLine: "The desk sergeant keeps soft conclusions behind glass. Exterior only for now."
            )
        ],
        pointsOfInterest: [
            .init(label: "STATION", worldPoint: pdStation.groundPoint, colorRGBA: (0.79, 0.55, 0.26, 1))
        ]
    )

    // MARK: - Lila Street (east)

    /// The densest ward: three modules to an edge and no gap anywhere, so the
    /// streets read as canyons. Lila's rooms are deliberately *not* marked out
    /// — attached, mid-terrace, indistinguishable from its neighbours except
    /// for the paired doors. That is the point of the place.
    private static let lilaBlock = CityBlockGrid.block(i: 2, j: -1)

    private static let lilaRooms = CityDistrictDefinition.VisualSprite(
        textureName: "city_building_lila_rooms",
        groundPoint: lilaBlock.point(on: .nearRight, at: 0.50),
        scale: CityDistrictLayout.BuildingDisplayScale.lilaRooms, anchorY: 0.10, depthBias: 0
    )
    private static let lilaNeighbor = CityDistrictDefinition.VisualSprite(
        textureName: "city_building_lila_neighbor",
        groundPoint: CityBlockGrid.block(i: 1, j: 0).point(on: .nearRight, at: 0.54),
        scale: CityDistrictLayout.BuildingDisplayScale.lilaNeighbor, anchorY: 0.12, depthBias: 0
    )
    private static let lilaOpposite = CityDistrictDefinition.VisualSprite(
        textureName: "city_building_lila_opposite",
        groundPoint: CityBlockGrid.block(i: 2, j: -2).point(on: .nearLeft, at: 0.48, outset: CityBlockGrid.pavementBand),
        scale: CityDistrictLayout.BuildingDisplayScale.lilaOpposite, anchorY: 0.12, depthBias: 0
    )
    private static let lilaAlcove = CityDistrictDefinition.VisualSprite(
        textureName: "city_building_lila_alcove",
        groundPoint: CityBlockGrid.block(i: 2, j: 0).point(on: .nearLeft, at: 0.44, outset: CityBlockGrid.pavementBand),
        scale: CityDistrictLayout.BuildingDisplayScale.lilaAlcove, anchorY: 0.16, depthBias: 1
    )
    private static let lilaRoomsDoor = CityDistrictLayout.doorLeaf(
        textureName: "city_door_lila_rooms",
        on: lilaRooms,
        aperture: .buildingLilaRooms
    )

    private static let lilaFrontage: [CityDistrictDefinition.VisualSprite] = {
        return districtRow(1, 1, .nearRight, [.tenement(at: 0.34), .lilaNeighbor(at: 0.68), .rowhouse(at: 0.96)])
            + districtRow(2, 0, .nearLeft, [.rowhouse(at: 0.28), .storefront(at: 0.62), .tenement(at: 0.92)])
            + districtRow(2, 0, .nearRight, [.lilaOpposite(at: 0.26), .tenement(at: 0.58), .storefront(at: 0.90)])
            + districtRow(3, -1, .nearLeft, [.storefront(at: 0.30), .rowCorner(at: 0.64), .lilaNeighbor(at: 0.94)])
            + districtRow(3, -1, .nearRight, [.tenement(at: 0.36), .rowhouse(at: 0.72)])
            + districtRow(1, 0, .nearLeft, [.lilaOpposite(at: 0.26), .rowhouse(at: 0.60), .tenement(at: 0.92)])
            + districtRow(1, 0, .nearRight, [.storefront(at: 0.22), .lilaNeighbor(at: 0.88)])
            + districtRow(2, -1, .nearLeft, [.tenement(at: 0.26), .lilaOpposite(at: 0.58), .rowhouse(at: 0.90)])
            + districtRow(2, -1, .nearRight, [.storefront(at: 0.22), .tenement(at: 0.86)])
            + districtRow(3, -2, .nearLeft, [.rowhouse(at: 0.34), .storefront(at: 0.72)])
            + districtRow(0, 0, .nearRight, [.tenement(at: 0.46), .lilaOpposite(at: 0.86)])
            + districtRow(1, -1, .nearLeft, [.storefront(at: 0.28), .tenement(at: 0.62), .lilaNeighbor(at: 0.94)])
            + districtRow(1, -1, .nearRight, [.rowhouse(at: 0.24), .rowCorner(at: 0.58), .tenement(at: 0.92)])
            + districtRow(2, -2, .nearLeft, [.tenement(at: 0.78)])
            + districtRow(2, -2, .nearRight, [.storefront(at: 0.34), .rowhouse(at: 0.70), .tenement(at: 0.96)])
            + districtRow(0, -1, .nearRight, [.rowhouse(at: 0.48), .storefront(at: 0.88)])
            + districtRow(1, -2, .nearLeft, [.tenement(at: 0.36), .rowhouse(at: 0.76)])
            + districtRow(1, -2, .nearRight, [.storefront(at: 0.42), .lilaOpposite(at: 0.84)])
            + districtRow(2, -3, .nearLeft, [.tenement(at: 0.42), .rowhouse(at: 0.82)])
            + districtRow(1, 1, .farRight, [.rowhouse(at: 0.55)])
            + districtRow(2, 0, .farLeft, [.tenement(at: 0.45)])
            + districtRow(2, 0, .farRight, [.storefront(at: 0.55)])
            + districtRow(3, -1, .farLeft, [.rowhouse(at: 0.50)])
            + districtRow(1, 0, .farLeft, [.tenement(at: 0.48)])
            + districtRow(1, 0, .farRight, [.rowhouse(at: 0.58)])
            + districtRow(2, -1, .farLeft, [.storefront(at: 0.44)])
            + districtRow(2, -1, .farRight, [.tenement(at: 0.60)])
            + districtRow(1, -1, .farLeft, [.rowhouse(at: 0.46)])
            + districtRow(1, -1, .farRight, [.storefront(at: 0.58)])
            + districtRow(2, -2, .farLeft, [.tenement(at: 0.50)])
    }()

    static let lilaStreet = CityDistrictDefinition(
        id: .lilaStreet,
        locationName: "LILA'S STREET",
        arrivalHint: "LILA'S STREET  •  Doorway posts remember the Gray Man.",
        groundTextureName: "city_lila_street_ground_v02",
        mapTextureName: "map_city_lila_street_v02",
        actorStart: CityBlockGrid.arrivalPoint(from: .west),
        spawnByArrivalKey: [
            "from.west": CityBlockGrid.arrivalPoint(from: .west),
            "from.north": CityBlockGrid.arrivalPoint(from: .north),
            "from.south": CityBlockGrid.arrivalPoint(from: .south),
            "from.east": CityBlockGrid.arrivalPoint(from: .east)
        ],
        visualSprites: lilaFrontage + [
            lilaRooms,
            lilaNeighbor,
            lilaOpposite,
            lilaAlcove,
            lilaRoomsDoor,
            CityDistrictLayout.doorLeaf(
                textureName: "city_door_lila_rooms_b",
                on: lilaRooms,
                aperture: .buildingLilaRoomsB
            ),
            CityDistrictLayout.doorLeaf(
                textureName: "city_door_lila_neighbor",
                on: lilaNeighbor,
                aperture: .buildingLilaNeighbor
            ),
            CityDistrictLayout.doorLeaf(
                textureName: "city_door_lila_opposite",
                on: lilaOpposite,
                aperture: .buildingLilaOpposite
            ),
            CityDistrictLayout.doorLeaf(
                textureName: "city_door_lila_alcove",
                on: lilaAlcove,
                aperture: .buildingLilaAlcove
            )
        ]
        + spokeCrossingLamps()
        + [
            kerbProp("city_prop_bench", at: CityDistrictLayout.StreetCrossing.midWard, slope: -0.75, distance: -160, scale: CityDistrictLayout.PropDisplayScale.benchSpoke, anchorY: 0.15),
            kerbProp("city_prop_bench", at: CityDistrictLayout.StreetCrossing.upperEast, slope: 0.75, distance: 160, scale: CityDistrictLayout.PropDisplayScale.benchSpoke, anchorY: 0.15),
            kerbProp("city_prop_car_olive", at: CityDistrictLayout.StreetCrossing.harborVoss, slope: 0.75, distance: 180, scale: CityDistrictLayout.PropDisplayScale.carSpoke, anchorY: 0.18),
            kerbProp("city_prop_car_maroon", at: CityDistrictLayout.StreetCrossing.midEast, slope: -0.75, distance: -180, scale: CityDistrictLayout.PropDisplayScale.carSpoke, anchorY: 0.18),
            kerbProp("city_prop_kiosk", at: CityDistrictLayout.StreetCrossing.harborWest, slope: 0.75, distance: 150, scale: CityDistrictLayout.PropDisplayScale.kiosk, anchorY: 0.20)
        ],
        obstacles: wardObstacles,
        portals: [
            .init(
                id: "portal.lilaRooms",
                label: "ROOMS",
                approachPoint: CityDistrictLayout.portalApproach(forLeaf: lilaRoomsDoor, clearOf: wardObstacles),
                hitArea: CityDistrictLayout.portalHitArea(forLeaf: lilaRoomsDoor),
                destination: .inspect,
                requiresCityOpen: false,
                lockedInspectLine: "Lila's rooms stay private. Watch the doorway posts instead."
            )
        ],
        pointsOfInterest: [
            .init(label: "ROOMS", worldPoint: lilaRooms.groundPoint, colorRGBA: (0.58, 0.20, 0.48, 1))
        ]
    )

    // MARK: - Civic Records (north)

    /// Formal quarter. The colonnade and its plaza take the camera-far corner
    /// block with an open forecourt in front — the one place in the district
    /// with room to stand back and look at a building — and the statue stands
    /// on that forecourt rather than on a street crossing. Everything else is
    /// disciplined terrace.
    private static let recordsCivicBlock = CityBlockGrid.block(i: 0, j: -1)

    private static let recordsAnnex = CityDistrictDefinition.VisualSprite(
        textureName: "city_building_records_annex",
        groundPoint: CityBlockGrid.block(i: 2, j: -1).point(on: .nearRight, at: 0.52),
        scale: CityDistrictLayout.BuildingDisplayScale.recordsAnnex, anchorY: 0.10, depthBias: 0
    )
    private static let recordsWing = CityDistrictDefinition.VisualSprite(
        textureName: "city_building_records_wing",
        groundPoint: CityBlockGrid.block(i: 1, j: 0).point(on: .nearLeft, at: 0.50, outset: CityBlockGrid.pavementBand),
        scale: CityDistrictLayout.BuildingDisplayScale.recordsWing, anchorY: 0.12, depthBias: 0
    )
    private static let recordsColonnade = CityDistrictDefinition.VisualSprite(
        textureName: "city_building_records_colonnade",
        groundPoint: recordsCivicBlock.point(on: .nearRight, at: 0.62),
        scale: CityDistrictLayout.BuildingDisplayScale.recordsColonnade, anchorY: 0.12, depthBias: 0
    )
    private static let recordsAnnexDoor = CityDistrictLayout.doorLeaf(
        textureName: "city_door_records_annex",
        on: recordsAnnex,
        aperture: .buildingRecordsAnnex
    )

    private static let recordsFrontage: [CityDistrictDefinition.VisualSprite] = {
        return districtRow(1, 1, .nearRight, [.storefront(at: 0.46), .recordsWing(at: 0.88)])
            + districtRow(2, 0, .nearLeft, [.recordsWing(at: 0.34), .tenement(at: 0.76)])
            + districtRow(2, 0, .nearRight, [.rowhouse(at: 0.30), .recordsWing(at: 0.64), .storefront(at: 0.94)])
            + districtRow(3, -1, .nearLeft, [.tenement(at: 0.34), .rowCorner(at: 0.76)])
            + districtRow(3, -1, .nearRight, [.recordsWing(at: 0.42), .rowhouse(at: 0.84)])
            + districtRow(1, 0, .nearRight, [.storefront(at: 0.24), .recordsColonnade(at: 0.92)])
            + districtRow(2, -1, .nearLeft, [.recordsWing(at: 0.30), .storefront(at: 0.68), .tenement(at: 0.96)])
            + districtRow(2, -1, .nearRight, [.rowhouse(at: 0.22), .recordsWing(at: 0.90)])
            + districtRow(3, -2, .nearLeft, [.tenement(at: 0.38), .storefront(at: 0.78)])
            + districtRow(0, 0, .nearRight, [.recordsWing(at: 0.50), .rowhouse(at: 0.90)])
            + districtRow(1, -1, .nearLeft, [.storefront(at: 0.30), .recordsColonnade(at: 0.72)])
            + districtRow(1, -1, .nearRight, [.tenement(at: 0.26), .rowCorner(at: 0.60), .recordsWing(at: 0.94)])
            + districtRow(2, -2, .nearLeft, [.rowhouse(at: 0.40), .storefront(at: 0.80)])
            + districtRow(2, -2, .nearRight, [.recordsWing(at: 0.44), .tenement(at: 0.88)])
            // Camera-far corner: the plaza closes the block behind the
            // colonnade, and the forecourt is the gap in front of both.
            + districtRow(0, -1, .nearRight, [.recordsPlaza(at: 0.96)])
            + districtRow(1, -2, .nearLeft, [.storefront(at: 0.38), .recordsWing(at: 0.78)])
            + districtRow(1, -2, .nearRight, [.tenement(at: 0.44), .rowhouse(at: 0.86)])
            + districtRow(2, -3, .nearLeft, [.recordsWing(at: 0.44), .storefront(at: 0.84)])
            + districtRow(1, 1, .farRight, [.tenement(at: 0.55)])
            + districtRow(2, 0, .farLeft, [.storefront(at: 0.45)])
            + districtRow(2, 0, .farRight, [.rowhouse(at: 0.55)])
            + districtRow(3, -1, .farLeft, [.tenement(at: 0.50)])
            + districtRow(1, 0, .farLeft, [.storefront(at: 0.48)])
            + districtRow(1, 0, .farRight, [.rowhouse(at: 0.58)])
            + districtRow(2, -1, .farLeft, [.tenement(at: 0.44)])
            + districtRow(2, -1, .farRight, [.storefront(at: 0.60)])
            + districtRow(1, -1, .farLeft, [.rowhouse(at: 0.46)])
            + districtRow(1, -1, .farRight, [.tenement(at: 0.58)])
            + districtRow(2, -2, .farLeft, [.storefront(at: 0.50)])
    }()

    static let civicRecords = CityDistrictDefinition(
        id: .civicRecords,
        locationName: "CIVIC RECORDS ANNEX",
        arrivalHint: "CIVIC RECORDS  •  Marble that still looks clean in the rain.",
        groundTextureName: "city_civic_records_ground_v02",
        mapTextureName: "map_city_civic_records_v02",
        actorStart: CityBlockGrid.arrivalPoint(from: .south),
        spawnByArrivalKey: [
            "from.south": CityBlockGrid.arrivalPoint(from: .south),
            "from.west": CityBlockGrid.arrivalPoint(from: .west),
            "from.east": CityBlockGrid.arrivalPoint(from: .east),
            "from.north": CityBlockGrid.arrivalPoint(from: .north)
        ],
        visualSprites: recordsFrontage + [
            recordsAnnex,
            recordsWing,
            recordsColonnade,
            recordsAnnexDoor,
            CityDistrictLayout.doorLeaf(
                textureName: "city_door_records_wing",
                on: recordsWing,
                aperture: .buildingRecordsWing
            ),
            CityDistrictLayout.doorLeaf(
                textureName: "city_door_records_colonnade",
                on: recordsColonnade,
                aperture: .buildingRecordsColonnade
            )
        ]
        + spokeCrossingLamps()
        + [
            // The statue stands on the colonnade's forecourt, not on a crossing.
            .init(
                textureName: "city_prop_statue",
                groundPoint: CGPoint(
                    x: recordsColonnade.groundPoint.x - 260,
                    y: recordsColonnade.groundPoint.y - 210
                ),
                scale: CityDistrictLayout.PropDisplayScale.statueSpoke,
                anchorY: 0.10,
                depthBias: 3
            ),
            kerbProp("city_prop_bench", at: CityDistrictLayout.StreetCrossing.upperWest, slope: 0.75, distance: 160, scale: CityDistrictLayout.PropDisplayScale.benchSpoke, anchorY: 0.15),
            kerbProp("city_prop_bench", at: CityDistrictLayout.StreetCrossing.upperEast, slope: -0.75, distance: -160, scale: CityDistrictLayout.PropDisplayScale.benchSpoke, anchorY: 0.15),
            kerbProp("city_prop_car_black", at: CityDistrictLayout.StreetCrossing.midWard, slope: -0.75, distance: -180, scale: CityDistrictLayout.PropDisplayScale.carSpoke, anchorY: 0.18),
            kerbProp("city_prop_car_maroon", at: CityDistrictLayout.StreetCrossing.harborVoss, slope: 0.75, distance: 180, scale: CityDistrictLayout.PropDisplayScale.carSpoke, anchorY: 0.18)
        ],
        obstacles: wardObstacles,
        portals: [
            .init(
                id: "portal.recordsEntrance",
                label: "ANNEX",
                approachPoint: CityDistrictLayout.portalApproach(forLeaf: recordsAnnexDoor, clearOf: wardObstacles),
                hitArea: CityDistrictLayout.portalHitArea(forLeaf: recordsAnnexDoor),
                destination: .inspect,
                requiresCityOpen: false,
                lockedInspectLine: "Dual ledgers wait behind polite glass. Exterior only for now."
            )
        ],
        pointsOfInterest: [
            .init(label: "ANNEX", worldPoint: recordsAnnex.groundPoint, colorRGBA: (0.55, 0.48, 0.32, 1))
        ]
    )
}
