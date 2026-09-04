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
    case interior(CityInteriorID)
    /// Walk-up inspect only (no scene change).
    case inspect
}

/// Small enterable landmark interiors. Each record has its own return travel
/// region, but they share one neutral 1950s lobby plate. This is the Infinity
/// Engine split: the door/region owns *where* it goes; the background is only
/// the pre-rendered picture drawn after arrival.
enum CityInteriorID: String, CaseIterable, Equatable {
    case shippingOffice = "shipping_office"
    case ironStairs = "iron_stairs"
    case policeStation = "police_station"
    case lilaRooms = "lila_rooms"
    case recordsAnnex = "records_annex"

    var areaID: AreaID { AreaID("interior_\(rawValue)") }

    var exteriorDistrict: CityDistrictID {
        switch self {
        case .shippingOffice: .wharfLadder
        case .ironStairs: .riverside
        case .policeStation: .harborpointPD
        case .lilaRooms: .lilaStreet
        case .recordsAnnex: .civicRecords
        }
    }

    var exteriorPortalID: String {
        switch self {
        case .shippingOffice: "portal.shippingOffice"
        case .ironStairs: "portal.ironStairs"
        case .policeStation: "portal.pdEntrance"
        case .lilaRooms: "portal.lilaRooms"
        case .recordsAnnex: "portal.recordsEntrance"
        }
    }

    var displayName: String {
        switch self {
        case .shippingOffice: "WHARF SHIPPING OFFICE"
        case .ironStairs: "RIVERSIDE ROOMS"
        case .policeStation: "HARBORPOINT POLICE STATION"
        case .lilaRooms: "LILA STREET ROOMS"
        case .recordsAnnex: "CIVIC RECORDS ANNEX"
        }
    }

    /// The exterior ARE entrance paired with this interior's return region.
    var exteriorEntranceName: String { "from.\(exteriorPortalID)" }
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
    /// Door leaves this ward measures but does not draw, because its plate has
    /// them painted in. They stay the scale authority for grading a door against
    /// a standing adult, and for deriving its approach.
    var measuredDoorLeaves: [VisualSprite] = []
    let obstacles: [CGRect]
    let portals: [Portal]
    let pointsOfInterest: [PointOfInterest]

    /// Literal AR0400/AR0500 BG:EE WED extent: 80×60 64-unit tiles.
    /// The former 4096×3072 ward is retained as the lower-left registered core;
    /// the extra north/east ring adds street depth without moving any landmark.
    static let sourceArtSize = CGSize(width: 5_120, height: 3_840)
    static let environmentScale: CGFloat = 1
    static let worldArtSize = CGSize(
        width: sourceArtSize.width * environmentScale,
        height: sourceArtSize.height * environmentScale
    )
    static let worldBounds = CGRect(origin: .zero, size: worldArtSize)
    static let standingAdultBodyHeight = OfficeInteriorScale.standingAdultBodyHeight

    /// The city and office share the same 100% native-sprite camera scale.
    /// Area size affects only the viewport clamp, never creature magnification.
    static var cameraScaleAt100Percent: CGFloat {
        OfficeInteriorScale.cameraScaleAt100Percent
    }

