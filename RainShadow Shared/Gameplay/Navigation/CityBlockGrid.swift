import CoreGraphics

/// The diamond block lattice the Act I ground plates are actually painted on.
///
/// `generate_city_grounds_world_scale_v05.py` paints every district with
/// `iso_street_masks(u, v)` — streets on the two BG:EE ground axes (slopes
/// ±0.75) at a 1680 plate-pixel period, which is 840 world units at the shipped
/// 2.00 px/unit. The script's axis-aligned `BLOCKS`/`STREETS_X`/`STREETS_Y`
/// constants sit in `street_masks()`, which `paint()` never calls, so they
/// describe nothing on disk. The diamonds do.
///
/// `survey_sable_iso_lots.py` measured the twelve blocks that land on a
/// 4096×2304 plate and wrote them to
/// `ArtSource/Generated/CityDistrict/V2/sable_iso_lots.json`. This is that
/// survey in Swift, district-agnostic: every district shares one lattice
/// because every district shares one painter.
///
/// Placing on it is the whole point. Facades stepped along a block's
/// camera-near edges read as street frontage; obstacles cut from the diamond
/// leave exactly the painted carriageway and its pavements walkable. Buildings
/// at hand-typed axis-aligned coordinates — which is what the five spoke
/// districts used to carry — land in the middle of painted streets and read as
/// scattered sheds on a field.
enum CityBlockGrid {
    /// Block centre → left/right tip. Half the diamond's long diagonal.
    static let halfWidth: CGFloat = 584
    /// Block centre → near/far tip. `halfWidth × 0.75`, the camera's ground slope.
    static let halfHeight: CGFloat = 438

    /// Centre-to-centre step along a ground axis. The painter's `period / 2`.
    static let period: CGFloat = 840
    /// Vertical step between block rows. `period × 0.75`.
    static let rowStep: CGFloat = 630

    /// Carriageway half-width, as an x-offset past the block edge. A street
    /// corridor is therefore `2 × (pavementBand + carriagewayHalf)` = 512 units
    /// of x between neighbouring block edges ≈ 410 perpendicular ≈ 10.2 m.
    static let carriagewayHalf: CGFloat = 168
    /// Raised pavement between the block edge and the kerb.
    static let pavementBand: CGFloat = 88

    /// Which side of a block a facade row or an obstacle edge faces.
    ///
    /// Only the two `near` edges carry visible frontage: under the ±0.75 lock a
    /// block's far edges point away from the camera, and what you see standing
    /// there is the *next* block up.
    enum Edge: String, CaseIterable, Equatable {
        case nearLeft
        case nearRight
        case farLeft
        case farRight

        var isNear: Bool { self == .nearLeft || self == .nearRight }
        /// −1 toward the left tip, +1 toward the right tip.
        var lateralSign: CGFloat { (self == .nearLeft || self == .farLeft) ? -1 : 1 }
    }

    /// How far each edge is pushed out from the painted block edge, in units of
    /// x-offset. This is how street width is tiered without repainting a plate:
    ///
    /// - `0` — facade line on the block edge, painted pavement stays walkable.
    ///   A 10.2 m main thoroughfare.
    /// - `pavementBand` (88) — facade line on the kerb, the block swallows its
    ///   own pavement. A 6.7 m cross street.
    ///
    /// A street only narrows when the blocks on *both* sides push the edge that
    /// faces it, so tiering is authored per street rather than per block.
    struct EdgeOutsets: Equatable {
        var nearLeft: CGFloat
        var nearRight: CGFloat
        var farLeft: CGFloat
        var farRight: CGFloat

        init(
            nearLeft: CGFloat = 0,
            nearRight: CGFloat = 0,
            farLeft: CGFloat = 0,
            farRight: CGFloat = 0
        ) {
            self.nearLeft = nearLeft
            self.nearRight = nearRight
            self.farLeft = farLeft
            self.farRight = farRight
        }

        /// Facades on the painted block edge all round; pavements stay open.
        static let blockEdge = EdgeOutsets()
        /// Facades on the kerb all round; the block takes its own pavement.
        static let kerb = EdgeOutsets(
            nearLeft: pavementBand, nearRight: pavementBand,
            farLeft: pavementBand, farRight: pavementBand
        )

        /// The shipped tiering. Every block faces two streets on each ground
        /// axis: `nearRight`/`farLeft` lie on the +0.75 family,
        /// `nearLeft`/`farRight` on the −0.75 family. Leaving one family on the
        /// block edge and pulling the other onto the kerb gives a district two
        /// visibly different street widths on its two diagonals — BG's street
        /// hierarchy, with no plate repainted. Measures ~41 % walkable against
        /// BG's 30–45 % band; leaving both families open measures ~46 %.
        static let tiered = EdgeOutsets(
            nearLeft: pavementBand, nearRight: 0,
            farLeft: 0, farRight: pavementBand
        )

