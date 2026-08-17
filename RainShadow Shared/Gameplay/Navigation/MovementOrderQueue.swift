import CoreGraphics
import Foundation

/// The Baldur's Gate waypoint queue: what a move order does, what it refuses,
/// and when a walk in progress should be replanned.
///
/// This is pure policy over a `NavigationMap` — it decides *whether* to walk and
/// *along which points*, and hands the answer back. Playing the walk, the bark,
/// the ground reticles and the blocked marker stay with the scene, which is
/// where SpriteKit lives.
///
/// It was previously written twice, in `CityDistrictScene` and
/// `DetectiveOfficeScene`, at about 150 near-identical lines each — the two
/// copies differed only in comment wording, one bark argument, and whether a
/// second actor's occupancy was updated. Being scene code, it was also the
/// largest piece of navigation behaviour in the project with no unit test at
/// all: the SwiftPM target is `Gameplay/Navigation`, and this logic sat outside
/// it. Moving it here is what makes `MovementOrderQueueTests` possible.
///
/// The engine behaviours reproduced here, each of which was a deliberate choice
/// in the scenes and would be easy to lose in a refactor:
///
/// - A click inside the cell you already occupy is a head turn, not a move
///   (`Movable::WalkTo`).
/// - An order onto impassable ground is *refused*, not snapped to a nearby tile
///   (`IE_CURSOR_BLOCKED`). Snapping is what let five unreachable city doors and
///   a sealed office floor ship green; see `AGENTS.md`.
/// - Pathing is two-tier: plan around other actors first, and only fall back to
///   a route through them — which the mover resolves by bumping — when no clear
///   route exists.
/// - A queued waypoint that resolves to an empty path is dropped rather than
///   appended (`AddWayPoint` returns without appending when the point is too
///   close), or the queue gains a goal no waypoints will ever consume.
/// - A leg is replanned periodically (Enhanced Path Search), and abandoned after
///   `MAX_PATH_TRIES` consecutive failures rather than retried forever.
final class MovementOrderQueue {
    /// What the scene should do about an order.
    enum Outcome: Equatable {
        /// Impassable ground: show the blocked marker, say nothing, clear pips.
        case refused
        /// Inside the occupied cell: pivot toward the point, take no step.
        case turnInPlace
        /// A fresh order. Replaces the queue and any walk in progress.
        case walk(path: [CGPoint])
        /// Appended behind the existing queue.
        case append(path: [CGPoint])
        /// A queued point too close to plan for. Nothing happens, silently.
        case ignored
    }

    /// What a periodic replan concluded.
    enum Repath: Equatable {
        /// Nothing to do — not due, not moving, or the live route is still good.
        case keepWalking
        /// Replanning has failed too often; stop and clear the queue.
        case abandon
        /// Adopt this route, current leg plus every remaining queued goal.
        case walk(path: [CGPoint])
    }

    /// How close counts as having reached a queued goal.
    ///
    /// Shared by pruning and by the "current leg" scan, so a goal cannot be
    /// pruned as reached while the leg scan still considers it ahead.
    static let arrivalSlop: CGFloat = 18

    /// BG:EE replans a walking actor on a timer rather than every frame.
    static let correctiveRepathInterval: TimeInterval = 0.75

    /// A replacement route has to beat the live one by this much before it is
    /// adopted, so near-identical replacements do not show as mid-walk kinks.
    static let meaningfulImprovement: CGFloat = 0.9

    private let navigation: NavigationMap
    private let actorID: String

    /// Ordered goals. Index 0 is the leg being walked.
    private(set) var goals: [CGPoint] = []
    private var lastRepathTime: TimeInterval = 0

    init(navigation: NavigationMap, actorID: String) {
        self.navigation = navigation
        self.actorID = actorID
    }

    var isEmpty: Bool { goals.isEmpty }

    /// The goal currently being walked toward.
    var currentGoal: CGPoint? { goals.first }

    // MARK: - Orders

    func order(
        actorAt position: CGPoint,
        to target: CGPoint,
        requiresExactDestination: Bool = false,
        queueWaypoint: Bool = false
    ) -> Outcome {
        let shouldQueue = queueWaypoint && !requiresExactDestination && !goals.isEmpty
        if shouldQueue {
            return appendWaypoint(to: target)
        }

        if !requiresExactDestination,
           navigation.searchMap.cell(for: position) == navigation.searchMap.cell(for: target) {
            goals.removeAll(keepingCapacity: true)
            return .turnInPlace
        }

        guard let waypoints = navigation.pathAvoidingActors(from: position, to: target)
            ?? navigation.path(from: position, to: target)
        else {
            goals.removeAll(keepingCapacity: true)
            return .refused
        }

        // A fresh order restarts the replan budget, as `Actor::WalkTo` resets
        // `pathTries` before planning.
        navigation.occupancy.clearCongestion(for: actorID)
        goals = [target]
        return .walk(path: waypoints)
    }

