import CoreGraphics
import Foundation

/// One node of a walked route, as GemRB models it (`core/PathFinder.h`).
///
/// The node carries its own orientation because the search computes it — the
/// engine never re-derives facing from velocity while walking, it assigns
/// `step.orient` outright in `DoStep`.
///
/// `waypoint` marks a node the player explicitly ordered, as distinct from the
/// nodes the search interpolated between them. `AddWayPoint` sets it on the last
/// node of the leg being extended; `DoStep` clears it on arrival. This is why the
/// engine needs no separate queue of pending goals.
struct PathNode: Equatable, Sendable {
    var point: CGPoint
    var orient: ActorFacing
    var waypoint: Bool

    init(point: CGPoint, orient: ActorFacing, waypoint: Bool = false) {
        self.point = point
        self.orient = orient
        self.waypoint = waypoint
    }
}

/// A whole route plus a cursor into it.
///
/// Nodes are **not** consumed as they are walked; `currentStep` advances instead.
/// Keeping the spent prefix is what lets `getMostLikelyPosition` extrapolate,
/// waypoint marking survive a leg being appended, and reticles be drawn for every
/// ordered goal rather than only the ones still ahead.
struct Path: Equatable, Sendable {
    var nodes: [PathNode] = []
    var currentStep: Int = 0

    init(nodes: [PathNode] = [], currentStep: Int = 0) {
        self.nodes = nodes
        self.currentStep = currentStep
    }

    /// Build a path from a bare polyline, giving each node the orientation the
    /// search would have stored on it (`GetOrient(parent, current)`).
    ///
    /// For authored routes — scripted beats, cutscene rails, bump sidesteps —
    /// which are points rather than a search result. Zero-length steps are
    /// dropped, because `DoStep` treats a zero delta as "already at the goal"
    /// and abandons the whole path.
    init(points: [CGPoint], from origin: CGPoint) {
        var previous = origin.rounded
        var nodes: [PathNode] = []
        for point in points {
            let rounded = point.rounded
            guard rounded != previous else { continue }
            nodes.append(
                PathNode(point: rounded, orient: ActorFacing.orient(from: previous, to: rounded))
            )
            previous = rounded
        }
        self.init(nodes: nodes)
    }

    /// GemRB spells this `operator bool` and tests it constantly; a path is
    /// "present" when it has nodes at all, regardless of how far it has been walked.
    var isEmpty: Bool { nodes.isEmpty }
    var isPresent: Bool { !nodes.isEmpty }
    var size: Int { nodes.count }

    /// Nodes still ahead of the walker, including the one being walked toward.
    var remaining: Int { max(0, nodes.count - currentStep) }

    mutating func clear() {
        nodes.removeAll(keepingCapacity: true)
        currentStep = 0
    }

    func step(at index: Int) -> PathNode? {
        nodes.indices.contains(index) ? nodes[index] : nil
    }

    /// `GetCurrentStep` — the node being walked toward.
    var currentStepNode: PathNode? {
        step(at: currentStep)
    }

    /// `GetNextStep(x)` — `x` nodes beyond the current one.
    func nextStep(_ x: Int) -> PathNode? {
        step(at: currentStep + x)
    }

    var destination: CGPoint? { nodes.last?.point }

    mutating func appendStep(_ node: PathNode) {
        nodes.append(node)
    }

    mutating func prependStep(_ node: PathNode) {
        nodes.insert(node, at: 0)
    }

    /// `AppendPath` — splice another leg onto the end. The cursor is untouched,
    /// so an actor mid-walk keeps walking.
    mutating func append(_ other: Path) {
        nodes.append(contentsOf: other.nodes)
    }

    /// Mark the final node as an ordered waypoint (`AddWayPoint`).
    mutating func markLastAsWaypoint() {
        guard !nodes.isEmpty else { return }
        nodes[nodes.count - 1].waypoint = true
    }

    /// Ordered goals still ahead — what the ground reticles are drawn from.
    var pendingWaypoints: [CGPoint] {
        guard currentStep < nodes.count else { return [] }
        return nodes[currentStep...].filter(\.waypoint).map(\.point)
    }

    /// The bare polyline still ahead. Callers that only need geometry (route
    /// length, tests, debug overlays) use this rather than reaching into nodes.
    var remainingPoints: [CGPoint] {
        guard currentStep < nodes.count else { return [] }
        return nodes[currentStep...].map(\.point)
    }
}
