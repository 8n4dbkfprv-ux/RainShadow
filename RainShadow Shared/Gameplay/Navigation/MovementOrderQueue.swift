import CoreGraphics
import Foundation

/// What a move order does, what it refuses, and when a walk in progress is
/// replanned.
///
/// This is pure policy over a `NavigationMap` and a `Movable` — it decides
/// *whether* to order a walk and which engine entry point to use. Playing the
/// walk, the bark, the ground reticles and the blocked marker stay with the
/// scene, which is where SpriteKit lives.
///
/// The queue itself is no longer here. The engine has no separate list of
/// pending goals: `AddWayPoint` marks the node it extends from and splices the
/// new leg onto the same `Path`, so the ordered goals travel with the route.
/// `Movable.pendingWaypoints` is what reticles are drawn from.
///
/// The engine behaviours reproduced here:
///
/// - A click on impassable ground is *refused*, not snapped to a nearby tile.
///   `GameControl::OnMouseUp` returns early on `IE_CURSOR_BLOCKED`, and
///   `UpdateCursor` has already greyed the cursor so the refusal is legible
///   before the click lands. Snapping is what let five unreachable city doors
///   and a sealed office floor ship green; see `AGENTS.md`.
/// - A click inside the cell you already occupy is a head turn, not a move
///   (`Movable::WalkTo`).
/// - A fresh order plans around other actors; an appended leg ignores them.
///   Both are `Movable`'s business — see `walkTo` and `addWayPoint`.
/// - `Map::UpdateScripts` replans for nearby actors or expired collision
///   backoff, not on an unconditional timer.
final class MovementOrderQueue {
    /// What the scene should do about an order.
    enum Outcome: Equatable {
        /// Impassable cursor: reject the click without disturbing the live order.
        case blocked
        /// An accepted replacement found no route; the previous order is gone.
        case refused
        /// Inside the occupied cell: request HEAD_TURN, without reorienting the body.
        case turnInPlace
        /// A proximity order whose target is already within its accepted range.
        case alreadyInRange
        /// A fresh order. Replaces any walk in progress.
        case walk
        /// Appended behind the existing route.
        case append
        /// Nothing happened, silently — a queued point too close to plan for,
        /// or an order swallowed by the engine's rate limit.
        case ignored
    }

    /// What a collision-triggered replan concluded.
    enum Repath: Equatable {
        /// No route change is needed.
        case keepWalking
        /// Replanning has failed too often; the route has been dropped.
        case abandon
        /// A new route was adopted.
        case replanned
    }

    enum StepPreparation: Equatable {
        case advance
        case wait
        case abandon
    }

    /// GemRB's `MAX_OPERATING_DISTANCE`: two 16x12 search-cell diagonals.
    /// Doors, containers, dialogue and triggers all use this range rather than
    /// requiring the actor to occupy an exact coordinate.
    static let defaultInteractionDistance = 2 * hypot(
        SearchMap.defaultCellSize.width,
        SearchMap.defaultCellSize.height
    )

    private let navigation: NavigationMap
    private let actorID: String

    init(navigation: NavigationMap, actorID: String) {
        self.navigation = navigation
        self.actorID = actorID
    }

    // MARK: - Orders

