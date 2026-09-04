import SpriteKit

/// A stable reference back to the original stack index in the active container.
/// Keeping the index alongside the resolved stack prevents filtered/paged UI order
/// from accidentally taking a different stack.
struct LootContainerPanelEntry: Equatable, Hashable, Sendable {
    let sourceIndex: Int
    let stack: ResolvedLootStack
}

enum LootContainerPanelFeedback: Equatable, Hashable, Sendable {
    case coins(pence: Int)
    case item(id: String, quantity: Int)
    case batch(pence: Int, itemStackCount: Int, bagIsFull: Bool)
    case bagFull
}

@MainActor
final class LootContainerPanelNode: SKNode {
    enum Target: Equatable, Hashable {
        case takeAll
        case sourcePreviousPage
        case sourceNextPage
        case bagPreviousRow
        case bagNextRow
        case source(LootContainerPanelEntry)
        /// Index into `CarriedInventoryState.stacks`, not the combined preview.
        case carried(acquiredIndex: Int)
    }

    private struct SlotNodes {
        let root: SKNode
        let hit: SKSpriteNode
        let frame: SKSpriteNode
        let icon: SKSpriteNode
        let amount: SKLabelNode
    }

    private struct BagEntry: Equatable {
        let item: InventoryItem
        let acquiredIndex: Int?
    }

    var onTakeSourceStackAtIndex: ((Int) -> Void)?
    var onTakeAllLoot: (() -> Void)?
    var onReturnCarriedStackAtIndex: ((Int) -> Void)?

    private let panelPlate = SKSpriteNode()
    private let sourceProp = SKSpriteNode()
    private let takeAllRoot = SKNode()
    private let takeAllHit = LootContainerPanelNode.transparentHitNode()
    private let takeAllArt = SKSpriteNode()
    private let sourcePreviousRoot = SKNode()
    private let sourcePreviousHit = LootContainerPanelNode.transparentHitNode()
    private let sourcePreviousArt = SKSpriteNode()
    private let sourceNextRoot = SKNode()
    private let sourceNextHit = LootContainerPanelNode.transparentHitNode()
    private let sourceNextArt = SKSpriteNode()
    private let bagPreviousRoot = SKNode()
    private let bagPreviousHit = LootContainerPanelNode.transparentHitNode()
    private let bagPreviousArt = SKSpriteNode()
    private let bagNextRoot = SKNode()
    private let bagNextHit = LootContainerPanelNode.transparentHitNode()
    private let bagNextArt = SKSpriteNode()
    private let caseBagArt = SKSpriteNode()
    private let occupiedLabel = SKLabelNode(fontNamed: UITheme.Font.overlayCondensed)
    private let capacityLabel = SKLabelNode(fontNamed: UITheme.Font.overlayCondensed)
    private let walletCoinArt = SKSpriteNode()
    private let walletValueLabel = SKLabelNode(fontNamed: UITheme.Font.overlayCondensed)
    private let feedbackRoot = SKNode()
    private let feedbackShadow = SKLabelNode(fontNamed: UITheme.Font.overlayCondensed)
    private let feedbackLabel = SKLabelNode(fontNamed: UITheme.Font.overlayCondensed)
    private var sourceSlots: [SlotNodes] = []
    private var bagSlots: [SlotNodes] = []

    private var sourceArtName = ""
    private var entries: [LootContainerPanelEntry] = []
    private var walletPence = 0
    private var carriedInventory = CarriedInventoryState()
    private var catalog: ItemCatalog = HarborpointItems.catalog
    private var requestedSourceRow = 0
    private var requestedBagRow = 0
    private var hoveredTarget: Target?
    private var pressedTarget: Target?
    private var pressIsInside = false
    /// BG2 keeps an opened source available for reverse transfer after its last
    /// ordinary item moves into the carried bag. Coin-only empty sources retain
    /// the shorter receipt-and-fade behavior.
    private(set) var keepsEmptySourceOpenForReverseTransfer = false
    private var currentLayout = HUDChromeLayout.lootContainerPanelLayout(
        for: CGSize(width: 1_280, height: 800)
    )

    private var sourcePage: HUDChromeLayout.LootContainerPage {
        HUDChromeLayout.lootContainerPage(
            itemCount: entries.count,
            requestedPage: requestedSourceRow
        )
    }

