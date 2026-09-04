import SpriteKit

/// The full-screen inventory window: a noir Mac OS 9 sheet over a darkened world.
///
/// Interaction is the Infinity Engine's, not the web's. A click lifts an item onto
/// the cursor; a second click puts it down. There is no drag — BG never had one,
/// and the loot strip beside this window is already click-only, so one idiom
/// covers both surfaces.
///
/// Geometry lives in `InventoryScreenLayout` (RainShadowCore) so it can be tested;
/// this file owns nodes, hit-testing, and ephemeral tints, and nothing else.
@MainActor
final class InventoryOverlay: SKNode {

    // MARK: - Held item

    /// Where a lifted stack came from, so it can be put back if the player
    /// changes their mind or the destination refuses it.
    enum HeldOrigin: Equatable {
        case bag(index: Int)
        case equipped(EquipmentSlot)
    }

    private struct HeldItem: Equatable {
        let stack: CarriedItemStack
        let origin: HeldOrigin
        let item: InventoryItem
    }

    // MARK: - Callbacks

    var onDismiss: (() -> Void)?
    /// Each returns the engine's refusal, or `nil` on success. The scene performs
    /// the mutation against `GameSession` and pushes fresh state back in.
    var onEquipCarriedItem: ((Int, EquipmentSlot) -> InventoryRefusal?)?
    var onUnequipItem: ((EquipmentSlot) -> InventoryRefusal?)?
    var onMoveEquippedItem: ((EquipmentSlot, EquipmentSlot) -> InventoryRefusal?)?
    var onMoveCarriedStack: ((Int, Int) -> Bool)?
    var onSplitCarriedStack: ((Int, Int) -> Bool)?
    var onIdentifyCarriedItem: ((Int) -> Bool)?
    /// Drop a carried stack on the floor. Returns the dropped stack's display
    /// name, or `nil` when the item refused to be put down.
    var onDropCarriedItem: ((Int) -> String?)?

    // MARK: - Palette

    private enum Palette {
        static let paper = SKColor(red: 0.88, green: 0.86, blue: 0.81, alpha: 1)
        static let quiet = SKColor(red: 0.62, green: 0.60, blue: 0.57, alpha: 1)
        static let amber = SKColor(red: 0.78, green: 0.62, blue: 0.32, alpha: 1)
        static let oxblood = SKColor(red: 0.62, green: 0.20, blue: 0.19, alpha: 1)
        /// The blue wash BG puts over an unidentified icon.
        static let unidentified = SKColor(red: 0.36, green: 0.52, blue: 0.78, alpha: 1)
    }

    // MARK: - State

    private var catalog: ItemCatalog = HarborpointItems.catalog
    private var inventory = CharacterInventory()
    private var walletPence = CurrencyAmount.startingWalletPence
    private var currentHealth = 0
    private var maximumHealth = 0
    private var held: HeldItem?
    private var selectedPresentationID: String?

    private var carriedItems: [InventoryItem] = []

    // MARK: - Nodes

    private let sheet = SKNode()
    private let content = SKNode()
    private let paperdollSlotsRoot = SKNode()
    private let loadoutSlotsRoot = SKNode()
    private let bagSlotsRoot = SKNode()
    private let heldItemRoot = SKNode()
    private let heldItemIcon = SKSpriteNode()

    private let itemNameLabel = InventoryOverlay.label(size: 20, color: Palette.paper, weight: .demibold)
    private let itemCategoryLabel = InventoryOverlay.label(size: 13, color: Palette.amber, weight: .demibold)
    private let itemDescriptionLabel = InventoryOverlay.label(size: 15, color: Palette.paper, weight: .regular)
    private let itemNoteLabel = InventoryOverlay.label(size: 13, color: Palette.quiet, weight: .regular)
    private let coinValueLabel = InventoryOverlay.label(size: 16, color: Palette.paper, weight: .demibold)
    private let weightLabel = InventoryOverlay.label(size: 14, color: Palette.quiet, weight: .demibold)
    private let bagCountLabel = InventoryOverlay.label(size: 14, color: Palette.quiet, weight: .demibold)
    private let bagOccupiedLabel = InventoryOverlay.label(size: 12, color: Palette.amber, weight: .demibold)
    private let bagCapacityLabel = InventoryOverlay.label(size: 11, color: Palette.quiet, weight: .demibold)
    private let feedbackLabel = InventoryOverlay.label(size: 15, color: Palette.oxblood, weight: .demibold)

