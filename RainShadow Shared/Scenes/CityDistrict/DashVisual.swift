import SpriteKit

/// A short, clock-driven gust at activation. No autonomous actions or emitters:
/// the same elapsed time freezes the pose and every wisp during tactical pause.
@MainActor final class DashVisual: SKNode {
    private var wisps: [SKShapeNode] = []
    private(set) var elapsed = 0.0

    init(bear: Bool) {
        super.init()
        name = "combat.dash.wind"
        setScale(bear ? 1.35 : 1)
        for index in 0..<9 {
            let wisp = SKShapeNode()
            wisp.strokeColor = SKColor(red: 0.82, green: 0.93, blue: 0.95, alpha: 1)
            wisp.lineWidth = index < 3 ? 1.5 : 0.8
            wisp.glowWidth = 1.2
            wisp.fillColor = .clear
            addChild(wisp); wisps.append(wisp)
        }
        advance(elapsed: 0)
    }
    required init?(coder: NSCoder) { fatalError("Created in code") }

    func advance(elapsed: Double) {
        self.elapsed = elapsed
        let t = (elapsed - DashAnimationSet.impactTime + 0.09) / 0.44
        isHidden = t <= 0 || t >= 1
        guard !isHidden else { return }
        for (index, wisp) in wisps.enumerated() {
            let angle = Double(index) * 2.399 + t * 0.8
            let radius = 10 + 35 * t
            let height = index < 3 ? 3.0 : Double(index - 2) * 8
            let path = CGMutablePath()
            for segment in 0...7 {
                let a = angle + Double(segment) * 0.07
                let point = CGPoint(x: cos(a) * radius,
                                    y: sin(a) * radius * 0.75 + height + t * 12)
                if segment == 0 { path.move(to: point) } else { path.addLine(to: point) }
            }
            wisp.path = path
            wisp.alpha = CGFloat(sin(.pi * t) * (index < 3 ? 0.75 : 0.55))
        }
    }
}