    private var allBagEntries: [BagEntry] {
        InventoryItemPresentation.carriedItems(carriedInventory.stacks, catalog: catalog)
            .enumerated()
            .map { index, item in BagEntry(item: item, acquiredIndex: index) }
    }

    private var bagViewport: HUDChromeLayout.LootContainerBagViewport {
        HUDChromeLayout.lootContainerBagViewport(
            itemCount: allBagEntries.count,
            requestedRow: requestedBagRow
        )
    }

    var currentPageIndex: Int { sourcePage.pageIndex }
    var pageCount: Int { sourcePage.pageCount }
    var currentBagRowIndex: Int { bagViewport.rowIndex }

    override init() {
        super.init()
        name = "hud.loot-container-panel"
        zPosition = 50
        isHidden = true
        buildChrome()
        buildSlots()
        buildLabels()
        layout(for: CGSize(width: 1_280, height: 800))
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("LootContainerPanelNode is created programmatically")
    }

    func present(
        sourceArtName: String,
        entries: [LootContainerPanelEntry],
        walletPence: Int,
        carriedInventory: CarriedInventoryState
    ) {
        resetFeedbackActions()
        self.sourceArtName = sourceArtName
        self.entries = entries
        self.walletPence = max(0, walletPence)
        self.carriedInventory = carriedInventory
        requestedSourceRow = 0
        requestedBagRow = 0
        hoveredTarget = nil
        pressedTarget = nil
        pressIsInside = false
        keepsEmptySourceOpenForReverseTransfer = false
        alpha = 1
        isHidden = entries.isEmpty
        refreshContent()
    }

    /// Refreshes both real transfer sides while preserving and clamping each row.
    /// Final coin-only receipts fade after 0.6 seconds; an item-bearing session
    /// keeps its empty source open so the newly carried stack can move back.
    func refresh(
        entries: [LootContainerPanelEntry],
        walletPence: Int,
        carriedInventory: CarriedInventoryState,
        feedback: LootContainerPanelFeedback? = nil
    ) {
        resetFeedbackActions()
        self.entries = entries
        self.walletPence = max(0, walletPence)
        self.carriedInventory = carriedInventory
        if feedback?.transferredAnyItem == true {
            keepsEmptySourceOpenForReverseTransfer = true
        }
        requestedSourceRow = sourcePage.pageIndex
        requestedBagRow = bagViewport.rowIndex
        alpha = 1
        let showFinalFeedback = entries.isEmpty && feedback?.isSuccess == true
        let autoDismissFinalFeedback = showFinalFeedback
            && !keepsEmptySourceOpenForReverseTransfer
        isHidden = entries.isEmpty
            && !showFinalFeedback
            && !keepsEmptySourceOpenForReverseTransfer
        normalizeInteractionState()
        refreshContent()
        if let feedback {
            show(feedback: feedback, autoDismiss: autoDismissFinalFeedback)
        }
    }

    func dismiss() {
        resetFeedbackActions()
        entries = []
        requestedSourceRow = 0
        requestedBagRow = 0
        hoveredTarget = nil
        pressedTarget = nil
        pressIsInside = false
        keepsEmptySourceOpenForReverseTransfer = false
        isHidden = true
        alpha = 1
        refreshContent()
    }

