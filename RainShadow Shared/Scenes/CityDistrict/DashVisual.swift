import SpriteKit

/// A short, clock-driven gust at activation. No autonomous actions or emitters:
/// the same elapsed time freezes the pose and every wisp during tactical pause.
@MainActor final class DashVisual: SKNode {
    private static let texture: SKTexture = {
        let texture = SKTexture(imageNamed: "dash_wind_wisp_v01")
        texture.filteringMode = .linear
        return texture
    }()
    private var wisps: [SKSpriteNode] = []
    private(set) var elapsed = 0.0

    init(bear: Bool) {
        super.init()
        name = "combat.dash.wind"
        setScale(bear ? 1.35 : 1)
        for index in 0..<5 {
            let wisp = SKSpriteNode(texture: Self.texture)
            wisp.name = "combat.dash.wisp.\(index)"
            // The effect's parent sits at +1: the far half of the foot gust
            // passes behind the body, with the near half in front of the boots.
            wisp.zPosition = index == 0 ? -1.2 : 0
            wisp.blendMode = .alpha
            addChild(wisp); wisps.append(wisp)
        }
        advance(elapsed: 0)
    }
    required init?(coder: NSCoder) { fatalError("Created in code") }

    func advance(elapsed: Double) {
        self.elapsed = elapsed
        let start = DashAnimationSet.impactTime - 0.15
        isHidden = elapsed <= start || elapsed >= DashAnimationSet.duration
        for (index, wisp) in wisps.enumerated() {
            let t = min(1, max(0, (elapsed - start - Double(index) * 0.032) / 0.53))
            // Fast gathering, then a long soft dissipation. Independent births
            // avoid the old nine arcs blinking on and off as one rigid ring.
            let gather = min(1, t / 0.22)
            let dissolve = min(1, max(0, (t - 0.28) / 0.72))
            let fade = 1 - dissolve * dissolve * (3 - 2 * dissolve)
            wisp.alpha = CGFloat(gather * fade * (index < 2 ? 0.72 : 0.58))
            let spread = 1 - pow(1 - t, 2)
            let side = index % 2 == 0 ? -1.0 : 1.0
            if index < 2 {
                wisp.size = CGSize(width: 54 + spread * 65, height: 28 + spread * 22)
                wisp.position = CGPoint(x: side * (3 + spread * 8), y: 3 + spread * 8)
                wisp.yScale = index == 0 ? -0.75 : 0.75
            } else {
                wisp.size = CGSize(width: 40 + spread * 36, height: 18 + spread * 14)
                wisp.position = CGPoint(x: side * (16 + spread * 15),
                                        y: Double(index - 1) * 15 + spread * 20)
                wisp.xScale = CGFloat(side)
                // Keep the textured quads axis-aligned for the native world's
                // direct sprite compositor; the curve is painted into the art.
                wisp.yScale = 1 + spread * 0.25
            }
        }
    }
}