    private var statValueLabels: [StatRow: SKLabelNode] = [:]
    private var statLineLabels: [StatRow: [SKLabelNode]] = [:]

    private enum StatRow: Int, CaseIterable {
        case defence, vitality, resolve, damage

        var badgeArt: String {
            switch self {
            case .defence: "inventory_stat_badge_defence_v05"
            case .vitality: "inventory_stat_badge_vitality_v05"
            case .resolve: "inventory_stat_badge_resolve_v05"
            case .damage: "inventory_stat_badge_damage_v05"
            }
        }

        var caption: String {
            switch self {
            case .defence: "DEFENCE"
            case .vitality: "VITALITY"
            case .resolve: "RESOLVE"
            case .damage: "DAMAGE"
            }
        }
    }

    // MARK: - Life cycle

    override init() {
        super.init()
        name = "inventory.overlay"
        isUserInteractionEnabled = false
        AreaLoadTrace.measure("init.InventoryOverlay") { buildInterface() }
        isHidden = true
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("InventoryOverlay is created programmatically")
    }

    func layout(for visibleSize: CGSize) {
        setScale(InventoryScreenLayout.scale(for: visibleSize))
    }

    func present(
        walletPence: Int,
        inventory: CharacterInventory,
        catalog: ItemCatalog,
        currentHealth: Int,
        maximumHealth: Int
    ) {
        applyInventory(
            walletPence: walletPence,
            inventory: inventory,
            catalog: catalog,
            currentHealth: currentHealth,
            maximumHealth: maximumHealth
        )
        removeAllActions()
        isHidden = false
        alpha = 0
        sheet.position.y = -12
        sheet.run(.moveTo(y: 0, duration: 0.22))
        run(.fadeIn(withDuration: 0.18))
    }

    func hideAnimated() {
        // A lifted item goes back where it came from; the engine never leaves one
        // on a cursor that is about to disappear.
        returnHeldItem()
        removeAllActions()
        run(.sequence([
            .fadeOut(withDuration: 0.14),
            .run { [weak self] in
                self?.isHidden = true
            }
        ]))
    }

    func applyInventory(
        walletPence pence: Int,
        inventory: CharacterInventory,
        catalog: ItemCatalog,
        currentHealth: Int,
        maximumHealth: Int
    ) {
        self.catalog = catalog
        self.inventory = inventory
        self.walletPence = max(0, pence)
        self.currentHealth = currentHealth
        self.maximumHealth = maximumHealth
        carriedItems = InventoryItemPresentation.carriedItems(
            inventory.backpack.stacks,
            catalog: catalog
        )
        if let selected = selectedPresentationID,
           !carriedItems.contains(where: { $0.id == selected }) {
            selectedPresentationID = nil
        }
        coinValueLabel.text = CurrencyAmount(pence: self.walletPence).formatted
        rebuildBagSlots()
        rebuildEquippedSlots()
        refreshCounters()
        refreshStats()
        refreshSelection()
    }

    // MARK: - Pointer

    /// `true` when the window consumed the click. The window is modal, so that is
    /// almost always — but a click on the veil now returns a held item rather than
    /// being silently swallowed.
    @discardableResult
    func handlePointer(at point: CGPoint, splitModifier: Bool = false) -> Bool {
        guard !isHidden else { return false }

        guard let target = target(at: point) else {
            // Outside every slot. BG drops what is on the cursor when you release
            // it away from the panel; a case-critical item refuses and comes back.
            dropHeldItemOnTheFloor()
            return true
        }

        switch target {
        case .close:
            returnHeldItem()
            onDismiss?()
        case .bag(let index):
            handleBagClick(index: index, splitModifier: splitModifier)
        case .equipment(let slot):
            handleEquipmentClick(slot: slot)
        }
        return true
    }

    /// Right-click. BG uses it to attempt identification against Lore.
    @discardableResult
    func handleSecondaryPointer(at point: CGPoint) -> Bool {
        guard !isHidden, held == nil else { return false }
        guard case .bag(let index)? = target(at: point) else { return false }
        guard inventory.backpack.stack(at: index) != nil else { return false }

        if onIdentifyCarriedItem?(index) == true {
            showFeedback("Identified.", tone: Palette.amber)
        } else {
            showFeedback("Nothing more comes to mind.", tone: Palette.quiet)
        }
        return true
    }