    func layout(for visibleSize: CGSize) {
        currentLayout = HUDChromeLayout.lootContainerPanelLayout(for: visibleSize)
        panelPlate.position = currentLayout.panelRect.center
        panelPlate.size = currentLayout.panelRect.size

        layoutSourceProp()
        apply(
            root: takeAllRoot,
            hit: takeAllHit,
            art: takeAllArt,
            hitRect: currentLayout.takeAllHitRect,
            artRect: currentLayout.takeAllArtRect
        )
        apply(
            root: sourcePreviousRoot,
            hit: sourcePreviousHit,
            art: sourcePreviousArt,
            hitRect: currentLayout.sourcePreviousPageHitRect,
            artRect: currentLayout.sourcePreviousPageArtRect
        )
        apply(
            root: sourceNextRoot,
            hit: sourceNextHit,
            art: sourceNextArt,
            hitRect: currentLayout.sourceNextPageHitRect,
            artRect: currentLayout.sourceNextPageArtRect
        )
        apply(
            root: bagPreviousRoot,
            hit: bagPreviousHit,
            art: bagPreviousArt,
            hitRect: currentLayout.bagPreviousRowHitRect,
            artRect: currentLayout.bagPreviousRowArtRect
        )
        apply(
            root: bagNextRoot,
            hit: bagNextHit,
            art: bagNextArt,
            hitRect: currentLayout.bagNextRowHitRect,
            artRect: currentLayout.bagNextRowArtRect
        )
        layout(
            slots: sourceSlots,
            hitRects: currentLayout.sourceSlotHitRects,
            artRects: currentLayout.sourceSlotArtRects
        )
        layout(
            slots: bagSlots,
            hitRects: currentLayout.bagSlotHitRects,
            artRects: currentLayout.bagSlotArtRects
        )
        layoutAspectFit(caseBagArt, in: currentLayout.caseBagArtRect)
        layoutAspectFit(walletCoinArt, in: currentLayout.walletCoinArtRect)
        layout(occupiedLabel, in: currentLayout.carriedWeightRect, fontSize: 13)
        layout(capacityLabel, in: currentLayout.maximumWeightRect, fontSize: 11)
        layout(walletValueLabel, in: currentLayout.walletValueRect, fontSize: 16)
        feedbackRoot.position = currentLayout.carryRect.center
        let feedbackFont = max(11, min(15, currentLayout.carryRect.width * 0.12))
        feedbackShadow.fontSize = feedbackFont
        feedbackLabel.fontSize = feedbackFont
        refreshContent()
    }

    func hitTest(_ point: CGPoint) -> Target? {
        guard !isHidden else { return nil }
        if !entries.isEmpty, currentLayout.takeAllHitRect.contains(point) {
            return .takeAll
        }
        if sourcePage.canGoPrevious,
           currentLayout.sourcePreviousPageHitRect.contains(point) {
            return .sourcePreviousPage
        }
        if sourcePage.canGoNext,
           currentLayout.sourceNextPageHitRect.contains(point) {
            return .sourceNextPage
        }
        for (index, entry) in visibleSourceEntries.enumerated()
        where currentLayout.sourceSlotHitRects.indices.contains(index) {
            if currentLayout.sourceSlotHitRects[index].contains(point) {
                return .source(entry)
            }
        }
        if bagViewport.canGoPrevious,
           currentLayout.bagPreviousRowHitRect.contains(point) {
            return .bagPreviousRow
        }
        if bagViewport.canGoNext,
           currentLayout.bagNextRowHitRect.contains(point) {
            return .bagNextRow
        }
        for (index, entry) in visibleBagEntries.enumerated()
        where currentLayout.bagSlotHitRects.indices.contains(index) {
            if let acquiredIndex = entry.acquiredIndex,
               currentLayout.bagSlotHitRects[index].contains(point) {
                return .carried(acquiredIndex: acquiredIndex)
            }
        }
        return nil
    }

    func isInteractive(at point: CGPoint) -> Bool { hitTest(point) != nil }

    /// True anywhere on the visible painted plate, including blank chrome.
    func containsPanel(at point: CGPoint) -> Bool {
        !isHidden && currentLayout.panelRect.contains(point)
    }

    func setHoveredTarget(_ target: Target?) {
        hoveredTarget = normalizedTarget(target)
        updatePresentation()
    }

    @discardableResult
    func updateHover(at point: CGPoint) -> Target? {
        let target = hitTest(point)
        setHoveredTarget(target)
        return target
    }

    func beginPress(at point: CGPoint) {
        pressedTarget = hitTest(point)
        pressIsInside = pressedTarget != nil
        updatePresentation()
    }

    func updatePress(at point: CGPoint) {
        guard let pressedTarget else { return }
        pressIsInside = hitTest(point) == pressedTarget
        updatePresentation()
    }

    @discardableResult
    func endPress(at point: CGPoint) -> Target? {
        updatePress(at: point)
        let activated = pressIsInside ? pressedTarget : nil
        pressedTarget = nil
        pressIsInside = false

        switch activated {
        case .sourcePreviousPage:
            requestedSourceRow = max(0, sourcePage.pageIndex - 1)
            hoveredTarget = nil
            refreshContent()
        case .sourceNextPage:
            requestedSourceRow = min(sourcePage.pageCount - 1, sourcePage.pageIndex + 1)
            hoveredTarget = nil
            refreshContent()
        case .bagPreviousRow:
            requestedBagRow = max(0, bagViewport.rowIndex - 1)
            hoveredTarget = nil
            refreshContent()
        case .bagNextRow:
            requestedBagRow = min(bagViewport.rowCount - 1, bagViewport.rowIndex + 1)
            hoveredTarget = nil
            refreshContent()
        case .takeAll:
            updatePresentation()
            onTakeAllLoot?()
        case .source(let entry):
            updatePresentation()
            onTakeSourceStackAtIndex?(entry.sourceIndex)
        case .carried(let acquiredIndex):
            updatePresentation()
            onReturnCarriedStackAtIndex?(acquiredIndex)
        case nil:
            updatePresentation()
        }
        return activated
    }

