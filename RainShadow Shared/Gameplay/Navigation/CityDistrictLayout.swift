import CoreGraphics

/// Compatibility facade for Sable Row hub metrics. Prefer `CityDistrictCatalog`.
///
/// Human-scale contract (shared with the office via `standingAdultBodyHeight`):
/// outdoor doors must clear Harlan Voss; cars stay near adult roof height;
/// multi-story facades sit several body-heights tall without becoming monumental.
enum CityDistrictLayout {
    typealias VisualSprite = CityDistrictDefinition.VisualSprite
    typealias PointOfInterest = CityDistrictDefinition.PointOfInterest

    static let sourceArtSize = CityDistrictDefinition.sourceArtSize
    static let environmentScale = CityDistrictDefinition.environmentScale
    static let worldArtSize = CityDistrictDefinition.worldArtSize
    static let worldBounds = CityDistrictDefinition.worldBounds
    static let standingAdultBodyHeight = CityDistrictDefinition.standingAdultBodyHeight

    /// Mid-band outdoor door target used to derive door-anchored building scales.
    /// Measured against the adult **as drawn on screen**, so 1.15 really is 15%
    /// of clearance. It previously multiplied the logical 82-unit body while Voss
    /// rendered at 90.625, leaving only ~4% — doors that barely cleared his head.
    static let targetDoorBodyMultiple: CGFloat = 1.15

    static var cameraVisibleHeight: CGFloat {
        CityDistrictDefinition.cameraVisibleHeight
    }

    static var actorStart: CGPoint { CityDistrictCatalog.sableRow.actorStart }
    static var visualSprites: [VisualSprite] { CityDistrictCatalog.sableRow.visualSprites }
    static var obstacles: [CGRect] { CityDistrictCatalog.sableRow.obstacles }
    static var pointsOfInterest: [PointOfInterest] { CityDistrictCatalog.sableRow.pointsOfInterest }

    /// One painted iso house per surveyed Harbor Street / upper-row diamond.
    enum TerraceID: String, CaseIterable, Equatable {
        case sableSW
        case sableSE
        case sableNW
        case sableNE

        var textureName: String {
            switch self {
            case .sableSW: return "city_terrace_sable_sw"
            case .sableSE: return "city_terrace_sable_se"
            case .sableNW: return "city_terrace_sable_nw"
            case .sableNE: return "city_terrace_sable_ne"
            }
        }

        /// Occlusion crop the leaf is registered to now that play draws lots,
        /// not the retired L-terrace sprites.
        var lotTextureName: String {
            switch self {
            case .sableSW: return "city_sable_lot_harborWest"
            case .sableSE: return "city_sable_lot_harborVoss"
            case .sableNW: return "city_sable_lot_upperWest"
            case .sableNE: return "city_sable_lot_upperEast"
            }
        }
    }

    /// Sable Row's names for eight of the twelve painted lattice blocks.
    ///
    /// The geometry lives in `CityBlockGrid`; this is the naming layer, kept
    /// because `CityDistrictScene.addDepthSlicedSprite` looks lots up by
    /// `rawValue` and the near-side walls sort against a named kerb. Houses sit
    /// on `nearTip`; nav uses `CityBlockGrid.Block.obstacleBands`.
    enum IsoLot: String, CaseIterable, Equatable {
        case harborWest
        case harborVoss
        case upperWest
        case upperEast
        case skylineWest
        case skylineEast
        /// Camera-near of Harbor Street. Survey near tips sit at y = −24;
        /// the on-plate foot is clamped to y = 0.
        case southWest
        case southEast

        var block: CityBlockGrid.Block {
            switch self {
            case .harborWest: return CityBlockGrid.block(i: 1, j: 0)
            case .harborVoss: return CityBlockGrid.block(i: 2, j: -1)
            case .upperWest: return CityBlockGrid.block(i: 1, j: -1)
            case .upperEast: return CityBlockGrid.block(i: 2, j: -2)
            case .skylineWest: return CityBlockGrid.block(i: 0, j: -1)
            case .skylineEast: return CityBlockGrid.block(i: 1, j: -2)
            case .southWest: return CityBlockGrid.block(i: 2, j: 0)
            case .southEast: return CityBlockGrid.block(i: 3, j: -1)
            }
        }

        /// Camera-near vertex of the lot (lowest world y on the plate).
        ///
        /// The two south lots are clamped onto the plate: their surveyed tips
        /// sit at y = −24, and the painted wall's foot must stay visible.
        var nearTip: CGPoint {
            let tip = block.nearTip
            switch self {
            case .southWest, .southEast: return CGPoint(x: tip.x, y: max(0, tip.y))
            default: return tip
            }
        }

        var centroid: CGPoint { block.centre }
        var leftTip: CGPoint { block.leftTip }
        var rightTip: CGPoint { block.rightTip }
        var farTip: CGPoint { block.farTip }

        /// Street-facing (camera-far) kerb y at world x. Near-side houses
        /// depth-sort along this line so Voss on Harbor Street draws in front.
        func northKerbY(atX x: CGFloat) -> CGFloat {
            let left = leftTip
            let far = farTip
            let right = rightTip
            if x <= far.x {
                let span = far.x - left.x
                guard span > 1 else { return far.y }
                let t = min(max((x - left.x) / span, 0), 1)
                return left.y + (far.y - left.y) * t
            }
            let span = right.x - far.x
            guard span > 1 else { return far.y }
            let t = min(max((x - far.x) / span, 0), 1)
            return far.y + (right.y - far.y) * t
        }

        /// Carriageway this lot faces. Harbor Street is the spawn street.
        var streetRole: String {
            switch self {
            case .harborWest, .harborVoss: return "harborStreet"
            case .southWest, .southEast: return "harborStreetNear"
            case .upperWest, .upperEast: return "upperRow"
            case .skylineWest, .skylineEast: return "skyline"
            }
        }

        /// Occupied lots: far-side terraces, near-side canyon wall, skyline.
        static var occupied: [IsoLot] {
            [
                .harborWest, .harborVoss, .southWest, .southEast,
                .upperWest, .upperEast, .skylineWest, .skylineEast
            ]
        }
    }

    /// u/v road intersections from the V5 painter (period 840 wu).
    /// Lamps sit on these crossings; cars sit in the carriageway beside them.
    enum StreetCrossing {
        static let harborWest = CGPoint(x: 840, y: 414)
        static let harborVoss = CGPoint(x: 2_520, y: 414)
        static let midWard = CGPoint(x: 1_680, y: 1_044)
        static let midEast = CGPoint(x: 3_360, y: 1_044)
        static let upperWest = CGPoint(x: 840, y: 1_674)
        static let upperEast = CGPoint(x: 2_520, y: 1_674)

