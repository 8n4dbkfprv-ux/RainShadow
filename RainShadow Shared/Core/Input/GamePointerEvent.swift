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
    /// BG:EE double-click, which also recenters the viewport on the click
    /// (`GameControl::OnMouseUp` calls `MoveViewportTo(p, true)`).
    let isDoubleClick: Bool

    init(
        location: CGPoint,
        kind: GamePointerKind,
        isWaypointQueue: Bool = false,
        isDoubleClick: Bool = false
    ) {
        self.location = location
        self.kind = kind
        self.isWaypointQueue = isWaypointQueue
        self.isDoubleClick = isDoubleClick
    }
}
