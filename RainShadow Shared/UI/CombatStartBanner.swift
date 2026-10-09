import SpriteKit

/// Presentation only: the director advances this clock alongside combat effects,
/// so inventory and tactical pause freeze the entrance as well as the turn.
@MainActor
final class CombatStartBanner: SKNode {
    static let duration: TimeInterval = 1.9
    private(set) var elapsed: TimeInterval = 0
    var finished: Bool { elapsed >= Self.duration }
    private let content = SKNode()
    private let title = SKLabelNode(fontNamed: UITheme.Font.overlayTitle)

    override init() {
        super.init()
        name = "combat.startBanner"
        zPosition = 20
        addChild(content)
        let texture = GameArt.texture(named: "combat_start_banner_v01")
        texture?.filteringMode = .linear
        let backing = SKSpriteNode(texture: texture)
        backing.size = CGSize(width: 680, height: 680 * 793 / 1983)
        content.addChild(backing)
        title.text = "Combat Begins"
        title.fontSize = 30
        title.fontColor = SKColor(red: 0.97, green: 0.88, blue: 0.67, alpha: 1)
        title.verticalAlignmentMode = .center
        title.position.y = -18
        content.addChild(title)
        render()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func layout(width: CGFloat, sceneHeight: CGFloat) {
        setScale(min(1, max(1, width) / 680))
        position.y = max(0, sceneHeight / 2 - 235)
    }

    func advance(delta: TimeInterval) {
        elapsed = min(Self.duration, elapsed + max(0, delta))
        render()
        if finished { removeFromParent() }
    }

    private func render() {
        let entrance = min(1, elapsed / 0.3)
        let eased = 1 - pow(1 - entrance, 3)
        let exit = max(0, min(1, (elapsed - 1.5) / 0.4))
        alpha = finished ? 0 : CGFloat(entrance * (1 - exit))
        content.setScale(CGFloat(0.94 + 0.06 * eased))
        content.position.y = CGFloat(12 * (1 - eased) + 8 * exit * exit)
        title.alpha = CGFloat(min(1, max(0, (elapsed - 0.12) / 0.22)))
    }
}
