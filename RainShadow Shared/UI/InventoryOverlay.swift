import SpriteKit
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

struct InventoryItem: Identifiable, Equatable {
    enum Category: String {
        case weapon = "SERVICE WEAPON"
        case evidence = "EVIDENCE"
        case tool = "FIELD TOOL"
        case personal = "PERSONAL EFFECT"
    }

    let id: String
    let name: String
    let category: Category
    let description: String
    let note: String
    let symbolName: String
    let artName: String
    let quantity: Int
}

@MainActor
final class InventoryOverlay: SKNode {
    private enum Metrics {
        static let canvas = CGSize(width: 1_960, height: 1_080)
        static let contentScale: CGFloat = 0.9
        static let primaryPanelY: CGFloat = 66
        static let lowerPanelY: CGFloat = -382
        static let lowerSlotSize: CGFloat = 78
        static let lowerFirstRowY: CGFloat = 23
        static let lowerRowSpacing: CGFloat = 88
    }

    private enum Palette {
        static let ink = SKColor(red: 0.018, green: 0.021, blue: 0.027, alpha: 0.94)
        static let panel = SKColor(red: 0.038, green: 0.043, blue: 0.052, alpha: 0.92)
        static let raised = SKColor(red: 0.068, green: 0.072, blue: 0.079, alpha: 0.94)
        static let line = SKColor(red: 0.46, green: 0.49, blue: 0.50, alpha: 0.48)
        static let paleLine = SKColor(red: 0.72, green: 0.74, blue: 0.72, alpha: 0.72)
        static let paper = SKColor(red: 0.82, green: 0.80, blue: 0.72, alpha: 1)
        static let quiet = SKColor(red: 0.55, green: 0.57, blue: 0.57, alpha: 1)
        static let amber = SKColor(red: 0.79, green: 0.55, blue: 0.26, alpha: 1)
        static let blood = SKColor(red: 0.48, green: 0.13, blue: 0.12, alpha: 1)
    }

    private let items: [InventoryItem] = [
        InventoryItem(
            id: "service-revolver",
            name: "Service Revolver",
            category: .weapon,
            description: "A six-shot Webley with a tired action and a clean barrel.",
            note: "Registered to Det. H. Voss · 5 rounds loaded",
            symbolName: "scope",
            artName: "inventory_item_service_revolver_v01",
            quantity: 1
        ),
        InventoryItem(
            id: "case-notes",
            name: "Case Notebook",
            category: .evidence,
            description: "Names, times, and three pages someone tried to tear out.",
            note: "Active file: The Empty Coat",
            symbolName: "book.closed.fill",
            artName: "inventory_item_case_notebook_v01",
            quantity: 1
        ),
        InventoryItem(
            id: "brass-key",
            name: "Brass Key",
            category: .evidence,
            description: "Sewn into Lillian's coat lining—old teeth, no hotel tag. Faint machine oil and river fog.",
            note: "The Empty Coat · in Voss's care",
            symbolName: "key.fill",
            artName: "inventory_item_brass_key_v01",
            quantity: 1
        ),
        InventoryItem(
            id: "flashlight",
            name: "Pocket Torch",
            category: .tool,
            description: "Dented steel, unreliable switch, enough battery for one long night.",
            note: "Condition: worn",
            symbolName: "flashlight.on.fill",
            artName: "inventory_item_flashlight_v01",
            quantity: 1
        ),
        InventoryItem(
            id: "wallet",
            name: "Leather Wallet",
            category: .personal,
            description: "Licence, tram pass, and the kind of money that disappears quickly.",
            note: "Cash on hand: £7  4s",
            symbolName: "creditcard.fill",
            artName: "inventory_item_wallet_v01",
            quantity: 1
        ),
        InventoryItem(
            id: "cigarette-case",
            name: "Cigarette Case",
            category: .personal,
            description: "Gunmetal silver. Initials scratched away with deliberate care.",
            note: "4 cigarettes remaining",
            symbolName: "cigarette.fill",
            artName: "inventory_item_cigarette_case_v01",
            quantity: 4
        )
    ]

    var onDismiss: (() -> Void)?

    private var slotFrames: [String: [SKShapeNode]] = [:]
    private var selectedItemID = "case-notes"
    private let itemNameLabel = InventoryOverlay.label(size: 25, color: Palette.paper, weight: .demibold)
    private let itemCategoryLabel = InventoryOverlay.label(size: 14, color: Palette.amber, weight: .demibold)
    private let itemDescriptionLabel = InventoryOverlay.label(size: 18, color: Palette.paper, weight: .regular)
    private let itemNoteLabel = InventoryOverlay.label(size: 15, color: Palette.quiet, weight: .regular)
    private let caseStatusLabel = InventoryOverlay.label(size: 16, color: Palette.quiet, weight: .regular)
    private let sheet = SKNode()
    private let content = SKNode()

