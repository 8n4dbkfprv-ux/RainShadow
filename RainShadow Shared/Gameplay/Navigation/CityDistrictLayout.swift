import CoreGraphics

/// Geometry contract for Sable Row, the first open city district. The generated
/// plate is shown at 2× its source resolution: its street doors, cars, lamps,
/// and stairs then remain in the same compact, human-scale range as Elias's
/// 100-point runtime body instead of reading as oversized set dressing.
enum CityDistrictLayout {
    struct PointOfInterest: Equatable {
        enum Kind: Equatable {
            case office
            case square
            case alley
            case exit
        }

        let label: String
        let worldPoint: CGPoint
        let kind: Kind
    }

    /// A separately rendered piece of the district. Ground points mark the
    /// physical contact point, not the centre of the transparent image, so
    /// depth sorting still lets Elias pass behind or in front of each object.
    struct VisualSprite: Equatable {
        let textureName: String
        let groundPoint: CGPoint
        let scale: CGFloat
        let anchorY: CGFloat
        let depthBias: CGFloat
    }

    static let sourceArtSize = CGSize(width: 1_774, height: 887)
    static let environmentScale: CGFloat = 2
    static let worldArtSize = CGSize(
        width: sourceArtSize.width * environmentScale,
        height: sourceArtSize.height * environmentScale
    )
    static let worldBounds = CGRect(origin: .zero, size: worldArtSize)

    /// Wider than the office's 666-point visible height, but still close enough
    /// that Elias and the street furniture retain the intended CRPG density.
    static let cameraVisibleHeight: CGFloat = 780

    /// The illuminated office stoop is at the southeast edge of the generated
    /// block; the start is placed on the clear wet pavement immediately outside.
    static let actorStart = CGPoint(x: 2_965, y: 190)

    /// The authored city plate remains the map reference, while play uses this
    /// compact set of independently registered sprites over the clean street
    /// underlay. Their scale deliberately keeps a car near Elias's height and
    /// a street block within a single fog reveal, rather than turning scenery
    /// into oversized set pieces.
    static let visualSprites: [VisualSprite] = [
        .init(textureName: "city_building_nw", groundPoint: CGPoint(x: 250, y: 1_360), scale: 1.45, anchorY: 0.17, depthBias: 0),
        .init(textureName: "city_building_central", groundPoint: CGPoint(x: 1_280, y: 1_375), scale: 1.70, anchorY: 0.15, depthBias: 0),
        .init(textureName: "city_building_ne", groundPoint: CGPoint(x: 2_650, y: 1_360), scale: 1.60, anchorY: 0.16, depthBias: 0),
        .init(textureName: "city_building_ne", groundPoint: CGPoint(x: 3_135, y: 1_015), scale: 1.38, anchorY: 0.16, depthBias: 0),
        .init(textureName: "city_building_sw", groundPoint: CGPoint(x: 285, y: 340), scale: 1.22, anchorY: 0.28, depthBias: 0),
        .init(textureName: "city_building_sw", groundPoint: CGPoint(x: 755, y: 265), scale: 0.92, anchorY: 0.28, depthBias: 0),
        .init(textureName: "city_building_mid", groundPoint: CGPoint(x: 1_590, y: 610), scale: 1.45, anchorY: 0.16, depthBias: 0),
        .init(textureName: "city_building_se", groundPoint: CGPoint(x: 2_485, y: 350), scale: 1.55, anchorY: 0.12, depthBias: 0),

        .init(textureName: "city_statue", groundPoint: CGPoint(x: 755, y: 1_165), scale: 0.78, anchorY: 0.09, depthBias: 3),
        .init(textureName: "city_bench", groundPoint: CGPoint(x: 620, y: 1_040), scale: 0.65, anchorY: 0.15, depthBias: 2),
        .init(textureName: "city_bench", groundPoint: CGPoint(x: 965, y: 1_075), scale: 0.56, anchorY: 0.15, depthBias: 2),
        .init(textureName: "city_lamp", groundPoint: CGPoint(x: 465, y: 1_470), scale: 0.64, anchorY: 0.13, depthBias: 1),
        .init(textureName: "city_lamp", groundPoint: CGPoint(x: 850, y: 1_385), scale: 0.64, anchorY: 0.13, depthBias: 1),
        .init(textureName: "city_lamp", groundPoint: CGPoint(x: 1_260, y: 1_360), scale: 0.64, anchorY: 0.13, depthBias: 1),
        .init(textureName: "city_lamp", groundPoint: CGPoint(x: 1_820, y: 1_440), scale: 0.64, anchorY: 0.13, depthBias: 1),
        .init(textureName: "city_lamp", groundPoint: CGPoint(x: 2_210, y: 1_510), scale: 0.64, anchorY: 0.13, depthBias: 1),
        .init(textureName: "city_lamp", groundPoint: CGPoint(x: 2_865, y: 1_320), scale: 0.64, anchorY: 0.13, depthBias: 1),
        .init(textureName: "city_lamp", groundPoint: CGPoint(x: 405, y: 1_130), scale: 0.64, anchorY: 0.13, depthBias: 1),
        .init(textureName: "city_lamp", groundPoint: CGPoint(x: 1_030, y: 970), scale: 0.64, anchorY: 0.13, depthBias: 1),
        .init(textureName: "city_lamp", groundPoint: CGPoint(x: 1_650, y: 1_020), scale: 0.64, anchorY: 0.13, depthBias: 1),
        .init(textureName: "city_lamp", groundPoint: CGPoint(x: 2_260, y: 870), scale: 0.64, anchorY: 0.13, depthBias: 1),
        .init(textureName: "city_lamp", groundPoint: CGPoint(x: 3_000, y: 930), scale: 0.64, anchorY: 0.13, depthBias: 1),
        .init(textureName: "city_lamp", groundPoint: CGPoint(x: 1_035, y: 350), scale: 0.64, anchorY: 0.13, depthBias: 1),
        .init(textureName: "city_lamp", groundPoint: CGPoint(x: 1_940, y: 430), scale: 0.64, anchorY: 0.13, depthBias: 1),
        .init(textureName: "city_lamp", groundPoint: CGPoint(x: 2_600, y: 265), scale: 0.64, anchorY: 0.13, depthBias: 1),
        .init(textureName: "city_car_black", groundPoint: CGPoint(x: 1_080, y: 1_050), scale: 0.50, anchorY: 0.17, depthBias: 2),
        .init(textureName: "city_car_black", groundPoint: CGPoint(x: 2_000, y: 1_020), scale: 0.50, anchorY: 0.17, depthBias: 2),
        .init(textureName: "city_car_olive", groundPoint: CGPoint(x: 1_280, y: 780), scale: 0.50, anchorY: 0.17, depthBias: 2),
        .init(textureName: "city_car_maroon", groundPoint: CGPoint(x: 2_870, y: 680), scale: 0.50, anchorY: 0.17, depthBias: 2),
        .init(textureName: "city_car_black", groundPoint: CGPoint(x: 3_050, y: 380), scale: 0.50, anchorY: 0.17, depthBias: 2),
        .init(textureName: "city_kiosk", groundPoint: CGPoint(x: 2_040, y: 300), scale: 0.65, anchorY: 0.21, depthBias: 2),
        .init(textureName: "city_crates_mail", groundPoint: CGPoint(x: 2_205, y: 260), scale: 0.55, anchorY: 0.25, depthBias: 2),
        .init(textureName: "city_gate", groundPoint: CGPoint(x: 865, y: 715), scale: 0.60, anchorY: 0.23, depthBias: 2)
    ]