        /// Unit step along a BG:EE ground axis (slope ±0.75).
        static func along(from origin: CGPoint, slope: CGFloat, distance: CGFloat) -> CGPoint {
            let length = (1 + slope * slope).squareRoot()
            return CGPoint(
                x: origin.x + distance / length,
                y: origin.y + slope * distance / length
            )
        }
    }

    /// Authored world size and texture canvas for each terrace. Texture is 2.00
    /// px/unit so stonework matches the V5 ground plates; `worldSize` is the
    /// draw size, not a `setScale` of a 512×640 cube.
    enum TerraceSpec {
        static let pixelsPerWorldUnit: CGFloat = 2
        /// 3-storey Infinity Engine city block: door 1.15× adult + two floors + roof.
        /// 420 / 70.3125 = 6.0 adults (~10.5 m). Uniform with a 840 px canvas.
        static let worldHeight: CGFloat = 420
        /// Foot sits just inside the block AABB, not out on the street.
        static let footInset: CGFloat = 10

        static let canvasSW = CGSize(width: 2_240, height: 840)
        static let canvasSE = CGSize(width: 2_240, height: 840)
        static let canvasNW = CGSize(width: 2_240, height: 840)
        static let canvasNE = CGSize(width: 2_240, height: 840)

        /// One surveyed diamond lot. Same 1120×420 for every Sable house.
        static let lotWorldSize = CGSize(width: 1_120, height: 420)

        static func lot(for id: TerraceID) -> IsoLot {
            switch id {
            case .sableSW: return .harborWest
            case .sableSE: return .harborVoss
            case .sableNW: return .upperWest
            case .sableNE: return .upperEast
            }
        }

        static func canvas(for id: TerraceID) -> CGSize {
            switch id {
            case .sableSW: return canvasSW
            case .sableSE: return canvasSE
            case .sableNW: return canvasNW
            case .sableNE: return canvasNE
            }
        }

        static func worldSize(for id: TerraceID) -> CGSize { lotWorldSize }

        static func groundPoint(for id: TerraceID) -> CGPoint {
            lot(for: id).nearTip
        }

        static func sprite(_ id: TerraceID) -> VisualSprite {
            let world = worldSize(for: id)
            let art = canvas(for: id)
            return VisualSprite(
                textureName: id.textureName,
                groundPoint: groundPoint(for: id),
                scale: world.width / art.width,
                anchorY: 0,
                depthBias: 0,
                worldSize: world
            )
        }

        /// Lot crop the runtime actually draws. Aperture pixels are on this canvas.
        static func lotSprite(_ id: TerraceID) -> VisualSprite {
            let world = lotDrawSize(for: id)
            return VisualSprite(
                textureName: id.lotTextureName,
                groundPoint: groundPoint(for: id),
                scale: 1,
                anchorY: 0,
                depthBias: 0,
                worldSize: world
            )
        }

        /// Bake crop world size (`sableAreaLots`). Do not reuse `lotWorldSize`.
        static func lotDrawSize(for id: TerraceID) -> CGSize {
            switch id {
            case .sableSW, .sableSE: return CGSize(width: 1_168, height: 1_263)
            case .sableNW: return CGSize(width: 1_168, height: 1_068)
            case .sableNE: return CGSize(width: 1_168, height: 1_069)
            }
        }

        static func lotCanvas(for id: TerraceID) -> CGSize {
            switch id {
            case .sableSW, .sableSE: return CGSize(width: 2_336, height: 2_526)
            case .sableNW: return CGSize(width: 2_336, height: 2_136)
            case .sableNE: return CGSize(width: 2_336, height: 2_138)
            }
        }

        /// Painted Voss stoop threshold on the seated SE lot crop.
        static var vossStoopWorld: CGPoint {
            aperturePoint(of: .lotSableVossStoop, on: lotSprite(.sableSE))
        }

        /// Street-side walk-up, 140 wu camera-near of the stoop on Harbor Street.
        static var vossStoopApproach: CGPoint {
            CGPoint(x: vossStoopWorld.x, y: vossStoopWorld.y - 140)
        }
    }

    // MARK: - Street frontage

    /// One facade in a terrace row, and where along the block edge it stands.
    ///
    /// `scale` and `anchorY` are the same values the district already used for
    /// that texture. `anchorY` is what makes this work: it was hand-tuned per
    /// facade so `groundPoint` lands on the building's *near base corner*, not
    /// on its lowest painted pixel. Put that point on the block edge and the
    /// wall fronts the street with its stoop projecting onto the pavement,
    /// which is exactly how a Baldur's Gate terrace meets its kerb.
    struct FrontageModule {
        let textureName: String
        let scale: CGFloat
        let anchorY: CGFloat
        /// Fraction along the edge, from the block's near tip (0) toward the
        /// side tip (1). Modules overlap by design — a block has to read as one
        /// mass, not as boxes with daylight between them.
        let t: CGFloat
        let depthBias: CGFloat

        init(
            _ textureName: String,
            scale: CGFloat,
            anchorY: CGFloat,
            at t: CGFloat,
            depthBias: CGFloat = 0
        ) {
            self.textureName = textureName
            self.scale = scale
            self.anchorY = anchorY
            self.t = t
            self.depthBias = depthBias
        }
    }

    /// Facades stepped along one of a block's edges, on the ±0.75 ground axis.
    ///
    /// This is `StreetCrossing.along(from:slope:distance:)` applied to building
    /// rows instead of lamps. The five spoke districts used to hand-type
    /// `groundPoint`s on an axis-aligned grid that exists nowhere in the art,
    /// which is why their buildings stood in the middle of painted streets.
    ///
    /// `outset` must match the outset the same edge carries in
    /// `obstacleBands`, so what you walk into is what you can see.
    static func frontage(
        on block: CityBlockGrid.Block,
        facing edge: CityBlockGrid.Edge,
        outset: CGFloat = 0,
        _ modules: [FrontageModule]
    ) -> [VisualSprite] {
        modules.map { module in
            VisualSprite(
                textureName: module.textureName,
                groundPoint: block.point(on: edge, at: module.t, outset: outset),
                scale: module.scale,
                anchorY: module.anchorY,
                depthBias: module.depthBias
            )
        }
    }

