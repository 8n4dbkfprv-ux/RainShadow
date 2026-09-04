import CoreGraphics
import Testing
@testable import RainShadowCore

/// Holds the draw order to `Map::SortQueues`.
///
/// The formula in `BaseGameScene.updateDepth` has always produced this order;
/// what it never had was a statement of *which direction*, and a sign nobody can
/// check is a sign that can silently invert. Every individual still frame looks
/// plausible either way, so this is the only place the axis flip is actually
/// asserted.
struct DrawQueueTests {
    /// Upstream is `b->Pos.y < a->Pos.y` on a **y-down** screen, where a larger
    /// `y` is nearer the camera. SpriteKit's world is y-up, so a larger `y` is
    /// *further* — and the object drawn first is the far one.
    @Test func theFartherObjectIsDrawnFirst() {
        #expect(DrawQueue.isOrderedBefore(500, 100), "y-up: 500 is farther, so it draws first")
        #expect(!DrawQueue.isOrderedBefore(100, 500))
    }

    @Test func equalGroundPointsAreNeitherBefore() {
        #expect(!DrawQueue.isOrderedBefore(250, 250))
    }

    /// The z offset must rise as the ground point recedes from the camera, so a
    /// nearer object lands on top. This is the same relationship as the
    /// comparator, expressed as a number, and the two are checked against each
    /// other below.
    @Test func depthOffsetRisesAsTheGroundPointNears() {
        let far = DrawQueue.depthOffset(groundY: 900, artHeight: 1000)
        let near = DrawQueue.depthOffset(groundY: 100, artHeight: 1000)
        #expect(near > far, "the nearer object must sort on top")
    }

    /// The comparator and the formula are two statements of one rule, and the
    /// scene uses the formula while upstream defines the comparator. If they ever
    /// disagree, the game draws in an order nothing asserts.
    @Test func theFormulaAgreesWithTheComparatorEverywhere() {
        let artHeight: CGFloat = 2304
        let samples = stride(from: CGFloat(-500), through: 2800, by: 37.0)
        for a in samples {
            for b in samples where a != b {
                let byComparator = DrawQueue.isOrderedBefore(a, b)
                let byFormula =
                    DrawQueue.depthOffset(groundY: a, artHeight: artHeight)
                    < DrawQueue.depthOffset(groundY: b, artHeight: artHeight)
                #expect(
                    byComparator == byFormula,
                    "comparator and formula disagree at y=\(a) vs y=\(b)"
                )
            }
        }
    }

    /// `artHeight` shifts the whole scene and must cancel out of every
    /// comparison — otherwise two areas with different plate heights would sort
    /// their contents differently.
    @Test func artHeightDoesNotChangeAnyOrdering() {
        for height in [CGFloat(512), 2304, 6144] {
            let a = DrawQueue.depthOffset(groundY: 300, artHeight: height)
            let b = DrawQueue.depthOffset(groundY: 700, artHeight: height)
            #expect(a > b, "ordering moved with artHeight \(height)")
        }
    }

    // MARK: - sorted

    @Test func sortedRunsFarToNear() {
        let ys: [CGFloat] = [100, 900, 500, 300]
        #expect(DrawQueue.sorted(ys) { $0 } == [900, 500, 300, 100])
    }

    /// `std::sort` is unstable, so upstream's order for two objects on the same
    /// `Pos.y` is unspecified. Ours keeps input order on purpose: the view runs
    /// `ignoresSiblingOrder`, and `BaseGameScene.makeProp` records the office's
    /// additive light casts rendering a step apart between two builds whose
    /// scene graphs were identical. A deliberate divergence, and the safer one.
    @Test func tiesKeepTheirInputOrder() {
        struct Item: Equatable { let id: String; let y: CGFloat }
        let items = [
            Item(id: "first", y: 400),
            Item(id: "second", y: 400),
            Item(id: "third", y: 400)
        ]
        #expect(DrawQueue.sorted(items, groundY: \.y).map(\.id) == ["first", "second", "third"])
    }

    /// Actors, props and area animations all go through one comparison, which is
    /// what `Map::DrawMap`'s single queue makes them do — the office's desk, the
    /// detective standing beside it and a flickering lamp between them must
    /// interleave by ground point rather than by which list they came from.
    @Test func differentObjectKindsInterleaveByGroundPoint() {
        struct Drawn: Equatable { let id: String; let y: CGFloat }
        let mixed = [
            Drawn(id: "actor", y: 500),
            Drawn(id: "prop", y: 900),
            Drawn(id: "animation", y: 700)
        ]
        #expect(
            DrawQueue.sorted(mixed, groundY: \.y).map(\.id) == ["prop", "animation", "actor"]
        )
    }

    @Test func sortingIsIdempotent() {
        let ys: [CGFloat] = [100, 900, 500, 300, 900]
        let once = DrawQueue.sorted(ys) { $0 }
        #expect(DrawQueue.sorted(once) { $0 } == once)
    }
}
