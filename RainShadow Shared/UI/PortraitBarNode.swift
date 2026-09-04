import SpriteKit

/// Camera-fixed right party rail: cropped `hud_right_rail_plate_v03` as a compact top unit
/// (portrait window + three utility slots). Aspect-locked; never stretched into a full-height spine.
@MainActor
final class PortraitBarNode: SKNode {
    enum Utility: Int, CaseIterable {
        case search
        case lantern
        case selectParty

        var artName: String {
            switch self {
            case .search: return "hud_party_search_v03"
            case .lantern: return "hud_party_lantern_v03"
            case .selectParty: return "hud_party_select_v03"
            }
        }

        var stubMessage: String {
            switch self {
            // Search now opens the quick-loot bar; the caption is only shown for
            // controls that are still stubs.
            case .search: return ""
            case .lantern: return ""
            case .selectParty: return "Select party — not yet"
            }
        }
    }

    private let railPlate = SKSpriteNode()
    private let portraitRoot = SKNode()
    /// Opaque well under the photo so the room never shows through the transparent hole.
    private let portraitWell = SKShapeNode()
    private let portraitCrop = SKCropNode()
    private let portraitMask = SKShapeNode()
    private let portrait = SKSpriteNode()
    private let statusBorder = SKShapeNode()
    private let healthShadow = SKLabelNode(fontNamed: UITheme.Font.hudVital)
    private let healthLabel = SKLabelNode(fontNamed: UITheme.Font.hudVital)
    private var utilityRoots: [Utility: SKNode] = [:]
    private var utilityArt: [Utility: SKSpriteNode] = [:]
    private let stubCaption = SKLabelNode(fontNamed: UITheme.Font.typewriter)

    private var displayedHealth = 0
    private var displayedMaximumHealth = 0
    private var pressedUtility: Utility?
    private var pressIsInside = false
    private var currentLayout = HUDChromeLayout.rightRailLayout(for: CGSize(width: 1_280, height: 800))

    /// Current rail width after layout (for HUD clearance consumers).
    var railWidth: CGFloat { currentLayout.railWidth }

    override init() {
        super.init()
        name = "hud.portrait-bar"
        buildRail()
        buildPortraitCell()
        buildUtilities()
        buildStubCaption()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("PortraitBarNode is created programmatically")
    }

    func layout(for visibleSize: CGSize) {
        let geometry = HUDChromeLayout.rightRailLayout(for: visibleSize)
        currentLayout = geometry
        position = geometry.plateCenter

        railPlate.size = geometry.plateSize
        railPlate.position = .zero

        layoutPortrait(geometry)
        layoutUtilities(geometry)

        stubCaption.position = CGPoint(
            x: -geometry.plateSize.width / 2 - 12,
            y: -geometry.plateSize.height / 2 + geometry.plateSize.height * 0.12
        )
    }

    func setHealth(current: Int, maximum: Int, animated: Bool = true) {
        let safeMaximum = max(1, maximum)
        let safeCurrent = min(max(0, current), safeMaximum)
        guard safeCurrent != displayedHealth || safeMaximum != displayedMaximumHealth else { return }
        let tookDamage = safeCurrent < displayedHealth && displayedMaximumHealth > 0

        displayedHealth = safeCurrent
        displayedMaximumHealth = safeMaximum

        let text = "\(safeCurrent)/\(safeMaximum)"
        healthShadow.text = text
        healthLabel.text = text

        let ratio = CGFloat(safeCurrent) / CGFloat(safeMaximum)
        let conditionColor: SKColor
        switch ratio {
        case 0.51...:
            conditionColor = UITheme.Color.healthy
        case 0.26...:
            conditionColor = UITheme.Color.wounded
        default:
            conditionColor = UITheme.Color.critical
        }
        statusBorder.strokeColor = conditionColor
        healthLabel.fontColor = ratio > 0.25
            ? SKColor(white: 0.96, alpha: 1)
            : SKColor(red: 1, green: 0.74, blue: 0.66, alpha: 1)

        guard animated, tookDamage else { return }
        portraitRoot.removeAction(forKey: "damagePulse")
        portraitRoot.run(.sequence([
            .scale(to: 1.035, duration: 0.08),
            .wait(forDuration: 0.06),
            .scale(to: 1, duration: 0.20)
        ]), withKey: "damagePulse")
        statusBorder.removeAction(forKey: "damageFlash")
        statusBorder.run(.sequence([
            .fadeAlpha(to: 0.35, duration: 0.06),
            .fadeAlpha(to: 1, duration: 0.18)
        ]), withKey: "damageFlash")
    }

    func hitTestPortrait(_ point: CGPoint) -> Bool {
        currentLayout.portraitWindowRect.contains(point)
    }

    func hitTestUtility(_ point: CGPoint) -> Utility? {
        for (index, utility) in Utility.allCases.enumerated() {
            guard currentLayout.utilityWellRects.indices.contains(index) else { continue }
            if currentLayout.utilityWellRects[index].contains(point) { return utility }
        }
        return nil
    }

    func beginUtilityPress(at point: CGPoint) {
        pressedUtility = hitTestUtility(point)
        pressIsInside = pressedUtility != nil
    }

    func updateUtilityPress(at point: CGPoint) {
        guard let pressedUtility else { return }
        pressIsInside = hitTestUtility(point) == pressedUtility
    }

    @discardableResult
    func endUtilityPress(at point: CGPoint) -> Utility? {
        updateUtilityPress(at: point)
        let activated = pressIsInside ? pressedUtility : nil
        pressedUtility = nil
        pressIsInside = false
        if let activated, !activated.stubMessage.isEmpty {
            showStubCaption(activated.stubMessage)
        }
        return activated
    }