    /// Issue a move order. `movable` is advanced to whatever the engine would
    /// have left it in.
    @discardableResult
    func order(
        _ movable: inout Movable,
        to target: CGPoint,
        minDistance: CGFloat = 0,
        queueWaypoint: Bool = false,
        ticks: Int
    ) -> Outcome {
        precondition(minDistance >= 0)
        // A floor click must name floor. An interaction order may name occupied
        // or blocked geometry and asks `FindPath` to stop within `MinDistance`,
        // which is how GemRB actions approach actors, doors and objects.
        let targetCanBeOrdered = minDistance > 0
            ? navigation.searchMap.contains(target)
            : navigation.isOrderableFloor(target)
        guard targetCanBeOrdered else {
            // GameControl::OnMouseUp: `if (lastCursor == IE_CURSOR_BLOCKED)
            // { return false; }` — before CommandSelectedMovement can stop it.
            return .blocked
        }

        // GameControl::CommandSelectedMovement: `if (!append) { actor->Stop(); }`.
        // Append is decided before WalkTo's same-cell branch: a waypoint near
        // the actor is a return leg from the route's end, not an idle turn.
        if queueWaypoint && minDistance == 0 && movable.hasPath {
            let before = movable.remainingPoints.count
            movable.addWayPoint(target, ticks: ticks)
            return movable.remainingPoints.count > before ? .append : .ignored
        }

        movable.stop()
        movable.resetPathTries()

        if minDistance > 0,
           hypot(target.x - movable.position.x, target.y - movable.position.y) <= minDistance {
            return .alreadyInRange
        }

        let searchMap = navigation.searchMap
        if searchMap.cell(for: movable.position) == searchMap.cell(for: target) {
            movable.walkTo(target, ticks: ticks)
            return .turnInPlace
        }

        movable.walkTo(target, minDistance: minDistance, ticks: ticks)
        switch movable.movementState {
        case .moving:
            return .walk
        case .pathSearchFailed:
            return .refused
        case .noMovement:
            // The engine's 2-tick rate limit, or a destination it decided was
            // already reached. Either way nothing visible should happen.
            return .ignored
        }
    }

    /// Stop and forget the route (`Movable::Stop`).
    func cancel(_ movable: inout Movable) {
        movable.stop()
        movable.resetPathTries()
    }

    // MARK: - Corrective repathing

    /// Player branch of `Map::UpdateScripts`, called once per movement tick,
    /// before DoStep. The controllable player can bump (GA_CAN_BUMP); combat
    /// and hostile-actor variants are outside this player-command adapter.
    func prepareStep(
        _ movable: inout Movable,
        ticks: Int,
        walkScale: CGFloat,
        animationCircleSize: Int = GroundCircleResolver.humanoidCircleSize
    ) -> StepPreparation {
        if movable.isBackingOff {
            movable.decreaseBackoff()
            if !movable.isBackingOff, walkScale > 0 {
                if correctiveRepath(&movable, ticks: ticks) == .abandon { return .abandon }
            }
            // Map::UpdateScripts uses if/else: the expiry tick replans but
            // does not also spend a walking step.
            return .wait
        }
        guard movable.isMoving, walkScale > 0 else { return .advance }
        // Map::GetActorInRadius compares PersonalDistance, not centre distance.
        // Occupancy contains the area's live, scheduled actors; ignore self.
        let nearby = navigation.occupancy.actors.values.contains { actor in
            actor.id != actorID && IEGeometry.personalDistance(
                from: movable.position,
                to: actor.position,
                circleSize: actor.personalSpaceCells
            ) <= animationCircleSize
        }
        if nearby, correctiveRepath(&movable, ticks: ticks) == .abandon { return .abandon }
        return .advance
    }

    /// `Actor::NewPath`, reached only through the engine's collision triggers.
    ///
    /// Note what this deliberately does *not* preserve: rebuilding to
    /// `Destination` discards intermediate waypoints. That is the engine's
    /// behaviour, waypoints and all.
    @discardableResult
    func correctiveRepath(
        _ movable: inout Movable,
        ticks: Int
    ) -> Repath {
        guard movable.isMoving else { return .keepWalking }

        if movable.destination == movable.position { return .keepWalking }

        // Do not replan the last cell. `Movable::WalkTo` answers a destination
        // in the cell the actor already occupies with `ClearPath` and a head
        // turn, which is right for a fresh order and wrong here: it would throw
        // away the live route a walker is a few units from finishing, drop it to
        // `noMovement`, and report `keepWalking` — leaving the caller holding a
        // walk that can never report arrival. Let `DoStep` finish the leg.
        let searchMap = navigation.searchMap
        if searchMap.cell(for: movable.position) == searchMap.cell(for: movable.destination) {
            return .keepWalking
        }

        if movable.hasExhaustedPathTries {
            movable.clearPath(resetDestination: true)
            movable.resetPathTries()
            return .abandon
        }

        let savedDestination = movable.destination
        movable.walkTo(
            savedDestination,
            minDistance: CGFloat(movable.pathfindingDistance),
            requestType: .walkToFromNewPath,
            ticks: ticks
        )
        switch movable.movementState {
        case .moving: return .replanned
        case .pathSearchFailed: return .abandon
        case .noMovement: return .keepWalking
        }
    }
}
