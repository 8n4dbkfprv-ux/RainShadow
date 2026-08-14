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

    /// Stable key for one painted/selectable occurrence. Starter keys equal their
    /// authored IDs; acquired keys also include their carried-stack index.
    let id: String
    /// Definition/catalog identity, intentionally independent of presentation.
    let authoredID: String
    let name: String
    let category: Category
    let description: String
    let note: String
    let symbolName: String
    let artName: String
    let quantity: Int
}

/// One presentation catalogue shared by the full inventory and compact loot panel.
/// Unknown authored IDs still get an honest generic item silhouette instead of
/// disappearing from either transfer surface.
enum InventoryItemCatalog {
    static let starterSlotCount = 6

    static func starterItems(walletPence: Int) -> [InventoryItem] {
        let cashNote = "Cash on hand: \(CurrencyAmount(pence: walletPence).formatted)"
        return [
            InventoryItem(
                id: "service-revolver",
                authoredID: "service-revolver",
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
                authoredID: "case-notes",
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
                authoredID: "brass-key",
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
                authoredID: "flashlight",
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
                authoredID: "wallet",
                name: "Leather Wallet",
                category: .personal,
                description: "Licence, tram pass, and the kind of money that disappears quickly.",
                note: cashNote,
                symbolName: "creditcard.fill",
                artName: "inventory_item_wallet_v01",
                quantity: 1
            ),
            InventoryItem(
                id: "cigarette-case",
                authoredID: "cigarette-case",
                name: "Cigarette Case",
                category: .personal,
                description: "Gunmetal silver. Initials scratched away with deliberate care.",
                note: "4 cigarettes remaining",
                symbolName: "cigarette.fill",
                artName: "inventory_item_cigarette_case_v01",
                quantity: 4
            )
        ]
    }

    /// Compatibility entry point for callers that do not own selectable slot
    /// occurrences (for example, the compact loot panel).
    static func acquiredItem(id: String, quantity: Int) -> InventoryItem {
        acquiredItem(authoredID: id, quantity: quantity, presentationID: id)
    }

    static func acquiredItem(
        authoredID: String,
        quantity: Int,
        presentationID: String
    ) -> InventoryItem {
        switch authoredID {
        case "service-revolver":
            return InventoryItem(
                id: presentationID,
                authoredID: authoredID,
                name: "Service Revolver",
                category: .weapon,
                description: "A recovered service revolver carried in the case bag.",
                note: "Carried item · not equipped",
                symbolName: "scope",
                artName: "inventory_item_service_revolver_v01",
                quantity: max(1, quantity)
            )
        case "matchbook":
            return InventoryItem(
                id: presentationID,
                authoredID: authoredID,
                name: "Matchbook",
                category: .evidence,
                description: "A paper matchbook kept as part of the case record.",
                note: "Recovered evidence",
                symbolName: "flame.fill",
                artName: "inventory_item_matchbook_v01",
                quantity: max(1, quantity)
            )
        default:
            let displayName = authoredID
                .replacingOccurrences(of: "-", with: " ")
                .replacingOccurrences(of: "_", with: " ")
                .capitalized
            return InventoryItem(
                id: presentationID,
                authoredID: authoredID,
                name: displayName.isEmpty ? "Recovered Item" : displayName,
                category: .evidence,
                description: "An item recovered while working the case.",
                note: "Recovered evidence",
                symbolName: "shippingbox.fill",
                artName: "inventory_slot_silhouette_item_v06",
                quantity: max(1, quantity)
            )
        }
    }
}

/// Modular V05 inventory: painted section plates + slot chrome; code places icons, live labels, and hit targets.
/// Paperdoll equipped slots follow BG:EE Enhanced ui.menu geometry (V06 silhouettes; noir holster/revolver).
@MainActor
final class InventoryOverlay: SKNode {
    /// Layout contract for the 1960×1080 canvas — BG EE hierarchy with EE Enhanced equipped geometry.
    /// Loadout rows share one left edge; the case bag spans the full lower band.
    private enum Metrics {
        static let canvas = CGSize(width: 1_960, height: 1_080)

        static let titleY: CGFloat = 520
        /// Sits in the content well just below V16's 39px Platinum title bar.
        static let identityBand = CGPoint(x: 0, y: 390)
        /// Center of the OS 9 close box stamped into V16's left stripe field.
        static let closeButton = CGPoint(x: -957, y: 520)
        static let closeArtworkSize = CGSize(width: 20, height: 20)

