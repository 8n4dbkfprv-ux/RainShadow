import SpriteKit

/// Camera-fixed left action rail: Infinity Engine density with RainShadow noir painted chrome.
@MainActor
final class ActionBarNode: SKNode {
    enum Button: Int, CaseIterable {
        case menu
        case map
        case journal
        case inventory
        case character
        case leads
        case contacts
        case settings
        case rest
        case help
        case hideUI
        case clock

        var artName: String {
            switch self {
            case .menu: return "hud_action_menu_v02"
            case .map: return "hud_action_map_v02"
            case .journal: return "hud_action_journal_v02"
            case .inventory: return "hud_action_inventory_v02"
            case .character: return "hud_action_character_v02"
            case .leads: return "hud_action_leads_v02"
            case .contacts: return "hud_action_contacts_v02"
            case .settings: return "hud_action_settings_v02"
            case .rest: return "hud_action_rest_v02"
            case .help: return "hud_action_help_v02"
            case .hideUI: return "hud_action_hide_ui_v02"
            case .clock: return "hud_action_clock_v02"
            }
        }

        var isInteractive: Bool {
            switch self {
            case .map, .journal, .inventory, .character: return true
            default: return false
            }
        }

        var stubMessage: String {
            switch self {
            case .menu: return "Agency menu — not yet"
            case .leads: return "Leads board — not yet"
            case .contacts: return "Contacts — not yet"
            case .settings: return "Settings — not yet"
            case .rest: return "Rest — not yet"
            case .help: return "Help — not yet"
            case .hideUI: return "Hide UI — not yet"
            case .clock: return "Time of day — not yet"
            default: return ""
            }
        }
    }

    private enum Metrics {
        static let railWidth: CGFloat = 108
        static let buttonSize = CGSize(width: 72, height: 56)
        static let hitSize = CGSize(width: 88, height: 60)
        static let topInset: CGFloat = 18
        static let buttonSpacing: CGFloat = 4
    }

    private let railPlate = SKSpriteNode()
    private var buttonRoots: [Button: SKNode] = [:]
    private var buttonArt: [Button: SKSpriteNode] = [:]
    private var highlightedButton: Button?
    private var pressedButton: Button?
    private var pressIsInside = false
    private let stubCaption = SKLabelNode(fontNamed: UITheme.Font.typewriter)

    var onStubActivated: ((Button) -> Void)?

    override init() {
        super.init()
        name = "hud.action-bar"
        buildRail()
        buildButtons()
        buildStubCaption()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("ActionBarNode is created programmatically")
    }

    func layout(for visibleSize: CGSize) {
        let railHeight = visibleSize.height + 12
        position = CGPoint(x: -visibleSize.width / 2 + Metrics.railWidth / 2, y: 0)
        railPlate.size = CGSize(width: Metrics.railWidth, height: railHeight)

        let topY = visibleSize.height / 2 - Metrics.topInset - Metrics.buttonSize.height / 2
        for (index, button) in Button.allCases.enumerated() {
            guard let root = buttonRoots[button] else { continue }
            root.position = CGPoint(
                x: 0,
                y: topY - CGFloat(index) * (Metrics.buttonSize.height + Metrics.buttonSpacing)
            )
        }
        stubCaption.position = CGPoint(x: Metrics.railWidth / 2 + 110, y: 0)
    }

    func hitTest(_ point: CGPoint) -> Button? {
        for button in Button.allCases {
            guard let root = buttonRoots[button] else { continue }
            let local = root.convert(point, from: self)
            let rect = CGRect(
                x: -Metrics.hitSize.width / 2,
                y: -Metrics.hitSize.height / 2,
                width: Metrics.hitSize.width,
                height: Metrics.hitSize.height
            )
            if rect.contains(local) { return button }
        }
        return nil
    }

    func hitTestMap(_ point: CGPoint) -> Bool { hitTest(point) == .map }
    func hitTestJournal(_ point: CGPoint) -> Bool { hitTest(point) == .journal }
    func hitTestInventory(_ point: CGPoint) -> Bool {
        let hit = hitTest(point)
        return hit == .inventory || hit == .character
    }