    /// A freestanding landmark seated inside a block rather than on its edge.
    ///
    /// Detachment is one of the three cues Baldur's Gate uses for "this
    /// building matters" (the others being a forecourt and a wall), so this is
    /// deliberately the only way a district places a facade off the frontage
    /// line.
    static func landmark(
        _ textureName: String,
        on block: CityBlockGrid.Block,
        scale: CGFloat,
        anchorY: CGFloat,
        offset: CGPoint = .zero,
        depthBias: CGFloat = 0
    ) -> VisualSprite {
        VisualSprite(
            textureName: textureName,
            groundPoint: CGPoint(
                x: block.nearTip.x + offset.x,
                y: block.nearTip.y + offset.y
            ),
            scale: scale,
            anchorY: anchorY,
            depthBias: depthBias
        )
    }

    /// World-sized set dressing that is not a door-bearing block face.
    /// Used for the opposite Harbor Street row, the north skyline, and corner shops.
    static func districtDressing(
        textureName: String,
        canvas: CGSize,
        worldSize: CGSize,
        groundPoint: CGPoint,
        depthBias: CGFloat = 0,
        depthSliceWidth: CGFloat? = nil,
        depthSortLot: IsoLot? = nil
    ) -> VisualSprite {
        VisualSprite(
            textureName: textureName,
            groundPoint: groundPoint,
            scale: worldSize.width / canvas.width,
            anchorY: 0,
            depthBias: depthBias,
            worldSize: worldSize,
            depthSliceWidth: depthSliceWidth,
            depthSortLot: depthSortLot?.rawValue
        )
    }

    /// Opaque bbox heights of shipped V2 city prop textures (texture pixels).
    enum SourceContentHeight {
        static let buildingVossStoop: CGFloat = 490
        static let buildingTenement: CGFloat = 471
        static let buildingStorefront: CGFloat = 471
        static let buildingRowhouse: CGFloat = 440
        static let buildingShop: CGFloat = 471
        static let buildingGatehouse: CGFloat = 321
        static let buildingShippingOffice: CGFloat = 491
        static let buildingWarehouse: CGFloat = 408
        static let buildingBoarding: CGFloat = 471
        static let buildingDockShed: CGFloat = 379
        static let buildingLilaRooms: CGFloat = 471
        static let buildingPDStation: CGFloat = 367
        static let buildingRecordsAnnex: CGFloat = 398
        static let buildingRowCorner: CGFloat = 543
        static let carBlack: CGFloat = 276
        static let carOlive: CGFloat = 274
        static let carMaroon: CGFloat = 274
        static let lamp: CGFloat = 412
        static let bench: CGFloat = 275
        static let kiosk: CGFloat = 276
    }

    /// A facade's painted doorway opening, measured in **texture-canvas pixels**
    /// with the origin at the top-left. Cube facades use the 512×640 canvas;
    /// Sable terraces use `canvas` equal to that terrace's authored texture size.
    ///
    /// `centreX`/`thresholdY` are what let a leaf be *derived* rather than authored.
    /// They were read off the grids emitted by
    /// `ArtSource/Processing/measure_city_door_apertures.py`, which also re-renders
    /// the recorded values back over the facade for confirmation.
    struct SourceDoorAperture {
        /// Horizontal centre of the opening.
        let centreX: CGFloat
        /// Threshold — the bottom of the opening, where a leaf's foot lands. This is
        /// *not* the facade's painted foot: entrances up a stoop sit well above it
        /// (`buildingTenement` is ~94 px up), which is exactly why it is measured.
        let thresholdY: CGFloat
        /// Clear opening height, threshold to lintel underside. Anchors display scale
        /// on cube facades; terrace world height is authored separately.
        let leafHeight: CGFloat
        /// Texture canvas the pixel coordinates are measured on.
        let canvas: CGSize

        init(
            centreX: CGFloat,
            thresholdY: CGFloat,
            leafHeight: CGFloat,
            canvas: CGSize = CGSize(width: 512, height: 640)
        ) {
            self.centreX = centreX
            self.thresholdY = thresholdY
            self.leafHeight = leafHeight
            self.canvas = canvas
        }

        // One entry per shipped `city_door_*` leaf. Buildings carrying two leaves
        // (the Voss stoop and its bay, the Lila Street paired entry) get one each.
        // Cube openings stay on 512×640 for the five districts that still use cubes.
        static let buildingVossStoop        = Self(centreX: 200, thresholdY: 488, leafHeight:  92)
        static let buildingVossStoopGarage  = Self(centreX: 365, thresholdY: 545, leafHeight:  75)
        static let buildingTenement         = Self(centreX: 268, thresholdY: 505, leafHeight:  74)
        static let buildingStorefront       = Self(centreX: 210, thresholdY: 508, leafHeight:  96)
        static let buildingRowhouse         = Self(centreX: 256, thresholdY: 545, leafHeight: 120)
        static let buildingShop             = Self(centreX: 256, thresholdY: 500, leafHeight:  80)
        static let buildingGatehouse        = Self(centreX: 250, thresholdY: 510, leafHeight: 120)
        static let buildingShippingOffice   = Self(centreX: 180, thresholdY: 500, leafHeight:  80)
        static let buildingWarehouse        = Self(centreX: 140, thresholdY: 520, leafHeight:  95)
        static let buildingBoarding         = Self(centreX: 197, thresholdY: 438, leafHeight:  66)
        static let buildingDockShed         = Self(centreX: 140, thresholdY: 460, leafHeight:  80)
        static let buildingLilaRooms        = Self(centreX: 180, thresholdY: 530, leafHeight:  98)
        static let buildingLilaRoomsB       = Self(centreX: 280, thresholdY: 540, leafHeight:  98)
        static let buildingLilaNeighbor     = Self(centreX: 203, thresholdY: 570, leafHeight: 114)
        static let buildingLilaOpposite     = Self(centreX: 232, thresholdY: 490, leafHeight: 102)
        static let buildingLilaAlcove       = Self(centreX: 211, thresholdY: 455, leafHeight: 115)
        static let buildingPDStation        = Self(centreX: 256, thresholdY: 520, leafHeight:  92)
        static let buildingPDAnnex          = Self(centreX: 166, thresholdY: 542, leafHeight: 130)
        static let buildingPDAlley          = Self(centreX: 142, thresholdY: 486, leafHeight: 104)
        static let buildingRecordsAnnex     = Self(centreX: 256, thresholdY: 500, leafHeight:  84)
        static let buildingRecordsWing      = Self(centreX: 145, thresholdY: 500, leafHeight:  88)
        static let buildingRecordsColonnade = Self(centreX: 250, thresholdY: 440, leafHeight:  68)
        static let buildingIronStairs       = Self(centreX: 292, thresholdY: 362, leafHeight: 128)
        static let buildingRiverWatch       = Self(centreX: 325, thresholdY: 440, leafHeight: 100)

