import SpriteKit

/// Camera-fixed left action rail: Infinity Engine density with RainShadow noir painted chrome.
/// Plate is aspect-locked to `hud_left_rail_plate_v03` (never non-uniformly stretched).
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
            case .menu: return "hud_action_menu_v03"
            case .map: return "hud_action_map_v03"
            case .journal: return "hud_action_journal_v03"
            case .inventory: return "hud_action_inventory_v03"
            case .character: return "hud_action_character_v03"
            case .leads: return "hud_action_leads_v03"
            case .contacts: return "hud_action_contacts_v03"
            case .settings: return "hud_action_settings_v03"
            case .rest: return "hud_action_rest_v03"
            case .help: return "hud_action_help_v03"
            case .hideUI: return "hud_action_hide_ui_v03"
            case .clock: return "hud_action_clock_v03"
            }
        }

        var isInteractive: Bool {
            switch self {
            // The clock is BG:EE's pause control — in the original it sits in this
            // same corner and toggling it freezes the world.
            case .map, .journal, .inventory, .character, .clock: return true
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
            case .clock: return "Pause"
            default: return ""
            }
        }
    }

    private let railPlate = SKSpriteNode()
    private var buttonRoots: [Button: SKNode] = [:]
    private var buttonArt: [Button: SKSpriteNode] = [:]
    private var highlightedButton: Button?
    private var pressedButton: Button?
    private var pressIsInside = false
    private let stubCaption = SKLabelNode(fontNamed: UITheme.Font.typewriter)
    private var currentLayout = HUDChromeLayout.leftRailLayout(for: CGSize(width: 1_280, height: 800))

    var onStubActivated: ((Button) -> Void)?

    /// Current rail width after aspect-locked layout (for HUD clearance consumers).
    var railWidth: CGFloat { currentLayout.railWidth }

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
        let geometry = HUDChromeLayout.leftRailLayout(for: visibleSize)
        currentLayout = geometry
        position = geometry.plateCenter

        railPlate.size = geometry.plateSize
        railPlate.position = .zero

        let buttons = Button.allCases
        for (index, button) in buttons.enumerated() {
            guard let root = buttonRoots[button], geometry.iconRects.indices.contains(index) else { continue }
            let iconRect = geometry.iconRects[index]
            root.position = CGPoint(x: iconRect.midX, y: iconRect.midY)
            if let art = buttonArt[button] {
                art.size = CGSize(width: iconRect.width, height: iconRect.height)
            }
        }
        stubCaption.position = CGPoint(x: geometry.plateSize.width / 2 + 14, y: 0)
    }

    func hitTest(_ point: CGPoint) -> Button? {
        let pad = HUDChromeLayout.LeftRail.hitPadding
        for (index, button) in Button.allCases.enumerated() {
            guard let root = buttonRoots[button], currentLayout.iconRects.indices.contains(index) else { continue }
            let local = root.convert(point, from: self)
            let icon = currentLayout.iconRects[index]
            let hit = CGRect(
                x: -icon.width / 2 - pad,
                y: -icon.height / 2 - pad,
                width: icon.width + pad * 2,
                height: icon.height + pad * 2
            )
            if hit.contains(local) { return button }
        }
        return nil
    }

    func hitTestMap(_ point: CGPoint) -> Bool { hitTest(point) == .map }
    func hitTestJournal(_ point: CGPoint) -> Bool { hitTest(point) == .journal }
    func hitTestInventory(_ point: CGPoint) -> Bool {
        let hit = hitTest(point)
        return hit == .inventory || hit == .character
    }

    /// Marks the clock as holding a player pause.
    func setClockPaused(_ paused: Bool) {
        guard let art = buttonArt[.clock] else { return }
        art.color = UITheme.Color.brass
        art.colorBlendFactor = paused ? 0.55 : 0
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
        if let full = UIPaintedChrome.texture(named: "hud_left_rail_plate_v03") {
            let cropped = SKTexture(rect: HUDChromeLayout.LeftRail.plateContentRect, in: full)
            cropped.filteringMode = .linear
            railPlate.texture = cropped
            railPlate.size = CGSize(width: 80, height: 640)
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
                let art = SKSpriteNode(texture: texture, size: CGSize(width: 40, height: 40))
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
