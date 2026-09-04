import CoreGraphics
import Foundation
import Testing
@testable import RainShadowCore

/// Holds the wall-stencil port (`AreaWallStencil`) to `Map::DrawStencil`.
///
/// The encoding is the part that has to match, because it is what the fragment
/// shader reads. A channel that drifts here does not crash or fail loudly — it
/// renders as "cover stopped working", which is why the values are pinned
/// individually rather than by comparing a whole baked mask.
struct AreaWallStencilTests {
    private let world = CGRect(x: 0, y: 0, width: 64, height: 64)

    private func wall(
        _ id: String = "w",
        rect: CGRect,
        coversActors: Bool = true,
        dithers: Bool = true
    ) -> AreaWallPolygon {
        AreaWallPolygon(id: id, rect: rect, coversActors: coversActors, dithers: dithers)
    }

    private func bake(_ walls: [AreaWallPolygon]) -> AreaWallStencil.Mask {
        AreaWallStencil.bake(wallPolygons: walls, worldFrame: world)
    }

    // MARK: - Channel encoding

    /// `stencilcol` starts `(0, 0, 0xff, 0x80)`; `WF_DITHER` sets red to `0x80`
    /// and `WF_COVERANIMS` copies red into green.
    @Test func aDitheringCoverWallWritesUpstreamsChannels() {
        let mask = bake([wall(rect: CGRect(x: 16, y: 16, width: 32, height: 32))])
        let inside = mask.sample(at: CGPoint(x: 32, y: 32))
        #expect(inside.r == 0x80)
        #expect(inside.g == 0x80)
        #expect(inside.b == 0xFF)
        #expect(inside.a == 0x80)
    }

    /// Without `WF_DITHER` the wall hides outright: red is `0xFF`, and green
    /// still follows red.
    @Test func aNonDitheringCoverWallWritesSolidRed() {
        let mask = bake([wall(rect: CGRect(x: 16, y: 16, width: 32, height: 32), dithers: false)])
        let inside = mask.sample(at: CGPoint(x: 32, y: 32))
        #expect(inside.r == 0xFF)
        #expect(inside.g == 0xFF)
        #expect(inside.b == 0xFF)
    }

    /// The `AreaWallPolygonTests` case, now at pixel level: a shade-only outline
    /// is not `WF_COVERANIMS`, so it must not reach the stencil at all.
    @Test func aShadeOnlyWallWritesNothing() {
        let mask = bake([wall(rect: CGRect(x: 16, y: 16, width: 32, height: 32), coversActors: false)])
        #expect(mask.isEmpty)
        #expect(mask.sample(at: CGPoint(x: 32, y: 32)).g == 0)
    }

    @Test func outsideEveryWallIsAllZero() {
        let mask = bake([wall(rect: CGRect(x: 16, y: 16, width: 8, height: 8))])
        let outside = mask.sample(at: CGPoint(x: 48, y: 48))
        #expect(outside == (0, 0, 0, 0))
    }

    @Test func aPointOutsideTheWorldFrameIsAllZero() {
        let mask = bake([wall(rect: CGRect(x: 0, y: 0, width: 64, height: 64))])
        #expect(mask.sample(at: CGPoint(x: -1, y: 32)) == (0, 0, 0, 0))
        #expect(mask.sample(at: CGPoint(x: 32, y: 999)) == (0, 0, 0, 0))
    }

    // MARK: - Rasterisation

    /// Upstream draws each polygon into one buffer in order, so a later wall
    /// overwrites an earlier one where they overlap. A solid wall laid over a
    /// dithering one must win, not blend to some third value the shader cannot
    /// interpret.
    @Test func aLaterWallOverwritesAnEarlierOneWhereTheyOverlap() {
        let mask = bake([
            wall("dither", rect: CGRect(x: 0, y: 0, width: 64, height: 64), dithers: true),
            wall("solid", rect: CGRect(x: 16, y: 16, width: 32, height: 32), dithers: false)
        ])
        #expect(mask.sample(at: CGPoint(x: 32, y: 32)).r == 0xFF)   // overlap
        #expect(mask.sample(at: CGPoint(x: 4, y: 4)).r == 0x80)     // dither only
    }