        // Sable Row lot openings — texture pixels on the seated `city_sable_lot_*`
        // crop (2.00 px/unit). Threshold is the wall/paving split, not the old
        // L-terrace canvas: those mapped doors onto the sidewalk in front of the
        // finished block. Opening height 162 px = 81 wu = 1.15× adult.
        static let lotSableTenement = Self(
            centreX: 1_099, thresholdY: 1_998, leafHeight: 162, canvas: TerraceSpec.lotCanvas(for: .sableSW)
        )
        static let lotSableShop = Self(
            centreX: 1_535, thresholdY: 1_998, leafHeight: 162, canvas: TerraceSpec.lotCanvas(for: .sableSW)
        )
        static let lotSableGatehouse = Self(
            centreX: 848, thresholdY: 1_992, leafHeight: 162, canvas: TerraceSpec.lotCanvas(for: .sableSE)
        )
        static let lotSableVossStoop = Self(
            centreX: 1_554, thresholdY: 1_992, leafHeight: 162, canvas: TerraceSpec.lotCanvas(for: .sableSE)
        )
        static let lotSableVossGarage = Self(
            centreX: 1_828, thresholdY: 1_992, leafHeight: 162, canvas: TerraceSpec.lotCanvas(for: .sableSE)
        )
        static let lotSableStorefront = Self(
            centreX: 1_521, thresholdY: 1_603, leafHeight: 162, canvas: TerraceSpec.lotCanvas(for: .sableNW)
        )
        static let lotSableRowhouse = Self(
            centreX: 857, thresholdY: 1_574, leafHeight: 162, canvas: TerraceSpec.lotCanvas(for: .sableNE)
        )
    }

    /// Pairing for Sable leaves: terrace id + leaf texture, not `city_door_*`
    /// prefix vs the first `city_building_*` copy.
    static let terraceIDByLeafTexture: [String: TerraceID] = [
        "city_door_tenement": .sableSW,
        "city_door_shop": .sableSW,
        "city_door_gatehouse": .sableSE,
        "city_door_voss_stoop": .sableSE,
        "city_door_voss_stoop_garage": .sableSE,
        "city_door_storefront": .sableNW,
        "city_door_rowhouse": .sableNE
    ]

    /// Measured clear doorway opening heights (texture px). Anchors building display
    /// scale. Reads through `SourceDoorAperture` so an opening's height and its
    /// position cannot drift apart.
    enum SourceDoorLeafHeight {
        static var buildingVossStoop: CGFloat { SourceDoorAperture.buildingVossStoop.leafHeight }
        static var buildingTenement: CGFloat { SourceDoorAperture.buildingTenement.leafHeight }
        static var buildingStorefront: CGFloat { SourceDoorAperture.buildingStorefront.leafHeight }
        static var buildingRowhouse: CGFloat { SourceDoorAperture.buildingRowhouse.leafHeight }
        static var buildingShop: CGFloat { SourceDoorAperture.buildingShop.leafHeight }
        static var buildingGatehouse: CGFloat { SourceDoorAperture.buildingGatehouse.leafHeight }
        static var buildingShippingOffice: CGFloat { SourceDoorAperture.buildingShippingOffice.leafHeight }
        static var buildingWarehouse: CGFloat { SourceDoorAperture.buildingWarehouse.leafHeight }
        static var buildingBoarding: CGFloat { SourceDoorAperture.buildingBoarding.leafHeight }
        static var buildingDockShed: CGFloat { SourceDoorAperture.buildingDockShed.leafHeight }
        static var buildingLilaRooms: CGFloat { SourceDoorAperture.buildingLilaRooms.leafHeight }
        static var buildingLilaNeighbor: CGFloat { SourceDoorAperture.buildingLilaNeighbor.leafHeight }
        static var buildingLilaOpposite: CGFloat { SourceDoorAperture.buildingLilaOpposite.leafHeight }
        static var buildingLilaAlcove: CGFloat { SourceDoorAperture.buildingLilaAlcove.leafHeight }
        static var buildingPDStation: CGFloat { SourceDoorAperture.buildingPDStation.leafHeight }
        static var buildingPDAnnex: CGFloat { SourceDoorAperture.buildingPDAnnex.leafHeight }
        static var buildingPDAlley: CGFloat { SourceDoorAperture.buildingPDAlley.leafHeight }
        static var buildingRecordsAnnex: CGFloat { SourceDoorAperture.buildingRecordsAnnex.leafHeight }
        static var buildingRecordsWing: CGFloat { SourceDoorAperture.buildingRecordsWing.leafHeight }
        static var buildingRecordsColonnade: CGFloat { SourceDoorAperture.buildingRecordsColonnade.leafHeight }
        static var buildingIronStairs: CGFloat { SourceDoorAperture.buildingIronStairs.leafHeight }
        static var buildingRiverWatch: CGFloat { SourceDoorAperture.buildingRiverWatch.leafHeight }
    }

    /// Measured opaque heights of separate `city_door_*` leaf textures (texture px).
    /// Every shipped leaf fits the same 256x384 canvas, so both bands share a height;
    /// `wide` stays distinct because it names the bay leaves, not a different size.
    enum SourceSeparateDoorLeafHeight {
        static let standard: CGFloat = 275
        static let wide: CGFloat = 275
    }