    private func appendWaypoint(to target: CGPoint) -> Outcome {
        guard let origin = goals.last else { return .ignored }
        guard let waypoints = navigation.path(from: origin, to: target) else {
            return .refused
        }
        // `[]` is the three-valued search's "already there", not a route.
        guard !waypoints.isEmpty else { return .ignored }
        goals.append(target)
        return .append(path: waypoints)
    }

    /// Clear the queue — the walk finished, or was cancelled.
    func finish() {
        goals.removeAll(keepingCapacity: true)
    }

    /// Drop goals already reached, so the repath tracks the live leg and the
    /// scene can retire the matching reticles. Returns the goals removed.
    ///
    /// The final goal is deliberately kept even when the actor is standing on
    /// it: locomotion's own completion clears the queue, and pruning it here
    /// would drop the destination reticle a frame early.
    @discardableResult
    func pruneReachedGoals(actorAt position: CGPoint) -> [CGPoint] {
        var removed: [CGPoint] = []
        while goals.count > 1, let goal = goals.first,
              hypot(position.x - goal.x, position.y - goal.y) <= Self.arrivalSlop {
            removed.append(goal)
            goals.removeFirst()
        }
        return removed
    }

    // MARK: - Corrective repath

    func correctiveRepath(
        actorAt position: CGPoint,
        remainingRoute: [CGPoint],
        isMoving: Bool,
        at currentTime: TimeInterval
    ) -> Repath {
        guard let destination = goals.first,
              isMoving,
              currentTime - lastRepathTime >= Self.correctiveRepathInterval
        else {
            return .keepWalking
        }
        lastRepathTime = currentTime

        guard let repath = navigation.repath(from: position, to: destination), !repath.isEmpty else {
            // Count consecutive failed replans toward the same goal and give up
            // past `MAX_PATH_TRIES`, rather than grinding a search every 0.75 s
            // for the rest of the scene against geometry that will not open.
            if navigation.occupancy.recordCongestion(for: actorID) {
                navigation.occupancy.clearCongestion(for: actorID)
                goals.removeAll(keepingCapacity: true)
                return .abandon
            }
            return .keepWalking
        }
        navigation.occupancy.clearCongestion(for: actorID)

        let currentLeg = Self.leg(of: remainingRoute, endingNear: destination)
        let remainingLength = Self.polylineLength(currentLeg, from: position)
        let newLength = Self.polylineLength(repath, from: position)
        let meaningfullyShorter = remainingLength > 0
            && newLength < remainingLength * Self.meaningfulImprovement
        guard meaningfullyShorter || isBlocked(currentLeg, from: position) else {
            return .keepWalking
        }

        var combined = repath
        var cursor = destination
        for goal in goals.dropFirst() {
            if let nextLeg = navigation.path(from: cursor, to: goal) {
                combined.append(contentsOf: nextLeg)
                cursor = goal
            }
        }
        return .walk(path: combined)
    }

    /// The part of a live route belonging to the current leg — up to and
    /// including the first point within arrival slop of the leg's destination.
    static func leg(of route: [CGPoint], endingNear destination: CGPoint) -> [CGPoint] {
        var points: [CGPoint] = []
        for point in route {
            points.append(point)
            if hypot(point.x - destination.x, point.y - destination.y) <= arrivalSlop {
                break
            }
        }
        return points
    }

    func isBlocked(_ points: [CGPoint], from origin: CGPoint) -> Bool {
        var cursor = origin
        for point in points {
            if !navigation.searchMap.isWalkableLine(
                from: cursor,
                to: point,
                radius: navigation.agentProfile.radius,
                treatActorsAsBlocking: true
            ) {
                return true
            }
            cursor = point
        }
        return false
    }

    /// Route length in the projected metric the actor walks, so a repath
    /// compares travel *time* rather than raw screen distance — on a 0.75
    /// vertical foreshortening those differ by a third along the depth axis.
    static func polylineLength(_ points: [CGPoint], from origin: CGPoint) -> CGFloat {
        guard let first = points.first else { return 0 }
        var length = ActorLocomotionPacing.projectedDistance(from: origin, to: first)
        var previous = first
        for point in points.dropFirst() {
            length += ActorLocomotionPacing.projectedDistance(from: previous, to: point)
            previous = point
        }
        return length
    }
}