    /// Antialiasing is off on purpose. A half-covered edge cell must be in or
    /// out: a red channel that is neither `0x80` nor `0xFF` matches no wall state
    /// and the shader would read it as a partial dither that upstream never
    /// produces.
    @Test func edgeCellsAreNeverPartiallyCovered() {
        // Deliberately fractional edges, so a filter would have something to
        // average across.
        let mask = bake([wall(rect: CGRect(x: 10.4, y: 10.6, width: 21.3, height: 19.7))])
        for value in mask.rgba.enumerated().filter({ $0.offset % 4 == 0 }).map(\.element) {
            #expect(value == 0 || value == 0x80 || value == 0xFF)
        }
    }

    /// The mask is y-up from the world's minimum corner, matching
    /// `AreaSearchMapLoader` and `AreaLightMap`. Flipped, cover would apply to
    /// the mirror image of the scenery — which looks plausible in a symmetric
    /// room and wrong everywhere else.
    @Test func theMaskIsYUpFromTheWorldMinimumCorner() {
        let mask = bake([wall(rect: CGRect(x: 0, y: 0, width: 64, height: 16))])
        #expect(mask.sample(at: CGPoint(x: 32, y: 4)).g == 0x80, "low y should be covered")
        #expect(mask.sample(at: CGPoint(x: 32, y: 60)).g == 0, "high y should be clear")
    }

    @Test func noWallPolygonsBakesAnEmptyMask() {
        #expect(bake([]).isEmpty)
    }

    // MARK: - Shipped areas

    /// A mask that silently comes back blank is the failure mode that reads as
    /// "cover stopped working", so the shipped covering geometry is checked to
    /// actually rasterise.
    @Test func theShippedOfficeWallsRasteriseNonEmpty() throws {
        let office = try AreaCatalogLoader.load(HarborpointAreas.office)
        #expect(!office.wallPolygons.isEmpty, "the office authored no wall polygons")
        #expect(!office.makeWallStencil().isEmpty, "the office stencil baked blank")
    }

    @Test func theShippedSableRowWallsRasteriseNonEmpty() throws {
        let ward = try AreaCatalogLoader.load(HarborpointAreas.sableRow)
        #expect(!ward.wallPolygons.isEmpty, "Sable Row authored no wall polygons")
        #expect(!ward.makeWallStencil().isEmpty, "the Sable Row stencil baked blank")
    }