    /// Door-anchored display scales: `targetDoorBodyMultiple × adult / doorLeafPx`.
    enum BuildingDisplayScale {
        static let vossStoop = doorAnchoredScale(doorLeaf: SourceDoorLeafHeight.buildingVossStoop)
        static let tenement = doorAnchoredScale(doorLeaf: SourceDoorLeafHeight.buildingTenement)
        static let storefront = doorAnchoredScale(doorLeaf: SourceDoorLeafHeight.buildingStorefront)
        static let rowhouse = doorAnchoredScale(doorLeaf: SourceDoorLeafHeight.buildingRowhouse)
        static let shop = doorAnchoredScale(doorLeaf: SourceDoorLeafHeight.buildingShop)
        static let gatehouse = doorAnchoredScale(doorLeaf: SourceDoorLeafHeight.buildingGatehouse)
        static let shippingOffice = doorAnchoredScale(doorLeaf: SourceDoorLeafHeight.buildingShippingOffice)
        static let warehouse = doorAnchoredScale(doorLeaf: SourceDoorLeafHeight.buildingWarehouse)
        static let boarding = doorAnchoredScale(doorLeaf: SourceDoorLeafHeight.buildingBoarding)
        static let dockShed = doorAnchoredScale(doorLeaf: SourceDoorLeafHeight.buildingDockShed)
        static let lilaRooms = doorAnchoredScale(doorLeaf: SourceDoorLeafHeight.buildingLilaRooms)
        static let lilaNeighbor = doorAnchoredScale(doorLeaf: SourceDoorLeafHeight.buildingLilaNeighbor)
        static let lilaOpposite = doorAnchoredScale(doorLeaf: SourceDoorLeafHeight.buildingLilaOpposite)
        static let lilaAlcove = doorAnchoredScale(doorLeaf: SourceDoorLeafHeight.buildingLilaAlcove)
        static let pdStation = doorAnchoredScale(doorLeaf: SourceDoorLeafHeight.buildingPDStation)
        static let pdAnnex = doorAnchoredScale(doorLeaf: SourceDoorLeafHeight.buildingPDAnnex)
        static let pdAlley = doorAnchoredScale(doorLeaf: SourceDoorLeafHeight.buildingPDAlley)
        /// Low plaza wall chunk — no door; match ~7× adult facade.
        static let pdPlazaWall = facadeAnchoredScale(contentHeight: 232)
        static let recordsAnnex = doorAnchoredScale(doorLeaf: SourceDoorLeafHeight.buildingRecordsAnnex)
        static let recordsWing = doorAnchoredScale(doorLeaf: SourceDoorLeafHeight.buildingRecordsWing)
        static let recordsColonnade = doorAnchoredScale(doorLeaf: SourceDoorLeafHeight.buildingRecordsColonnade)
        static let recordsPlaza = facadeAnchoredScale(contentHeight: 284)
        /// Corner block with no painted opening — the piece that turns a
        /// terrace through 90°, which is how a block gets a corner instead of
        /// two rows meeting at a seam.
        static let rowCorner = facadeAnchoredScale(contentHeight: 543)
        static let ironStairs = doorAnchoredScale(doorLeaf: SourceDoorLeafHeight.buildingIronStairs)
        static let riverWatch = doorAnchoredScale(doorLeaf: SourceDoorLeafHeight.buildingRiverWatch)
        static let railLamp = facadeAnchoredScale(contentHeight: 472)
        static let abutment = facadeAnchoredScale(contentHeight: 470)
    }

    /// Separate outdoor door leaves — door-anchored to clear Voss at ~1.15× adult.
    enum DoorDisplayScale {
        static let standard = doorAnchoredScale(doorLeaf: SourceSeparateDoorLeafHeight.standard)
        static let wide = doorAnchoredScale(doorLeaf: SourceSeparateDoorLeafHeight.wide)
    }

    /// Street props stay human-scale vs Voss (cars intentionally not scaled with buildings).
    /// Unlike the building scales these are fixed absolutes and do **not** re-derive
    /// from `standingAdultBodyHeight`, so they are retuned by hand against real
    /// object heights normalized to a 1.75 m adult.
    enum PropDisplayScale {
        /// Sedan roof ~1.6 m → 0.95× body (was 0.32, reading 1.26× / 2.2 m).
        static let car: CGFloat = 0.242
        static let carSpoke: CGFloat = 0.265
        /// Street lamp ~4.1 m → 2.34× body. Already correct; left alone.
        static let lampHub: CGFloat = 0.40
        static let lampSpoke: CGFloat = 0.47
        /// Park bench back ~1.05 m → 0.60× body (was 0.32, reading 1.25× / 2.2 m —
        /// a bench taller than the man sitting on it).
        static let bench: CGFloat = 0.1534
        static let benchSpoke: CGFloat = 0.1918
        /// Newsstand kiosk ~2.45 m → 1.40× body.
        static let kiosk: CGFloat = 0.357
        static let gate: CGFloat = 0.38
        static let statue: CGFloat = 0.42
        static let statueSpoke: CGFloat = 0.50
        static let crates: CGFloat = 0.36
        static let cratesSpoke: CGFloat = 0.42
    }

    enum Band {
        /// Painted doorway leaf vs standing adult — must clear Voss.
        static let doorLeaf: ClosedRange<CGFloat> = 1.05...1.35
        /// Multi-story / landmark facade (door-anchored; low gatehouses sit near the floor).
        static let multiStoryBuilding: ClosedRange<CGFloat> = 3.0...12.0
        static let car: ClosedRange<CGFloat> = 0.82...1.05
        static let streetLamp: ClosedRange<CGFloat> = 1.80...2.90
        /// Was 0.50…1.50 — loose enough to pass a 2.2 m bench.
        static let bench: ClosedRange<CGFloat> = 0.50...0.75
        static let kiosk: ClosedRange<CGFloat> = 1.00...2.20
    }

    // MARK: - Registering leaves to openings

    /// Every shipped leaf and the aperture it fills. The catalog names its aperture
    /// explicitly at each call site; this is the same pairing in walkable form, for
    /// tooling and for the tests that check no leaf has drifted off its opening.
    static let aperturesByLeafTexture: [String: SourceDoorAperture] = [
        "city_door_voss_stoop":        .lotSableVossStoop,
        "city_door_voss_stoop_garage": .lotSableVossGarage,
        "city_door_tenement":          .lotSableTenement,
        "city_door_storefront":        .lotSableStorefront,
        "city_door_rowhouse":          .lotSableRowhouse,
        "city_door_shop":              .lotSableShop,
        "city_door_gatehouse":         .lotSableGatehouse,
        "city_door_shipping_office":   .buildingShippingOffice,
        "city_door_warehouse":         .buildingWarehouse,
        "city_door_boarding":          .buildingBoarding,
        "city_door_dock_shed":         .buildingDockShed,
        "city_door_lila_rooms":        .buildingLilaRooms,
        "city_door_lila_rooms_b":      .buildingLilaRoomsB,
        "city_door_lila_neighbor":     .buildingLilaNeighbor,
        "city_door_lila_opposite":     .buildingLilaOpposite,
        "city_door_lila_alcove":       .buildingLilaAlcove,
        "city_door_pd_station":        .buildingPDStation,
        "city_door_pd_annex":          .buildingPDAnnex,
        "city_door_pd_alley":          .buildingPDAlley,
        "city_door_records_annex":     .buildingRecordsAnnex,
        "city_door_records_wing":      .buildingRecordsWing,
        "city_door_records_colonnade": .buildingRecordsColonnade,
        "city_door_iron_stairs":       .buildingIronStairs,
        "city_door_river_watch":       .buildingRiverWatch
    ]

    /// Shipped texture canvases (`process_city_districts_v02.py` fits every facade
    /// to 512x640 and every leaf to 256x384).
    static let buildingCanvas = CGSize(width: 512, height: 640)
    static let doorCanvas = CGSize(width: 256, height: 384)
    /// `fit_canvas` bottom-aligns content with a 4 px margin, so a leaf's painted
    /// threshold sits 4 px above its canvas bottom.
    static let doorCanvasFootInset: CGFloat = 4