        /// One shared content rectangle inside the outer frame's inner rails.
        /// Keeping every opaque plate on these edges prevents uneven gutters
        /// and stops the lower band from covering the frame itself.
        static let contentLeft: CGFloat = -840
        static let contentRight: CGFloat = 840
        static let contentWidth = contentRight - contentLeft
        static let sectionGap: CGFloat = 25

        static let primaryY: CGFloat = 90

        /// Column center; slots left-align from `loadoutSlotLeft` (not centered per row).
        static let loadoutSize = CGSize(width: 460, height: 520)
        static let loadoutOrigin = CGPoint(x: contentLeft + loadoutSize.width / 2, y: primaryY)
        static let loadoutSlotLeft: CGFloat = -168
        static let loadoutSlotSize: CGFloat = 92
        static let loadoutSlotPitch: CGFloat = 108

        static let paperdollSize = CGSize(width: 520, height: 520)
        static let paperdollOrigin = CGPoint(
            x: contentLeft + loadoutSize.width + sectionGap + paperdollSize.width / 2,
            y: primaryY
        )
        /// Slightly below center so the EE top row clears the fedora/crown.
        static let chamberOffset = CGPoint(x: 0, y: -8)
        static let equipSlotSize = CGSize(width: 72, height: 68)

        /// BG:EE Enhanced ui.menu equipped-slot geometry, scaled into the paperdoll panel
        /// (52px STONSLOT → ~72px; helmet on the head centerline).
        /// Top row order is armor · gauntlets · helmet · amulet (helmet = paperdoll x=0).
        static let equipTopY: CGFloat = 190
        static let equipTopPitch: CGFloat = 78
        static let equipArmor = CGPoint(x: -2 * equipTopPitch, y: equipTopY)
        static let equipGauntlets = CGPoint(x: -1 * equipTopPitch, y: equipTopY)
        static let equipHelmet = CGPoint(x: 0, y: equipTopY)
        static let equipAmulet = CGPoint(x: 1 * equipTopPitch, y: equipTopY)
        static let equipCloak = CGPoint(x: -177, y: 68)
        static let equipHolster = CGPoint(x: 159, y: -21)
        static let equipRingLeft = CGPoint(x: -177, y: -101)
        static let equipRingRight = CGPoint(x: 159, y: -101)
        static let equipBelt = CGPoint(x: -11, y: -126)
        static let equipBoots = CGPoint(x: -11, y: -182)

        static let statsSize = CGSize(width: 650, height: 560)
        static let statsOrigin = CGPoint(x: contentRight - statsSize.width / 2, y: primaryY)
        static let statRowPitch: CGFloat = 116
        static let statRowTopY: CGFloat = 195
        static let statBadgeSize: CGFloat = 84
        static let statTextWidth: CGFloat = 490

        static let midStripY: CGFloat = -225
        static let midSize = CGSize(width: contentWidth, height: 80)
        static let midDescOrigin = CGPoint(x: 0, y: midStripY)
        static let midPausedOrigin = CGPoint(x: -790, y: midStripY)
        static let midCoinsOrigin = CGPoint(x: 750, y: midStripY)

        /// Full-width lower band: satchel + one-row bag grid.
        static let lowerY: CGFloat = -365
        static let bagSize = CGSize(width: 1_680, height: 190)
        static let bagOrigin = CGPoint(x: 0, y: lowerY)
        static let bagSlotCount = 16
        static let bagSlotSize: CGFloat = 70
        static let bagSlotPitch: CGFloat = 84
        static let bagFirstSlotX: CGFloat = -560
        static let bagSlotY: CGFloat = -20
        static let bagArtOffset = CGPoint(x: -750, y: 0)
    }

    private enum Palette {
        static let paper = SKColor(red: 0.82, green: 0.80, blue: 0.72, alpha: 1)
        static let quiet = SKColor(red: 0.55, green: 0.57, blue: 0.57, alpha: 1)
        static let amber = SKColor(red: 0.79, green: 0.55, blue: 0.26, alpha: 1)
    }

    private var items: [InventoryItem] = InventoryItemCatalog.starterItems(
        walletPence: CurrencyAmount.startingWalletPence
    )

    var onDismiss: (() -> Void)?