    static func cameraVisibleHeight(forSceneHeight sceneHeight: CGFloat) -> CGFloat {
        OfficeInteriorScale.cameraVisibleHeight(forSceneHeight: sceneHeight)
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

    /// A monolithic background already contains every facade, lamp, parked car
    /// and closed leaf. The full authoring sprite list remains available for
    /// measured portal geometry, but emitting it at runtime would draw the ward
    /// a second time over the baked plate.
    var runtimeVisualSprites: [VisualSprite] {
        groundTextureName.hasSuffix("_block_v02") ? [] : visualSprites
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

    /// Painted building masses plus painted portal apertures (door leaves sit
    /// on the mass; min-width bands alone do not cover the threshold).
    static var wardObstacles: [CGRect] {
        CityStreetPlan.wardObstacles + paintedPortalObstacles(
            office: sharedOfficePortalKeepOut
        )
    }

    /// The shared mass plan retains the original office keep-out. Sable Row's
    /// supplied continuous plate moves only its painted aperture; allowing that
    /// visual registration to mutate this rect would change all six SR rasters.
    private static let sharedOfficePortalKeepOut = CGRect(
        x: 2_580.75, y: 490, width: 38.5, height: 85.5
    )

    private static func paintedPortalObstacles(office: CGRect) -> [CGRect] {
        [office] + [
            "portal.shippingOffice", "portal.ironStairs",
            "portal.pdEntrance", "portal.lilaRooms", "portal.recordsEntrance"
        ].compactMap { CityDoorPaintedAperture.rect(for: $0)?.cgRect }
    }

    /// The river Riverside's plate fades to below y = 130.
    static let riverWater = CGRect(x: 0, y: 0, width: 4_096, height: 140)
    /// Wharf Ladder waterfront. Matches the V5 ground fade (`y < 180`); the
    /// rect is the walkable cut, so it sits inside the fade. The quay street
    /// through `(840, 414)` / `(2520, 414)` stays dry.
    static let wharfWater = CGRect(x: 0, y: 0, width: 4_096, height: 160)
    /// Kerb furniture must sit above the painted quay fade, not in the drink.
    private static let wharfQuayMinimumY = wharfWater.maxY + 12

    // MARK: - Shared street furniture

    /// Map a legacy 840/630 crossing to the nearest IE street-plan junction.
    private static func planCrossing(_ legacy: CGPoint) -> CGPoint {
        CityStreetPlan.nearestCrossing(to: legacy)
    }

    /// Kerb offset that stays on open street — steps inward when a fixed offset
    /// would land inside a pad mass.
    private static func kerbPointOnStreet(
        from origin: CGPoint,
        slope: CGFloat,
        preferredDistance: CGFloat,
        minimumY: CGFloat? = nil
    ) -> CGPoint {
        let sign: CGFloat = preferredDistance >= 0 ? 1 : -1
        var offset = abs(preferredDistance)
        while offset >= 36 {
            let candidate = CityDistrictLayout.StreetCrossing.along(
                from: origin,
                slope: slope,
                distance: sign * offset
            )
            if CityStreetPlan.isOnStreet(candidate),
               minimumY.map({ candidate.y > $0 }) ?? true {
                return candidate
            }
            offset -= 12
        }
        return CityDistrictLayout.StreetCrossing.along(
            from: origin,
            slope: slope,
            distance: preferredDistance
        )
    }

    /// Four kerb lamps around a road crossing, on the ±0.75 ground axes.
    ///
    /// Was `sableCrossingLamps`, private to one district while the other five
    /// repeated the same seven hand-typed axis-aligned points — the same ring
    /// in four different districts, most of it standing in the middle of
    /// painted blocks. Lamps belong on kerbs, and the kerbs are on the axes.
    static func crossingLamps(
        at origin: CGPoint,
        scale: CGFloat = CityDistrictLayout.PropDisplayScale.lampHub,
        distance: CGFloat = 80,
        minimumY: CGFloat? = nil
    ) -> [CityDistrictDefinition.VisualSprite] {
        let slopes: [CGFloat] = [0.75, 0.75, -0.75, -0.75]
        let distances: [CGFloat] = [distance, -distance, distance, -distance]
        return zip(slopes, distances).compactMap { slope, step in
            let ground = kerbPointOnStreet(
                from: origin,
                slope: slope,
                preferredDistance: step,
                minimumY: minimumY
            )
            guard CityStreetPlan.isOnStreet(ground),
                  minimumY.map({ ground.y > $0 }) ?? true
            else { return nil }
            return .init(
                textureName: "city_prop_lamp",
                groundPoint: ground,
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
        depthBias: CGFloat = 2,
        minimumY: CGFloat? = nil
    ) -> CityDistrictDefinition.VisualSprite {
        .init(
            textureName: textureName,
            groundPoint: kerbPointOnStreet(
                from: origin, slope: slope, preferredDistance: distance, minimumY: minimumY
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
    static func spokeCrossingLamps(minimumY: CGFloat? = nil) -> [CityDistrictDefinition.VisualSprite] {
        CityStreetPlan.crossings.flatMap {
            crossingLamps(
                at: $0,
                scale: CityDistrictLayout.PropDisplayScale.lampSpoke,
                distance: 190,
                minimumY: minimumY
            )
        }
    }

    // MARK: - Sable Row (center / lower ward)

    private static func sableLotSprite(_ textureName: String) -> CityDistrictDefinition.VisualSprite {
        sableAreaLots.first { $0.textureName == textureName }!
    }

    /// Painted threshold on the supplied V15 continuous district plate.
    private static let sablePaintedThreshold = CityDoorPaintedAperture.threshold(for: "portal.office")!
    private static let sablePaintedAperture = CityDoorPaintedAperture.rect(for: "portal.office")!.cgRect
    private static var sableRowObstacles: [CGRect] {
        CityStreetPlan.wardObstacles + paintedPortalObstacles(office: sablePaintedAperture)
    }
    /// Exact centre of walkable search-map cell (167, 21), on the street side
    /// of the painted door and in the main connected component. The generic
    /// rectangle-only helper selects roof terrain for this particular plate.
    private static let sableOfficeApproach = CGPoint(x: 2_680, y: 258)

    /// Authoring-only leaf at the painted threshold.
    ///
    /// Sable Row's IE outdoor rebuild paints its closed doors into the day
    /// plate, so this leaf is never stamped as an overlay — but it is still
    /// *measured*: the approach points derive from it, and it is the scale
    /// authority for grading the door against a standing adult. It therefore
    /// lives in `measuredDoorLeaves`, not in `visualSprites`.
    private static let sableVossDoor = CityDistrictDefinition.VisualSprite(
        textureName: "city_door_voss_stoop",
        groundPoint: sablePaintedThreshold,
        scale: CityDistrictLayout.DoorDisplayScale.standard,
        anchorY: CityDistrictLayout.doorLeafAnchorY,
        depthBias: 96
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
        // IE outdoor: one day plate. Closed doors and roofs are painted in;
        // Extended Night swaps `nightPlateTextureName` on the area record.
        groundTextureName: "city_sable_row_day_v01",
        mapTextureName: "map_city_sable_row_v02",
        actorStart: sableOfficeApproach,
        spawnByArrivalKey: [
            "from.office": sableOfficeApproach,
            "from.north": CityStreetPlan.arrivalPoint(from: .north),
            "from.south": CityStreetPlan.arrivalPoint(from: .south),
            "from.east": CityStreetPlan.arrivalPoint(from: .east),
            "from.west": CityStreetPlan.arrivalPoint(from: .west)
        ],
        // No modular lots or door-leaf overlays — the district painting carries
        // architecture. Wall polygons on the area record own walk-behind.
        visualSprites: [],
        measuredDoorLeaves: [sableVossDoor],
        obstacles: sableRowObstacles,
        portals: [
            .init(
                id: "portal.office",
                label: "VOSS APT",
                approachPoint: sableOfficeApproach,
                hitArea: CityDistrictLayout.portalHitArea(paintedAperture: sablePaintedAperture),
                destination: .office,
                requiresCityOpen: false,
                lockedInspectLine: "The office door is locked from this side."
            )
        ],
        pointsOfInterest: [
            .init(label: "VOSS APT", worldPoint: sableOfficeApproach, colorRGBA: (0.72, 0.22, 0.18, 1)),
            .init(label: "WARD PLAZA", worldPoint: CityStreetPlan.wardPlaza, colorRGBA: (0.55, 0.48, 0.32, 1))
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
    private static let wharfPaintedThreshold = CityDoorPaintedAperture.threshold(for: "portal.shippingOffice")!
    private static let wharfPaintedAperture = CityDoorPaintedAperture.rect(for: "portal.shippingOffice")!.cgRect
    private static let wharfShippingApproach = CityDistrictLayout.portalApproach(
        fromThreshold: wharfPaintedThreshold,
        clearOf: wardObstacles + [wharfWater]
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
        groundTextureName: "city_wharf_ladder_block_v02",
        mapTextureName: "map_city_wharf_ladder_v02",
        actorStart: CityStreetPlan.arrivalPoint(from: .east),
        spawnByArrivalKey: [
            "from.east": CityStreetPlan.arrivalPoint(from: .east),
            "from.south": CityStreetPlan.arrivalPoint(from: .south),
            "from.north": CityStreetPlan.arrivalPoint(from: .north),
            "from.west": CityStreetPlan.arrivalPoint(from: .west)
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
        + spokeCrossingLamps(minimumY: wharfQuayMinimumY)
        + [
            // Mid-quay lamps, on the carriageway, not in a warehouse.
            .init(
                textureName: "city_prop_lamp",
                groundPoint: kerbPointOnStreet(
                    from: planCrossing(CityDistrictLayout.StreetCrossing.harborWest),
                    slope: -0.75,
                    preferredDistance: 180,
                    minimumY: wharfQuayMinimumY
                ),
                scale: CityDistrictLayout.PropDisplayScale.lampSpoke, anchorY: 0.12, depthBias: 1
            ),
            .init(
                textureName: "city_prop_lamp",
                groundPoint: kerbPointOnStreet(
                    from: planCrossing(CityDistrictLayout.StreetCrossing.harborVoss),
                    slope: -0.75,
                    preferredDistance: -180,
                    minimumY: wharfQuayMinimumY
                ),
                scale: CityDistrictLayout.PropDisplayScale.lampSpoke, anchorY: 0.12, depthBias: 1
            ),
            // Cargo on The Quay kerb.
            kerbProp("city_prop_crates_mail", at: planCrossing(CityDistrictLayout.StreetCrossing.harborWest), slope: 0.75, distance: 150, scale: CityDistrictLayout.PropDisplayScale.cratesSpoke, anchorY: 0.24, minimumY: wharfQuayMinimumY),
            kerbProp("city_prop_crates_mail", at: planCrossing(CityDistrictLayout.StreetCrossing.harborVoss), slope: 0.75, distance: 160, scale: CityDistrictLayout.PropDisplayScale.cratesSpoke, anchorY: 0.24, minimumY: wharfQuayMinimumY),
            kerbProp("city_prop_crates_mail", at: planCrossing(CityDistrictLayout.StreetCrossing.harborVoss), slope: -0.75, distance: 140, scale: CityDistrictLayout.PropDisplayScale.cratesSpoke, anchorY: 0.24, minimumY: wharfQuayMinimumY),
            // Two cars inland — docks are cargo, not a car park.
            kerbProp("city_prop_car_black", at: planCrossing(CityDistrictLayout.StreetCrossing.midWard), slope: 0.75, distance: 190, scale: CityDistrictLayout.PropDisplayScale.carSpoke, anchorY: 0.18, minimumY: wharfQuayMinimumY),
            kerbProp("city_prop_car_olive", at: planCrossing(CityDistrictLayout.StreetCrossing.midEast), slope: -0.75, distance: -180, scale: CityDistrictLayout.PropDisplayScale.carSpoke, anchorY: 0.18, minimumY: wharfQuayMinimumY),
            kerbProp("city_prop_gate", at: planCrossing(CityDistrictLayout.StreetCrossing.harborVoss), slope: 0.75, distance: 80, scale: CityDistrictLayout.PropDisplayScale.gate, anchorY: 0.22, minimumY: wharfQuayMinimumY)
        ],
        obstacles: wardObstacles + [wharfWater],
        portals: [
            .init(
                id: "portal.shippingOffice",
                label: "SHIPPING",
                approachPoint: wharfShippingApproach,
                hitArea: CityDistrictLayout.portalHitArea(paintedAperture: wharfPaintedAperture),
                destination: .interior(.shippingOffice),
                requiresCityOpen: false,
                lockedInspectLine: "Lillian's shipping office. Ledgers and a late errand uptown — exterior only for now."
            )
        ],
        pointsOfInterest: [
            .init(label: "SHIPPING", worldPoint: wharfShippingApproach, colorRGBA: (0.72, 0.22, 0.18, 1))
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
        groundTextureName: "city_riverside_block_v02",
        mapTextureName: "map_city_riverside_v02",
        actorStart: CityStreetPlan.arrivalPoint(from: .east),
        spawnByArrivalKey: [
            "from.east": CityStreetPlan.arrivalPoint(from: .east),
            "from.north": CityStreetPlan.arrivalPoint(from: .north),
            "from.south": CityStreetPlan.arrivalPoint(from: .south),
            "from.west": CityStreetPlan.arrivalPoint(from: .west)
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
            kerbProp("city_prop_crates_mail", at: planCrossing(CityDistrictLayout.StreetCrossing.harborWest), slope: -0.75, distance: -150, scale: CityDistrictLayout.PropDisplayScale.cratesSpoke, anchorY: 0.24),
            kerbProp("city_prop_crates_mail", at: planCrossing(CityDistrictLayout.StreetCrossing.upperWest), slope: 0.75, distance: 150, scale: CityDistrictLayout.PropDisplayScale.cratesSpoke, anchorY: 0.24),
            kerbProp("city_prop_car_black", at: planCrossing(CityDistrictLayout.StreetCrossing.midWard), slope: 0.75, distance: 190, scale: CityDistrictLayout.PropDisplayScale.carSpoke, anchorY: 0.18),
            kerbProp("city_prop_car_maroon", at: planCrossing(CityDistrictLayout.StreetCrossing.upperEast), slope: -0.75, distance: -190, scale: CityDistrictLayout.PropDisplayScale.carSpoke, anchorY: 0.18),
            kerbProp("city_prop_bench", at: planCrossing(CityDistrictLayout.StreetCrossing.midEast), slope: 0.75, distance: 150, scale: CityDistrictLayout.PropDisplayScale.benchSpoke, anchorY: 0.15)
        ],
        obstacles: wardObstacles + [riverWater],
        portals: [
            .init(
                id: "portal.ironStairs",
                label: "STAIRS",
                approachPoint: CityDistrictLayout.portalApproach(
                    fromThreshold: CityDoorPaintedAperture.threshold(for: "portal.ironStairs")!,
                    clearOf: wardObstacles + [riverWater]
                ),
                hitArea: CityDistrictLayout.portalHitArea(
                    paintedAperture: CityDoorPaintedAperture.rect(for: "portal.ironStairs")!.cgRect
                ),
                destination: .interior(.ironStairs),
                requiresCityOpen: false,
                lockedInspectLine: "Wet iron and staged stones. The coat is already in police custody."
            )
        ],
        pointsOfInterest: [
            .init(
                label: "STAIRS",
                worldPoint: CityDoorPaintedAperture.threshold(for: "portal.ironStairs")!,
                colorRGBA: (0.32, 0.51, 0.66, 1)
            )
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
        groundTextureName: "city_harborpoint_pd_block_v02",
        mapTextureName: "map_city_harborpoint_pd_v02",
        actorStart: CityStreetPlan.arrivalPoint(from: .north),
        spawnByArrivalKey: [
            "from.north": CityStreetPlan.arrivalPoint(from: .north),
            "from.west": CityStreetPlan.arrivalPoint(from: .west),
            "from.east": CityStreetPlan.arrivalPoint(from: .east),
            "from.south": CityStreetPlan.arrivalPoint(from: .south)
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
            kerbProp("city_prop_car_black", at: planCrossing(CityDistrictLayout.StreetCrossing.midWard), slope: 0.75, distance: 170, scale: CityDistrictLayout.PropDisplayScale.carSpoke, anchorY: 0.18),
            kerbProp("city_prop_car_black", at: planCrossing(CityDistrictLayout.StreetCrossing.midWard), slope: 0.75, distance: 320, scale: CityDistrictLayout.PropDisplayScale.carSpoke, anchorY: 0.18),
            kerbProp("city_prop_car_olive", at: planCrossing(CityDistrictLayout.StreetCrossing.midEast), slope: -0.75, distance: -180, scale: CityDistrictLayout.PropDisplayScale.carSpoke, anchorY: 0.18),
            kerbProp("city_prop_crates_mail", at: planCrossing(CityDistrictLayout.StreetCrossing.harborVoss), slope: 0.75, distance: 160, scale: CityDistrictLayout.PropDisplayScale.cratesSpoke, anchorY: 0.24),
            kerbProp("city_prop_bench", at: planCrossing(CityDistrictLayout.StreetCrossing.upperWest), slope: -0.75, distance: -150, scale: CityDistrictLayout.PropDisplayScale.benchSpoke, anchorY: 0.15)
        ],
        obstacles: wardObstacles,
        portals: [
            .init(
                id: "portal.pdEntrance",
                label: "STATION",
                approachPoint: CityDistrictLayout.portalApproach(
                    fromThreshold: CityDoorPaintedAperture.threshold(for: "portal.pdEntrance")!,
                    clearOf: wardObstacles
                ),
                hitArea: CityDistrictLayout.portalHitArea(
                    paintedAperture: CityDoorPaintedAperture.rect(for: "portal.pdEntrance")!.cgRect
                ),
                destination: .interior(.policeStation),
                requiresCityOpen: false,
                lockedInspectLine: "The desk sergeant keeps soft conclusions behind glass. Exterior only for now."
            )
        ],
        pointsOfInterest: [
            .init(
                label: "STATION",
                worldPoint: CityDoorPaintedAperture.threshold(for: "portal.pdEntrance")!,
                colorRGBA: (0.79, 0.55, 0.26, 1)
            )
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
        groundTextureName: "city_lila_street_block_v02",
        mapTextureName: "map_city_lila_street_v02",
        actorStart: CityStreetPlan.arrivalPoint(from: .west),
        spawnByArrivalKey: [
            "from.west": CityStreetPlan.arrivalPoint(from: .west),
            "from.north": CityStreetPlan.arrivalPoint(from: .north),
            "from.south": CityStreetPlan.arrivalPoint(from: .south),
            "from.east": CityStreetPlan.arrivalPoint(from: .east)
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
            kerbProp("city_prop_bench", at: planCrossing(CityDistrictLayout.StreetCrossing.midWard), slope: -0.75, distance: -160, scale: CityDistrictLayout.PropDisplayScale.benchSpoke, anchorY: 0.15),
            kerbProp("city_prop_bench", at: planCrossing(CityDistrictLayout.StreetCrossing.upperEast), slope: 0.75, distance: 160, scale: CityDistrictLayout.PropDisplayScale.benchSpoke, anchorY: 0.15),
            kerbProp("city_prop_car_olive", at: planCrossing(CityDistrictLayout.StreetCrossing.harborVoss), slope: 0.75, distance: 180, scale: CityDistrictLayout.PropDisplayScale.carSpoke, anchorY: 0.18),
            kerbProp("city_prop_car_maroon", at: planCrossing(CityDistrictLayout.StreetCrossing.midEast), slope: -0.75, distance: -180, scale: CityDistrictLayout.PropDisplayScale.carSpoke, anchorY: 0.18),
            kerbProp("city_prop_kiosk", at: planCrossing(CityDistrictLayout.StreetCrossing.harborWest), slope: 0.75, distance: 150, scale: CityDistrictLayout.PropDisplayScale.kiosk, anchorY: 0.20)
        ],
        obstacles: wardObstacles,
        portals: [
            .init(
                id: "portal.lilaRooms",
                label: "ROOMS",
                approachPoint: CityDistrictLayout.portalApproach(
                    fromThreshold: CityDoorPaintedAperture.threshold(for: "portal.lilaRooms")!,
                    clearOf: wardObstacles
                ),
                hitArea: CityDistrictLayout.portalHitArea(
                    paintedAperture: CityDoorPaintedAperture.rect(for: "portal.lilaRooms")!.cgRect
                ),
                destination: .interior(.lilaRooms),
                requiresCityOpen: false,
                lockedInspectLine: "Lila's rooms stay private. Watch the doorway posts instead."
            )
        ],
        pointsOfInterest: [
            .init(
                label: "ROOMS",
                worldPoint: CityDoorPaintedAperture.threshold(for: "portal.lilaRooms")!,
                colorRGBA: (0.58, 0.20, 0.48, 1)
            )
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
        groundTextureName: "city_civic_records_block_v02",
        mapTextureName: "map_city_civic_records_v02",
        actorStart: CityStreetPlan.arrivalPoint(from: .south),
        spawnByArrivalKey: [
            "from.south": CityStreetPlan.arrivalPoint(from: .south),
            "from.west": CityStreetPlan.arrivalPoint(from: .west),
            "from.east": CityStreetPlan.arrivalPoint(from: .east),
            "from.north": CityStreetPlan.arrivalPoint(from: .north)
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
            kerbProp("city_prop_bench", at: planCrossing(CityDistrictLayout.StreetCrossing.upperWest), slope: 0.75, distance: 160, scale: CityDistrictLayout.PropDisplayScale.benchSpoke, anchorY: 0.15),
            kerbProp("city_prop_bench", at: planCrossing(CityDistrictLayout.StreetCrossing.upperEast), slope: -0.75, distance: -160, scale: CityDistrictLayout.PropDisplayScale.benchSpoke, anchorY: 0.15),
            kerbProp("city_prop_car_black", at: planCrossing(CityDistrictLayout.StreetCrossing.midWard), slope: -0.75, distance: -180, scale: CityDistrictLayout.PropDisplayScale.carSpoke, anchorY: 0.18),
            kerbProp("city_prop_car_maroon", at: planCrossing(CityDistrictLayout.StreetCrossing.harborVoss), slope: 0.75, distance: 180, scale: CityDistrictLayout.PropDisplayScale.carSpoke, anchorY: 0.18)
        ],
        obstacles: wardObstacles,
        portals: [
            .init(
                id: "portal.recordsEntrance",
                label: "ANNEX",
                approachPoint: CityDistrictLayout.portalApproach(
                    fromThreshold: CityDoorPaintedAperture.threshold(for: "portal.recordsEntrance")!,
                    clearOf: wardObstacles
                ),
                hitArea: CityDistrictLayout.portalHitArea(
                    paintedAperture: CityDoorPaintedAperture.rect(for: "portal.recordsEntrance")!.cgRect
                ),
                destination: .interior(.recordsAnnex),
                requiresCityOpen: false,
                lockedInspectLine: "Dual ledgers wait behind polite glass. Exterior only for now."
            )
        ],
        pointsOfInterest: [
            .init(
                label: "ANNEX",
                worldPoint: CityDoorPaintedAperture.threshold(for: "portal.recordsEntrance")!,
                colorRGBA: (0.55, 0.48, 0.32, 1)
            )
        ]
    )
}