    /// Anchor that puts a leaf's own painted threshold on its `groundPoint`, so the
    /// authored point *is* the aperture rather than an offset from it.
    static var doorLeafAnchorY: CGFloat { doorCanvasFootInset / doorCanvas.height }

    /// World position of a texture-canvas pixel (origin top-left) on a placed sprite.
    ///
    /// `anchorY` is a fraction of the **full canvas**, transparent padding included,
    /// so a sprite's painted foot can sit far below its `groundPoint` — 85-100 units
    /// for a facade, 4 for a leaf. Going through canvas pixels is what keeps the two
    /// comparable; offsets eyeballed between `groundPoint`s are not.
    static func worldPoint(canvasPixel pixel: CGPoint, canvas: CGSize, sprite: VisualSprite) -> CGPoint {
        let scaleX: CGFloat
        let scaleY: CGFloat
        if let worldSize = sprite.worldSize, canvas.width > 0, canvas.height > 0 {
            scaleX = worldSize.width / canvas.width
            scaleY = worldSize.height / canvas.height
        } else {
            scaleX = sprite.scale
            scaleY = sprite.scale
        }
        let canvasBottomY = sprite.groundPoint.y - sprite.anchorY * canvas.height * scaleY
        return CGPoint(
            x: sprite.groundPoint.x + (pixel.x - canvas.width / 2) * scaleX,
            y: canvasBottomY + (canvas.height - pixel.y) * scaleY
        )
    }

    /// World point of a facade's painted doorway threshold.
    static func aperturePoint(of aperture: SourceDoorAperture, on building: VisualSprite) -> CGPoint {
        worldPoint(
            canvasPixel: CGPoint(x: aperture.centreX, y: aperture.thresholdY),
            canvas: aperture.canvas,
            sprite: building
        )
    }

    /// Facade a leaf is registered to. Terrace leaves pair by `TerraceID`; cube
    /// leaves narrow by the `city_door_*` / `city_building_*` name stem and then
    /// settle it on geometry.
    ///
    /// The name stem alone is not an answer once a district repeats a texture,
    /// and they all do now — a dock quarter is warehouses, so `wharf_ladder`
    /// carries a dozen `city_building_warehouse` copies with one door between
    /// them. Picking by name returned whichever copy happened to sort last.
    /// The leaf's `groundPoint` *is* its facade's aperture point, so asking
    /// which candidate's aperture the leaf is standing in front of names the
    /// right one however many copies there are.
    static func facade(
        forLeafTexture name: String,
        in district: CityDistrictDefinition
    ) -> VisualSprite? {
        if let terraceID = terraceIDByLeafTexture[name] {
            return district.visualSprites.first { $0.textureName == terraceID.lotTextureName }
                ?? TerraceSpec.lotSprite(terraceID)
        }
        let stem = Self.strippingPrefix("city_door_", from: name)
        let candidates = district.visualSprites
            .filter { $0.textureName.hasPrefix("city_building_") }
            .filter {
                let base = Self.strippingPrefix("city_building_", from: $0.textureName)
                return stem == base || stem.hasPrefix(base + "_")
            }
        guard candidates.count > 1 else { return candidates.first }
        guard let aperture = aperturesByLeafTexture[name],
              let leaf = district.visualSprites.first(where: { $0.textureName == name })
        else {
            return candidates.max { $0.textureName.count < $1.textureName.count }
        }
        return candidates.min {
            Self.squaredDistance(aperturePoint(of: aperture, on: $0), leaf.groundPoint)
                < Self.squaredDistance(aperturePoint(of: aperture, on: $1), leaf.groundPoint)
        }
    }

