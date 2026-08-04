import CoreGraphics

enum GamePointerKind {
    case touch
    case mouse
}

struct GamePointerEvent {
    let location: CGPoint
    let kind: GamePointerKind
    /// BG:EE Shift+click (macOS) or long-press (iOS) — append a waypoint instead of replacing the route.
    let isWaypointQueue: Bool

    init(location: CGPoint, kind: GamePointerKind, isWaypointQueue: Bool = false) {
        self.location = location
        self.kind = kind
        self.isWaypointQueue = isWaypointQueue
    }
}