    func cancelPress() {
        pressedTarget = nil
        pressIsInside = false
        updatePresentation()
    }

    private var visibleSourceEntries: [LootContainerPanelEntry] {
        let range = sourcePage.visibleRange
        return range.isEmpty ? [] : Array(entries[range])
    }

    private var visibleBagEntries: [BagEntry] {
        let range = bagViewport.visibleRange
        let all = allBagEntries
        return range.isEmpty ? [] : Array(all[range])
    }

    private func buildChrome() {
        panelPlate.texture = UIPaintedChrome.texture(named: "hud_loot_container_panel_v02")
        panelPlate.texture?.filteringMode = .linear
        panelPlate.name = "loot.panel.plate"
        panelPlate.zPosition = -10
        addChild(panelPlate)

        sourceProp.zPosition = -1
        sourceProp.name = "loot.panel.source-prop"
        addChild(sourceProp)

        takeAllArt.texture = UIPaintedChrome.texture(named: "hud_loot_take_all_v03")
        sourcePreviousArt.texture = UIPaintedChrome.texture(named: "dialogue_scroll_up_v06")
        sourceNextArt.texture = UIPaintedChrome.texture(named: "dialogue_scroll_down_v06")
        bagPreviousArt.texture = UIPaintedChrome.texture(named: "dialogue_scroll_up_v06")
        bagNextArt.texture = UIPaintedChrome.texture(named: "dialogue_scroll_down_v06")
        caseBagArt.texture = UIPaintedChrome.texture(named: "inventory_case_bag_v05")
        walletCoinArt.texture = UIPaintedChrome.texture(named: "inventory_coin_stack_v05")
        for art in [
            takeAllArt, sourcePreviousArt, sourceNextArt,
            bagPreviousArt, bagNextArt, caseBagArt, walletCoinArt
        ] {
            art.texture?.filteringMode = .linear
            art.zPosition = 1
        }

        install(root: takeAllRoot, hit: takeAllHit, art: takeAllArt, name: "take-all")
        install(root: sourcePreviousRoot, hit: sourcePreviousHit, art: sourcePreviousArt, name: "source-up")
        install(root: sourceNextRoot, hit: sourceNextHit, art: sourceNextArt, name: "source-down")
        install(root: bagPreviousRoot, hit: bagPreviousHit, art: bagPreviousArt, name: "bag-up")
        install(root: bagNextRoot, hit: bagNextHit, art: bagNextArt, name: "bag-down")
        addChild(caseBagArt)
        addChild(walletCoinArt)
    }

    private func install(
        root: SKNode,
        hit: SKSpriteNode,
        art: SKSpriteNode,
        name: String
    ) {
        root.name = "loot.panel.\(name)"
        root.addChild(hit)
        root.addChild(art)
        addChild(root)
    }

    private func buildSlots() {
        sourceSlots = makeSlots(count: HUDChromeLayout.LootContainerPanel.slotsPerPage, prefix: "source")
        bagSlots = makeSlots(count: HUDChromeLayout.LootContainerPanel.bagSlotsPerViewport, prefix: "bag")
    }

    private func makeSlots(count: Int, prefix: String) -> [SlotNodes] {
        let frameTexture = UIPaintedChrome.texture(named: "inventory_slot_frame_v05")
        frameTexture?.filteringMode = .linear
        return (0..<count).map { index in
            let root = SKNode()
            root.name = "loot.panel.\(prefix).slot.\(index)"
            let hit = Self.transparentHitNode()
            let frame = SKSpriteNode(texture: frameTexture)
            frame.zPosition = 1
            let icon = SKSpriteNode()
            icon.zPosition = 2
            let amount = SKLabelNode(fontNamed: UITheme.Font.overlayCondensed)
            amount.fontColor = UITheme.Color.paper
            amount.horizontalAlignmentMode = .right
            amount.verticalAlignmentMode = .center
            amount.zPosition = 3
            root.addChild(hit)
            root.addChild(frame)
            root.addChild(icon)
            root.addChild(amount)
            addChild(root)
            return SlotNodes(root: root, hit: hit, frame: frame, icon: icon, amount: amount)
        }
    }