    /// Moves the held item's icon with the cursor.
    func updateHover(at point: CGPoint) {
        guard !isHidden, held != nil else { return }
        heldItemRoot.position = convert(point, to: content)
    }

    func moveSelection(_ direction: Int) {
        guard !carriedItems.isEmpty else { return }
        let current = carriedItems.firstIndex { $0.id == selectedPresentationID } ?? 0
        let next = (current + direction + carriedItems.count) % carriedItems.count
        selectedPresentationID = carriedItems[next].id
        refreshSelection()
    }

    func isInteractive(at point: CGPoint) -> Bool {
        target(at: point) != nil
    }

    /// Whether a lifted item is riding the cursor — the scene uses this to keep
    /// the pointer updating.
    var isHoldingItem: Bool { held != nil }

    // MARK: - Click handling

    private func handleBagClick(index: Int, splitModifier: Bool) {
        if let held {
            place(held, intoBagAt: index)
            return
        }
        guard let stack = inventory.backpack.stack(at: index) else { return }

        if splitModifier, stack.quantity > 1 {
            // BG splits a stack in half on a modified click; the halves land in
            // adjacent slots and either can then be lifted.
            if onSplitCarriedStack?(index, stack.quantity / 2) == true {
                showFeedback("Split.", tone: Palette.quiet)
            } else {
                showFeedback("That stack will not divide.", tone: Palette.oxblood)
            }
            return
        }

        selectedPresentationID = carriedItems.indices.contains(index)
            ? carriedItems[index].id
            : nil
        refreshSelection()
        lift(stack, from: .bag(index: index))
    }

    private func handleEquipmentClick(slot: EquipmentSlot) {
        if let held {
            place(held, intoEquipment: slot)
            return
        }
        guard let stack = inventory.item(in: slot) else { return }
        selectedPresentationID = InventoryItemPresentation.presentationID(
            authoredID: stack.id,
            slot: slot
        )
        refreshSelection()
        lift(stack, from: .equipped(slot))
    }

    private func lift(_ stack: CarriedItemStack, from origin: HeldOrigin) {
        guard let item = InventoryItemPresentation.item(
            for: stack,
            catalog: catalog,
            presentationID: "held.\(stack.id)"
        ) else { return }
        held = HeldItem(stack: stack, origin: origin, item: item)
        showHeldIcon(item)
        describe(item)
        rebuildBagSlots()
        rebuildEquippedSlots()
    }

    private func place(_ heldItem: HeldItem, intoEquipment slot: EquipmentSlot) {
        let refusal: InventoryRefusal?
        switch heldItem.origin {
        case .bag(let index):
            refusal = onEquipCarriedItem?(index, slot)
        case .equipped(let source):
            refusal = source == slot ? nil : onMoveEquippedItem?(source, slot)
        }
        finishPlacement(refusal: refusal)
    }

    private func place(_ heldItem: HeldItem, intoBagAt index: Int) {
        let refusal: InventoryRefusal?
        switch heldItem.origin {
        case .equipped(let slot):
            refusal = onUnequipItem?(slot)
        case .bag(let source):
            // Reordering inside the bag. A move onto itself is a put-down.
            if source != index {
                _ = onMoveCarriedStack?(source, index)
            }
            refusal = nil
        }
        finishPlacement(refusal: refusal)
    }

    private func finishPlacement(refusal: InventoryRefusal?) {
        if let refusal {
            showFeedback(refusal.description, tone: Palette.oxblood)
        }
        // Either way the cursor is empty again: on success the item landed, and on
        // a refusal nothing moved, so it is still where it was lifted from.
        clearHeldItem()
    }

    /// BG's drop: the held stack leaves the bag and lands at Voss's feet. Only a
    /// carried stack can go straight to the floor — something worn has to come off
    /// first, which is what putting it back in the bag is for.
    private func dropHeldItemOnTheFloor() {
        guard let held else { return }
        guard case .bag(let index) = held.origin else {
            showFeedback("Take it off first.", tone: Palette.quiet)
            clearHeldItem()
            return
        }
        if let name = onDropCarriedItem?(index) {
            showFeedback("Dropped \(name).", tone: Palette.quiet)
        } else {
            showFeedback("That stays with him.", tone: Palette.oxblood)
        }
        clearHeldItem()
    }

    private func returnHeldItem() {
        guard held != nil else { return }
        clearHeldItem()
    }

