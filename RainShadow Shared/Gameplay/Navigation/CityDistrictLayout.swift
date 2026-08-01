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
    /// Slightly above rendered Voss (~1.1× logical adult) so entrances read enterable.
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
        static let buildingVossStoop: CGFloat = 491
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

    /// Measured painted door-leaf heights (threshold → lintel underside, texture px).
    /// Used for door-anchored runtime scale; not the full facade opaque height.
    enum SourceDoorLeafHeight {
        static let buildingVossStoop: CGFloat = 83
        static let buildingTenement: CGFloat = 62
        static let buildingStorefront: CGFloat = 64
        static let buildingRowhouse: CGFloat = 65
        static let buildingShop: CGFloat = 87
        static let buildingGatehouse: CGFloat = 90
        static let buildingShippingOffice: CGFloat = 100
        static let buildingWarehouse: CGFloat = 75
        static let buildingBoarding: CGFloat = 75
        static let buildingDockShed: CGFloat = 75
        static let buildingLilaRooms: CGFloat = 85
        static let buildingLilaNeighbor: CGFloat = 75
        static let buildingLilaOpposite: CGFloat = 75
        static let buildingLilaAlcove: CGFloat = 80
        static let buildingPDStation: CGFloat = 48
        static let buildingPDAnnex: CGFloat = 85
        static let buildingPDAlley: CGFloat = 80
        static let buildingRecordsAnnex: CGFloat = 90
        static let buildingRecordsWing: CGFloat = 80
        static let buildingRecordsColonnade: CGFloat = 80
        static let buildingIronStairs: CGFloat = 80
        static let buildingRiverWatch: CGFloat = 75
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
        static let pdPlazaWall = facadeAnchoredScale(contentHeight: 381)
        static let recordsAnnex = doorAnchoredScale(doorLeaf: SourceDoorLeafHeight.buildingRecordsAnnex)
        static let recordsWing = doorAnchoredScale(doorLeaf: SourceDoorLeafHeight.buildingRecordsWing)
        static let recordsColonnade = doorAnchoredScale(doorLeaf: SourceDoorLeafHeight.buildingRecordsColonnade)
        static let recordsPlaza = facadeAnchoredScale(contentHeight: 472)
        static let ironStairs = doorAnchoredScale(doorLeaf: SourceDoorLeafHeight.buildingIronStairs)
        static let riverWatch = doorAnchoredScale(doorLeaf: SourceDoorLeafHeight.buildingRiverWatch)
        static let railLamp = facadeAnchoredScale(contentHeight: 472)
        static let abutment = facadeAnchoredScale(contentHeight: 453)
    }

    /// Street props stay human-scale vs Voss (cars intentionally not scaled with buildings).
    enum PropDisplayScale {
        static let car: CGFloat = 0.32
        static let carSpoke: CGFloat = 0.35
        static let lampHub: CGFloat = 0.40
        static let lampSpoke: CGFloat = 0.48
        static let bench: CGFloat = 0.32
        static let benchSpoke: CGFloat = 0.40
        static let kiosk: CGFloat = 0.38
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
        static let car: ClosedRange<CGFloat> = 0.90...1.30
        static let streetLamp: ClosedRange<CGFloat> = 1.80...2.80
        static let bench: ClosedRange<CGFloat> = 0.50...1.50
        static let kiosk: ClosedRange<CGFloat> = 1.00...2.20
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

    static func makeGrid() -> NavigationGrid {
        CityDistrictCatalog.sableRow.makeGrid()
    }

    static func isBlocked(_ point: CGPoint) -> Bool {
        obstacles.contains { $0.contains(point) }
    }
}