    override init() {
        super.init()
        name = "inventory.overlay"
        isUserInteractionEnabled = false
        buildInterface()
        refreshSelection()
        isHidden = true
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("InventoryOverlay is created programmatically")
    }

    func layout(for visibleSize: CGSize) {
        let horizontalFit = (visibleSize.width - 34) / Metrics.canvas.width
        let verticalFit = (visibleSize.height - 30) / Metrics.canvas.height
        setScale(min(1, horizontalFit, verticalFit))
    }

    func present() {
        removeAllActions()
        isHidden = false
        alpha = 0
        sheet.position.y = -12
        sheet.run(.moveTo(y: 0, duration: 0.22))
        run(.fadeIn(withDuration: 0.18))
    }

    func hideAnimated() {
        removeAllActions()
        run(.sequence([
            .fadeOut(withDuration: 0.14),
            .run { [weak self] in self?.isHidden = true }
        ]))
    }

    @discardableResult
    func handlePointer(at point: CGPoint) -> Bool {
        guard !isHidden else { return false }
        guard let target = targetName(at: point) else { return true }

        if target == "inventory.close" {
            onDismiss?()
            return true
        }
        if target.hasPrefix("inventory.item.") {
            selectedItemID = String(target.dropFirst("inventory.item.".count))
            refreshSelection()
        }
        return true
    }

    func moveSelection(_ direction: Int) {
        guard !items.isEmpty else { return }
        let current = items.firstIndex { $0.id == selectedItemID } ?? 0
        let next = (current + direction + items.count) % items.count
        selectedItemID = items[next].id
        refreshSelection()
    }

    func isInteractive(at point: CGPoint) -> Bool {
        guard let target = targetName(at: point) else { return false }
        return target == "inventory.close" || target.hasPrefix("inventory.item.")
    }

    private func buildInterface() {
        let veil = SKShapeNode(rectOf: CGSize(width: 3_000, height: 1_600))
        veil.fillColor = SKColor(white: 0.005, alpha: 0.83)
        veil.strokeColor = .clear
        veil.zPosition = -20
        addChild(veil)

        let shadow = SKShapeNode(rectOf: Metrics.canvas, cornerRadius: 16)
        shadow.fillColor = SKColor(white: 0, alpha: 0.64)
        shadow.strokeColor = .clear
        shadow.position = CGPoint(x: 11, y: -14)
        shadow.zPosition = -10
        sheet.addChild(shadow)

        if !addGeneratedOuterFrame() {
            let frame = panel(size: Metrics.canvas, radius: 14, fill: Palette.ink, stroke: Palette.paleLine, lineWidth: 2)
            sheet.addChild(frame)
            addInnerBorder(to: sheet, size: CGSize(width: 1_928, height: 1_048))
            addFilmGrainLines(to: sheet)
        }

        content.setScale(Metrics.contentScale)
        sheet.addChild(content)

        let title = Self.label(size: 39, color: Palette.paper, weight: .display)
        title.text = "INVENTORY"
        title.position = CGPoint(x: 0, y: 474)
        content.addChild(title)

        addHeaderRail(from: -900, to: -170, y: 487)
        addHeaderRail(from: 170, to: 900, y: 487)

        let identityBandSize = CGSize(width: 1_300, height: 58)
        let identityBand = panel(size: identityBandSize, radius: 3, fill: Palette.ink, stroke: Palette.line, lineWidth: 2)
        identityBand.position = CGPoint(x: -235, y: 415)
        let identityColumnCenterX = identityBandSize.width / 4
        let detectiveName = Self.label(size: 23, color: Palette.paper, weight: .demibold)
        detectiveName.text = "HARLAN VOSS"
        detectiveName.verticalAlignmentMode = .center
        detectiveName.position = CGPoint(x: -identityColumnCenterX, y: 1)
        identityBand.addChild(detectiveName)
        let profession = Self.label(size: 21, color: Palette.paper, weight: .demibold)
        profession.text = "PRIVATE INVESTIGATOR"
        profession.verticalAlignmentMode = .center
        profession.position = CGPoint(x: identityColumnCenterX, y: 1)
        identityBand.addChild(profession)
        let identityDivider = SKShapeNode(rectOf: CGSize(width: 1, height: 42))
        identityDivider.fillColor = Palette.line
        identityDivider.strokeColor = .clear
        identityBand.addChild(identityDivider)
        content.addChild(identityBand)

        buildCloseButton()
        buildLoadoutPanel()
        buildPaperdollPanel()
        buildCasePanel()
        buildBagPanel()
        addChild(sheet)
    }