    private func clearHeldItem() {
        held = nil
        heldItemRoot.isHidden = true
        rebuildBagSlots()
        rebuildEquippedSlots()
        refreshSelection()
    }

    private func showHeldIcon(_ item: InventoryItem) {
        guard let texture = GameArt.texture(named: item.artName) else {
            assertionFailure("Missing inventory item art: \(item.artName)")
            return
        }
        texture.filteringMode = .linear
        heldItemIcon.texture = texture
        heldItemIcon.size = CGSize(width: 56, height: 56)
        heldItemRoot.isHidden = false
    }

    // MARK: - Hit testing

    private enum Target: Equatable {
        case close
        case bag(index: Int)
        case equipment(EquipmentSlot)
    }

    private func target(at point: CGPoint) -> Target? {
        for hit in nodes(at: point) {
            var candidate: SKNode? = hit
            while let node = candidate, node !== self {
                if let name = node.name {
                    if name == "inventory.close" { return .close }
                    if name.hasPrefix("inventory.bag."),
                       let index = Int(name.dropFirst("inventory.bag.".count)) {
                        return .bag(index: index)
                    }
                    if name.hasPrefix("inventory.equip."),
                       let slot = EquipmentSlot(
                           rawValue: String(name.dropFirst("inventory.equip.".count))
                       ) {
                        return .equipment(slot)
                    }
                }
                candidate = node.parent
            }
        }
        return nil
    }

    // MARK: - Building

