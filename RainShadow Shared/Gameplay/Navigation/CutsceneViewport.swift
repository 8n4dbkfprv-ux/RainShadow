import CoreGraphics

/// GemRB GlobalTimer::SetMoveViewPort / DoStep (1c45c185), expressed as
/// camera centres rather than viewport origins. No actor projection correction:
/// the viewport moves in already-projected map pixels, at speed * 2 per tick.
struct CutsceneViewport: Equatable, Sendable {
    private(set) var position: CGPoint
    private(set) var destination: CGPoint?
    private var speed: ScrollSpeed = .instant

    init(position: CGPoint) { self.position = position }
    var isMoving: Bool { destination.map { $0 != position } ?? false }

    mutating func move(to point: CGPoint, speed: ScrollSpeed) {
        guard destination != point else { return }
        destination = point
        self.speed = speed
        if speed == .instant { position = point }
    }

    mutating func advance(ticks: Int = 1) {
        guard let destination, isMoving, ticks > 0 else { return }
        let distance = Int(hypot(destination.x - position.x, destination.y - position.y))
        let magnitude = CGFloat(ticks) * speed.pointsPerTick
        if CGFloat(distance) <= magnitude {
            position = destination
        } else {
            let ratio = magnitude / CGFloat(distance)
            position = CGPoint(
                x: Int((1 - ratio) * position.x + ratio * destination.x),
                y: Int((1 - ratio) * position.y + ratio * destination.y)
            )
        }
    }

    /// MoveViewportTo stops a rail when the area boundary prevents further motion.
    mutating func reconcile(clamped: CGPoint, previous: CGPoint) {
        position = clamped
        if clamped == previous { destination = clamped }
    }
}