    @discardableResult
    private func addGeneratedOuterFrame() -> Bool {
        guard let texture = GameArt.texture(named: "inventory_outer_frame_overlay_v01") else { return false }
        texture.filteringMode = .linear

        let backing = panel(size: Metrics.canvas, radius: 14, fill: Palette.ink, stroke: .clear, lineWidth: 0)
        backing.zPosition = -9
        sheet.addChild(backing)

        let overlay = SKSpriteNode(texture: texture, size: Metrics.canvas)
        overlay.name = "inventory.outer-frame-overlay"
        overlay.zPosition = -8
        sheet.addChild(overlay)
        return true
    }

    private func buildCloseButton() {
        let button = ClassicMacCloseButtonNode(
            targetName: "inventory.close",
            fill: Palette.raised,
            stroke: Palette.line,
            highlight: Palette.paleLine,
            accent: Palette.blood
        )
        button.position = CGPoint(x: -873, y: 487)
        content.addChild(button)
    }

    private func buildLoadoutPanel() {
        let root = SKNode()
        root.position = CGPoint(x: -665, y: Metrics.primaryPanelY)
        root.addChild(majorPanel(size: CGSize(width: 470, height: 620)))

        addSlotSection("READY WEAPONS", items: [item(id: "service-revolver"), nil, nil], to: root, headerY: 258, slotY: 174)
        addSlotSection("QUICK ITEMS", items: [item(id: "flashlight"), item(id: "case-notes"), item(id: "cigarette-case")], to: root, headerY: 78, slotY: -6)
        addSlotSection("COAT POCKETS", items: [item(id: "brass-key"), nil, item(id: "wallet")], to: root, headerY: -102, slotY: -186)

        let paused = Self.label(size: 18, color: Palette.quiet, weight: .demibold)
        paused.text = "CASEWORK PAUSED"
        paused.horizontalAlignmentMode = .left
        paused.position = CGPoint(x: -205, y: -280)
        root.addChild(paused)

        content.addChild(root)
    }

    private func buildPaperdollPanel() {
        let root = SKNode()
        root.position = CGPoint(x: -50, y: Metrics.primaryPanelY)
        root.addChild(majorPanel(size: CGSize(width: 730, height: 620)))

        let chamber = panel(size: CGSize(width: 390, height: 390), radius: 3, fill: Palette.ink, stroke: Palette.line, lineWidth: 2)
        chamber.position = CGPoint(x: 50, y: -15)
        root.addChild(chamber)

        let glow = SKShapeNode(ellipseOf: CGSize(width: 270, height: 350))
        glow.fillColor = SKColor(red: 0.48, green: 0.44, blue: 0.33, alpha: 0.065)
        glow.strokeColor = SKColor(red: 0.52, green: 0.5, blue: 0.42, alpha: 0.12)
        glow.lineWidth = 2
        chamber.addChild(glow)

        let floorLight = SKShapeNode(ellipseOf: CGSize(width: 250, height: 42))
        floorLight.fillColor = SKColor(white: 0.66, alpha: 0.1)
        floorLight.strokeColor = .clear
        floorLight.position = CGPoint(x: 0, y: -145)
        chamber.addChild(floorLight)

        if let detectiveTexture = GameArt.texture(named: "voss_paperdoll_front_rgba_v01") {
            detectiveTexture.filteringMode = .linear
            let paperdoll = SKSpriteNode(texture: detectiveTexture, size: CGSize(width: 246, height: 369))
            paperdoll.name = "inventory.paperdoll"
            paperdoll.position = CGPoint(x: 0, y: -8)
            chamber.addChild(paperdoll)
        } else if let detectiveTexture = GameArt.texture(named: "voss_standing_idle_se_00") {
            detectiveTexture.filteringMode = .linear
            let fallbackPaperdoll = SKSpriteNode(texture: detectiveTexture, size: CGSize(width: 256, height: 256))
            fallbackPaperdoll.name = "inventory.paperdoll"
            fallbackPaperdoll.setScale(3.15)
            fallbackPaperdoll.position = CGPoint(x: 0, y: 108)
            chamber.addChild(fallbackPaperdoll)
        } else {
            let fallback = Self.label(size: 74, color: Palette.quiet, weight: .regular)
            fallback.text = "♟"
            fallback.verticalAlignmentMode = .center
            chamber.addChild(fallback)
        }

        let equipment: [(String, String, CGPoint)] = [
            ("hat.widebrim.fill", "FEDORA", CGPoint(x: -238, y: 244)),
            ("hand.raised.fill", "GLOVES", CGPoint(x: -119, y: 244)),
            ("shield.lefthalf.filled", "COAT", CGPoint(x: 0, y: 244)),
            ("briefcase.fill", "HOLSTER", CGPoint(x: 119, y: 244)),
            ("camera.metering.matrix", "CHARM", CGPoint(x: 238, y: 244)),
            ("eyeglasses", "EYES", CGPoint(x: -285, y: 73)),
            ("hand.raised.fill", "HANDS", CGPoint(x: -285, y: -74)),
            ("scope", "WEAPON", CGPoint(x: 285, y: 73)),
            ("creditcard.fill", "POCKET", CGPoint(x: 285, y: -74)),
            ("shoe.fill", "SHOES", CGPoint(x: -176, y: -244)),
            ("figure.walk", "STANCE", CGPoint(x: -58, y: -244)),
            ("circle.hexagongrid.fill", "LUCK", CGPoint(x: 60, y: -244))
        ]
        for equipmentItem in equipment {
            root.addChild(equipmentSlot(symbol: equipmentItem.0, caption: equipmentItem.1, at: equipmentItem.2))
        }
        root.addChild(coinDisplay(at: CGPoint(x: 245, y: -244)))

        content.addChild(root)
    }