    private func buildLabels() {
        occupiedLabel.fontColor = UITheme.Color.brass
        capacityLabel.fontColor = UITheme.Color.paper
        walletValueLabel.fontColor = UITheme.Color.paper
        for label in [occupiedLabel, capacityLabel, walletValueLabel] {
            label.horizontalAlignmentMode = .center
            label.verticalAlignmentMode = .center
            label.zPosition = 3
            addChild(label)
        }

        feedbackShadow.fontColor = SKColor(white: 0, alpha: 0.9)
        feedbackLabel.fontColor = UITheme.Color.brass
        for (index, label) in [feedbackShadow, feedbackLabel].enumerated() {
            label.horizontalAlignmentMode = .center
            label.verticalAlignmentMode = .center
            label.position = CGPoint(x: index == 0 ? 1 : 0, y: index == 0 ? -1 : 0)
            label.zPosition = CGFloat(index)
            feedbackRoot.addChild(label)
        }
        feedbackRoot.zPosition = 8
        feedbackRoot.isHidden = true
        addChild(feedbackRoot)
    }

    private func refreshContent() {
        requestedSourceRow = sourcePage.pageIndex
        requestedBagRow = bagViewport.rowIndex
        refreshSourceProp()
        refreshSourceSlots()
        refreshBagSlots()
        occupiedLabel.text = "\(carriedInventory.occupiedSlotCount) OCCUPIED"
        capacityLabel.text = "\(carriedInventory.totalSlotCapacity) SLOTS"
        walletValueLabel.text = CurrencyAmount(pence: walletPence).formatted
        normalizeInteractionState()
        updatePresentation()
    }

    private func refreshSourceProp() {
        guard !sourceArtName.isEmpty,
              sourceProp.texture == nil || sourceProp.name != "loot.panel.source-prop.\(sourceArtName)" else {
            layoutSourceProp()
            return
        }
        sourceProp.texture = GameArt.texture(named: sourceArtName)
        sourceProp.texture?.filteringMode = .linear
        sourceProp.name = "loot.panel.source-prop.\(sourceArtName)"
        layoutSourceProp()
    }

    private func refreshSourceSlots() {
        let visible = visibleSourceEntries
        for (index, slot) in sourceSlots.enumerated() {
            guard visible.indices.contains(index) else {
                clear(slot: slot)
                continue
            }
            let entry = visible[index]
            switch entry.stack {
            case .coins(let pence):
                set(slot: slot, artName: "inventory_coin_stack_v05")
                slot.amount.text = CurrencyAmount(pence: pence).formatted
            case .item(let id, let quantity):
                let artName = catalog.definition(for: id)?.iconArtName
                    ?? "inventory_slot_silhouette_item_v06"
                set(slot: slot, artName: artName)
                slot.amount.text = quantity > 1 ? "×\(quantity)" : nil
            }
            slot.frame.alpha = 1
        }
    }

    private func refreshBagSlots() {
        let visible = visibleBagEntries
        for (index, slot) in bagSlots.enumerated() {
            guard visible.indices.contains(index) else {
                clear(slot: slot)
                continue
            }
            let entry = visible[index]
            set(slot: slot, artName: entry.item.artName)
            slot.amount.text = entry.item.quantity > 1 ? "×\(entry.item.quantity)" : nil
            let isTransferable = entry.acquiredIndex != nil
            slot.icon.alpha = isTransferable ? 1 : 0.52
            slot.frame.alpha = isTransferable ? 1 : 0.56
        }
    }

    private func clear(slot: SlotNodes) {
        slot.icon.texture = nil
        slot.icon.isHidden = true
        slot.icon.alpha = 1
        slot.amount.text = nil
        slot.frame.alpha = 0.34
        slot.frame.colorBlendFactor = 0
    }

    private func set(slot: SlotNodes, artName: String) {
        slot.icon.texture = GameArt.texture(named: artName)
            ?? UIPaintedChrome.texture(named: artName)
        slot.icon.texture?.filteringMode = .linear
        slot.icon.isHidden = false
        slot.icon.alpha = 1
    }