    private var slotFramesByPresentationID: [String: [SKNode]] = [:]
    private var selectedPresentationID = "case-notes"
    private let itemNameLabel = InventoryOverlay.label(size: 20, color: Palette.paper, weight: .demibold)
    private let itemCategoryLabel = InventoryOverlay.label(size: 13, color: Palette.amber, weight: .demibold)
    private let itemDescriptionLabel = InventoryOverlay.label(size: 15, color: Palette.paper, weight: .regular)
    private let itemNoteLabel = InventoryOverlay.label(size: 13, color: Palette.quiet, weight: .regular)
    private let sheet = SKNode()
    private let content = SKNode()
    private let coinValueLabel = InventoryOverlay.label(size: 16, color: Palette.paper, weight: .demibold)
    private let bagSlotsRoot = SKNode()
    private let bagCountLabel = InventoryOverlay.label(size: 14, color: Palette.quiet, weight: .demibold)
    private let bagOccupiedLabel = InventoryOverlay.label(size: 12, color: Palette.amber, weight: .demibold)
    private let bagCapacityLabel = InventoryOverlay.label(size: 11, color: Palette.quiet, weight: .demibold)
    private var carriedItems: [CarriedItemStack] = []
    private var walletPence = CurrencyAmount.startingWalletPence

    override init() {
        super.init()
        name = "inventory.overlay"
        isUserInteractionEnabled = false
        buildInterface()
        refreshSelection()
        isHidden = true
    }

    private static func makeStarterItems(walletPence: Int) -> [InventoryItem] {
        InventoryItemCatalog.starterItems(walletPence: walletPence)
    }

    /// Persistence currently stores ordered stacks rather than per-stack UUIDs,
    /// so the carried index is the occurrence identity for this presentation.
    private static func acquiredPresentationID(
        authoredID: String,
        carriedIndex: Int
    ) -> String {
        "acquired.\(carriedIndex).\(authoredID)"
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("InventoryOverlay is created programmatically")
    }

    func layout(for visibleSize: CGSize) {
        let horizontalFit = (visibleSize.width - 34) / Metrics.canvas.width
        let verticalFit = (visibleSize.height - 30) / Metrics.canvas.height
        setScale(min(1, horizontalFit, verticalFit))
    }