    private func buildCasePanel() {
        let rail = SKNode()
        rail.position = CGPoint(x: 390, y: Metrics.primaryPanelY)
        rail.addChild(majorPanel(size: CGSize(width: 140, height: 620)))
        rail.addChild(statBadge(title: "DEFENCE", value: "8", subtitle: "COAT", at: CGPoint(x: 0, y: 220)))
        rail.addChild(statBadge(title: "VITALITY", value: "8/10", subtitle: "STEADY", at: CGPoint(x: 0, y: 74)))
        rail.addChild(statBadge(title: "FOCUS", value: "6", subtitle: "RESOLVE", at: CGPoint(x: 0, y: -72)))
        rail.addChild(statBadge(title: "DAMAGE", value: "2–7", subtitle: "WEBLEY", at: CGPoint(x: 0, y: -218)))
        content.addChild(rail)

        let root = SKNode()
        root.position = CGPoint(x: 690, y: Metrics.primaryPanelY)
        root.addChild(majorPanel(size: CGSize(width: 450, height: 620)))

        let condition = detailBox(title: "CASE CONDITION", size: CGSize(width: 410, height: 166), at: CGPoint(x: 0, y: 212))
        addMeter(to: condition, title: "VITALITY", value: "8 / 10", fraction: 0.8, y: 24, width: 350, color: Palette.blood)
        addMeter(to: condition, title: "COMPOSURE", value: "6 / 8", fraction: 0.75, y: -42, width: 350, color: SKColor(red: 0.30, green: 0.43, blue: 0.51, alpha: 1))
        root.addChild(condition)

        let traits = detailBox(title: "FIELD ABILITIES", size: CGSize(width: 410, height: 154), at: CGPoint(x: 0, y: 37))
        addTrait("OBSERVATION", value: "7", to: traits, at: CGPoint(x: -174, y: 24))
        addTrait("RESOLVE", value: "6", to: traits, at: CGPoint(x: 16, y: 24))
        addTrait("INSTINCT", value: "8", to: traits, at: CGPoint(x: -174, y: -28))
        addTrait("PERSUASION", value: "5", to: traits, at: CGPoint(x: 16, y: -28))
        root.addChild(traits)

        let detail = detailBox(title: "SELECTED ITEM", size: CGSize(width: 410, height: 246), at: CGPoint(x: 0, y: -185))
        itemCategoryLabel.horizontalAlignmentMode = .left
        itemCategoryLabel.position = CGPoint(x: -180, y: 69)
        detail.addChild(itemCategoryLabel)
        itemNameLabel.fontSize = 23
        itemNameLabel.horizontalAlignmentMode = .left
        itemNameLabel.position = CGPoint(x: -180, y: 37)
        detail.addChild(itemNameLabel)
        itemDescriptionLabel.fontSize = 17
        itemDescriptionLabel.horizontalAlignmentMode = .left
        itemDescriptionLabel.verticalAlignmentMode = .top
        itemDescriptionLabel.preferredMaxLayoutWidth = 360
        itemDescriptionLabel.numberOfLines = 3
        itemDescriptionLabel.position = CGPoint(x: -180, y: 10)
        detail.addChild(itemDescriptionLabel)
        itemNoteLabel.fontSize = 14
        itemNoteLabel.horizontalAlignmentMode = .left
        itemNoteLabel.position = CGPoint(x: -180, y: -91)
        detail.addChild(itemNoteLabel)
        root.addChild(detail)
        content.addChild(root)
    }