    private static func squaredDistance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        let dx = a.x - b.x
        let dy = a.y - b.y
        return dx * dx + dy * dy
    }

    private static func strippingPrefix(_ prefix: String, from name: String) -> String {
        name.hasPrefix(prefix) ? String(name.dropFirst(prefix.count)) : name
    }

    /// A closed leaf registered to its building's opening.
    ///
    /// The leaf is anchored on its own threshold and dropped straight onto the
    /// aperture, so nothing is hand-authored and the pair cannot drift apart.
    ///
    /// `depthBias` is derived rather than passed: an entrance up a stoop puts the
    /// leaf *above* its facade's `groundPoint`, and `BaseGameScene.updateDepth`
    /// sorts by `(artHeight - y) * 0.5 + bias`, so a higher leaf would otherwise
    /// sort behind the wall it is set into. Cancelling the y difference and adding
    /// `ahead` leaves the leaf exactly that far in front, wherever the opening sits.
    static func doorLeaf(
        textureName: String,
        on building: VisualSprite,
        aperture: SourceDoorAperture,
        scale: CGFloat = DoorDisplayScale.standard,
        ahead: CGFloat = 1
    ) -> VisualSprite {
        let groundPoint = aperturePoint(of: aperture, on: building)
        let depthBias = building.depthBias
            + (groundPoint.y - building.groundPoint.y) * 0.5
            + ahead
        return VisualSprite(
            textureName: textureName,
            groundPoint: groundPoint,
            scale: scale,
            anchorY: doorLeafAnchorY,
            depthBias: depthBias
        )
    }

    // MARK: - Portals derived from the door they open

    /// Widest and tallest painted leaf in the shipped set, in canvas pixels.
    ///
    /// Every one of the 24 leaves is horizontally centred to within a pixel and
    /// bottom-aligned to 4–8 px, so one box sized off the largest covers any of
    /// them. That is what lets a portal be derived from its leaf instead of
    /// hand-typed beside it — which is how Sable Row once ended up with a hit
    /// area covering 28 % of its own apartment door.
    static let widestDoorLeafContent = CGSize(width: 184, height: 276)

    /// Clickable area over a placed leaf. The leaf is anchored on its painted
    /// threshold, so the box hangs from `groundPoint` and rises with the door.
    static func portalHitArea(
        forLeaf leaf: VisualSprite,
        pad: CGFloat = 10
    ) -> CGRect {
        let width = widestDoorLeafContent.width * leaf.scale + pad * 2
        let height = widestDoorLeafContent.height * leaf.scale + pad * 2
        return CGRect(
            x: leaf.groundPoint.x - width / 2,
            y: leaf.groundPoint.y - doorCanvasFootInset * leaf.scale - pad,
            width: width,
            height: height
        )
    }

    /// Walk-up point on the street the door faces.
    ///
    /// Stepping out from the threshold until the point clears the district's
    /// own obstacles — rather than authoring an offset — is what keeps an
    /// approach reachable when a facade moves. Every city approach was
    /// unreachable once before, because they had been authored inside the
    /// building's own obstacle.
    ///
    /// It must be tested against the *shipped rects*, not against the painted
    /// block: the two differ wherever a street is tiered onto the kerb, and a
    /// district can add its own water or quay. Testing the painted diamond put
    /// Riverside's stairs approach in the river and Wharf Ladder's inside a
    /// block.
    ///
    /// Camera-near is tried first because that is where a Baldur's Gate door
    /// faces, with a small lateral fan for the doors that open onto a corner.
    static func portalApproach(
        forLeaf leaf: VisualSprite,
        clearOf obstacles: [CGRect],
        minimumOffset: CGFloat = 140,
        clearance: CGFloat = 24
    ) -> CGPoint {
        let laterals: [CGFloat] = [0, -50, 50, -110, 110, -180, 180, -260, 260]
        // Camera-near first, then camera-far. A waterfront building has no
        // standable ground in front of it — you reach the top of Riverside's
        // stairs from the street behind them.
        let senses: [CGFloat] = [-1, 1]
        var offset = minimumOffset
        while offset < 1_000 {
            for sense in senses {
                for lateral in laterals {
                    let candidate = CGPoint(
                        x: leaf.groundPoint.x + lateral,
                        y: leaf.groundPoint.y + sense * offset
                    )
                    if isClearGround(candidate, of: obstacles, clearance: clearance) {
                        return candidate
                    }
                }
            }
            offset += 12
        }
        return CGPoint(x: leaf.groundPoint.x, y: leaf.groundPoint.y - minimumOffset)
    }

    /// Standable, and standable for the actor's whole footprint rather than
    /// only at its centre.
    static func isClearGround(
        _ point: CGPoint,
        of obstacles: [CGRect],
        clearance: CGFloat
    ) -> Bool {
        let probes = [
            point,
            CGPoint(x: point.x - clearance, y: point.y),
            CGPoint(x: point.x + clearance, y: point.y),
            CGPoint(x: point.x, y: point.y - clearance),
            CGPoint(x: point.x, y: point.y + clearance)
        ]
        return probes.allSatisfy { probe in
            CityDistrictDefinition.worldBounds.insetBy(dx: 24, dy: 24).contains(probe)
                && !obstacles.contains { $0.contains(probe) }
        }
    }

    /// Painted rect of a placed sprite, given its opaque bbox in canvas pixels.
    static func paintedRect(
        of sprite: VisualSprite,
        canvas: CGSize,
        contentX: ClosedRange<CGFloat>,
        contentY: ClosedRange<CGFloat>
    ) -> CGRect {
        let topLeft = worldPoint(
            canvasPixel: CGPoint(x: contentX.lowerBound, y: contentY.lowerBound),
            canvas: canvas, sprite: sprite
        )
        let bottomRight = worldPoint(
            canvasPixel: CGPoint(x: contentX.upperBound, y: contentY.upperBound),
            canvas: canvas, sprite: sprite
        )
        return CGRect(
            x: topLeft.x, y: bottomRight.y,
            width: bottomRight.x - topLeft.x, height: topLeft.y - bottomRight.y
        )
    }

    /// Scale so a measured door leaf lands on `targetDoorBodyMultiple` of the adult.
    static func doorAnchoredScale(doorLeaf: CGFloat) -> CGFloat {
        guard doorLeaf > 0 else { return 1 }
        let raw = (targetDoorBodyMultiple * standingAdultBodyHeight) / doorLeaf
        return (raw * 100).rounded() / 100
    }

    /// Scale so opaque facade height lands near 7× adult (doorless chunks).
    static func facadeAnchoredScale(contentHeight: CGFloat, bodyMultiple: CGFloat = 7.0) -> CGFloat {
        guard contentHeight > 0 else { return 1 }
        let raw = (bodyMultiple * standingAdultBodyHeight) / contentHeight
        return (raw * 100).rounded() / 100
    }

    static func representativeScale(forTextureName name: String) -> CGFloat? {
        visualSprites.first(where: { $0.textureName == name })?.scale
    }

    /// Representative scale for a texture across any Act I district (hub + spokes).
    static func anyDistrictScale(forTextureName name: String) -> CGFloat? {
        for id in CityDistrictID.allCases {
            if let scale = CityDistrictCatalog.definition(for: id).visualSprites
                .first(where: { $0.textureName == name })?.scale {
                return scale
            }
        }
        return nil
    }

    static func displayHeight(contentHeight: CGFloat, scale: CGFloat) -> CGFloat {
        contentHeight * scale
    }

    static func bodyMultiple(contentHeight: CGFloat, scale: CGFloat) -> CGFloat {
        displayHeight(contentHeight: contentHeight, scale: scale) / standingAdultBodyHeight
    }

    static func bodyMultiple(contentHeight: CGFloat, textureName: String) -> CGFloat? {
        guard let scale = representativeScale(forTextureName: textureName)
            ?? anyDistrictScale(forTextureName: textureName) else { return nil }
        return bodyMultiple(contentHeight: contentHeight, scale: scale)
    }

    static func doorBodyMultiple(doorLeafHeight: CGFloat, textureName: String) -> CGFloat? {
        guard let scale = representativeScale(forTextureName: textureName)
            ?? anyDistrictScale(forTextureName: textureName) else { return nil }
        return bodyMultiple(contentHeight: doorLeafHeight, scale: scale)
    }

    static func makeGrid() -> NavigationMap {
        CityDistrictCatalog.sableRow.makeGrid()
    }

    static func isBlocked(_ point: CGPoint) -> Bool {
        obstacles.contains { $0.contains(point) }
    }
}

/// Every shipped city facade, with the scale and ground anchor it is placed at.
///
/// These two numbers used to be retyped at each of the ~50 call sites in
/// `CityDistrictCatalog`, so the same texture could and did sit at different
/// anchors in different districts. `anchorY` is the building's near base
/// corner — the point that has to land on a kerb — so it belongs to the
/// texture, not to the placement.
extension CityDistrictLayout.FrontageModule {
    static func shippingOffice(at t: CGFloat, depthBias: CGFloat = 0) -> Self {
        Self("city_building_shipping_office", scale: CityDistrictLayout.BuildingDisplayScale.shippingOffice, anchorY: 0.10, at: t, depthBias: depthBias)
    }

    static func warehouse(at t: CGFloat, depthBias: CGFloat = 0) -> Self {
        Self("city_building_warehouse", scale: CityDistrictLayout.BuildingDisplayScale.warehouse, anchorY: 0.10, at: t, depthBias: depthBias)
    }

    static func boarding(at t: CGFloat, depthBias: CGFloat = 0) -> Self {
        Self("city_building_boarding", scale: CityDistrictLayout.BuildingDisplayScale.boarding, anchorY: 0.12, at: t, depthBias: depthBias)
    }

