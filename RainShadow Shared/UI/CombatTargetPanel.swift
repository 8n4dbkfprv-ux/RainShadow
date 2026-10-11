import SpriteKit

/// Parchment readout kept separate from action-bar art and hit regions.
@MainActor final class CombatTargetPanel: SKNode {
    private let plate = UIPaintedChrome.tooltipBackground()
    private let title = SKLabelNode(fontNamed: UITheme.Font.hudVital)
    private let body = SKLabelNode(fontNamed: UITheme.Font.overlayBody)
    private let footer = SKLabelNode(fontNamed: UITheme.Font.overlayBodyBold)
    private(set) var text = ""
    private(set) var examining = false
    var panelWidth: CGFloat = 330
    private(set) var panelHeight: CGFloat = 240

    override init() {
        super.init()
        name = "combat.targetPanel"; zPosition = 120; isHidden = true
        plate.zPosition = -1
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
        footer.text = examining ? "Close [T / Esc]" : "Examine [T]"
        text = ([heading] + lines + [footer.text!]).joined(separator: "\n")
        for label in [title, body, footer] { label.preferredMaxLayoutWidth = panelWidth - 44 }
        let titleHeight = max(22, title.frame.height)
        panelHeight = titleHeight + body.frame.height + 80
        UIPaintedChrome.sizeTooltipBackground(plate, to: CGSize(width: panelWidth, height: panelHeight))
        plate.position = CGPoint(x: panelWidth / 2, y: -panelHeight / 2)
        title.position = CGPoint(x: 22, y: -20)
        body.position = CGPoint(x: 22, y: -28 - titleHeight)
        footer.position = CGPoint(x: 22, y: -panelHeight + 30)
    }
    func containsPanelPoint(_ point: CGPoint) -> Bool { !isHidden && CGRect(x: 0, y: -panelHeight, width: panelWidth, height: panelHeight).contains(point) }
    func footerContains(_ point: CGPoint) -> Bool { containsPanelPoint(point) && point.y < -panelHeight + 40 }
    func clear() { isHidden = true; examining = false; text = "" }
}
