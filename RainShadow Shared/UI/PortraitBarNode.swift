import SpriteKit

/// Camera-fixed right party rail: painted chrome, live HP text, utility stubs.
@MainActor
final class PortraitBarNode: SKNode {
    enum Utility: Int, CaseIterable {
        case search
        case lantern
        case selectParty

        var artName: String {
            switch self {
            case .search: return "hud_party_search_v02"
            case .lantern: return "hud_party_lantern_v02"
            case .selectParty: return "hud_party_select_v02"
            }
        }

        var stubMessage: String {
            switch self {
            case .search: return "Search / loot — not yet"
            case .lantern: return "Lantern — not yet"
            case .selectParty: return "Select party — not yet"
            }
        }
    }

    private enum Metrics {
        static let railWidth: CGFloat = 148
        static let frameSize = CGSize(width: 128, height: 172)
        static let portraitWindowSize = CGSize(width: 96, height: 130)
        static let utilitySize = CGSize(width: 56, height: 56)
        static let utilityHit = CGSize(width: 64, height: 60)
        static let topInset: CGFloat = 18
        static let utilitySpacing: CGFloat = 8
        static let utilityBottomInset: CGFloat = 28
    }

    private let railPlate = SKSpriteNode()
    private let portraitRoot = SKNode()
    private let portraitCrop = SKCropNode()
    private let portraitMask = SKShapeNode(
        rectOf: Metrics.portraitWindowSize,
        cornerRadius: 2
    )
    private let portrait = SKSpriteNode()
    private let statusBorder = SKShapeNode(
        rectOf: Metrics.portraitWindowSize,
        cornerRadius: 2
    )
    private let portraitFrame = SKSpriteNode()
    private let healthShadow = SKLabelNode(fontNamed: UITheme.Font.hudVital)
    private let healthLabel = SKLabelNode(fontNamed: UITheme.Font.hudVital)
    private var utilityRoots: [Utility: SKNode] = [:]
    private var utilityArt: [Utility: SKSpriteNode] = [:]
    private let stubCaption = SKLabelNode(fontNamed: UITheme.Font.typewriter)

    private var displayedHealth = 0
    private var displayedMaximumHealth = 0
    private var pressedUtility: Utility?
    private var pressIsInside = false

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
        let railHeight = visibleSize.height + 12
        position = CGPoint(x: visibleSize.width / 2 - Metrics.railWidth / 2, y: 0)
        railPlate.size = CGSize(width: Metrics.railWidth, height: railHeight)

        let frameCenterY = visibleSize.height / 2 - Metrics.topInset - Metrics.frameSize.height / 2
        portraitRoot.position = CGPoint(x: 0, y: frameCenterY)

        let bottomY = -visibleSize.height / 2 + Metrics.utilityBottomInset + Metrics.utilitySize.height / 2
        for (index, utility) in Utility.allCases.enumerated() {
            guard let root = utilityRoots[utility] else { continue }
            let reverseIndex = Utility.allCases.count - 1 - index
            root.position = CGPoint(
                x: 0,
                y: bottomY + CGFloat(reverseIndex) * (Metrics.utilitySize.height + Metrics.utilitySpacing)
            )
        }
        stubCaption.position = CGPoint(x: -Metrics.railWidth / 2 - 120, y: bottomY)
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
        let portraitPoint = portraitRoot.convert(point, from: self)
        return CGRect(
            x: -Metrics.frameSize.width / 2,
            y: -Metrics.frameSize.height / 2,
            width: Metrics.frameSize.width,
            height: Metrics.frameSize.height
        ).contains(portraitPoint)
    }

    func hitTestUtility(_ point: CGPoint) -> Utility? {
        for utility in Utility.allCases {
            guard let root = utilityRoots[utility] else { continue }
            let local = root.convert(point, from: self)
            let rect = CGRect(
                x: -Metrics.utilityHit.width / 2,
                y: -Metrics.utilityHit.height / 2,
                width: Metrics.utilityHit.width,
                height: Metrics.utilityHit.height
            )
            if rect.contains(local) { return utility }
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
        if let activated {
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
        if let texture = UIPaintedChrome.texture(named: "hud_right_rail_plate_v02") {
            railPlate.texture = texture
            railPlate.size = CGSize(width: Metrics.railWidth, height: 800)
            railPlate.zPosition = -7
            addChild(railPlate)
        }
    }

    private func buildPortraitCell() {
        portraitRoot.name = "hud.detective-portrait"
        addChild(portraitRoot)

        portraitMask.fillColor = .white
        portraitMask.strokeColor = .clear
        portraitCrop.maskNode = portraitMask
        portraitCrop.zPosition = 1
        portraitRoot.addChild(portraitCrop)

        if let texture = UIPaintedChrome.texture(named: "dialogue_portrait_harlan_voss_v01") {
            portrait.texture = texture
            portrait.size = CGSize(
                width: Metrics.portraitWindowSize.height,
                height: Metrics.portraitWindowSize.height
            )
            portraitCrop.addChild(portrait)
        }

        statusBorder.fillColor = .clear
        statusBorder.strokeColor = UITheme.Color.healthy
        statusBorder.lineWidth = 2
        statusBorder.zPosition = 2
        portraitRoot.addChild(statusBorder)

        if let texture = UIPaintedChrome.texture(named: "hud_portrait_frame_v02")
            ?? UIPaintedChrome.texture(named: "hud_portrait_frame_v01") {
            portraitFrame.texture = texture
            portraitFrame.size = Metrics.frameSize
            portraitFrame.zPosition = 3
            portraitRoot.addChild(portraitFrame)
        }

        for label in [healthShadow, healthLabel] {
            label.text = "12/12"
            label.fontSize = 20
            label.horizontalAlignmentMode = .left
            label.verticalAlignmentMode = .top
            label.zPosition = 5
            portraitRoot.addChild(label)
        }
        let labelPosition = CGPoint(
            x: -Metrics.portraitWindowSize.width / 2 + 6,
            y: Metrics.portraitWindowSize.height / 2 - 4
        )
        healthShadow.position = CGPoint(x: labelPosition.x + 2, y: labelPosition.y - 2)
        healthShadow.fontColor = SKColor(white: 0, alpha: 0.92)
        healthShadow.zPosition = 4
        healthLabel.position = labelPosition
        healthLabel.fontColor = SKColor(white: 0.96, alpha: 1)
    }

    private func buildUtilities() {
        for utility in Utility.allCases {
            let root = SKNode()
            root.name = "hud.party.\(utility)"
            addChild(root)
            utilityRoots[utility] = root

            if let texture = UIPaintedChrome.texture(named: utility.artName) {
                let art = SKSpriteNode(texture: texture, size: Metrics.utilitySize)
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
}
