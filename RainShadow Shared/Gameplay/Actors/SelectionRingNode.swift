import SpriteKit

/// Painted underfoot selection ring (IE-style isometric ellipse).
/// Sits above the soft contact shadow (`ContactShadowFactory`) and below the body.
@MainActor
enum SelectionRingKind {
    case party
    case npc

    var textureName: String {
        switch self {
        case .party: "ui_selection_ring_party"
        case .npc: "ui_selection_ring_npc"
        }
    }
}

@MainActor
enum SelectionRingFactory {
    /// Builds a nearest-filtered ring sprite sized to the actor footprint.
    static func make(
        kind: SelectionRingKind,
        displaySize: CGSize,
        position: CGPoint,
        scale: CGFloat
    ) -> SKSpriteNode {
        let texture = GameArt.texture(named: kind.textureName)
        let ring: SKSpriteNode
        if let texture {
            ring = SKSpriteNode(texture: texture, size: displaySize)
            texture.filteringMode = .nearest
        } else {
            ring = SKSpriteNode(color: .clear, size: displaySize)
        }
        ring.name = kind.textureName
        ring.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        ring.position = position
        ring.setScale(scale)
        // Above contact shadow (default 0), below body layers.
        ring.zPosition = 0.5
        return ring
    }
}
