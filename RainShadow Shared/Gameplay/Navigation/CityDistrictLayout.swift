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
        static let carBlack: CGFloat = 276
        static let carOlive: CGFloat = 274
        static let carMaroon: CGFloat = 274
        static let lamp: CGFloat = 412
        static let bench: CGFloat = 275
        static let kiosk: CGFloat = 276
    }

    /// A facade's painted doorway opening, measured in **texture-canvas pixels**
    /// on the shipped 512x640 building canvas with the origin at the top-left.
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
        /// Clear opening height, threshold to lintel underside. Anchors display scale.
        let leafHeight: CGFloat

        // One entry per shipped `city_door_*` leaf. Buildings carrying two leaves
        // (the Voss stoop and its bay, the Lila Street paired entry) get one each.
        static let buildingVossStoop        = Self(centreX: 212, thresholdY: 480, leafHeight:  92)
        static let buildingVossStoopGarage  = Self(centreX: 375, thresholdY: 520, leafHeight:  75)
        static let buildingTenement         = Self(centreX: 275, thresholdY: 482, leafHeight:  74)
        static let buildingStorefront       = Self(centreX: 210, thresholdY: 508, leafHeight:  96)
        static let buildingRowhouse         = Self(centreX: 295, thresholdY: 535, leafHeight: 120)
        static let buildingShop             = Self(centreX: 280, thresholdY: 455, leafHeight:  80)
        static let buildingGatehouse        = Self(centreX: 265, thresholdY: 505, leafHeight: 120)
        static let buildingShippingOffice   = Self(centreX: 120, thresholdY: 450, leafHeight:  80)
        static let buildingWarehouse        = Self(centreX: 135, thresholdY: 535, leafHeight:  95)
        static let buildingBoarding         = Self(centreX: 197, thresholdY: 438, leafHeight:  66)
        static let buildingDockShed         = Self(centreX: 140, thresholdY: 460, leafHeight:  80)
        static let buildingLilaRooms        = Self(centreX: 129, thresholdY: 525, leafHeight:  98)
        static let buildingLilaRoomsB       = Self(centreX: 249, thresholdY: 560, leafHeight:  98)
        static let buildingLilaNeighbor     = Self(centreX: 203, thresholdY: 570, leafHeight: 114)
        static let buildingLilaOpposite     = Self(centreX: 232, thresholdY: 490, leafHeight: 102)
        static let buildingLilaAlcove       = Self(centreX: 211, thresholdY: 455, leafHeight: 115)
        static let buildingPDStation        = Self(centreX: 250, thresholdY: 532, leafHeight:  92)
        static let buildingPDAnnex          = Self(centreX: 166, thresholdY: 542, leafHeight: 130)
        static let buildingPDAlley          = Self(centreX: 142, thresholdY: 486, leafHeight: 104)
        static let buildingRecordsAnnex     = Self(centreX: 250, thresholdY: 466, leafHeight:  84)
        static let buildingRecordsWing      = Self(centreX: 145, thresholdY: 500, leafHeight:  88)
        static let buildingRecordsColonnade = Self(centreX: 250, thresholdY: 440, leafHeight:  68)
        static let buildingIronStairs       = Self(centreX: 292, thresholdY: 362, leafHeight: 128)
        static let buildingRiverWatch       = Self(centreX: 325, thresholdY: 440, leafHeight: 100)
    }

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
        /// Multi-story / landmark facade (door-anchored; low gatehouses may sit near floor).
        static let multiStoryBuilding: ClosedRange<CGFloat> = 3.5...12.0
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
        "city_door_voss_stoop":        .buildingVossStoop,
        "city_door_voss_stoop_garage": .buildingVossStoopGarage,
        "city_door_tenement":          .buildingTenement,
        "city_door_storefront":        .buildingStorefront,
        "city_door_rowhouse":          .buildingRowhouse,
        "city_door_shop":              .buildingShop,
        "city_door_gatehouse":         .buildingGatehouse,
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
        let canvasBottomY = sprite.groundPoint.y - sprite.anchorY * canvas.height * sprite.scale
        return CGPoint(
            x: sprite.groundPoint.x + (pixel.x - canvas.width / 2) * sprite.scale,
            y: canvasBottomY + (canvas.height - pixel.y) * sprite.scale
        )
    }

    /// World point of a facade's painted doorway threshold.
    static func aperturePoint(of aperture: SourceDoorAperture, on building: VisualSprite) -> CGPoint {
        worldPoint(
            canvasPixel: CGPoint(x: aperture.centreX, y: aperture.thresholdY),
            canvas: buildingCanvas,
            sprite: building
        )
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