    /// The mask must answer the same question `isCovered` does.
    ///
    /// This is the real regression risk in replacing `ActorCover`: the stencil is
    /// a *different mechanism* reaching what has to be the same answer, and a
    /// disagreement shows up as an actor stippled in open floor or walking
    /// opaque through a facade.
    ///
    /// **Away from edges the two must agree exactly.** A raster cannot resolve
    /// closer than one cell, so a sample within a cell of a polygon boundary may
    /// legitimately land on the far side of it — that is what rasterising *is*,
    /// and the office (one unit per cell) has no such samples at all while a
    /// ward (three units per cell, see `maximumMaskDimension`) has a scattering
    /// along every facade. Tolerating a flat percentage instead would also
    /// tolerate a systematic offset, which is the fault worth catching.
    ///
    /// Not asserted for wall polygons outside the area's own world frame:
    /// `CityStreetPlan` is a **city-wide** lattice and every ward carries all of
    /// it, so a ward legitimately holds masses whose bounding boxes sit entirely
    /// at negative y. They belong to the ward next door.
    @Test func theMaskAgreesWithIsCoveredAwayFromWallEdges() throws {
        for id in [HarborpointAreas.office, HarborpointAreas.sableRow] {
            let area = try AreaCatalogLoader.load(id)
            let frame = CGRect(
                origin: area.worldOrigin.cgPoint,
                size: CGSize(width: area.worldSize.w, height: area.worldSize.h)
            )
            let cell = AreaWallStencil.worldUnitsPerCell(for: frame)
            let mask = area.makeWallStencil()

            /// Whether a polygon boundary runs within about a cell of here.
            func isNearAWallEdge(_ point: CGPoint, _ covered: Bool) -> Bool {
                let reach = cell * 1.5
                for dx in [-reach, 0, reach] {
                    for dy in [-reach, 0, reach] where !(dx == 0 && dy == 0) {
                        let probe = CGPoint(x: point.x + dx, y: point.y + dy)
                        if area.isCovered(probe) != covered { return true }
                    }
                }
                return false
            }

            var offEdgeDisagreements: [CGPoint] = []
            let steps = 60
            for xi in 0..<steps {
                for yi in 0..<steps {
                    let point = CGPoint(
                        x: frame.minX + frame.width * (CGFloat(xi) + 0.5) / CGFloat(steps),
                        y: frame.minY + frame.height * (CGFloat(yi) + 0.5) / CGFloat(steps)
                    )
                    let covered = area.isCovered(point)
                    guard (mask.sample(at: point).g != 0) != covered else { continue }
                    if !isNearAWallEdge(point, covered) {
                        offEdgeDisagreements.append(point)
                    }
                }
            }
            let detail = offEdgeDisagreements.prefix(5)
                .map { "(\($0.x), \($0.y))" }
                .joined(separator: ", ")
            #expect(
                offEdgeDisagreements.isEmpty,
                "\(id): stencil and isCovered disagree away from any wall edge at \(detail) — that is an encoding fault, not raster resolution"
            )
        }
    }

    // MARK: - Cost

    /// The mask must stay small enough to bake and upload on area entry.
    ///
    /// This is a regression guard with a specific history: the first version
    /// rasterised a **full world-sized buffer per polygon** at one unit per cell,
    /// so entering Sable Row — 5120x3840 with 86 covering masses — took
    /// **119 seconds** and produced a 78 MB texture. It read as the game freezing
    /// on area transition. Both halves are pinned here: the resolution cap, and
    /// that a ward bakes in well under a second.
    @Test func aWardBakesSmallAndFast() throws {
        for id in HarborpointAreas.shippedIDs {
            let area = try AreaCatalogLoader.load(id)
            guard !area.wallPolygons.isEmpty else { continue }
            let start = Date()
            let mask = area.makeWallStencil()
            let elapsed = Date().timeIntervalSince(start)
            #expect(
                max(mask.columns, mask.rows) <= AreaWallStencil.maximumMaskDimension,
                "\(id) baked \(mask.columns)x\(mask.rows), over the cap"
            )
            let megabytes = mask.columns * mask.rows * 4 / 1_000_000
            #expect(megabytes <= 24, "\(id) baked a \(megabytes) MB mask")
            // Generous against machine load; the fault this catches was 119 s.
            #expect(elapsed < 5, "\(id) took \(elapsed) s to bake")
        }
    }

    /// The office is small enough to stay at the finest resolution, so its mask
    /// is exact rather than merely close. If this ever coarsens, the agreement
    /// test above stops proving anything about encoding.
    @Test func theOfficeStaysAtTheFinestResolution() throws {
        let area = try AreaCatalogLoader.load(HarborpointAreas.office)
        let frame = CGRect(
            origin: area.worldOrigin.cgPoint,
            size: CGSize(width: area.worldSize.w, height: area.worldSize.h)
        )
        #expect(
            AreaWallStencil.worldUnitsPerCell(for: frame)
                == AreaWallStencil.finestWorldUnitsPerCell
        )
    }

    /// A wall too low to hide a standing adult must not reach the mask, the same
    /// way `coversActor(at:height:)` refuses it. Without this every kerb stipples
    /// anyone who walks past.
    @Test func aWallTooLowToHideAnAdultIsNotBaked() {
        let low = AreaWallPolygon(
            id: "kerb",
            rect: CGRect(x: 16, y: 16, width: 32, height: 32),
            height: 4
        )
        let mask = AreaWallStencil.bake(
            wallPolygons: [low],
            worldFrame: world,
            actorHeight: 70
        )
        #expect(mask.isEmpty, "a 4-unit kerb covered a 70-unit adult")

        let tall = AreaWallPolygon(
            id: "facade",
            rect: CGRect(x: 16, y: 16, width: 32, height: 32),
            height: 60
        )
        let covered = AreaWallStencil.bake(
            wallPolygons: [tall],
            worldFrame: world,
            actorHeight: 70
        )
        #expect(!covered.isEmpty, "a 60-unit facade did not cover a 70-unit adult")
    }
}