    private func buildBagPanel() {
        let bag = SKNode()
        bag.position = CGPoint(x: -270, y: Metrics.lowerPanelY)
        bag.addChild(majorPanel(size: CGSize(width: 1_260, height: 230)))
        addGridHeader("CASE BAG", counter: "\(items.count) / 18", to: bag, width: 1_210)

        if let bagTexture = GameArt.texture(named: "inventory_case_bag_v01") {
            bagTexture.filteringMode = .linear
            let bagArt = SKSpriteNode(texture: bagTexture, size: CGSize(width: 150, height: 150))
            bagArt.position = CGPoint(x: -548, y: -21)
            bag.addChild(bagArt)
        }
        let carriedWeight = Self.label(size: 14, color: Palette.amber, weight: .demibold)
        carriedWeight.text = "14 lb"
        carriedWeight.position = CGPoint(x: -548, y: 52)
        bag.addChild(carriedWeight)
        let maximumWeight = Self.label(size: 13, color: Palette.quiet, weight: .demibold)
        maximumWeight.text = "70 lb MAX"
        maximumWeight.position = CGPoint(x: -548, y: -104)
        bag.addChild(maximumWeight)

        let bagItems: [InventoryItem?] = items.map(Optional.some) + Array(repeating: nil, count: 11)
        for index in 0..<18 {
            let column = index % 9
            let row = index / 9
            let position = CGPoint(
                x: -400 + CGFloat(column) * 112,
                y: Metrics.lowerFirstRowY - CGFloat(row) * Metrics.lowerRowSpacing
            )
            if let item = bagItems[index] {
                bag.addChild(itemSlot(
                    item,
                    size: Metrics.lowerSlotSize,
                    at: position,
                    showQuantity: true
                ))
            } else {
                bag.addChild(emptySlot(size: Metrics.lowerSlotSize, at: position))
            }
        }
        content.addChild(bag)

        let ground = SKNode()
        ground.position = CGPoint(x: 650, y: Metrics.lowerPanelY)
        ground.addChild(majorPanel(size: CGSize(width: 500, height: 230)))
        addGridHeader("NEARBY", counter: "0 / 8", to: ground, width: 450)
        for index in 0..<8 {
            let column = index % 4
            let row = index / 4
            ground.addChild(emptySlot(
                size: Metrics.lowerSlotSize,
                at: CGPoint(
                    x: -171 + CGFloat(column) * 114,
                    y: Metrics.lowerFirstRowY - CGFloat(row) * Metrics.lowerRowSpacing
                )
            ))
        }
        content.addChild(ground)
    }

    private func itemSlot(_ item: InventoryItem, size: CGFloat, at position: CGPoint, showQuantity: Bool) -> SKShapeNode {
        let slot = slotBase(size: CGSize(width: size, height: size))
        slot.name = "inventory.item.\(item.id)"
        slot.position = position

        if let texture = GameArt.texture(named: item.artName) {
            texture.filteringMode = .linear
            let icon = SKSpriteNode(texture: texture, size: CGSize(width: size * 0.72, height: size * 0.72))
            icon.name = "inventory.item-art"
            slot.addChild(icon)
        } else {
            let icon = Self.symbol(item.symbolName, pointSize: size * 0.42)
            icon.color = Palette.paper
            icon.colorBlendFactor = 1
            icon.alpha = 0.88
            slot.addChild(icon)
        }

        if showQuantity, item.quantity > 1 {
            let countPlate = panel(size: CGSize(width: 30, height: 24), radius: 3, fill: Palette.ink, stroke: Palette.line, lineWidth: 1)
            countPlate.position = CGPoint(x: size / 2 - 17, y: -size / 2 + 14)
            let count = Self.label(size: 13, color: Palette.paper, weight: .demibold)
            count.text = "\(item.quantity)"
            count.verticalAlignmentMode = .center
            countPlate.addChild(count)
            slot.addChild(countPlate)
        }
        slotFrames[item.id, default: []].append(slot)
        return slot
    }

    private func emptySlot(size: CGFloat, at position: CGPoint) -> SKShapeNode {
        let slot = slotBase(size: CGSize(width: size, height: size))
        slot.position = position
        return slot
    }

