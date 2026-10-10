import SpriteKit

/// Parchment readout kept separate from action-bar art and hit regions.
@MainActor final class CombatTargetPanel: SKNode {
    private let plate = SKShapeNode()
    private let title = SKLabelNode(fontNamed: UITheme.Font.hudVital)
    private let body = SKLabelNode(fontNamed: "AvenirNext-Medium")
    private let footer = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
    private(set) var text = ""
    private(set) var examining = false
    var panelWidth: CGFloat = 330
    private(set) var panelHeight: CGFloat = 240

    override init() {
        super.init()
        name = "combat.targetPanel"; zPosition = 120; isHidden = true
        plate.fillTexture = UIPaintedChrome.parchmentSurface()
        plate.fillColor = .white; plate.strokeColor = UITheme.Color.engraved; plate.lineWidth = 2
        addChild(plate)
        for label in [title, body, footer] {
            label.fontColor = UITheme.Color.ink
            label.horizontalAlignmentMode = .left; label.verticalAlignmentMode = .top
            label.numberOfLines = 0; addChild(label)
        }
        title.fontSize = 17; body.fontSize = 12; footer.fontSize = 11
    }
    required init?(coder: NSCoder) { fatalError("Created in code") }
    func show(title heading: String, lines: [String], examining: Bool = false) {
        self.examining = examining; isHidden = false
        title.text = heading; body.text = lines.joined(separator: "\n")
        footer.text = examining ? "Close · click here / T / Escape" : "Examine · click here / T"
        text = ([heading] + lines + [footer.text!]).joined(separator: "\n")
        for label in [title, body, footer] { label.preferredMaxLayoutWidth = panelWidth - 32 }
        let titleHeight = max(22, title.frame.height)
        panelHeight = titleHeight + body.frame.height + 72
        plate.path = CGPath(roundedRect: CGRect(x: 0, y: -panelHeight, width: panelWidth, height: panelHeight), cornerWidth: 7, cornerHeight: 7, transform: nil)
        title.position = CGPoint(x: 16, y: -14)
        body.position = CGPoint(x: 16, y: -22 - titleHeight)
        footer.position = CGPoint(x: 16, y: -panelHeight + 28)
    }
    func containsPanelPoint(_ point: CGPoint) -> Bool { !isHidden && CGRect(x: 0, y: -panelHeight, width: panelWidth, height: panelHeight).contains(point) }
    func footerContains(_ point: CGPoint) -> Bool { containsPanelPoint(point) && point.y < -panelHeight + 40 }
    func clear() { isHidden = true; examining = false; text = "" }
}
