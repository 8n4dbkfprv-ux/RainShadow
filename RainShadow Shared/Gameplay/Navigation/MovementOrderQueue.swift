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
/// - A walk is replanned periodically, and abandoned once `MAX_PATH_TRIES`
///   consecutive searches have found nothing (`Actor::NewPath`).
final class MovementOrderQueue {
    /// What the scene should do about an order.
    enum Outcome: Equatable {
        /// Impassable ground: show the blocked marker, say nothing, clear pips.
        case refused
        /// Inside the occupied cell: pivot toward the point, take no step.
        case turnInPlace
        /// A fresh order. Replaces any walk in progress.
        case walk
        /// Appended behind the existing route.
        case append
        /// Nothing happened, silently — a queued point too close to plan for,
        /// or an order swallowed by the engine's rate limit.
        case ignored
    }

    /// What a periodic replan concluded.
    enum Repath: Equatable {
        /// Nothing to do — not due, not moving, or the order was rate-limited.
        case keepWalking
        /// Replanning has failed too often; the route has been dropped.
        case abandon
        /// A new route was adopted.
        case replanned
    }

    /// BG:EE replans a walking actor on a timer rather than every frame.
    static let correctiveRepathInterval: TimeInterval = 0.75

    private let navigation: NavigationMap
    private let actorID: String
    private var lastRepathTime: TimeInterval = 0

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
        requiresExactDestination: Bool = false,
        queueWaypoint: Bool = false,
        ticks: Int
    ) -> Outcome {
        guard navigation.isOrderableFloor(target) else {
            movable.stop()
            return .refused
        }

        let searchMap = navigation.searchMap
        if searchMap.cell(for: movable.position) == searchMap.cell(for: target) {
            movable.walkTo(target, ticks: ticks)
            return .turnInPlace
        }

        let shouldQueue = queueWaypoint && !requiresExactDestination && movable.hasPath
        if shouldQueue {
            let before = movable.remainingPoints.count
            movable.addWayPoint(target, ticks: ticks)
            return movable.remainingPoints.count > before ? .append : .ignored
        }

        movable.walkTo(target, ticks: ticks)
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

    /// `Actor::NewPath`, on BG:EE's "Enhanced Path Search" cadence.
    ///
    /// Note what this deliberately does *not* preserve: rebuilding to
    /// `Destination` discards intermediate waypoints. That is the engine's
    /// behaviour, waypoints and all.
    @discardableResult
    func correctiveRepath(
        _ movable: inout Movable,
        at currentTime: TimeInterval,
        ticks: Int
    ) -> Repath {
        guard movable.isMoving else { return .keepWalking }
        guard currentTime - lastRepathTime >= Self.correctiveRepathInterval else {
            return .keepWalking
        }
        lastRepathTime = currentTime

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

    /// Reset the replan clock, e.g. after a scene resumes from a modal overlay.
    func resetRepathClock() {
        lastRepathTime = 0
    }
}
