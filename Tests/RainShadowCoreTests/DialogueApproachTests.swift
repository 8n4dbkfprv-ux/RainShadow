import CoreGraphics
import Testing
@testable import RainShadowCore

/// Baldur's Gate turns "click a person" into "walk into range, face them, talk".
/// RainShadow's three shipped conversations were all scene-scripted, so nothing
/// generalised that. This is the pure half, tested against the same grid fixtures the
/// pathfinder uses.
struct DialogueApproachTests {
    private func makeMap(obstacles: [CGRect] = []) -> NavigationMap {
        NavigationMap(
            origin: .zero,
            columns: 8,
            rows: 8,
            cellSize: CGSize(width: 10, height: 10),
            obstacles: obstacles
        )
    }

    @Test func standsOffTheActorRatherThanOnTop() throws {
        let map = makeMap()
        let actor = CGPoint(x: 40, y: 40)
        let walker = CGPoint(x: 5, y: 40)

        let approach = try #require(
            DialogueApproach.approachPoint(toActorAt: actor, from: walker, standoff: 20, in: map)
        )

        #expect(approach != actor)
        #expect(hypot(approach.x - actor.x, approach.y - actor.y) > 1)
        #expect(map.path(from: walker, to: approach) != nil)
    }

    /// Candidates are ordered so the straight-line approach is tried first — the
    /// detective should not circle to a fixed compass point.
    @Test func prefersTheSideTheWalkerIsAlreadyOn() throws {
        let map = makeMap()
        let actor = CGPoint(x: 40, y: 40)

        let fromLeft = try #require(
            DialogueApproach.approachPoint(
                toActorAt: actor, from: CGPoint(x: 5, y: 40), standoff: 20, in: map
            )
        )
        let fromRight = try #require(
            DialogueApproach.approachPoint(
                toActorAt: actor, from: CGPoint(x: 75, y: 40), standoff: 20, in: map
            )
        )

        #expect(fromLeft.x < actor.x)
        #expect(fromRight.x > actor.x)
    }

    /// The whole reason this uses `path` and not `route`: `route` snaps to the nearest
    /// reachable cell and reports success, which would park the detective on the far side
    /// of a wall from the person he is supposedly talking to.
    @Test func refusesAnActorItCannotActuallyReach() {
        let sealingWall = CGRect(x: 30, y: 0, width: 10, height: 80)
        let map = makeMap(obstacles: [sealingWall])
        let walker = CGPoint(x: 5, y: 40)
        let actor = CGPoint(x: 65, y: 40)

        #expect(
            DialogueApproach.approachPoint(
                toActorAt: actor, from: walker, standoff: 15, in: map
            ) == nil
        )
        // A snapping route would have happily claimed success here.
        #expect(map.route(from: walker, to: actor) != nil)
    }

    /// Already beside them: do not make the player watch a pointless shuffle.
    @Test func staysPutWhenAlreadyInRange() throws {
        let map = makeMap()
        let actor = CGPoint(x: 40, y: 40)
        let walker = CGPoint(x: 45, y: 40)

        let approach = try #require(
            DialogueApproach.approachPoint(toActorAt: actor, from: walker, standoff: 20, in: map)
        )
        #expect(approach == walker)
    }

    @Test func candidatesRingTheActorAtTheStandoffDistance() {
        let actor = CGPoint(x: 100, y: 100)
        let candidates = DialogueApproach.candidates(
            around: actor,
            facing: CGPoint(x: 0, y: 100),
            standoff: 50
        )

        #expect(candidates.count == 8)
        for candidate in candidates {
            let distance = hypot(candidate.x - actor.x, candidate.y - actor.y)
            #expect(abs(distance - 50) < 0.001)
        }
        // First candidate points back at the walker.
        #expect(candidates[0].x < actor.x)
        #expect(abs(candidates[0].y - actor.y) < 0.001)
    }

    /// Degenerate input must not produce NaN positions.
    @Test func handlesAWalkerStandingExactlyOnTheActor() {
        let candidates = DialogueApproach.candidates(
            around: CGPoint(x: 10, y: 10),
            facing: CGPoint(x: 10, y: 10),
            standoff: 5
        )
        #expect(candidates.allSatisfy { $0.x.isFinite && $0.y.isFinite })
    }
}