    func cancelUtilityPress() {
        pressedUtility = nil
        pressIsInside = false
    }

    private func showStubCaption(_ text: String) {
        stubCaption.removeAction(forKey: "stubFade")
        stubCaption.text = text
        stubCaption.alpha = 1
        stubCaption.run(.sequence([
            .wait(forDuration: 1.4),
            .fadeOut(withDuration: 0.35)
        ]), withKey: "stubFade")
    }

    private func buildRail() {
        zPosition = 18
        if let full = UIPaintedChrome.texture(named: "hud_right_rail_plate_v03") {
            let cropped = SKTexture(rect: HUDChromeLayout.RightRail.plateContentRect, in: full)
            cropped.filteringMode = .linear
            railPlate.texture = cropped
            railPlate.size = CGSize(
                width: HUDChromeLayout.RightRail.railWidth,
                height: HUDChromeLayout.RightRail.plateHeight
            )
            // Plate draws over the portrait so the painted rim frames the photo.
            railPlate.zPosition = 4
            addChild(railPlate)
        }
    }

    private func buildPortraitCell() {
        portraitRoot.name = "hud.detective-portrait"
        portraitRoot.zPosition = 1
        addChild(portraitRoot)

        // Solid well fills the painted hole so transparent chrome never shows the room.
        portraitWell.fillColor = SKColor(white: 0.02, alpha: 1)
        portraitWell.strokeColor = .clear
        portraitWell.zPosition = 0
        portraitRoot.addChild(portraitWell)

        portraitMask.fillColor = .white
        portraitMask.strokeColor = .clear
        portraitCrop.maskNode = portraitMask
        portraitCrop.zPosition = 1
        portraitRoot.addChild(portraitCrop)

        if let texture = UIPaintedChrome.texture(named: "dialogue_portrait_harlan_voss_v01") {
            portrait.texture = texture
            portraitCrop.addChild(portrait)
        }

        statusBorder.fillColor = .clear
        statusBorder.strokeColor = UITheme.Color.healthy
        statusBorder.lineWidth = 1.5
        statusBorder.zPosition = 2
        portraitRoot.addChild(statusBorder)

        for label in [healthShadow, healthLabel] {
            label.text = "12/12"
            label.fontSize = 13
            label.horizontalAlignmentMode = .left
            label.verticalAlignmentMode = .top
            label.zPosition = 6
            addChild(label)
        }
        healthShadow.fontColor = SKColor(white: 0, alpha: 0.92)
        healthShadow.zPosition = 5
        healthLabel.fontColor = SKColor(white: 0.96, alpha: 1)
    }

    private func buildUtilities() {
        for utility in Utility.allCases {
            let root = SKNode()
            root.name = "hud.party.\(utility)"
            root.zPosition = 5
            addChild(root)
            utilityRoots[utility] = root

            if let texture = UIPaintedChrome.texture(named: utility.artName) {
                let art = SKSpriteNode(texture: texture, size: CGSize(width: 40, height: 40))
                art.alpha = UITheme.Tint.disabledAlpha
                art.zPosition = 1
                root.addChild(art)
                utilityArt[utility] = art
            }
        }
    }

    private func buildStubCaption() {
        stubCaption.fontSize = 13
        stubCaption.fontColor = UITheme.Color.stubCaption
        stubCaption.horizontalAlignmentMode = .right
        stubCaption.verticalAlignmentMode = .center
        stubCaption.alpha = 0
        stubCaption.zPosition = 20
        addChild(stubCaption)
    }

    private func layoutPortrait(_ geometry: HUDChromeLayout.RightRailLayout) {
        let window = geometry.portraitWindowRect
        let photo = geometry.portraitPhotoRect
        portraitRoot.position = .zero

        // Black well = full painted hole (under the photo).
        portraitWell.path = CGPath(rect: window, transform: nil)
        portraitWell.position = .zero

        // Crop mask matches the hole; photo is a smaller square centered inside.
        portraitMask.path = CGPath(
            rect: CGRect(
                x: -window.width / 2,
                y: -window.height / 2,
                width: window.width,
                height: window.height
            ),
            transform: nil
        )
        portraitCrop.position = CGPoint(x: window.midX, y: window.midY)

        // Square photo contained in the window (side = short axis − inset).
        portrait.size = CGSize(width: photo.width, height: photo.height)
        portrait.position = .zero

        // Condition ring on the photo bounds.
        statusBorder.path = CGPath(
            rect: CGRect(
                x: -photo.width / 2,
                y: -photo.height / 2,
                width: photo.width,
                height: photo.height
            ),
            transform: nil
        )
        statusBorder.position = CGPoint(x: photo.midX, y: photo.midY)

        let labelPos = CGPoint(x: photo.minX + 3, y: photo.maxY - 2)
        healthShadow.position = CGPoint(x: labelPos.x + 1.2, y: labelPos.y - 1.2)
        healthLabel.position = labelPos
        let hpSize = max(10, min(13, photo.height * 0.16))
        healthShadow.fontSize = hpSize
        healthLabel.fontSize = hpSize
    }

    private func layoutUtilities(_ geometry: HUDChromeLayout.RightRailLayout) {
        for (index, utility) in Utility.allCases.enumerated() {
            guard let root = utilityRoots[utility],
                  geometry.utilityIconRects.indices.contains(index)
            else { continue }
            let icon = geometry.utilityIconRects[index]
            root.position = CGPoint(x: icon.midX, y: icon.midY)
            if let art = utilityArt[utility] {
                art.size = CGSize(width: icon.width, height: icon.height)
            }
        }
    }
}
