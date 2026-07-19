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
            obstacles: obstacles
        )
    }

    static func isBlocked(_ point: CGPoint) -> Bool {
        obstacles.contains { $0.contains(point) }
    }
}
