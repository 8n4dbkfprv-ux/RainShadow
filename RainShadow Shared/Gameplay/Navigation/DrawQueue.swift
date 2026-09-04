import CoreGraphics
import Foundation

/// The object draw order (GemRB `core/Map.cpp`, `Map::SortQueues`, `Map::DrawMap`).
///
/// ```cpp
/// void Map::SortQueues()
/// {
///     for (auto& subq : queue) {
///         std::sort(subq.begin(), subq.end(), [](const Actor* a, const Actor* b) {
///             return b->Pos.y < a->Pos.y;
///         });
///     }
/// }
/// ```
///
/// **RainShadow already draws in this order**, and this file exists to say so in
/// a way that can be tested rather than to change it. `BaseGameScene.updateDepth`
/// puts every depth-sorted object — actors, `depthWorld` props and area
/// animations alike — into one continuous z space keyed on the ground point, so
/// they interleave exactly as upstream's single queue makes them. What was
/// missing was any statement of *which direction*, and a formula whose sign
/// nobody can check is a formula that can silently invert.
///
/// **The axis flips, and that is the whole subtlety.** Upstream's `Pos.y` is
/// screen space, y **down**: a larger `y` is further down the screen, which is
/// nearer the camera. Its comparator sorts descending by `y` and `DrawMap` then
/// walks the queue *backwards* (`size_t index = queue[q].size();` counting
/// down), so drawing runs far-to-near — painter's order. RainShadow's world is
/// SpriteKit, y **up**: a larger `y` is further *from* the camera. Far-to-near is
/// therefore ascending z as `y` descends, which is what ``depthOffset(groundY:artHeight:)``
/// produces.
///
/// Get the sign backwards and every depth relationship in the game inverts while
/// each individual still frame looks plausible, which is why
/// ``isOrderedBefore(_:_:)`` and the formula are pinned to each other by test.
enum DrawQueue {
    /// The z scale per world unit of ground-point separation.
    ///
    /// Not 1: the ground plane is foreshortened by the projection lock's 0.75,
    /// and this is the constant `updateDepth` has always used. It only has to be
    /// positive and consistent — the *ordering* is what carries meaning, and the
    /// magnitude exists so an authored `bias` can express "half a step".
    static let unitsPerWorldY: CGFloat = 0.5

    /// `SortQueues`' comparator, with the y-axis flipped into SpriteKit's world.
    ///
    /// Returns whether `a` is drawn **before** `b` — further from the camera.
    /// Upstream is `b->Pos.y < a->Pos.y` on a y-down screen; y-up here makes the
    /// same relationship `a.y > b.y`.
    static func isOrderedBefore(_ a: CGFloat, _ b: CGFloat) -> Bool {
        a > b
    }

    /// Far-to-near, the order objects are drawn in.
    ///
    /// `std::sort` is not stable, so upstream's order for two objects on the same
    /// `Pos.y` is unspecified. Ours is not: ties keep their input order, because
    /// the scene relies on it. `BaseGameScene.makeProp` documents why — the view
    /// runs `ignoresSiblingOrder`, under which equal-z siblings draw in whatever
    /// order batches best, and the office's five additive light casts rendered a
    /// step apart per channel between two builds whose scene graphs were
    /// provably identical. A deliberate divergence, and the safer one.
    static func sorted<T>(_ items: [T], groundY: (T) -> CGFloat) -> [T] {
        items.enumerated()
            .sorted { lhs, rhs in
                let a = groundY(lhs.element)
                let b = groundY(rhs.element)
                if a == b { return lhs.offset < rhs.offset }
                return isOrderedBefore(a, b)
            }
            .map(\.element)
    }

    /// The z offset `updateDepth` applies above its layer base.
    ///
    /// `artHeight` only shifts the whole scene, so it cancels out of every
    /// comparison; it is there to keep the offset positive for a plate-sized
    /// world rather than to carry meaning.
    static func depthOffset(groundY: CGFloat, artHeight: CGFloat) -> CGFloat {
        (artHeight - groundY) * unitsPerWorldY
    }
}