    /// Architectural footprints only. They intentionally leave the sidewalks,
    /// alleys, square, and broad cobbled streets walkable. Coordinates are in
    /// world space after the 2× environment scale above.
    static let obstacles: [CGRect] = [
        CGRect(x: 0, y: 1_000, width: 590, height: 774),
        CGRect(x: 810, y: 1_210, width: 900, height: 564),
        CGRect(x: 2_080, y: 1_110, width: 1_468, height: 664),
        CGRect(x: 0, y: 0, width: 585, height: 860),
        CGRect(x: 510, y: 0, width: 460, height: 520),
        CGRect(x: 1_245, y: 395, width: 840, height: 590),
        CGRect(x: 2_080, y: 110, width: 750, height: 770),
        CGRect(x: 2_940, y: 520, width: 608, height: 645)
    ]

    static let pointsOfInterest: [PointOfInterest] = [
        .init(label: "OFFICE", worldPoint: actorStart, kind: .office),
        .init(label: "SQUARE", worldPoint: CGPoint(x: 760, y: 1_125), kind: .square),
        .init(label: "ALLEY", worldPoint: CGPoint(x: 2_060, y: 1_010), kind: .alley),
        .init(label: "SOUTH EXIT", worldPoint: CGPoint(x: 1_050, y: 115), kind: .exit)
    ]

    static func makeGrid() -> NavigationGrid {
        NavigationGrid(
            origin: .zero,
            columns: Int(ceil(worldArtSize.width / 64)),
            rows: Int(ceil(worldArtSize.height / 64)),
            cellSize: CGSize(width: 64, height: 64),
            obstacles: obstacles,
            agentProfile: .detective,
            worldBounds: worldBounds
        )
    }

    static func isBlocked(_ point: CGPoint) -> Bool {
        obstacles.contains { $0.contains(point) }
    }
}
