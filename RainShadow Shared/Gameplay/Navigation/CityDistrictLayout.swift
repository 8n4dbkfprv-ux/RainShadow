import CoreGraphics

/// Compatibility facade for Sable Row hub metrics. Prefer `CityDistrictCatalog`.
enum CityDistrictLayout {
    typealias VisualSprite = CityDistrictDefinition.VisualSprite
    typealias PointOfInterest = CityDistrictDefinition.PointOfInterest

    static let sourceArtSize = CityDistrictDefinition.sourceArtSize
    static let environmentScale = CityDistrictDefinition.environmentScale
    static let worldArtSize = CityDistrictDefinition.worldArtSize
    static let worldBounds = CityDistrictDefinition.worldBounds
    static let standingAdultBodyHeight = CityDistrictDefinition.standingAdultBodyHeight

    static var cameraVisibleHeight: CGFloat {
        CityDistrictDefinition.cameraVisibleHeight
    }

    static var actorStart: CGPoint { CityDistrictCatalog.sableRow.actorStart }
    static var visualSprites: [VisualSprite] { CityDistrictCatalog.sableRow.visualSprites }
    static var obstacles: [CGRect] { CityDistrictCatalog.sableRow.obstacles }
    static var pointsOfInterest: [PointOfInterest] { CityDistrictCatalog.sableRow.pointsOfInterest }

    /// Opaque bbox heights of shipped V2 city prop textures.
    enum SourceContentHeight {
        static let buildingVossStoop: CGFloat = 491
        static let buildingTenement: CGFloat = 471
        static let buildingStorefront: CGFloat = 470
        static let buildingRowhouse: CGFloat = 470
        static let buildingShop: CGFloat = 420
        static let buildingGatehouse: CGFloat = 400
        static let carBlack: CGFloat = 274
        static let carOlive: CGFloat = 274
        static let carMaroon: CGFloat = 274
        static let lamp: CGFloat = 412
        static let bench: CGFloat = 275
        static let kiosk: CGFloat = 274
    }

    enum Band {
        static let multiStoryBuilding: ClosedRange<CGFloat> = 4.0...12.0
        static let car: ClosedRange<CGFloat> = 0.80...1.70
        static let streetLamp: ClosedRange<CGFloat> = 1.40...2.80
        static let bench: ClosedRange<CGFloat> = 0.50...1.50
        static let kiosk: ClosedRange<CGFloat> = 1.00...2.20
    }

    static func representativeScale(forTextureName name: String) -> CGFloat? {
        visualSprites.first(where: { $0.textureName == name })?.scale
    }

    static func displayHeight(contentHeight: CGFloat, scale: CGFloat) -> CGFloat {
        contentHeight * scale
    }

    static func bodyMultiple(contentHeight: CGFloat, scale: CGFloat) -> CGFloat {
        displayHeight(contentHeight: contentHeight, scale: scale) / standingAdultBodyHeight
    }

    static func bodyMultiple(contentHeight: CGFloat, textureName: String) -> CGFloat? {
        guard let scale = representativeScale(forTextureName: textureName) else { return nil }
        return bodyMultiple(contentHeight: contentHeight, scale: scale)
    }

    static func makeGrid() -> NavigationGrid {
        CityDistrictCatalog.sableRow.makeGrid()
    }

    static func isBlocked(_ point: CGPoint) -> Bool {
        obstacles.contains { $0.contains(point) }
    }
}