    private func equipmentSlot(symbol: String, caption: String, at position: CGPoint) -> SKNode {
        let root = SKNode()
        root.position = position
        let slot = slotBase(size: CGSize(width: 88, height: 82))
        let icon = Self.symbol(symbol, pointSize: 31)
        icon.color = Palette.quiet
        icon.colorBlendFactor = 1
        icon.alpha = 0.82
        slot.addChild(icon)
        root.addChild(slot)

        let label = Self.label(size: 12, color: Palette.quiet, weight: .demibold)
        label.text = caption
        label.position.y = -58
        root.addChild(label)
        return root
    }

    private func slotBase(size: CGSize) -> SKShapeNode {
        let slot = panel(size: size, radius: 5, fill: Palette.ink, stroke: Palette.line, lineWidth: 1)
        if let texture = GameArt.texture(named: "inventory_slot_frame_v01") {
            texture.filteringMode = .linear
            slot.fillColor = .clear
            slot.strokeColor = .clear
            let art = SKSpriteNode(texture: texture, size: size)
            art.name = "inventory.slot-art"
            art.zPosition = -1
            slot.addChild(art)
        }
        return slot
    }

    private func majorPanel(size: CGSize) -> SKNode {
        let root = SKNode()
        root.name = "inventory.panel"

        let surface = panel(
            size: size,
            radius: 5,
            fill: Palette.panel,
            stroke: Palette.paleLine.withAlphaComponent(0.50),
            lineWidth: 2
        )
        root.addChild(surface)

        let insetSize = CGSize(width: max(0, size.width - 14), height: max(0, size.height - 14))
        let inset = panel(
            size: insetSize,
            radius: 3,
            fill: .clear,
            stroke: Palette.line.withAlphaComponent(0.42),
            lineWidth: 1
        )
        inset.zPosition = 1
        root.addChild(inset)

        return root
    }

    private func coinDisplay(at position: CGPoint) -> SKNode {
        let root = SKNode()
        root.position = position

        if let texture = GameArt.texture(named: "inventory_coin_stack_v01") {
            texture.filteringMode = .linear
            let coins = SKSpriteNode(texture: texture, size: CGSize(width: 112, height: 82))
            coins.position.y = 20
            root.addChild(coins)
        }

        let valuePlate = panel(size: CGSize(width: 150, height: 34), radius: 3, fill: Palette.ink, stroke: Palette.line, lineWidth: 1)
        valuePlate.position.y = -43
        let value = Self.label(size: 17, color: Palette.paper, weight: .demibold)
        value.text = "£7  4s"
        value.verticalAlignmentMode = .center
        value.position.y = 1
        valuePlate.addChild(value)
        root.addChild(valuePlate)

        let caption = Self.label(size: 11, color: Palette.quiet, weight: .demibold)
        caption.text = "COINS"
        caption.position.y = -70
        root.addChild(caption)
        return root
    }

    private func addMeter(
        to root: SKNode,
        title: String,
        value: String,
        fraction: CGFloat,
        y: CGFloat,
        width: CGFloat,
        color: SKColor
    ) {
        let titleLabel = Self.label(size: 15, color: Palette.quiet, weight: .demibold)
        titleLabel.text = title
        titleLabel.horizontalAlignmentMode = .left
        titleLabel.position = CGPoint(x: -width / 2, y: y + 17)
        root.addChild(titleLabel)

        let valueLabel = Self.label(size: 17, color: Palette.paper, weight: .demibold)
        valueLabel.text = value
        valueLabel.horizontalAlignmentMode = .right
        valueLabel.position = CGPoint(x: width / 2, y: y + 15)
        root.addChild(valueLabel)

        let track = panel(size: CGSize(width: width, height: 15), radius: 2, fill: Palette.ink, stroke: Palette.line, lineWidth: 1)
        track.position = CGPoint(x: 0, y: y - 12)
        root.addChild(track)

        let usableWidth = width - 8
        let fillWidth = usableWidth * max(0, min(1, fraction))
        let fill = SKShapeNode(rectOf: CGSize(width: fillWidth, height: 9), cornerRadius: 2)
        fill.fillColor = color
        fill.strokeColor = .clear
        fill.position = CGPoint(x: -(usableWidth - fillWidth) / 2, y: 0)
        track.addChild(fill)
    }

    private func addHeaderRail(from startX: CGFloat, to endX: CGFloat, y: CGFloat) {
        let rail = SKShapeNode(rectOf: CGSize(width: endX - startX, height: 2))
        rail.fillColor = Palette.line
        rail.strokeColor = .clear
        rail.position = CGPoint(x: (startX + endX) / 2, y: y)
        content.addChild(rail)

        for x in [startX, endX] {
            let rivet = SKShapeNode(circleOfRadius: 5)
            rivet.fillColor = Palette.raised
            rivet.strokeColor = Palette.paleLine
            rivet.lineWidth = 1
            rivet.position = CGPoint(x: x, y: y)
            content.addChild(rivet)
        }
    }

