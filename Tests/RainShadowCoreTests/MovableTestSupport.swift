import CoreGraphics
import Foundation
@testable import RainShadowCore

/// Shared fixtures for the movement suites.
///
/// Everything here is built at the engine's own scale — 16×12 cells, integral
/// positions — because `NormalizeDeltas` rounds each step up to a whole unit and
/// arrival is an exact `position == node.point` test. A fixture on some other
/// grid measures arithmetic the game never performs.
enum MovableTestSupport {
    static let cellSize = SearchMap.defaultCellSize

    /// A rectangle of open floor, `columns` × `rows` engine cells.
    static func openMap(
        columns: Int = 40,
        rows: Int = 40,
        obstacles: [CGRect] = [],
        circleSize: Int = 1
    ) -> NavigationMap {
        NavigationMap(
            worldBounds: CGRect(
                x: 0,
                y: 0,
                width: CGFloat(columns) * cellSize.width,
                height: CGFloat(rows) * cellSize.height
            ),
            obstacles: obstacles,
            agentProfile: NavigationAgentProfile(
                halfWidth: 0,
                halfHeight: 0,
                circleSize: circleSize
            ),
            doorObstacles: [],
            entranceDoorBlocking: false,
            cellSize: cellSize
        )
    }

    static func movable(
        on map: NavigationMap,
        at position: CGPoint,
        id: String = "walker",
        blocksSearchMap: Bool = false
    ) -> Movable {
        Movable(
            map: map,
            identity: id,
            position: position,
            circleSize: map.circleSize,
            blocksSearchMap: blocksSearchMap
        )
    }

    /// `walkScale` for an ordinary humanoid — what `doStep` is fed.
    static var humanoidWalkScale: CGFloat {
        ActorLocomotionPacing.infinityEngineWalkScale
    }

    /// Run `ticks` logic ticks, returning every outcome.
    @discardableResult
    static func run(
        _ movable: inout Movable,
        ticks: Int,
        startingAt tick: Int = 1,
        walkScale: CGFloat? = nil
    ) -> [StepOutcome] {
        var outcomes: [StepOutcome] = []
        for offset in 0..<ticks {
            outcomes.append(
                movable.doStep(
                    walkScale: walkScale ?? humanoidWalkScale,
                    time: tick + offset
                )
            )
        }
        return outcomes
    }
}
