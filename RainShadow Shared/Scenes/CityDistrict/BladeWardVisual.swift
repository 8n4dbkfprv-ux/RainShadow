import SpriteKit

/// Clock-driven particles: tactical pause and inventory freeze every element.
@MainActor final class BladeWardVisual: SKNode {
    private let shell = SKShapeNode(ellipseOf: CGSize(width: 72, height: 106))
    private let seal = SKShapeNode()
    private var motes: [SKShapeNode] = []
    private(set) var elapsed: Double = 0
    private var flash: Double = 0

    override init() {
        super.init()
        name = "combat.blade-ward.effect"
        shell.position.y = 48; shell.fillColor = SKColor(red: 0.25, green: 0.75, blue: 1, alpha: 0.025)
        shell.strokeColor = SKColor(red: 0.63, green: 0.9, blue: 1, alpha: 1)
        shell.lineWidth = 1; shell.glowWidth = 2
        addChild(shell)
        let path = CGMutablePath()
        for i in 0...6 {
            let a = CGFloat(i) * .pi / 3
            let p = CGPoint(x: sin(a) * 34, y: cos(a) * 25.5)
            if i == 0 { path.move(to: p) } else { path.addLine(to: p) }
        }
        seal.path = path; seal.fillColor = .clear
        seal.strokeColor = SKColor(red: 0.91, green: 0.8, blue: 0.5, alpha: 1)
        seal.glowWidth = 2; seal.lineWidth = 1.2
        addChild(seal)
        for index in 0..<18 {
            let mote = SKShapeNode(circleOfRadius: index % 3 == 0 ? 1.5 : 0.8)
            mote.fillColor = index % 3 == 0 ? seal.strokeColor : shell.strokeColor
            mote.strokeColor = .clear; mote.glowWidth = 2
            addChild(mote); motes.append(mote)
        }
    }
    required init?(coder: NSCoder) { fatalError("Created in code") }
    func struck() { flash = 0.32 }
    func advance(delta: Double, castTime: Double?, bear: Bool) {
        elapsed += delta; flash = max(0, flash - delta)
        let forming = castTime.map { min(1, $0 / BladeWardAnimationSet.impactTime) } ?? 1
        let burst = castTime.map { max(0, 1 - abs($0 - BladeWardAnimationSet.impactTime) / 0.35) } ?? 0
        setScale(bear ? 1.25 : 1)
        shell.alpha = CGFloat(0.09 + burst * 0.65 + flash * 1.9)
        shell.setScale(CGFloat(0.7 + forming * 0.3 + flash * 0.3))
        seal.alpha = CGFloat(0.18 + burst * 0.6 + flash)
        seal.setScale(CGFloat(0.7 + forming * 0.3))
        for (i, mote) in motes.enumerated() {
            let t = elapsed * 0.65 + Double(i) * 0.37
            let angle = t * 2 + Double(i) * 2.4
            let height = (t.truncatingRemainder(dividingBy: 1)) * 92
            mote.position = CGPoint(x: cos(angle) * 32 * forming, y: 7 + height + sin(angle) * 8)
            mote.alpha = CGFloat((0.22 + burst * 0.65 + flash) * sin(.pi * height / 92))
        }
    }
}