    private func show(feedback: LootContainerPanelFeedback, autoDismiss: Bool) {
        feedbackShadow.text = feedback.text
        feedbackLabel.text = feedback.text
        feedbackLabel.fontColor = feedback.showsBagFullWarning
            ? UITheme.Color.paper
            : UITheme.Color.brass
        feedbackRoot.isHidden = false
        feedbackRoot.alpha = 0
        feedbackRoot.setScale(0.94)
        caseBagArt.alpha = 0.28
        feedbackRoot.run(
            .sequence([
                .group([.fadeIn(withDuration: 0.08), .scale(to: 1.05, duration: 0.10)]),
                .scale(to: 1, duration: 0.06),
                .wait(forDuration: 0.31),
                .fadeOut(withDuration: 0.15),
                .run { [weak self] in
                    self?.feedbackRoot.isHidden = true
                    self?.feedbackRoot.alpha = 1
                    self?.caseBagArt.alpha = 1
                }
            ]),
            withKey: "loot.panel.feedback"
        )
        if autoDismiss {
            run(
                .sequence([
                    .wait(forDuration: 0.45),
                    .fadeOut(withDuration: 0.15),
                    .run { [weak self] in self?.finishFinalDismissal() }
                ]),
                withKey: "loot.panel.final-dismiss"
            )
        }
    }

    private func finishFinalDismissal() {
        entries = []
        requestedSourceRow = 0
        hoveredTarget = nil
        pressedTarget = nil
        pressIsInside = false
        keepsEmptySourceOpenForReverseTransfer = false
        isHidden = true
        alpha = 1
        resetFeedbackActions()
    }

    private func resetFeedbackActions() {
        removeAction(forKey: "loot.panel.final-dismiss")
        feedbackRoot.removeAction(forKey: "loot.panel.feedback")
        feedbackRoot.isHidden = true
        feedbackRoot.alpha = 1
        feedbackRoot.setScale(1)
        caseBagArt.alpha = 1
    }

    private func normalizeInteractionState() {
        hoveredTarget = normalizedTarget(hoveredTarget)
        pressedTarget = normalizedTarget(pressedTarget)
        if pressedTarget == nil { pressIsInside = false }
    }

    private func normalizedTarget(_ target: Target?) -> Target? {
        guard let target else { return nil }
        switch target {
        case .takeAll:
            return entries.isEmpty ? nil : target
        case .sourcePreviousPage:
            return sourcePage.canGoPrevious ? target : nil
        case .sourceNextPage:
            return sourcePage.canGoNext ? target : nil
        case .bagPreviousRow:
            return bagViewport.canGoPrevious ? target : nil
        case .bagNextRow:
            return bagViewport.canGoNext ? target : nil
        case .source(let entry):
            return visibleSourceEntries.contains(entry) ? target : nil
        case .carried(let acquiredIndex):
            return visibleBagEntries.contains(where: { $0.acquiredIndex == acquiredIndex })
                ? target
                : nil
        }
    }

    private func updatePresentation() {
        present(takeAllArt, as: .takeAll, enabled: !entries.isEmpty)
        present(sourcePreviousArt, as: .sourcePreviousPage, enabled: sourcePage.canGoPrevious)
        present(sourceNextArt, as: .sourceNextPage, enabled: sourcePage.canGoNext)
        present(bagPreviousArt, as: .bagPreviousRow, enabled: bagViewport.canGoPrevious)
        present(bagNextArt, as: .bagNextRow, enabled: bagViewport.canGoNext)

        let source = visibleSourceEntries
        for (index, slot) in sourceSlots.enumerated() where source.indices.contains(index) {
            present(slot.frame, as: .source(source[index]), enabled: true)
        }
        let bag = visibleBagEntries
        for (index, slot) in bagSlots.enumerated() where bag.indices.contains(index) {
            guard let acquiredIndex = bag[index].acquiredIndex else {
                slot.frame.colorBlendFactor = 0
                continue
            }
            present(slot.frame, as: .carried(acquiredIndex: acquiredIndex), enabled: true)
        }
    }

    private func present(_ art: SKSpriteNode, as target: Target, enabled: Bool) {
        guard enabled else {
            art.alpha = 0.24
            art.colorBlendFactor = 0
            art.isHidden = true
            return
        }
        art.isHidden = false
        let isPressed = pressedTarget == target && pressIsInside
        let isHovered = hoveredTarget == target
        art.color = isPressed ? UITheme.Tint.pressedColor : UITheme.Tint.hoverColor
        art.colorBlendFactor = isPressed
            ? UITheme.Tint.pressedBlend
            : (isHovered ? UITheme.Tint.hoverBlend : 0)
        if art !== caseBagArt { art.alpha = 1 }
    }