    private func addSlotSection(_ title: String, items: [InventoryItem?], to root: SKNode, headerY: CGFloat, slotY: CGFloat) {
        let header = panel(size: CGSize(width: 420, height: 46), radius: 3, fill: Palette.ink, stroke: Palette.line, lineWidth: 2)
        header.position = CGPoint(x: 0, y: headerY)
        let label = Self.label(size: 18, color: Palette.paper, weight: .demibold)
        label.text = title
        label.verticalAlignmentMode = .center
        label.position.y = 1
        header.addChild(label)
        root.addChild(header)

        for index in 0..<3 {
            let position = CGPoint(x: CGFloat(index - 1) * 132, y: slotY)
            if let item = items[index] {
                root.addChild(itemSlot(item, size: 104, at: position, showQuantity: true))
            } else {
                root.addChild(emptySlot(size: 104, at: position))
            }
        }
    }

    private func statBadge(title: String, value: String, subtitle: String, at position: CGPoint) -> SKNode {
        let root = SKNode()
        root.position = position

        let titleLabel = Self.label(size: 12, color: Palette.quiet, weight: .demibold)
        titleLabel.text = title
        titleLabel.position.y = 57
        root.addChild(titleLabel)

        let halo = SKShapeNode(circleOfRadius: 44)
        halo.fillColor = Palette.panel
        halo.strokeColor = Palette.paleLine
        halo.lineWidth = 2
        root.addChild(halo)

        let inner = SKShapeNode(circleOfRadius: 35)
        inner.fillColor = Palette.ink
        inner.strokeColor = Palette.line
        inner.lineWidth = 1
        root.addChild(inner)

        let valueLabel = Self.label(size: value.count > 2 ? 22 : 29, color: Palette.paper, weight: .demibold)
        valueLabel.text = value
        valueLabel.verticalAlignmentMode = .center
        valueLabel.position.y = 1
        root.addChild(valueLabel)

        let subtitleLabel = Self.label(size: 11, color: Palette.quiet, weight: .demibold)
        subtitleLabel.text = subtitle
        subtitleLabel.position.y = -61
        root.addChild(subtitleLabel)
        return root
    }

    private func detailBox(title: String, size: CGSize, at position: CGPoint) -> SKShapeNode {
        let box = panel(size: size, radius: 3, fill: Palette.ink, stroke: Palette.line, lineWidth: 1)
        box.position = position

        let titlePlate = panel(size: CGSize(width: size.width - 18, height: 30), radius: 2, fill: Palette.raised, stroke: Palette.line, lineWidth: 1)
        titlePlate.position.y = size.height / 2 - 20
        let titleLabel = Self.label(size: 13, color: Palette.paper, weight: .demibold)
        titleLabel.text = title
        titleLabel.horizontalAlignmentMode = .left
        titleLabel.verticalAlignmentMode = .center
        titleLabel.position = CGPoint(x: -size.width / 2 + 23, y: 1)
        titlePlate.addChild(titleLabel)
        box.addChild(titlePlate)
        return box
    }

    private func addTrait(_ title: String, value: String, to root: SKNode, at position: CGPoint) {
        let key = Self.label(size: 14, color: Palette.quiet, weight: .demibold)
        key.text = title
        key.horizontalAlignmentMode = .left
        key.position = position
        root.addChild(key)

        let valueLabel = Self.label(size: 18, color: Palette.paper, weight: .demibold)
        valueLabel.text = value
        valueLabel.horizontalAlignmentMode = .right
        valueLabel.position = CGPoint(x: position.x + 157, y: position.y - 2)
        root.addChild(valueLabel)
    }

    private func addGridHeader(_ title: String, counter: String, to root: SKNode, width: CGFloat) {
        let header = panel(size: CGSize(width: width, height: 36), radius: 2, fill: Palette.ink, stroke: Palette.line, lineWidth: 1)
        header.position.y = 88
        root.addChild(header)

        let titleLabel = Self.label(size: 15, color: Palette.paper, weight: .demibold)
        titleLabel.text = title
        titleLabel.horizontalAlignmentMode = .left
        titleLabel.verticalAlignmentMode = .center
        titleLabel.position = CGPoint(x: -width / 2 + 16, y: 1)
        header.addChild(titleLabel)

        let countLabel = Self.label(size: 15, color: Palette.quiet, weight: .demibold)
        countLabel.text = counter
        countLabel.horizontalAlignmentMode = .right
        countLabel.verticalAlignmentMode = .center
        countLabel.position = CGPoint(x: width / 2 - 16, y: 1)
        header.addChild(countLabel)
    }