    private func buildInterface() {
        let veil = SKShapeNode(rectOf: CGSize(width: 3_000, height: 1_600))
        veil.fillColor = SKColor(white: 0.005, alpha: 0.83)
        veil.strokeColor = .clear
        veil.zPosition = -20
        addChild(veil)

        addChromeSprite(
            named: "inventory_outer_frame_v16",
            size: InventoryScreenLayout.canvas,
            z: -8,
            parent: sheet
        )

        sheet.addChild(content)
        content.zPosition = 0

        let title = Self.label(size: 36, color: Palette.paper, weight: .display)
        title.text = "INVENTORY"
        title.verticalAlignmentMode = .center
        title.position = CGPoint(x: 0, y: InventoryScreenLayout.titleY)
        title.zPosition = 20
        content.addChild(title)

        let band = InventoryScreenLayout.identityBand
        let detectiveName = Self.label(size: 20, color: Palette.paper, weight: .demibold)
        detectiveName.text = "HARLAN VOSS"
        detectiveName.horizontalAlignmentMode = .right
        detectiveName.position = CGPoint(x: band.x - 18, y: band.y)
        detectiveName.zPosition = 20
        content.addChild(detectiveName)

        let divider = Self.label(size: 18, color: Palette.quiet, weight: .demibold)
        divider.text = "·"
        divider.horizontalAlignmentMode = .center
        divider.position = band
        divider.zPosition = 20
        content.addChild(divider)

        let profession = Self.label(size: 18, color: Palette.paper, weight: .demibold)
        profession.text = "PRIVATE INVESTIGATOR"
        profession.horizontalAlignmentMode = .left
        profession.position = CGPoint(x: band.x + 18, y: band.y)
        profession.zPosition = 20
        content.addChild(profession)

        buildCloseButton()
        buildLoadoutPanel()
        buildPaperdollPanel()
        buildStatsPanel()
        buildMidStrip()
        buildBagPanel()
        buildHeldItemCursor()
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
            artworkSize: InventoryScreenLayout.closeArtworkSize
        )
        button.position = InventoryScreenLayout.closeButton
        button.zPosition = 30
        content.addChild(button)
    }

    private func buildHeldItemCursor() {
        heldItemRoot.zPosition = 60
        heldItemRoot.isHidden = true
        heldItemIcon.zPosition = 1
        heldItemIcon.alpha = 0.92
        heldItemRoot.addChild(heldItemIcon)
        content.addChild(heldItemRoot)
    }

    private func buildLoadoutPanel() {
        let root = SKNode()
        root.position = InventoryScreenLayout.loadoutOrigin
        root.zPosition = 1

        addChromeSprite(
            named: "inventory_section_loadout_v05",
            size: InventoryScreenLayout.loadoutSize,
            z: -1,
            parent: root
        )

        for row in InventoryScreenLayout.LoadoutRow.allCases {
            let label = Self.label(size: 15, color: Palette.paper, weight: .demibold)
            label.text = row.title
            label.horizontalAlignmentMode = .left
            label.verticalAlignmentMode = .center
            label.position = CGPoint(x: InventoryScreenLayout.loadoutSlotLeft, y: row.headerY)
            label.zPosition = 3
            root.addChild(label)
        }

        loadoutSlotsRoot.zPosition = 2
        root.addChild(loadoutSlotsRoot)
        content.addChild(root)
    }

    private func buildPaperdollPanel() {
        let root = SKNode()
        root.position = InventoryScreenLayout.paperdollOrigin
        root.zPosition = 1

        addChromeSprite(
            named: "inventory_section_paperdoll_v05",
            size: InventoryScreenLayout.paperdollSize,
            z: -1,
            parent: root
        )

        if let detectiveTexture = GameArt.texture(named: "voss_paperdoll_front_rgba_v01") {
            detectiveTexture.filteringMode = .nearest
            let paperdoll = SKSpriteNode(
                texture: detectiveTexture,
                size: InventoryScreenLayout.paperdollBodySize
            )
            paperdoll.name = "inventory.paperdoll"
            paperdoll.position = InventoryScreenLayout.chamberOffset
            paperdoll.zPosition = 0
            root.addChild(paperdoll)
        } else {
            assertionFailure("Missing voss_paperdoll_front_rgba_v01.png")
        }

        paperdollSlotsRoot.zPosition = 2
        root.addChild(paperdollSlotsRoot)
        content.addChild(root)
    }

    private func buildStatsPanel() {
        let root = SKNode()
        root.position = InventoryScreenLayout.statsOrigin
        root.zPosition = 1

        addChromeSprite(
            named: "inventory_section_stats_v05",
            size: InventoryScreenLayout.statsSize,
            z: -1,
            parent: root
        )

        for row in StatRow.allCases {
            root.addChild(buildStatRow(
                row,
                at: CGPoint(x: 0, y: InventoryScreenLayout.statRowY(index: row.rawValue))
            ))
        }
        content.addChild(root)
    }

    private func buildStatRow(_ row: StatRow, at position: CGPoint) -> SKNode {
        let root = SKNode()
        root.position = position
        root.zPosition = 2

        let badgeX = InventoryScreenLayout.statBadgeX
        let badgeSize = InventoryScreenLayout.statBadgeSize
        if let texture = GameArt.texture(named: row.badgeArt) {
            texture.filteringMode = .linear
            let badge = SKSpriteNode(
                texture: texture,
                size: CGSize(width: badgeSize, height: badgeSize)
            )
            badge.position = CGPoint(x: badgeX, y: 0)
            root.addChild(badge)
        } else {
            assertionFailure("Missing inventory stat badge: \(row.badgeArt)")
        }

        let valueLabel = Self.label(size: 24, color: Palette.paper, weight: .demibold)
        valueLabel.verticalAlignmentMode = .center
        valueLabel.position = CGPoint(x: badgeX, y: 1)
        valueLabel.zPosition = 2
        root.addChild(valueLabel)
        statValueLabels[row] = valueLabel

        let captionLabel = Self.label(size: 11, color: Palette.quiet, weight: .demibold)
        captionLabel.text = row.caption
        captionLabel.position = CGPoint(x: badgeX, y: -badgeSize / 2 - 14)
        root.addChild(captionLabel)

        let textX = badgeX + badgeSize / 2 + 28
        var lines: [SKLabelNode] = []
        for index in 0..<2 {
            let label = Self.label(
                size: index == 0 ? 16 : 14,
                color: index == 0 ? Palette.paper : Palette.quiet,
                weight: index == 0 ? .demibold : .regular
            )
            label.horizontalAlignmentMode = .left
            label.verticalAlignmentMode = .center
            label.preferredMaxLayoutWidth = InventoryScreenLayout.statTextWidth - 28
            label.numberOfLines = 2
            label.position = CGPoint(x: textX + 14, y: index == 0 ? 14 : -12)
            root.addChild(label)
            lines.append(label)
        }
        statLineLabels[row] = lines
        return root
    }

    private func buildMidStrip() {
        addChromeSprite(
            named: "inventory_section_mid_v05",
            size: InventoryScreenLayout.midSize,
            at: CGPoint(x: 0, y: InventoryScreenLayout.midStripY),
            z: 0,
            parent: content
        )

        let paused = Self.label(size: 16, color: Palette.quiet, weight: .demibold)
        paused.text = "CASEWORK PAUSED"
        paused.horizontalAlignmentMode = .left
        paused.verticalAlignmentMode = .center
        paused.position = InventoryScreenLayout.midPausedOrigin
        paused.zPosition = 2
        content.addChild(paused)

        let desc = SKNode()
        desc.position = InventoryScreenLayout.midDescOrigin
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

        weightLabel.horizontalAlignmentMode = .right
        weightLabel.verticalAlignmentMode = .center
        weightLabel.position = InventoryScreenLayout.midWeightOrigin
        weightLabel.zPosition = 2
        content.addChild(weightLabel)

        content.addChild(coinDisplay(at: InventoryScreenLayout.midCoinsOrigin))

        feedbackLabel.horizontalAlignmentMode = .center
        feedbackLabel.verticalAlignmentMode = .center
        feedbackLabel.position = CGPoint(x: 0, y: InventoryScreenLayout.midStripY - 62)
        feedbackLabel.zPosition = 40
        feedbackLabel.alpha = 0
        content.addChild(feedbackLabel)
    }

    private func buildBagPanel() {
        let bag = SKNode()
        bag.position = InventoryScreenLayout.bagOrigin
        bag.zPosition = 1
        addChromeSprite(
            named: "inventory_section_bag_v06",
            size: InventoryScreenLayout.bagSize,
            z: -1,
            parent: bag
        )

        let bagTitle = Self.label(size: 14, color: Palette.paper, weight: .demibold)
        bagTitle.text = "CASE BAG"
        bagTitle.horizontalAlignmentMode = .left
        bagTitle.verticalAlignmentMode = .center
        bagTitle.position = CGPoint(x: -InventoryScreenLayout.bagSize.width / 2 + 22, y: 83)
        bagTitle.zPosition = 3
        bag.addChild(bagTitle)

        bagCountLabel.horizontalAlignmentMode = .right
        bagCountLabel.verticalAlignmentMode = .center
        bagCountLabel.position = CGPoint(x: InventoryScreenLayout.bagSize.width / 2 - 44, y: 68)
        bagCountLabel.zPosition = 3
        bag.addChild(bagCountLabel)

        if let bagTexture = GameArt.texture(named: "inventory_case_bag_v05") {
            bagTexture.filteringMode = .linear
            let bagArt = SKSpriteNode(texture: bagTexture, size: CGSize(width: 92, height: 92))
            bagArt.position = InventoryScreenLayout.bagArtOffset
            bagArt.zPosition = 1
            bag.addChild(bagArt)
        } else {
            assertionFailure("Missing inventory_case_bag_v05.png")
        }

        let bagArtOffset = InventoryScreenLayout.bagArtOffset
        bagOccupiedLabel.position = CGPoint(x: bagArtOffset.x, y: bagArtOffset.y + 55)
        bagOccupiedLabel.zPosition = 2
        bag.addChild(bagOccupiedLabel)
        bagCapacityLabel.position = CGPoint(x: bagArtOffset.x, y: bagArtOffset.y - 60)
        bagCapacityLabel.zPosition = 2
        bag.addChild(bagCapacityLabel)

        bagSlotsRoot.zPosition = 2
        bag.addChild(bagSlotsRoot)
        content.addChild(bag)
    }

    // MARK: - Slot rebuilding

    private func rebuildBagSlots() {
        bagSlotsRoot.removeAllChildren()
        for index in 0..<InventoryScreenLayout.bagSlotCount {
            let position = InventoryScreenLayout.bagSlotPosition(index: index)
            let size = InventoryScreenLayout.bagSlotSize
            let node: SKNode
            if let item = visibleBagItem(at: index) {
                node = itemSlot(item, size: CGSize(width: size, height: size))
            } else {
                node = emptySlot(
                    size: CGSize(width: size, height: size),
                    silhouette: "inventory_slot_silhouette_bag_v06",
                    silhouetteAlpha: 0.16
                )
            }
            node.name = "inventory.bag.\(index)"
            node.position = position
            node.zPosition = 2
            bagSlotsRoot.addChild(node)
        }
    }

    /// The lifted stack leaves a hole where it was, the way BG empties the slot an
    /// item was picked up from.
    private func visibleBagItem(at index: Int) -> InventoryItem? {
        if case .bag(let heldIndex)? = held?.origin, heldIndex == index { return nil }
        guard carriedItems.indices.contains(index) else { return nil }
        return carriedItems[index]
    }

    private func rebuildEquippedSlots() {
        paperdollSlotsRoot.removeAllChildren()
        loadoutSlotsRoot.removeAllChildren()

        for slot in EquipmentSlot.paperdollSlots {
            guard let position = InventoryScreenLayout.paperdollSlotPosition(slot) else { continue }
            let node = equipmentSlotNode(slot, size: InventoryScreenLayout.equipSlotSize)
            node.position = position
            paperdollSlotsRoot.addChild(node)
        }

        let loadoutSize = CGSize(
            width: InventoryScreenLayout.loadoutSlotSize,
            height: InventoryScreenLayout.loadoutSlotSize
        )
        for row in InventoryScreenLayout.LoadoutRow.allCases {
            for (index, slot) in row.slots.enumerated() {
                let node = equipmentSlotNode(slot, size: loadoutSize)
                node.position = InventoryScreenLayout.loadoutSlotPosition(row: row, index: index)
                loadoutSlotsRoot.addChild(node)
            }
        }
    }

    private func equipmentSlotNode(_ slot: EquipmentSlot, size: CGSize) -> SKNode {
        let root = SKNode()
        root.name = slot.nodeName
        root.zPosition = 2

        let lifted: Bool
        if case .equipped(let heldSlot)? = held?.origin, heldSlot == slot {
            lifted = true
        } else {
            lifted = false
        }

        if !lifted,
           let stack = inventory.item(in: slot),
           let item = InventoryItemPresentation.item(
               for: stack,
               catalog: catalog,
               presentationID: InventoryItemPresentation.presentationID(
                   authoredID: stack.id,
                   slot: slot
               )
           ) {
            root.addChild(itemSlot(item, size: size))
        } else {
            root.addChild(emptySlot(
                size: size,
                silhouette: InventoryScreenLayout.emptySilhouetteArtName(for: slot),
                silhouetteAlpha: 0.78
            ))
        }

        // While an item is on the cursor, every slot that would take it reads as a
        // live target. BG lights the legal destinations rather than making you guess.
        if let held, !lifted,
           inventory.canEquip(held.stack, in: slot, catalog: catalog) {
            let glow = SKSpriteNode(
                color: Palette.amber.withAlphaComponent(0.16),
                size: CGSize(width: size.width + 6, height: size.height + 6)
            )
            glow.zPosition = 4
            root.addChild(glow)
        }
        return root
    }

    // MARK: - Slot nodes

    private func itemSlot(_ item: InventoryItem, size: CGSize) -> SKNode {
        let slot = slotBase(size: size)
        let iconSize = CGSize(width: size.width * 0.72, height: size.height * 0.72)

        if let texture = GameArt.texture(named: item.artName) {
            texture.filteringMode = .linear
            let icon = SKSpriteNode(texture: texture, size: iconSize)
            icon.name = "inventory.item-art"
            icon.zPosition = 1
            slot.addChild(icon)

            // BG washes an unidentified icon blue until its name is known.
            if !item.isIdentified {
                let wash = SKSpriteNode(texture: texture, size: iconSize)
                wash.color = Palette.unidentified
                wash.colorBlendFactor = 0.72
                wash.alpha = 0.55
                wash.zPosition = 2
                slot.addChild(wash)
            }
        } else {
            assertionFailure("Missing inventory item art: \(item.artName)")
        }

        if item.quantity > 1 {
            let count = Self.label(size: 12, color: Palette.paper, weight: .demibold)
            count.text = "\(item.quantity)"
            count.verticalAlignmentMode = .center
            count.horizontalAlignmentMode = .right
            count.position = CGPoint(x: size.width / 2 - 8, y: -size.height / 2 + 12)
            count.zPosition = 3
            slot.addChild(count)
        }

        if let texture = GameArt.texture(named: "inventory_selection_frame_v05") {
            texture.filteringMode = .linear
            let selection = SKSpriteNode(
                texture: texture,
                size: CGSize(width: size.width + 8, height: size.height + 8)
            )
            selection.name = "inventory.selection-frame"
            selection.zPosition = 5
            selection.isHidden = item.id != selectedPresentationID
            slot.addChild(selection)
        }
        return slot
    }

    private func emptySlot(
        size: CGSize,
        silhouette: String,
        silhouetteAlpha: CGFloat
    ) -> SKNode {
        let slot = slotBase(size: size)
        if let texture = GameArt.texture(named: silhouette)
            ?? UIPaintedChrome.texture(named: silhouette) {
            let icon = SKSpriteNode(
                texture: texture,
                size: CGSize(width: size.width * 0.62, height: size.height * 0.62)
            )
            icon.alpha = silhouetteAlpha
            icon.zPosition = 0
            slot.addChild(icon)
        }
        return slot
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

    // MARK: - Refresh

    private func refreshCounters() {
        let occupied = inventory.backpack.occupiedSlotCount
        let capacity = InventoryScreenLayout.bagSlotCount
        bagCountLabel.text = "\(occupied) / \(capacity)"
        bagOccupiedLabel.text = "\(occupied) OCCUPIED"
        bagCapacityLabel.text = "\(capacity) SLOTS"

        let readout = inventory.encumbrance(catalog: catalog)
        weightLabel.text = readout.formatted
        // Amber warns before any penalty lands; oxblood means the engine has
        // actually stopped him. BG's yellow is a warning and nothing more.
        switch readout.band {
        case .unencumbered:
            weightLabel.fontColor = readout.isWarning ? Palette.amber : Palette.quiet
        case .overloaded:
            weightLabel.fontColor = Palette.amber
        case .immobile:
            weightLabel.fontColor = Palette.oxblood
        }
    }

    private func refreshStats() {
        let defence = inventory.defenceBonus(catalog: catalog)
        setStat(
            .defence,
            value: "\(defence)",
            lines: [
                "Defence: \(defence)",
                defence > 0
                    ? "Worn gear turns glancing blows."
                    : "Nothing worn but the clothes he stands in."
            ]
        )

        setStat(
            .vitality,
            value: "\(currentHealth)/\(maximumHealth)",
            lines: [
                "Vitality: \(currentHealth) / \(maximumHealth)",
                currentHealth >= maximumHealth
                    ? "Steady under night pressure."
                    : "Carrying an injury."
            ]
        )

        setStat(
            .resolve,
            value: "\(GameSession.detectiveLore)",
            lines: [
                "Resolve: \(GameSession.detectiveLore)",
                "What he recognises on sight."
            ]
        )

        if let weapon = inventory.readiedWeapon(catalog: catalog),
           let band = weapon.damageBand {
            setStat(
                .damage,
                value: band,
                lines: ["Damage: \(band)", "\(weapon.identifiedName) · readied"]
            )
        } else {
            setStat(.damage, value: "—", lines: ["Damage: —", "Nothing readied."])
        }
    }

    private func setStat(_ row: StatRow, value: String, lines: [String]) {
        if let label = statValueLabels[row] {
            label.text = value
            label.fontSize = value.count > 3 ? 18 : 24
        }
        guard let labels = statLineLabels[row] else { return }
        for (index, label) in labels.enumerated() {
            label.text = lines.indices.contains(index) ? lines[index] : ""
        }
    }

    private func refreshSelection() {
        if let held {
            describe(held.item)
            return
        }
        guard let selected = selectedPresentationID,
              let item = carriedItems.first(where: { $0.id == selected })
                ?? equippedItem(withPresentationID: selected) else {
            clearDescription()
            return
        }
        describe(item)
    }

    private func equippedItem(withPresentationID id: String) -> InventoryItem? {
        for slot in inventory.equippedSlots {
            guard let stack = inventory.item(in: slot) else { continue }
            let presentationID = InventoryItemPresentation.presentationID(
                authoredID: stack.id,
                slot: slot
            )
            guard presentationID == id else { continue }
            return InventoryItemPresentation.item(
                for: stack,
                catalog: catalog,
                presentationID: presentationID
            )
        }
        return nil
    }

    private func describe(_ item: InventoryItem) {
        itemCategoryLabel.text = item.categoryDisplayName
        itemNameLabel.text = item.name
        itemDescriptionLabel.text = item.description
        itemNoteLabel.text = item.note
    }

    private func clearDescription() {
        itemCategoryLabel.text = ""
        itemNameLabel.text = ""
        itemDescriptionLabel.text = ""
        itemNoteLabel.text = ""
    }

    private func showFeedback(_ message: String, tone: SKColor) {
        feedbackLabel.removeAllActions()
        feedbackLabel.text = message
        feedbackLabel.fontColor = tone
        feedbackLabel.alpha = 0
        feedbackLabel.run(.sequence([
            .fadeAlpha(to: 1, duration: 0.1),
            .wait(forDuration: 1.6),
            .fadeAlpha(to: 0, duration: 0.3)
        ]))
    }

    // MARK: - Helpers

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