    func present(walletPence: Int, carriedItems: [CarriedItemStack]) {
        applyInventory(walletPence: walletPence, carriedItems: carriedItems)
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
            .run { [weak self] in
                self?.isHidden = true
            }
        ]))
    }

    func applyWallet(_ pence: Int) {
        applyInventory(walletPence: pence, carriedItems: carriedItems)
    }

    func applyInventory(walletPence pence: Int, carriedItems: [CarriedItemStack]) {
        walletPence = max(0, pence)
        coinValueLabel.text = CurrencyAmount(pence: walletPence).formatted
        self.carriedItems = carriedItems
        items = Self.makeStarterItems(walletPence: walletPence) + carriedItems.enumerated().map {
            index, stack in
            InventoryItemCatalog.acquiredItem(
                authoredID: stack.id,
                quantity: stack.quantity,
                presentationID: Self.acquiredPresentationID(
                    authoredID: stack.id,
                    carriedIndex: index
                )
            )
        }
        rebuildBagSlots()
        if !items.contains(where: { $0.id == selectedPresentationID }) {
            selectedPresentationID = items.first?.id ?? "case-notes"
        }
        refreshSelection()
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
            selectedPresentationID = String(target.dropFirst("inventory.item.".count))
            refreshSelection()
        }
        return true
    }

    func moveSelection(_ direction: Int) {
        guard !items.isEmpty else { return }
        let current = items.firstIndex { $0.id == selectedPresentationID } ?? 0
        let next = (current + direction + items.count) % items.count
        selectedPresentationID = items[next].id
        refreshSelection()
    }

    func isInteractive(at point: CGPoint) -> Bool {
        guard let target = targetName(at: point) else { return false }
        return target == "inventory.close"
            || target.hasPrefix("inventory.item.")
    }

    private func buildInterface() {
        let veil = SKShapeNode(rectOf: CGSize(width: 3_000, height: 1_600))
        veil.fillColor = SKColor(white: 0.005, alpha: 0.83)
        veil.strokeColor = .clear
        veil.zPosition = -20
        addChild(veil)

        addChromeSprite(named: "inventory_outer_frame_v16", size: Metrics.canvas, z: -8, parent: sheet)

        sheet.addChild(content)
        content.zPosition = 0

        let title = Self.label(size: 36, color: Palette.paper, weight: .display)
        title.text = "INVENTORY"
        title.verticalAlignmentMode = .center
        title.position = CGPoint(x: 0, y: Metrics.titleY)
        title.zPosition = 20
        content.addChild(title)

        let detectiveName = Self.label(size: 20, color: Palette.paper, weight: .demibold)
        detectiveName.text = "HARLAN VOSS"
        detectiveName.horizontalAlignmentMode = .right
        detectiveName.position = CGPoint(x: Metrics.identityBand.x - 18, y: Metrics.identityBand.y)
        detectiveName.zPosition = 20
        content.addChild(detectiveName)

        let divider = Self.label(size: 18, color: Palette.quiet, weight: .demibold)
        divider.text = "·"
        divider.horizontalAlignmentMode = .center
        divider.position = Metrics.identityBand
        divider.zPosition = 20
        content.addChild(divider)

        let profession = Self.label(size: 18, color: Palette.paper, weight: .demibold)
        profession.text = "PRIVATE INVESTIGATOR"
        profession.horizontalAlignmentMode = .left
        profession.position = CGPoint(x: Metrics.identityBand.x + 18, y: Metrics.identityBand.y)
        profession.zPosition = 20
        content.addChild(profession)

        buildCloseButton()
        buildLoadoutPanel()
        buildPaperdollPanel()
        buildStatsPanel()
        buildMidStrip()
        buildBagPanel()
        addChild(sheet)
    }

    private func buildCloseButton() {
        let button = ClassicMacCloseButtonNode(
            targetName: "inventory.close",
            fill: .clear,
            stroke: .clear,
            highlight: .clear,
            accent: .clear,
            artworkName: "inventory_close_box_macos9_noir_v15",
            artworkSize: Metrics.closeArtworkSize
        )
        button.position = Metrics.closeButton
        button.zPosition = 30
        content.addChild(button)
    }

    private func buildLoadoutPanel() {
        let root = SKNode()
        root.position = Metrics.loadoutOrigin
        root.zPosition = 1

        addChromeSprite(
            named: "inventory_section_loadout_v05",
            size: Metrics.loadoutSize,
            z: -1,
            parent: root
        )

        addSlotSection(
            "READY WEAPONS",
            items: [item(id: "service-revolver"), nil, nil, nil],
            emptySilhouette: "inventory_slot_silhouette_weapon_v06",
            to: root,
            headerY: 200,
            slotY: 144
        )
        addSlotSection(
            "QUICK ITEMS",
            items: [item(id: "flashlight"), item(id: "case-notes"), item(id: "cigarette-case")],
            emptySilhouette: "inventory_slot_silhouette_item_v06",
            to: root,
            headerY: 55,
            slotY: -5
        )
        addSlotSection(
            "COAT POCKETS",
            items: [item(id: "brass-key"), nil, item(id: "wallet")],
            emptySilhouette: "inventory_slot_silhouette_item_v06",
            to: root,
            headerY: -110,
            slotY: -180
        )

        content.addChild(root)
    }

    private func buildPaperdollPanel() {
        let root = SKNode()
        root.position = Metrics.paperdollOrigin
        root.zPosition = 1

        addChromeSprite(
            named: "inventory_section_paperdoll_v05",
            size: Metrics.paperdollSize,
            z: -1,
            parent: root
        )

        if let detectiveTexture = GameArt.texture(named: "voss_paperdoll_front_rgba_v01") {
            detectiveTexture.filteringMode = .nearest
            let paperdoll = SKSpriteNode(texture: detectiveTexture, size: CGSize(width: 220, height: 315))
            paperdoll.name = "inventory.paperdoll"
            paperdoll.position = Metrics.chamberOffset
            paperdoll.zPosition = 0
            root.addChild(paperdoll)
        } else {
            assertionFailure("Missing voss_paperdoll_front_rgba_v01.png")
        }

        // BG:EE Enhanced equipped geometry: armor/gauntlets/helmet/amulet top row,
        // cloak left shoulder, noir holster as off-hand, rings, belt, boots.
        // No captions — BG:EE empty slots have none.
        let equipment: [(String, String, CGPoint)] = [
            ("inventory_slot_silhouette_coat_v06", "inventory.equip.coat", Metrics.equipArmor),
            ("inventory_slot_silhouette_hands_v06", "inventory.equip.gloves", Metrics.equipGauntlets),
            ("inventory_slot_silhouette_hat_v06", "inventory.equip.fedora", Metrics.equipHelmet),
            ("inventory_slot_silhouette_charm_v06", "inventory.equip.charm", Metrics.equipAmulet),
            ("inventory_slot_silhouette_cloak_v06", "inventory.equip.cloak", Metrics.equipCloak),
            ("inventory_slot_silhouette_holster_v06", "inventory.equip.holster", Metrics.equipHolster),
            ("inventory_slot_silhouette_ring_v06", "inventory.equip.ringLeft", Metrics.equipRingLeft),
            ("inventory_slot_silhouette_ring_v06", "inventory.equip.ringRight", Metrics.equipRingRight),
            ("inventory_slot_silhouette_belt_v06", "inventory.equip.belt", Metrics.equipBelt),
            ("inventory_slot_silhouette_feet_v06", "inventory.equip.shoes", Metrics.equipBoots)
        ]
        for equipmentItem in equipment {
            root.addChild(
                equipmentSlot(artName: equipmentItem.0, name: equipmentItem.1, at: equipmentItem.2)
            )
        }

        content.addChild(root)
    }

    private func buildStatsPanel() {
        let root = SKNode()
        root.position = Metrics.statsOrigin
        root.zPosition = 1

        addChromeSprite(
            named: "inventory_section_stats_v05",
            size: Metrics.statsSize,
            z: -1,
            parent: root
        )

        let rows: [(String, String, String, [String])] = [
            ("inventory_stat_badge_defence_v05", "8", "DEFENCE", ["Defence: 8", "Coat & leather turn glancing blows."]),
            ("inventory_stat_badge_vitality_v05", "8/10", "VITALITY", ["Vitality: 8 / 10", "Steady under night pressure."]),
            ("inventory_stat_badge_resolve_v05", "6", "RESOLVE", ["Resolve: 6", "Keeps the case moving forward."]),
            ("inventory_stat_badge_damage_v05", "2–7", "DAMAGE", ["Damage: 2–7", "Webley · service load."])
        ]
        for (index, row) in rows.enumerated() {
            let y = Metrics.statRowTopY - CGFloat(index) * Metrics.statRowPitch
            root.addChild(statRow(badgeArt: row.0, value: row.1, caption: row.2, lines: row.3, at: CGPoint(x: 0, y: y)))
        }

        content.addChild(root)
    }

    private func buildMidStrip() {
        addChromeSprite(
            named: "inventory_section_mid_v05",
            size: Metrics.midSize,
            at: CGPoint(x: 0, y: Metrics.midStripY),
            z: 0,
            parent: content
        )

        let paused = Self.label(size: 16, color: Palette.quiet, weight: .demibold)
        paused.text = "CASEWORK PAUSED"
        paused.horizontalAlignmentMode = .left
        paused.verticalAlignmentMode = .center
        paused.position = Metrics.midPausedOrigin
        paused.zPosition = 2
        content.addChild(paused)

        let desc = SKNode()
        desc.position = Metrics.midDescOrigin
        desc.zPosition = 2
        itemCategoryLabel.horizontalAlignmentMode = .left
        itemCategoryLabel.verticalAlignmentMode = .center
        itemCategoryLabel.position = CGPoint(x: -520, y: 18)
        desc.addChild(itemCategoryLabel)
        itemNameLabel.horizontalAlignmentMode = .left
        itemNameLabel.verticalAlignmentMode = .center
        itemNameLabel.position = CGPoint(x: -370, y: 18)
        desc.addChild(itemNameLabel)
        itemDescriptionLabel.horizontalAlignmentMode = .left
        itemDescriptionLabel.verticalAlignmentMode = .center
        itemDescriptionLabel.preferredMaxLayoutWidth = 1_040
        itemDescriptionLabel.numberOfLines = 1
        itemDescriptionLabel.position = CGPoint(x: -520, y: -4)
        desc.addChild(itemDescriptionLabel)
        itemNoteLabel.horizontalAlignmentMode = .left
        itemNoteLabel.verticalAlignmentMode = .center
        itemNoteLabel.position = CGPoint(x: -520, y: -24)
        desc.addChild(itemNoteLabel)
        content.addChild(desc)

        content.addChild(coinDisplay(at: Metrics.midCoinsOrigin))
    }

    private func buildBagPanel() {
        let bag = SKNode()
        bag.position = Metrics.bagOrigin
        bag.zPosition = 1
        addChromeSprite(named: "inventory_section_bag_v06", size: Metrics.bagSize, z: -1, parent: bag)
        let bagTitle = Self.label(size: 14, color: Palette.paper, weight: .demibold)
        bagTitle.text = "CASE BAG"
        bagTitle.horizontalAlignmentMode = .left
        bagTitle.verticalAlignmentMode = .center
        bagTitle.position = CGPoint(x: -Metrics.bagSize.width / 2 + 22, y: 83)
        bagTitle.zPosition = 3
        bag.addChild(bagTitle)
        bagCountLabel.horizontalAlignmentMode = .right
        bagCountLabel.verticalAlignmentMode = .center
        bagCountLabel.position = CGPoint(x: Metrics.bagSize.width / 2 - 44, y: 68)
        bagCountLabel.zPosition = 3
        bag.addChild(bagCountLabel)

        if let bagTexture = GameArt.texture(named: "inventory_case_bag_v05") {
            bagTexture.filteringMode = .linear
            let bagArt = SKSpriteNode(texture: bagTexture, size: CGSize(width: 92, height: 92))
            bagArt.position = Metrics.bagArtOffset
            bagArt.zPosition = 1
            bag.addChild(bagArt)
        } else {
            assertionFailure("Missing inventory_case_bag_v05.png")
        }
        bagOccupiedLabel.position = CGPoint(x: Metrics.bagArtOffset.x, y: Metrics.bagArtOffset.y + 55)
        bagOccupiedLabel.zPosition = 2
        bag.addChild(bagOccupiedLabel)
        bagCapacityLabel.position = CGPoint(x: Metrics.bagArtOffset.x, y: Metrics.bagArtOffset.y - 60)
        bagCapacityLabel.zPosition = 2
        bag.addChild(bagCapacityLabel)

        bagSlotsRoot.zPosition = 2
        bag.addChild(bagSlotsRoot)
        rebuildBagSlots()
        content.addChild(bag)
    }

    private func rebuildBagSlots() {
        bagSlotsRoot.removeAllChildren()
        slotFramesByPresentationID = slotFramesByPresentationID.reduce(
            into: [String: [SKNode]]()
        ) { result, pair in
            let attached = pair.value.filter { $0.parent != nil }
            if !attached.isEmpty { result[pair.key] = attached }
        }
        let visibleItems = Array(items.prefix(Metrics.bagSlotCount))
        bagCountLabel.text = "\(visibleItems.count) / \(Metrics.bagSlotCount)"
        bagOccupiedLabel.text = "\(visibleItems.count) OCCUPIED"
        bagCapacityLabel.text = "\(Metrics.bagSlotCount) SLOTS"

        for index in 0..<Metrics.bagSlotCount {
            let position = CGPoint(
                x: Metrics.bagFirstSlotX + CGFloat(index) * Metrics.bagSlotPitch,
                y: Metrics.bagSlotY
            )
            if visibleItems.indices.contains(index) {
                bagSlotsRoot.addChild(itemSlot(
                    visibleItems[index],
                    size: Metrics.bagSlotSize,
                    at: position,
                    showQuantity: true
                ))
            } else {
                bagSlotsRoot.addChild(emptySlot(
                    size: Metrics.bagSlotSize,
                    at: position,
                    silhouette: "inventory_slot_silhouette_bag_v06",
                    silhouetteAlpha: 0.16
                ))
            }
        }
    }

    private func itemSlot(_ item: InventoryItem, size: CGFloat, at position: CGPoint, showQuantity: Bool) -> SKNode {
        let slot = slotBase(size: CGSize(width: size, height: size))
        slot.name = "inventory.item.\(item.id)"
        slot.position = position
        slot.zPosition = 2

        if let texture = GameArt.texture(named: item.artName) {
            texture.filteringMode = .linear
            let icon = SKSpriteNode(texture: texture, size: CGSize(width: size * 0.72, height: size * 0.72))
            icon.name = "inventory.item-art"
            icon.zPosition = 1
            slot.addChild(icon)
        } else {
            assertionFailure("Missing inventory item art: \(item.artName)")
        }

        if showQuantity, item.quantity > 1 {
            let count = Self.label(size: 12, color: Palette.paper, weight: .demibold)
            count.text = "\(item.quantity)"
            count.verticalAlignmentMode = .center
            count.horizontalAlignmentMode = .right
            count.position = CGPoint(x: size / 2 - 8, y: -size / 2 + 12)
            count.zPosition = 2
            slot.addChild(count)
        }

        if let texture = GameArt.texture(named: "inventory_selection_frame_v05") {
            texture.filteringMode = .linear
            let selection = SKSpriteNode(texture: texture, size: CGSize(width: size + 8, height: size + 8))
            selection.name = "inventory.selection-frame"
            selection.zPosition = 3
            selection.isHidden = true
            slot.addChild(selection)
        }

        slotFramesByPresentationID[item.id, default: []].append(slot)
        return slot
    }

    private func emptySlot(
        size: CGFloat,
        at position: CGPoint,
        silhouette: String,
        silhouetteAlpha: CGFloat = 0.45
    ) -> SKNode {
        let slot = slotBase(size: CGSize(width: size, height: size))
        slot.position = position
        slot.zPosition = 2
        if let texture = GameArt.texture(named: silhouette) ?? UIPaintedChrome.texture(named: silhouette) {
            let icon = SKSpriteNode(texture: texture, size: CGSize(width: size * 0.62, height: size * 0.62))
            icon.alpha = silhouetteAlpha
            icon.zPosition = 0
            slot.addChild(icon)
        }
        return slot
    }

    private func equipmentSlot(artName: String, name: String, at position: CGPoint) -> SKNode {
        let root = SKNode()
        root.name = name
        root.position = position
        root.zPosition = 2
        let slot = slotBase(size: Metrics.equipSlotSize)
        if let texture = GameArt.texture(named: artName) ?? UIPaintedChrome.texture(named: artName) {
            let icon = SKSpriteNode(texture: texture, size: CGSize(width: 52, height: 48))
            icon.alpha = 0.78
            slot.addChild(icon)
        }
        root.addChild(slot)
        return root
    }

    private func slotBase(size: CGSize) -> SKNode {
        let root = SKNode()
        let hit = SKSpriteNode(color: SKColor(white: 1, alpha: 0.001), size: size)
        hit.zPosition = -2
        root.addChild(hit)

        if let texture = GameArt.texture(named: "inventory_slot_frame_v05") {
            texture.filteringMode = .linear
            let art = SKSpriteNode(texture: texture, size: size)
            art.name = "inventory.slot-art"
            art.zPosition = -1
            root.addChild(art)
        } else {
            assertionFailure("Missing inventory_slot_frame_v05.png")
        }
        return root
    }

    private func coinDisplay(at position: CGPoint) -> SKNode {
        let root = SKNode()
        root.position = position
        root.zPosition = 2

        if let texture = GameArt.texture(named: "inventory_coin_stack_v05") {
            texture.filteringMode = .linear
            let coins = SKSpriteNode(texture: texture, size: CGSize(width: 88, height: 64))
            coins.position = CGPoint(x: -55, y: 4)
            root.addChild(coins)
        } else {
            assertionFailure("Missing inventory_coin_stack_v05.png")
        }

        coinValueLabel.text = CurrencyAmount(pence: walletPence).formatted
        coinValueLabel.verticalAlignmentMode = .center
        coinValueLabel.horizontalAlignmentMode = .left
        coinValueLabel.position = CGPoint(x: 8, y: 0)
        root.addChild(coinValueLabel)
        return root
    }

    private func statRow(badgeArt: String, value: String, caption: String, lines: [String], at position: CGPoint) -> SKNode {
        let root = SKNode()
        root.position = position
        root.zPosition = 2

        let badgeX: CGFloat = -Metrics.statsSize.width / 2 + 62
        if let texture = GameArt.texture(named: badgeArt) {
            texture.filteringMode = .linear
            let badge = SKSpriteNode(texture: texture, size: CGSize(width: Metrics.statBadgeSize, height: Metrics.statBadgeSize))
            badge.position = CGPoint(x: badgeX, y: 0)
            root.addChild(badge)
        } else {
            assertionFailure("Missing inventory stat badge: \(badgeArt)")
        }

        let valueLabel = Self.label(size: value.count > 3 ? 18 : 24, color: Palette.paper, weight: .demibold)
        valueLabel.text = value
        valueLabel.verticalAlignmentMode = .center
        valueLabel.position = CGPoint(x: badgeX, y: 1)
        valueLabel.zPosition = 2
        root.addChild(valueLabel)

        let captionLabel = Self.label(size: 11, color: Palette.quiet, weight: .demibold)
        captionLabel.text = caption
        captionLabel.position = CGPoint(x: badgeX, y: -Metrics.statBadgeSize / 2 - 14)
        root.addChild(captionLabel)

        let textX = badgeX + Metrics.statBadgeSize / 2 + 28
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

    private func addSlotSection(
        _ title: String,
        items: [InventoryItem?],
        emptySilhouette: String,
        to root: SKNode,
        headerY: CGFloat,
        slotY: CGFloat
    ) {
        let count = items.count
        let label = Self.label(size: 15, color: Palette.paper, weight: .demibold)
        label.text = title
        label.horizontalAlignmentMode = .left
        label.verticalAlignmentMode = .center
        label.position = CGPoint(x: Metrics.loadoutSlotLeft, y: headerY)
        label.zPosition = 3
        root.addChild(label)

        // Shared left edge for every loadout row (4-slot and 3-slot rows align).
        for index in 0..<count {
            let position = CGPoint(
                x: Metrics.loadoutSlotLeft + CGFloat(index) * Metrics.loadoutSlotPitch,
                y: slotY
            )
            if let item = items[index] {
                root.addChild(itemSlot(item, size: Metrics.loadoutSlotSize, at: position, showQuantity: true))
            } else {
                root.addChild(emptySlot(
                    size: Metrics.loadoutSlotSize,
                    at: position,
                    silhouette: emptySilhouette
                ))
            }
        }
    }

    private func addGridHeader(
        _ title: String,
        counter: String,
        to root: SKNode,
        width: CGFloat,
        y: CGFloat = 72
    ) {
        let titleLabel = Self.label(size: 14, color: Palette.paper, weight: .demibold)
        titleLabel.text = title
        titleLabel.horizontalAlignmentMode = .left
        titleLabel.verticalAlignmentMode = .center
        titleLabel.position = CGPoint(x: -width / 2 + 12, y: y)
        titleLabel.zPosition = 3
        root.addChild(titleLabel)

        let countLabel = Self.label(size: 14, color: Palette.quiet, weight: .demibold)
        countLabel.text = counter
        countLabel.horizontalAlignmentMode = .right
        countLabel.verticalAlignmentMode = .center
        countLabel.position = CGPoint(x: width / 2 - 12, y: y)
        countLabel.zPosition = 3
        root.addChild(countLabel)
    }

    @discardableResult
    private func addChromeSprite(
        named name: String,
        size: CGSize,
        at position: CGPoint = .zero,
        z: CGFloat,
        parent: SKNode
    ) -> Bool {
        guard let texture = GameArt.texture(named: name) else {
            assertionFailure("Missing \(name).png")
            return false
        }
        texture.filteringMode = .linear
        let sprite = SKSpriteNode(texture: texture, size: size)
        sprite.name = "inventory.chrome.\(name)"
        sprite.position = position
        sprite.zPosition = z
        parent.addChild(sprite)
        return true
    }

    private func item(id: String) -> InventoryItem? {
        items.first { $0.id == id }
    }

    private func refreshSelection() {
        guard let item = items.first(where: { $0.id == selectedPresentationID }) else { return }
        itemCategoryLabel.text = item.category.rawValue
        itemNameLabel.text = item.name
        itemDescriptionLabel.text = item.description
        itemNoteLabel.text = item.note

        for (presentationID, slots) in slotFramesByPresentationID {
            let selected = presentationID == selectedPresentationID
            for slot in slots {
                if let frame = slot.childNode(withName: "inventory.selection-frame") {
                    frame.isHidden = !selected
                }
            }
        }
    }

    private func targetName(at point: CGPoint) -> String? {
        for hit in nodes(at: point) {
            var candidate: SKNode? = hit
            while let node = candidate, node !== self {
                if let name = node.name,
                   name == "inventory.close" || name.hasPrefix("inventory.item.") {
                    return name
                }
                candidate = node.parent
            }
        }
        return nil
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