    private func addSectionTitle(_ text: String, to root: SKNode, y: CGFloat) {
        let title = Self.label(size: 17, color: Palette.paper, weight: .demibold)
        title.text = text
        title.horizontalAlignmentMode = .left
        title.position = CGPoint(x: -222, y: y)
        root.addChild(title)

        let rule = SKShapeNode(rectOf: CGSize(width: 444, height: 1))
        rule.fillColor = Palette.line
        rule.strokeColor = .clear
        rule.position = CGPoint(x: 0, y: y - 23)
        root.addChild(rule)
    }

    private func item(id: String) -> InventoryItem? {
        items.first { $0.id == id }
    }

    private func refreshSelection() {
        guard let item = items.first(where: { $0.id == selectedItemID }) else { return }
        itemCategoryLabel.text = item.category.rawValue
        itemNameLabel.text = item.name
        itemDescriptionLabel.text = item.description
        itemNoteLabel.text = item.note

        for (id, slots) in slotFrames {
            let selected = id == selectedItemID
            for slot in slots {
                let hasGeneratedFrame = slot.childNode(withName: "inventory.slot-art") != nil
                slot.strokeColor = selected ? Palette.amber : (hasGeneratedFrame ? .clear : Palette.line)
                slot.lineWidth = selected ? 3 : 2
                slot.glowWidth = selected ? 3 : 0
            }
        }
    }

    private func targetName(at point: CGPoint) -> String? {
        for hit in nodes(at: point) {
            var candidate: SKNode? = hit
            while let node = candidate, node !== self {
                if let name = node.name, name.hasPrefix("inventory.") {
                    return name
                }
                candidate = node.parent
            }
        }
        return nil
    }

    private func addInnerBorder(to root: SKNode, size: CGSize) {
        let border = SKShapeNode(rectOf: size, cornerRadius: 10)
        border.fillColor = .clear
        border.strokeColor = Palette.line.withAlphaComponent(0.36)
        border.lineWidth = 1
        root.addChild(border)
    }

    private func addFilmGrainLines(to root: SKNode) {
        for index in 0..<18 {
            let line = SKShapeNode(rectOf: CGSize(width: 1_880, height: 1))
            line.fillColor = SKColor(white: 0.85, alpha: index.isMultiple(of: 3) ? 0.016 : 0.008)
            line.strokeColor = .clear
            line.position.y = -490 + CGFloat(index) * 57
            root.addChild(line)
        }
    }

    private func panel(size: CGSize, radius: CGFloat, fill: SKColor, stroke: SKColor, lineWidth: CGFloat) -> SKShapeNode {
        let node = SKShapeNode(rectOf: size, cornerRadius: radius)
        node.fillColor = fill
        node.strokeColor = stroke
        node.lineWidth = lineWidth
        return node
    }

    private enum LabelWeight {
        case regular
        case demibold
        case display
    }

    private static func label(size: CGFloat, color: SKColor, weight: LabelWeight) -> SKLabelNode {
        let fontName: String
        switch weight {
        case .regular:
            fontName = "AvenirNext-Regular"
        case .demibold:
            fontName = "AvenirNextCondensed-DemiBold"
        case .display:
            fontName = "Copperplate-Bold"
        }
        let label = SKLabelNode(fontNamed: fontName)
        label.fontSize = size
        label.fontColor = color
        return label
    }

    private static func symbol(_ systemName: String, pointSize: CGFloat) -> SKSpriteNode {
        #if os(iOS)
        let configuration = UIImage.SymbolConfiguration(pointSize: pointSize, weight: .regular)
            .applying(UIImage.SymbolConfiguration(hierarchicalColor: .white))
        let image = UIImage(systemName: systemName, withConfiguration: configuration)
            ?? UIImage(systemName: "square.dashed", withConfiguration: configuration)!
        return SKSpriteNode(texture: SKTexture(image: image))
        #elseif os(macOS)
        let configuration = NSImage.SymbolConfiguration(pointSize: pointSize, weight: .regular)
            .applying(NSImage.SymbolConfiguration(hierarchicalColor: .white))
        let image = NSImage(systemSymbolName: systemName, accessibilityDescription: nil)?.withSymbolConfiguration(configuration)
            ?? NSImage(systemSymbolName: "square.dashed", accessibilityDescription: nil)!.withSymbolConfiguration(configuration)!
        return SKSpriteNode(texture: SKTexture(image: image))
        #else
        return SKSpriteNode(color: .clear, size: CGSize(width: pointSize, height: pointSize))
        #endif
    }
}
