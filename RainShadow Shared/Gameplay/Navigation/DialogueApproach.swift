import CoreGraphics
import Foundation

/// Where the player character stands to talk to somebody.
///
/// Baldur's Gate turns "click an NPC" into "walk into conversation range, face them,
/// then start the dialogue". RainShadow's three shipped conversations are all
/// scene-scripted, so nothing generalised that flow — this is the pure half of it, kept
/// out of the scene so it can be tested against the same navigation fixtures the
/// pathfinder uses.
///
/// The solver deliberately demands an *exactly reachable authored standoff*.
/// `FindPath` relocates a blocked goal on its own (`AdjustPositionDirected`), so a
/// non-empty path only means the actor got somewhere near what was asked for. Runtime
/// movement may stop within its operating distance of the chosen standoff, but the
/// standoff itself cannot be allowed to snap across a wall. `reachesExactly` is the
/// stricter authoring question.
enum DialogueApproach {
    /// Default standoff in world units — close enough to read a face, far enough that the
    /// two sprites do not overlap at this camera scale.
    static let defaultStandoff: CGFloat = 96

    /// A walkable, genuinely reachable point beside `actor`, or `nil` when there is no
    /// honest way to reach them.
    ///
    /// Candidates are tried nearest-first around the actor so the detective takes the
    /// shortest sensible approach rather than circling to a fixed compass point.
    static func approachPoint(
        toActorAt actor: CGPoint,
        from walker: CGPoint,
        standoff: CGFloat = defaultStandoff,
        in map: NavigationMap
    ) -> CGPoint? {
        // Already close enough, and we can stand where we are.
        if hypot(walker.x - actor.x, walker.y - actor.y) <= standoff,
           map.isOrderableFloor(walker) {
            return walker
        }

        for candidate in candidates(around: actor, facing: walker, standoff: standoff) {
            guard let walkable = map.nearestWalkablePoint(to: candidate) else { continue }
            // A destination the search had to move is exactly the failure this
            // guard exists to catch, so the arrival cell must be the one asked for.
            guard map.reachesExactly(from: walker, to: walkable) else { continue }
            return walkable
        }
        return nil
    }

    /// Ring of standing spots around the actor, ordered by how little the walker has to
    /// deviate: straight-line approach first, then progressively further around.
    static func candidates(
        around actor: CGPoint,
        facing walker: CGPoint,
        standoff: CGFloat
    ) -> [CGPoint] {
        let dx = walker.x - actor.x
        let dy = walker.y - actor.y
        let baseAngle = (dx == 0 && dy == 0) ? 0 : atan2(dy, dx)
        // 0 first (straight at the walker), then alternating either side.
        let offsets: [CGFloat] = [0, 0.25, -0.25, 0.5, -0.5, 0.75, -0.75, 1.0]
        return offsets.map { turn in
            let angle = baseAngle + turn * .pi
            return CGPoint(
                x: actor.x + cos(angle) * standoff,
                y: actor.y + sin(angle) * standoff
            )
        }
    }
}