    private func layoutSourceProp() {
        layoutAspectFit(sourceProp, in: currentLayout.sourcePropArtRect)
    }

    private func layoutAspectFit(_ sprite: SKSpriteNode, in rect: CGRect) {
        sprite.position = rect.center
        guard let texture = sprite.texture else {
            sprite.isHidden = true
            return
        }
        sprite.isHidden = false
        let source = texture.size()
        guard source.width > 0, source.height > 0 else {
            sprite.size = rect.size
            return
        }
        let scale = min(rect.width / source.width, rect.height / source.height)
        sprite.size = CGSize(width: source.width * scale, height: source.height * scale)
    }

    private func layout(
        slots: [SlotNodes],
        hitRects: [CGRect],
        artRects: [CGRect]
    ) {
        for (index, slot) in slots.enumerated() {
            guard hitRects.indices.contains(index), artRects.indices.contains(index) else { continue }
            let hitRect = hitRects[index]
            let artRect = artRects[index]
            slot.root.position = hitRect.center
            slot.hit.size = hitRect.size
            slot.frame.size = artRect.size
            slot.frame.position = CGPoint(
                x: artRect.midX - hitRect.midX,
                y: artRect.midY - hitRect.midY
            )
            let iconExtent = min(artRect.width, artRect.height) * 0.66
            slot.icon.size = CGSize(width: iconExtent, height: iconExtent)
            slot.icon.position = CGPoint(x: 0, y: artRect.height * 0.05)
            slot.amount.fontSize = max(9, min(12, artRect.height * 0.18))
            slot.amount.position = CGPoint(
                x: artRect.width / 2 - 9,
                y: -artRect.height / 2 + max(11, artRect.height * 0.17)
            )
        }
    }

    private func apply(
        root: SKNode,
        hit: SKSpriteNode,
        art: SKSpriteNode,
        hitRect: CGRect,
        artRect: CGRect
    ) {
        root.position = hitRect.center
        hit.size = hitRect.size
        art.size = artRect.size
        art.position = CGPoint(
            x: artRect.midX - hitRect.midX,
            y: artRect.midY - hitRect.midY
        )
    }

    private func layout(_ label: SKLabelNode, in rect: CGRect, fontSize: CGFloat) {
        label.position = rect.center
        label.fontSize = fontSize
    }

    private static func transparentHitNode() -> SKSpriteNode {
        SKSpriteNode(
            color: SKColor(white: 1, alpha: 0.001),
            size: CGSize(width: 44, height: 44)
        )
    }
}

private extension LootContainerPanelFeedback {
    var isSuccess: Bool {
        switch self {
        case .coins, .item, .batch: return true
        case .bagFull: return false
        }
    }

    var transferredAnyItem: Bool {
        switch self {
        case .item:
            return true
        case .batch(_, let itemStackCount, _):
            return itemStackCount > 0
        case .coins, .bagFull:
            return false
        }
    }

    var showsBagFullWarning: Bool {
        switch self {
        case .batch(_, _, let bagIsFull):
            return bagIsFull
        case .bagFull:
            return true
        case .coins, .item:
            return false
        }
    }

    var text: String {
        switch self {
        case .coins(let pence):
            return "+\(CurrencyAmount(pence: pence).formatted)"
        case .item(let id, let quantity):
            let name = InventoryItemPresentation
                .displayName(forItemID: id, catalog: HarborpointItems.catalog)
                .uppercased()
            return quantity > 1 ? "+\(quantity) × \(name)" : "+\(name)"
        case .batch(let pence, let itemStackCount, let bagIsFull):
            let currency = pence > 0 ? "+\(CurrencyAmount(pence: pence).formatted)" : nil
            let items = itemStackCount > 0
                ? "+\(itemStackCount) \(itemStackCount == 1 ? "ITEM" : "ITEMS")"
                : nil
            let warning = bagIsFull ? "CASE BAG FULL" : nil
            return [currency, items, warning].compactMap { $0 }.joined(separator: " · ")
        case .bagFull:
            return "CASE BAG FULL"
        }
    }
}

private extension CGRect {
    var center: CGPoint { CGPoint(x: midX, y: midY) }
}
