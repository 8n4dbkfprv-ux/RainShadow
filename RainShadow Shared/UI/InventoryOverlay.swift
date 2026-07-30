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
    /// Layout contract for the 1960×1080 canvas, tuned to BG EE Classic hierarchy
    /// and sampled wells from `inventory_outer_frame_overlay_v03`.
    private enum Metrics {
        static let canvas = CGSize(width: 1_960, height: 1_080)

        static let titleY: CGFloat = 490
        static let headerRailY: CGFloat = 505
        static let identityBand = CGPoint(x: -40, y: 432)
        static let identitySize = CGSize(width: 1_520, height: 52)
        static let closeButton = CGPoint(x: -910, y: 505)

        static let primaryY: CGFloat = 95

        static let loadoutOrigin = CGPoint(x: -720, y: primaryY)
        static let loadoutSize = CGSize(width: 420, height: 520)
        static let loadoutSlotSize: CGFloat = 88
        static let loadoutSlotPitch: CGFloat = 98
        static let loadoutHeaderWidth: CGFloat = 400

        static let paperdollOrigin = CGPoint(x: -40, y: primaryY)
        static let paperdollSize = CGSize(width: 620, height: 520)
        static let chamberSize = CGSize(width: 280, height: 400)
        static let chamberOffset = CGPoint(x: 0, y: 10)
        static let equipSlotSize = CGSize(width: 72, height: 68)

        static let statsOrigin = CGPoint(x: 520, y: primaryY)
        static let statsSize = CGSize(width: 500, height: 520)
        static let statRowPitch: CGFloat = 118
        static let statRowTopY: CGFloat = 175
        static let statBadgeRadius: CGFloat = 38
        static let statTextWidth: CGFloat = 340

        static let midStripY: CGFloat = -210
        static let midDescSize = CGSize(width: 980, height: 72)
        static let midDescOrigin = CGPoint(x: -40, y: midStripY)
        static let midPausedOrigin = CGPoint(x: -720, y: midStripY + 8)
        static let midCoinsOrigin = CGPoint(x: 720, y: midStripY)

        static let lowerY: CGFloat = -400
        static let bagOrigin = CGPoint(x: -280, y: lowerY)
        static let bagSize = CGSize(width: 1_100, height: 210)
        static let bagColumns = 8
        static let bagRows = 2
        static let bagSlotCount = bagColumns * bagRows
        static let bagSlotSize: CGFloat = 78
        static let bagSlotPitchX: CGFloat = 92
        static let bagSlotPitchY: CGFloat = 90
        static let bagFirstSlotX: CGFloat = -280
        static let bagFirstRowY: CGFloat = 18
        static let bagArtOffset = CGPoint(x: -470, y: -10)

        static let nearbyOrigin = CGPoint(x: 620, y: lowerY)
        static let nearbySize = CGSize(width: 520, height: 210)
        static let nearbySlotCount = 6
        static let nearbySlotSize: CGFloat = 72
        static let nearbySlotPitch: CGFloat = 82
        static let nearbyFirstSlotX: CGFloat = -140
        static let nearbySlotY: CGFloat = -10
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
    private let itemNameLabel = InventoryOverlay.label(size: 20, color: Palette.paper, weight: .demibold)
    private let itemCategoryLabel = InventoryOverlay.label(size: 13, color: Palette.amber, weight: .demibold)
    private let itemDescriptionLabel = InventoryOverlay.label(size: 15, color: Palette.paper, weight: .regular)
    private let itemNoteLabel = InventoryOverlay.label(size: 13, color: Palette.quiet, weight: .regular)
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
            assertionFailure("Missing inventory_outer_frame_overlay_v03.png")
        }

        sheet.addChild(content)

        let title = Self.label(size: 36, color: Palette.paper, weight: .display)
        title.text = "INVENTORY"
        title.position = CGPoint(x: 0, y: Metrics.titleY)
        content.addChild(title)

        addHeaderRail(from: -920, to: -160, y: Metrics.headerRailY)
        addHeaderRail(from: 160, to: 920, y: Metrics.headerRailY)

        let identityBand = panel(size: Metrics.identitySize, radius: 3, fill: Palette.ink, stroke: Palette.line, lineWidth: 2)
        identityBand.position = Metrics.identityBand
        let identityColumnCenterX = Metrics.identitySize.width / 4
        let detectiveName = Self.label(size: 22, color: Palette.paper, weight: .demibold)
        detectiveName.text = "HARLAN VOSS"
        detectiveName.verticalAlignmentMode = .center
        detectiveName.position = CGPoint(x: -identityColumnCenterX, y: 1)
        identityBand.addChild(detectiveName)
        let profession = Self.label(size: 20, color: Palette.paper, weight: .demibold)
        profession.text = "PRIVATE INVESTIGATOR"
        profession.verticalAlignmentMode = .center
        profession.position = CGPoint(x: identityColumnCenterX, y: 1)
        identityBand.addChild(profession)
        let identityDivider = SKShapeNode(rectOf: CGSize(width: 1, height: 36))
        identityDivider.fillColor = Palette.line
        identityDivider.strokeColor = .clear
        identityBand.addChild(identityDivider)
        content.addChild(identityBand)

        buildCloseButton()
        buildLoadoutPanel()
        buildPaperdollPanel()
        buildStatsPanel()
        buildMidStrip()
        buildBagPanel()
        addChild(sheet)
    }

    @discardableResult
    private func addGeneratedOuterFrame() -> Bool {
        guard let texture = GameArt.texture(named: "inventory_outer_frame_overlay_v03")
            ?? GameArt.texture(named: "inventory_outer_frame_overlay_v02") else { return false }
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
        button.position = Metrics.closeButton
        content.addChild(button)
    }

    private func buildLoadoutPanel() {
        let root = SKNode()
        root.position = Metrics.loadoutOrigin
        root.addChild(majorPanel(size: Metrics.loadoutSize))

        addSlotSection(
            "READY WEAPONS",
            items: [item(id: "service-revolver"), nil, nil, nil],
            to: root,
            headerY: 210,
            slotY: 130
        )
        addSlotSection(
            "QUICK ITEMS",
            items: [item(id: "flashlight"), item(id: "case-notes"), item(id: "cigarette-case")],
            to: root,
            headerY: 40,
            slotY: -40
        )
        addSlotSection(
            "COAT POCKETS",
            items: [item(id: "brass-key"), nil, item(id: "wallet")],
            to: root,
            headerY: -130,
            slotY: -210
        )

        content.addChild(root)
    }

    private func buildPaperdollPanel() {
        let root = SKNode()
        root.position = Metrics.paperdollOrigin
        root.addChild(majorPanel(size: Metrics.paperdollSize))

        let chamber = panel(
            size: Metrics.chamberSize,
            radius: 3,
            fill: Palette.ink,
            stroke: Palette.line,
            lineWidth: 2
        )
        chamber.position = Metrics.chamberOffset
        root.addChild(chamber)

        let floorLight = SKShapeNode(ellipseOf: CGSize(width: 200, height: 36))
        floorLight.fillColor = SKColor(white: 0.66, alpha: 0.1)
        floorLight.strokeColor = .clear
        floorLight.position = CGPoint(x: 0, y: -155)
        chamber.addChild(floorLight)

        if let detectiveTexture = GameArt.texture(named: "voss_paperdoll_front_rgba_v01") {
            detectiveTexture.filteringMode = .linear
            let paperdoll = SKSpriteNode(texture: detectiveTexture, size: CGSize(width: 210, height: 315))
            paperdoll.name = "inventory.paperdoll"
            paperdoll.position = CGPoint(x: 0, y: -6)
            chamber.addChild(paperdoll)
        } else {
            assertionFailure("Missing voss_paperdoll_front_rgba_v01.png")
        }

        // Classic density: top row, side rings, bottom row.
        let equipment: [(String, String, CGPoint)] = [
            ("inventory_slot_silhouette_hat_v03", "FEDORA", CGPoint(x: -168, y: 220)),
            ("inventory_slot_silhouette_hands_v03", "GLOVES", CGPoint(x: -84, y: 220)),
            ("inventory_slot_silhouette_coat_v03", "COAT", CGPoint(x: 0, y: 220)),
            ("inventory_slot_silhouette_weapon_v03", "HOLSTER", CGPoint(x: 84, y: 220)),
            ("inventory_slot_silhouette_item_v03", "CHARM", CGPoint(x: 168, y: 220)),
            ("inventory_slot_silhouette_hands_v03", "HANDS", CGPoint(x: -210, y: 20)),
            ("inventory_slot_silhouette_ring_v03", "LUCK", CGPoint(x: 210, y: 20)),
            ("inventory_slot_silhouette_feet_v03", "SHOES", CGPoint(x: -84, y: -220)),
            ("inventory_slot_silhouette_coat_v03", "STANCE", CGPoint(x: 0, y: -220)),
            ("inventory_slot_silhouette_weapon_v03", "WEAPON", CGPoint(x: 84, y: -220))
        ]
        for equipmentItem in equipment {
            root.addChild(equipmentSlot(artName: equipmentItem.0, caption: equipmentItem.1, at: equipmentItem.2))
        }

        content.addChild(root)
    }

    private func buildStatsPanel() {
        let root = SKNode()
        root.position = Metrics.statsOrigin
        root.addChild(majorPanel(size: Metrics.statsSize))

        let rows: [(String, String, [String])] = [
            ("8", "DEFENCE", ["Defence: 8", "Coat & leather turn glancing blows."]),
            ("8/10", "VITALITY", ["Vitality: 8 / 10", "Steady under night pressure."]),
            ("6", "RESOLVE", ["Resolve: 6", "Keeps the case moving forward."]),
            ("2–7", "DAMAGE", ["Damage: 2–7", "Webley · service load."])
        ]
        for (index, row) in rows.enumerated() {
            let y = Metrics.statRowTopY - CGFloat(index) * Metrics.statRowPitch
            root.addChild(statRow(value: row.0, caption: row.1, lines: row.2, at: CGPoint(x: 0, y: y)))
        }

        content.addChild(root)
    }

    private func buildMidStrip() {
        let paused = Self.label(size: 18, color: Palette.quiet, weight: .demibold)
        paused.text = "CASEWORK PAUSED"
        paused.horizontalAlignmentMode = .left
        paused.position = Metrics.midPausedOrigin
        content.addChild(paused)

        let desc = panel(size: Metrics.midDescSize, radius: 3, fill: Palette.ink, stroke: Palette.line, lineWidth: 1)
        desc.position = Metrics.midDescOrigin
        itemCategoryLabel.horizontalAlignmentMode = .left
        itemCategoryLabel.verticalAlignmentMode = .center
        itemCategoryLabel.position = CGPoint(x: -Metrics.midDescSize.width / 2 + 18, y: 18)
        desc.addChild(itemCategoryLabel)
        itemNameLabel.horizontalAlignmentMode = .left
        itemNameLabel.verticalAlignmentMode = .center
        itemNameLabel.position = CGPoint(x: -Metrics.midDescSize.width / 2 + 160, y: 18)
        desc.addChild(itemNameLabel)
        itemDescriptionLabel.horizontalAlignmentMode = .left
        itemDescriptionLabel.verticalAlignmentMode = .center
        itemDescriptionLabel.preferredMaxLayoutWidth = Metrics.midDescSize.width - 36
        itemDescriptionLabel.numberOfLines = 1
        itemDescriptionLabel.position = CGPoint(x: -Metrics.midDescSize.width / 2 + 18, y: -4)
        desc.addChild(itemDescriptionLabel)
        itemNoteLabel.horizontalAlignmentMode = .left
        itemNoteLabel.verticalAlignmentMode = .center
        itemNoteLabel.position = CGPoint(x: -Metrics.midDescSize.width / 2 + 18, y: -24)
        desc.addChild(itemNoteLabel)
        content.addChild(desc)

        content.addChild(coinDisplay(at: Metrics.midCoinsOrigin))
    }

    private func buildBagPanel() {
        let bag = SKNode()
        bag.position = Metrics.bagOrigin
        bag.addChild(majorPanel(size: Metrics.bagSize))
        addGridHeader("CASE BAG", counter: "\(items.count) / \(Metrics.bagSlotCount)", to: bag, width: Metrics.bagSize.width - 40)

        if let bagTexture = GameArt.texture(named: "inventory_case_bag_v01") {
            bagTexture.filteringMode = .linear
            let bagArt = SKSpriteNode(texture: bagTexture, size: CGSize(width: 120, height: 120))
            bagArt.position = Metrics.bagArtOffset
            bag.addChild(bagArt)
        }
        let carriedWeight = Self.label(size: 13, color: Palette.amber, weight: .demibold)
        carriedWeight.text = "14 lb"
        carriedWeight.position = CGPoint(x: Metrics.bagArtOffset.x, y: Metrics.bagArtOffset.y + 72)
        bag.addChild(carriedWeight)
        let maximumWeight = Self.label(size: 12, color: Palette.quiet, weight: .demibold)
        maximumWeight.text = "70 lb MAX"
        maximumWeight.position = CGPoint(x: Metrics.bagArtOffset.x, y: Metrics.bagArtOffset.y - 72)
        bag.addChild(maximumWeight)

        let bagItems: [InventoryItem?] = items.map(Optional.some)
            + Array(repeating: nil, count: max(0, Metrics.bagSlotCount - items.count))
        for index in 0..<Metrics.bagSlotCount {
            let column = index % Metrics.bagColumns
            let row = index / Metrics.bagColumns
            let position = CGPoint(
                x: Metrics.bagFirstSlotX + CGFloat(column) * Metrics.bagSlotPitchX,
                y: Metrics.bagFirstRowY - CGFloat(row) * Metrics.bagSlotPitchY
            )
            if let item = bagItems[index] {
                bag.addChild(itemSlot(item, size: Metrics.bagSlotSize, at: position, showQuantity: true))
            } else {
                bag.addChild(emptySlot(size: Metrics.bagSlotSize, at: position))
            }
        }
        content.addChild(bag)

        let ground = SKNode()
        ground.position = Metrics.nearbyOrigin
        ground.addChild(majorPanel(size: Metrics.nearbySize))
        addGridHeader("NEARBY", counter: "0 / \(Metrics.nearbySlotCount)", to: ground, width: Metrics.nearbySize.width - 40)

        let pageLabel = Self.label(size: 13, color: Palette.quiet, weight: .demibold)
        pageLabel.text = "1 / 1"
        pageLabel.position = CGPoint(x: 0, y: 52)
        ground.addChild(pageLabel)

        ground.addChild(pageArrow(direction: -1, at: CGPoint(x: -210, y: Metrics.nearbySlotY)))
        ground.addChild(pageArrow(direction: 1, at: CGPoint(x: 210, y: Metrics.nearbySlotY)))

        for index in 0..<Metrics.nearbySlotCount {
            ground.addChild(emptySlot(
                size: Metrics.nearbySlotSize,
                at: CGPoint(
                    x: Metrics.nearbyFirstSlotX + CGFloat(index) * Metrics.nearbySlotPitch,
                    y: Metrics.nearbySlotY
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
            assertionFailure("Missing inventory item art: \(item.artName)")
        }

        if showQuantity, item.quantity > 1 {
            let countPlate = panel(size: CGSize(width: 28, height: 22), radius: 3, fill: Palette.ink, stroke: Palette.line, lineWidth: 1)
            countPlate.position = CGPoint(x: size / 2 - 15, y: -size / 2 + 13)
            let count = Self.label(size: 12, color: Palette.paper, weight: .demibold)
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
        if let texture = UIPaintedChrome.texture(named: "inventory_slot_silhouette_bag_v03") {
            let silhouette = SKSpriteNode(texture: texture, size: CGSize(width: size * 0.72, height: size * 0.72))
            silhouette.alpha = 0.55
            silhouette.zPosition = 0
            slot.addChild(silhouette)
        }
        return slot
    }

    private func equipmentSlot(artName: String, caption: String, at position: CGPoint) -> SKNode {
        let root = SKNode()
        root.position = position
        let slot = slotBase(size: Metrics.equipSlotSize)
        if let texture = UIPaintedChrome.texture(named: artName) {
            let icon = SKSpriteNode(texture: texture, size: CGSize(width: 52, height: 48))
            icon.alpha = 0.78
            slot.addChild(icon)
        }
        root.addChild(slot)

        let label = Self.label(size: 11, color: Palette.quiet, weight: .demibold)
        label.text = caption
        label.position.y = -48
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
        // Layout anchor only — visible chrome comes from inventory_outer_frame_overlay_v03.
        let surface = panel(
            size: size,
            radius: 0,
            fill: .clear,
            stroke: .clear,
            lineWidth: 0
        )
        root.addChild(surface)
        return root
    }

    private func coinDisplay(at position: CGPoint) -> SKNode {
        let root = SKNode()
        root.position = position

        if let texture = GameArt.texture(named: "inventory_coin_stack_v01") {
            texture.filteringMode = .linear
            let coins = SKSpriteNode(texture: texture, size: CGSize(width: 88, height: 64))
            coins.position = CGPoint(x: -55, y: 4)
            root.addChild(coins)
        }

        let valuePlate = panel(size: CGSize(width: 110, height: 32), radius: 3, fill: Palette.ink, stroke: Palette.line, lineWidth: 1)
        valuePlate.position = CGPoint(x: 45, y: 0)
        let value = Self.label(size: 16, color: Palette.paper, weight: .demibold)
        value.text = "£7  4s"
        value.verticalAlignmentMode = .center
        value.position.y = 1
        valuePlate.addChild(value)
        root.addChild(valuePlate)
        return root
    }

    private func statRow(value: String, caption: String, lines: [String], at position: CGPoint) -> SKNode {
        let root = SKNode()
        root.position = position

        let badgeX: CGFloat = -Metrics.statsSize.width / 2 + 55
        let halo = SKShapeNode(circleOfRadius: Metrics.statBadgeRadius)
        halo.fillColor = Palette.panel
        halo.strokeColor = Palette.paleLine
        halo.lineWidth = 2
        halo.position = CGPoint(x: badgeX, y: 0)
        root.addChild(halo)

        let inner = SKShapeNode(circleOfRadius: Metrics.statBadgeRadius - 8)
        inner.fillColor = Palette.ink
        inner.strokeColor = Palette.line
        inner.lineWidth = 1
        inner.position = halo.position
        root.addChild(inner)

        let valueLabel = Self.label(size: value.count > 3 ? 18 : 24, color: Palette.paper, weight: .demibold)
        valueLabel.text = value
        valueLabel.verticalAlignmentMode = .center
        valueLabel.position = CGPoint(x: badgeX, y: 1)
        root.addChild(valueLabel)

        let captionLabel = Self.label(size: 11, color: Palette.quiet, weight: .demibold)
        captionLabel.text = caption
        captionLabel.position = CGPoint(x: badgeX, y: -Metrics.statBadgeRadius - 14)
        root.addChild(captionLabel)

        let textX = badgeX + Metrics.statBadgeRadius + 28
        let plate = panel(
            size: CGSize(width: Metrics.statTextWidth, height: 88),
            radius: 3,
            fill: Palette.ink,
            stroke: Palette.line,
            lineWidth: 1
        )
        plate.position = CGPoint(x: textX + Metrics.statTextWidth / 2, y: 0)
        root.addChild(plate)

        for (index, line) in lines.enumerated() {
            let label = Self.label(
                size: index == 0 ? 16 : 14,
                color: index == 0 ? Palette.paper : Palette.quiet,
                weight: index == 0 ? .demibold : .regular
            )
            label.text = line
            label.horizontalAlignmentMode = .left
            label.verticalAlignmentMode = .center
            label.preferredMaxLayoutWidth = Metrics.statTextWidth - 28
            label.numberOfLines = 2
            label.position = CGPoint(x: textX + 14, y: index == 0 ? 14 : -12)
            root.addChild(label)
        }

        return root
    }

    private func pageArrow(direction: Int, at position: CGPoint) -> SKNode {
        let root = SKNode()
        root.position = position
        root.name = direction < 0 ? "inventory.nearby.prev" : "inventory.nearby.next"

        let plate = panel(size: CGSize(width: 36, height: 56), radius: 3, fill: Palette.raised, stroke: Palette.line, lineWidth: 1)
        root.addChild(plate)

        let mark = Self.label(size: 22, color: Palette.paper, weight: .demibold)
        mark.text = direction < 0 ? "‹" : "›"
        mark.verticalAlignmentMode = .center
        mark.position.y = 1
        root.addChild(mark)
        return root
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

    private func addSlotSection(
        _ title: String,
        items: [InventoryItem?],
        to root: SKNode,
        headerY: CGFloat,
        slotY: CGFloat
    ) {
        let count = items.count
        let header = panel(
            size: CGSize(width: Metrics.loadoutHeaderWidth, height: 40),
            radius: 3,
            fill: Palette.ink,
            stroke: Palette.line,
            lineWidth: 2
        )
        header.position = CGPoint(x: 0, y: headerY)
        let label = Self.label(size: 16, color: Palette.paper, weight: .demibold)
        label.text = title
        label.verticalAlignmentMode = .center
        label.position.y = 1
        header.addChild(label)
        root.addChild(header)

        let startX = -CGFloat(count - 1) * Metrics.loadoutSlotPitch / 2
        for index in 0..<count {
            let position = CGPoint(x: startX + CGFloat(index) * Metrics.loadoutSlotPitch, y: slotY)
            if let item = items[index] {
                root.addChild(itemSlot(item, size: Metrics.loadoutSlotSize, at: position, showQuantity: true))
            } else {
                root.addChild(emptySlot(size: Metrics.loadoutSlotSize, at: position))
            }
        }
    }

    private func addGridHeader(_ title: String, counter: String, to root: SKNode, width: CGFloat) {
        let header = panel(size: CGSize(width: width, height: 34), radius: 2, fill: Palette.ink, stroke: Palette.line, lineWidth: 1)
        header.position.y = 78
        root.addChild(header)

        let titleLabel = Self.label(size: 14, color: Palette.paper, weight: .demibold)
        titleLabel.text = title
        titleLabel.horizontalAlignmentMode = .left
        titleLabel.verticalAlignmentMode = .center
        titleLabel.position = CGPoint(x: -width / 2 + 14, y: 1)
        header.addChild(titleLabel)

        let countLabel = Self.label(size: 14, color: Palette.quiet, weight: .demibold)
        countLabel.text = counter
        countLabel.horizontalAlignmentMode = .right
        countLabel.verticalAlignmentMode = .center
        countLabel.position = CGPoint(x: width / 2 - 14, y: 1)
        header.addChild(countLabel)
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
}