    static func dockShed(at t: CGFloat, depthBias: CGFloat = 0) -> Self {
        Self("city_building_dock_shed", scale: CityDistrictLayout.BuildingDisplayScale.dockShed, anchorY: 0.16, at: t, depthBias: depthBias)
    }

    static func ironStairs(at t: CGFloat, depthBias: CGFloat = 0) -> Self {
        Self("city_building_iron_stairs", scale: CityDistrictLayout.BuildingDisplayScale.ironStairs, anchorY: 0.08, at: t, depthBias: depthBias)
    }

    static func riverWatch(at t: CGFloat, depthBias: CGFloat = 0) -> Self {
        Self("city_building_river_watch", scale: CityDistrictLayout.BuildingDisplayScale.riverWatch, anchorY: 0.14, at: t, depthBias: depthBias)
    }

    static func railLamp(at t: CGFloat, depthBias: CGFloat = 0) -> Self {
        Self("city_building_rail_lamp", scale: CityDistrictLayout.BuildingDisplayScale.railLamp, anchorY: 0.14, at: t, depthBias: depthBias)
    }

    static func abutment(at t: CGFloat, depthBias: CGFloat = 0) -> Self {
        Self("city_building_abutment", scale: CityDistrictLayout.BuildingDisplayScale.abutment, anchorY: 0.16, at: t, depthBias: depthBias)
    }

    static func pdStation(at t: CGFloat, depthBias: CGFloat = 0) -> Self {
        Self("city_building_pd_station", scale: CityDistrictLayout.BuildingDisplayScale.pdStation, anchorY: 0.10, at: t, depthBias: depthBias)
    }

    static func pdAnnex(at t: CGFloat, depthBias: CGFloat = 0) -> Self {
        Self("city_building_pd_annex", scale: CityDistrictLayout.BuildingDisplayScale.pdAnnex, anchorY: 0.12, at: t, depthBias: depthBias)
    }

    static func pdAlley(at t: CGFloat, depthBias: CGFloat = 0) -> Self {
        Self("city_building_pd_alley", scale: CityDistrictLayout.BuildingDisplayScale.pdAlley, anchorY: 0.14, at: t, depthBias: depthBias)
    }

    static func pdPlazaWall(at t: CGFloat, depthBias: CGFloat = 0) -> Self {
        Self("city_building_pd_plaza_wall", scale: CityDistrictLayout.BuildingDisplayScale.pdPlazaWall, anchorY: 0.18, at: t, depthBias: depthBias)
    }

    static func lilaRooms(at t: CGFloat, depthBias: CGFloat = 0) -> Self {
        Self("city_building_lila_rooms", scale: CityDistrictLayout.BuildingDisplayScale.lilaRooms, anchorY: 0.10, at: t, depthBias: depthBias)
    }

    static func lilaNeighbor(at t: CGFloat, depthBias: CGFloat = 0) -> Self {
        Self("city_building_lila_neighbor", scale: CityDistrictLayout.BuildingDisplayScale.lilaNeighbor, anchorY: 0.12, at: t, depthBias: depthBias)
    }

    static func lilaOpposite(at t: CGFloat, depthBias: CGFloat = 0) -> Self {
        Self("city_building_lila_opposite", scale: CityDistrictLayout.BuildingDisplayScale.lilaOpposite, anchorY: 0.12, at: t, depthBias: depthBias)
    }

    static func lilaAlcove(at t: CGFloat, depthBias: CGFloat = 0) -> Self {
        Self("city_building_lila_alcove", scale: CityDistrictLayout.BuildingDisplayScale.lilaAlcove, anchorY: 0.16, at: t, depthBias: depthBias)
    }

    static func recordsAnnex(at t: CGFloat, depthBias: CGFloat = 0) -> Self {
        Self("city_building_records_annex", scale: CityDistrictLayout.BuildingDisplayScale.recordsAnnex, anchorY: 0.10, at: t, depthBias: depthBias)
    }

    static func recordsWing(at t: CGFloat, depthBias: CGFloat = 0) -> Self {
        Self("city_building_records_wing", scale: CityDistrictLayout.BuildingDisplayScale.recordsWing, anchorY: 0.12, at: t, depthBias: depthBias)
    }

    static func recordsColonnade(at t: CGFloat, depthBias: CGFloat = 0) -> Self {
        Self("city_building_records_colonnade", scale: CityDistrictLayout.BuildingDisplayScale.recordsColonnade, anchorY: 0.12, at: t, depthBias: depthBias)
    }

    static func recordsPlaza(at t: CGFloat, depthBias: CGFloat = 0) -> Self {
        Self("city_building_records_plaza", scale: CityDistrictLayout.BuildingDisplayScale.recordsPlaza, anchorY: 0.18, at: t, depthBias: depthBias)
    }

    static func tenement(at t: CGFloat, depthBias: CGFloat = 0) -> Self {
        Self("city_building_tenement", scale: CityDistrictLayout.BuildingDisplayScale.tenement, anchorY: 0.12, at: t, depthBias: depthBias)
    }

    static func storefront(at t: CGFloat, depthBias: CGFloat = 0) -> Self {
        Self("city_building_storefront", scale: CityDistrictLayout.BuildingDisplayScale.storefront, anchorY: 0.12, at: t, depthBias: depthBias)
    }

    static func rowhouse(at t: CGFloat, depthBias: CGFloat = 0) -> Self {
        Self("city_building_rowhouse", scale: CityDistrictLayout.BuildingDisplayScale.rowhouse, anchorY: 0.12, at: t, depthBias: depthBias)
    }

    static func shop(at t: CGFloat, depthBias: CGFloat = 0) -> Self {
        Self("city_building_shop", scale: CityDistrictLayout.BuildingDisplayScale.shop, anchorY: 0.14, at: t, depthBias: depthBias)
    }

    static func gatehouse(at t: CGFloat, depthBias: CGFloat = 0) -> Self {
        Self("city_building_gatehouse", scale: CityDistrictLayout.BuildingDisplayScale.gatehouse, anchorY: 0.16, at: t, depthBias: depthBias)
    }

    static func vossStoop(at t: CGFloat, depthBias: CGFloat = 0) -> Self {
        Self("city_building_voss_stoop", scale: CityDistrictLayout.BuildingDisplayScale.vossStoop, anchorY: 0.10, at: t, depthBias: depthBias)
    }

    static func rowCorner(at t: CGFloat, depthBias: CGFloat = 0) -> Self {
        Self("city_building_row_corner", scale: CityDistrictLayout.BuildingDisplayScale.rowCorner, anchorY: 0.12, at: t, depthBias: depthBias)
    }
}