        subscript(edge: Edge) -> CGFloat {
            switch edge {
            case .nearLeft: return nearLeft
            case .nearRight: return nearRight
            case .farLeft: return farLeft
            case .farRight: return farRight
            }
        }
    }

    /// One painted diamond. `i`/`j` are the survey's lattice indices.
    struct Block: Equatable {
        let i: Int
        let j: Int

        init(i: Int, j: Int) {
            self.i = i
            self.j = j
        }

        var centre: CGPoint {
            CGPoint(
                x: period * CGFloat(i - j),
                y: 1_674 - rowStep * CGFloat(i + j)
            )
        }

        /// Camera-near vertex — the lowest world y on the diamond, and where a
        /// frontage row starts.
        var nearTip: CGPoint { CGPoint(x: centre.x, y: centre.y - halfHeight) }
        var farTip: CGPoint { CGPoint(x: centre.x, y: centre.y + halfHeight) }
        var leftTip: CGPoint { CGPoint(x: centre.x - halfWidth, y: centre.y) }
        var rightTip: CGPoint { CGPoint(x: centre.x + halfWidth, y: centre.y) }

        /// Near, right, far, left — the survey's winding.
        var vertices: [CGPoint] { [nearTip, rightTip, farTip, leftTip] }

        /// A point along an edge, from the block's tip (0) toward the side
        /// tip (1), with the edge's outset applied. Frontage rows and the
        /// door-bearing heroes both go through this, so a hero sits in its
        /// terrace rather than beside it.
        func point(on edge: Edge, at t: CGFloat, outset: CGFloat = 0) -> CGPoint {
            let origin = edge.isNear ? nearTip : farTip
            let rise = edge.isNear ? halfHeight : -halfHeight
            return CGPoint(
                x: origin.x + edge.lateralSign * (halfWidth + outset) * t,
                y: origin.y + rise * t
            )
        }

        /// The two vertices bounding an edge, near end first.
        func endpoints(of edge: Edge) -> (CGPoint, CGPoint) {
            switch edge {
            case .nearLeft: return (nearTip, leftTip)
            case .nearRight: return (nearTip, rightTip)
            case .farLeft: return (farTip, leftTip)
            case .farRight: return (farTip, rightTip)
            }
        }

        func contains(_ point: CGPoint) -> Bool {
            let dx = abs(point.x - centre.x) / halfWidth
            let dy = abs(point.y - centre.y) / halfHeight
            return dx + dy <= 1
        }

        /// Whether any part of the diamond lands on the district plate. The
        /// `x = 0` and `x = 4200` columns are half off-plate but still paint,
        /// so they still need frontage and still need blocking.
        var isOnPlate: Bool {
            centre.x > -halfWidth && centre.x < CityDistrictDefinition.worldArtSize.width + halfWidth
                && centre.y > -halfHeight
                && centre.y < CityDistrictDefinition.worldArtSize.height + halfHeight
        }

        /// Number of horizontal bands the obstacle is cut into. Sixteen is
        /// where the stepped shape stops moving: the walkable fraction is
        /// 46.4 % at six bands and 45.5 % at sixteen, and each band's error
        /// against the true diamond edge is under 37 units — about two search
        /// cells.
        static let bandCount = 16

        /// The diamond as a stack of horizontal rects, so `SearchMap`'s
        /// rect rasteriser reproduces a *diagonal* street instead of a square
        /// one. A single AABB per block would seal the corridors; the old
        /// `WardBlocks` rects did exactly that, which is why Voss was blocked
        /// in open street and walked through painted blocks.
        func obstacleBands(_ outsets: EdgeOutsets = .blockEdge) -> [CGRect] {
            let bandHeight = (halfHeight * 2) / CGFloat(Self.bandCount)
            var rects: [CGRect] = []
            rects.reserveCapacity(Self.bandCount)
            for index in 0..<Self.bandCount {
                let bottom = centre.y - halfHeight + bandHeight * CGFloat(index)
                let top = bottom + bandHeight
                // Sampled at the band's midpoint rather than its widest row.
                // Widest circumscribes: every band then juts up to 97 units
                // into the street, which measured 30 % walkable and read as
                // pavements you could not stand on. Midpoint converges on the
                // painted diamond from both sides.
                let sample = (bottom + top) / 2
                let left = edgeX(atY: sample, lateral: -1, outsets: outsets)
                let right = edgeX(atY: sample, lateral: 1, outsets: outsets)
                guard right > left else { continue }
                rects.append(
                    CGRect(x: left, y: bottom, width: right - left, height: bandHeight)
                )
            }
            return rects
        }