    func setHighlightedButton(_ button: Button?) {
        highlightedButton = button
        updateButtonPresentation()
    }

    func setMapButtonHighlighted(_ highlighted: Bool) {
        if highlighted { setHighlightedButton(.map) }
        else if highlightedButton == .map { setHighlightedButton(nil) }
    }

    func setJournalButtonHighlighted(_ highlighted: Bool) {
        if highlighted { setHighlightedButton(.journal) }
        else if highlightedButton == .journal { setHighlightedButton(nil) }
    }

    func beginPress(at point: CGPoint) {
        pressedButton = hitTest(point)
        pressIsInside = pressedButton != nil
        updateButtonPresentation()
    }

    func updatePress(at point: CGPoint) {
        guard let pressedButton else { return }
        pressIsInside = hitTest(point) == pressedButton
        updateButtonPresentation()
    }

    @discardableResult
    func endPress(at point: CGPoint) -> Button? {
        updatePress(at: point)
        let activated = pressIsInside ? pressedButton : nil
        pressedButton = nil
        pressIsInside = false
        updateButtonPresentation()

        guard let activated else { return nil }
        if activated.isInteractive {
            hideStubCaption()
            return activated
        }
        showStubCaption(activated.stubMessage)
        onStubActivated?(activated)
        return nil
    }

    func cancelPress() {
        pressedButton = nil
        pressIsInside = false
        updateButtonPresentation()
    }

    func showStubCaption(_ text: String) {
        stubCaption.removeAction(forKey: "stubFade")
        stubCaption.text = text
        stubCaption.alpha = 1
        stubCaption.run(.sequence([
            .wait(forDuration: 1.4),
            .fadeOut(withDuration: 0.35)
        ]), withKey: "stubFade")
    }

    func hideStubCaption() {
        stubCaption.removeAction(forKey: "stubFade")
        stubCaption.alpha = 0
    }

    private func buildRail() {
        zPosition = 18
        if let texture = UIPaintedChrome.texture(named: "hud_left_rail_plate_v02") {
            railPlate.texture = texture
            railPlate.size = CGSize(width: Metrics.railWidth, height: 800)
            railPlate.zPosition = -7
            addChild(railPlate)
        }
    }

    private func buildButtons() {
        for button in Button.allCases {
            let root = SKNode()
            root.name = "hud.action.\(button)"
            addChild(root)
            buttonRoots[button] = root

            if let texture = UIPaintedChrome.texture(named: button.artName) {
                let art = SKSpriteNode(texture: texture, size: Metrics.buttonSize)
                art.zPosition = 1
                if !button.isInteractive {
                    art.alpha = UITheme.Tint.disabledAlpha
                }
                root.addChild(art)
                buttonArt[button] = art
            }
        }
    }

    private func buildStubCaption() {
        stubCaption.fontSize = 13
        stubCaption.fontColor = UITheme.Color.stubCaption
        stubCaption.horizontalAlignmentMode = .left
        stubCaption.verticalAlignmentMode = .center
        stubCaption.alpha = 0
        stubCaption.zPosition = 20
        addChild(stubCaption)
    }

    private func updateButtonPresentation() {
        for button in Button.allCases {
            guard let art = buttonArt[button] else { continue }
            let isPressed = pressedButton == button && pressIsInside
            let isHot = highlightedButton == button || isPressed
            if !button.isInteractive {
                art.alpha = UITheme.Tint.disabledAlpha
                art.color = .white
                art.colorBlendFactor = 0
                continue
            }
            art.alpha = 1
            if isPressed {
                art.color = UITheme.Tint.pressedColor
                art.colorBlendFactor = UITheme.Tint.pressedBlend
            } else if isHot {
                art.color = UITheme.Tint.hoverColor
                art.colorBlendFactor = UITheme.Tint.hoverBlend
            } else {
                art.color = .white
                art.colorBlendFactor = 0
            }
        }
    }
}
