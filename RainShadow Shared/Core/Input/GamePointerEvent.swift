import CoreGraphics

enum GamePointerKind {
    case touch
    case mouse
}

struct GamePointerEvent {
    let location: CGPoint
    let kind: GamePointerKind
}