        /// Block boundary x at a world y, on the given side, with the facing
        /// edge's outset applied.
        func edgeX(atY y: CGFloat, lateral: CGFloat, outsets: EdgeOutsets) -> CGFloat {
            let isNear = y <= centre.y
            let edge: Edge
            switch (isNear, lateral < 0) {
            case (true, true): edge = .nearLeft
            case (true, false): edge = .nearRight
            case (false, true): edge = .farLeft
            case (false, false): edge = .farRight
            }
            let taper = 1 - abs(y - centre.y) / halfHeight
            let reach = (halfWidth + outsets[edge]) * max(0, taper)
            return centre.x + lateral * reach
        }
    }

    /// The twelve blocks the survey found on a 4096×2304 plate, plus the three
    /// camera-far lots that land on the 4096×3072 IE-proportion ward (i+j = −2).
    /// Order: bottom row first, left to right, then the extra far row.
    static let all: [Block] = [
        Block(i: 1, j: 1), Block(i: 2, j: 0), Block(i: 3, j: -1),
        Block(i: 1, j: 0), Block(i: 2, j: -1), Block(i: 3, j: -2),
        Block(i: 0, j: 0), Block(i: 1, j: -1), Block(i: 2, j: -2),
        Block(i: 0, j: -1), Block(i: 1, j: -2), Block(i: 2, j: -3),
        Block(i: -1, j: -1), Block(i: 0, j: -2), Block(i: 1, j: -3)
    ]

    /// The twelve blocks the original survey found on a 4096×2304 plate.
    /// Kit art (lot crops, warehouse cubes) is registered to these only.
    static let surveyed: [Block] = Array(all.prefix(12))

    static func block(i: Int, j: Int) -> Block { Block(i: i, j: j) }

    /// Nearest lattice block containing a point, if any. A `nil` means the
    /// point is on a street, which is what every spawn and approach must be.
    static func blockContaining(_ point: CGPoint) -> Block? {
        all.first { $0.contains(point) }
    }

    static func isOnStreet(_ point: CGPoint) -> Bool {
        blockContaining(point) == nil
    }

    /// Road intersections inside the plate. Lamps sit on these, and the one
    /// open crossing a district is allowed becomes its plaza. The last pair
    /// is the extra depth of the 4096×3072 ward.
    static let crossings: [CGPoint] = [
        CGPoint(x: 840, y: 414), CGPoint(x: 2_520, y: 414),
        CGPoint(x: 1_680, y: 1_044), CGPoint(x: 3_360, y: 1_044),
        CGPoint(x: 840, y: 1_674), CGPoint(x: 2_520, y: 1_674),
        CGPoint(x: 1_680, y: 2_304), CGPoint(x: 3_360, y: 2_304)
    ]

    /// Which plate edge a travel spawn arrives from.
    enum PlateEdge: String, CaseIterable {
        case south, north, west, east
    }

    /// A standable point on the street corridor nearest a plate edge.
    ///
    /// BG districts terminate every main street in a travel strip at the map
    /// edge, so an arrival lands on road rather than being snapped off a wall.
    /// Derived rather than authored because blocking the real diamonds moved
    /// several hand-typed spawns inside a block — `from.east (3880, 1220)` sat
    /// squarely in the `x = 4200` column.
    static func arrivalPoint(from edge: PlateEdge, margin: CGFloat = 220) -> CGPoint {
        let size = CityDistrictDefinition.worldArtSize
        let candidates: [CGPoint]
        switch edge {
        case .south:
            candidates = stride(from: margin, through: size.width - margin, by: 20)
                .map { CGPoint(x: $0, y: margin) }
        case .north:
            candidates = stride(from: margin, through: size.width - margin, by: 20)
                .map { CGPoint(x: $0, y: size.height - margin) }
        case .west:
            candidates = stride(from: margin, through: size.height - margin, by: 20)
                .map { CGPoint(x: margin, y: $0) }
        case .east:
            candidates = stride(from: margin, through: size.height - margin, by: 20)
                .map { CGPoint(x: size.width - margin, y: $0) }
        }
        let mid = CGPoint(x: size.width / 2, y: size.height / 2)
        // Deepest point in the corridor, tie-broken toward the plate centre so
        // an arrival faces into the district rather than along its rim.
        return candidates
            .filter(isOnStreet)
            .max { lhs, rhs in
                let l = (streetDepth(at: lhs), -hypot(lhs.x - mid.x, lhs.y - mid.y))
                let r = (streetDepth(at: rhs), -hypot(rhs.x - mid.x, rhs.y - mid.y))
                return l < r
            } ?? CGPoint(x: size.width / 2, y: size.height / 2)
    }

    /// How far a street point sits from the nearest painted block, as the
    /// smallest diamond-metric slack over all blocks. Bigger is more central in
    /// the carriageway.
    static func streetDepth(at point: CGPoint) -> CGFloat {
        all.reduce(CGFloat.greatestFiniteMagnitude) { best, block in
            let dx = abs(point.x - block.centre.x) / halfWidth
            let dy = abs(point.y - block.centre.y) / halfHeight
            return min(best, dx + dy - 1)
        }
    }
}
