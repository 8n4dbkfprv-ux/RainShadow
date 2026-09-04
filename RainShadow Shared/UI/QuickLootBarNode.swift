import SpriteKit

/// The EE quick-loot strip: everything on the ground near Voss, in one row, with
/// page chevrons once there is more than a row's worth.
///
/// BG:EE added this to remove the walk-click-open-take loop for ordinary drops.
/// A click lifts one stack straight into the case bag; the bar never opens a
/// panel and never blocks the world, so it is non-modal in the same sense the
/// container strip is.
///
/// All chrome is painted art. The plate is the container strip's own backing for
/// now — a dedicated quick-loot plate is an outstanding Image Generator batch —
/// and the chevrons are `inventory_page_arrow_{prev,next}_v05`, which the asset
/// manifest kept back for exactly this surface. Code owns layout, hit-testing,
/// and hover tints only.
@MainActor
final class QuickLootBarNode: SKNode {

    enum Target: Equatable {
        case stack(GroundItemStack)
        case previousPage
        case nextPage
    }

    private struct SlotNodes {
        let root: SKNode
        let hit: SKSpriteNode
        let frame: SKSpriteNode
        let icon: SKSpriteNode
        let amount: SKLabelNode
    }

    /// Called with the ground stack the player clicked.
    var onTakeGroundStack: ((GroundItemStack) -> Void)?

    private let plate = SKSpriteNode()
    private var slots: [SlotNodes] = []
    private let previousArrow = SKNode()
    private let previousArrowArt = SKSpriteNode()
    private let previousArrowHit = SKSpriteNode()
    private let nextArrow = SKNode()
    private let nextArrowArt = SKSpriteNode()
    private let nextArrowHit = SKSpriteNode()
    private let emptyLabel = SKLabelNode(fontNamed: UITheme.Font.typewriter)

    private var entries: [GroundItemStack] = []
    private var requestedPage = 0
    private var catalog: ItemCatalog = HarborpointItems.catalog
    private var hoveredTarget: Target?
    private var pressedTarget: Target?
    /// Paging changes the arrow lane, so the bar re-solves its own geometry on
    /// every refresh and has to remember the viewport it was last given.
    private var lastVisibleSize = CGSize(width: 1_280, height: 800)
    private var currentLayout = HUDChromeLayout.quickLootBarLayout(
        for: CGSize(width: 1_280, height: 800),
        showsPaging: false
    )

    private var page: QuickLootPage {
        QuickLootPage(itemCount: entries.count, requestedPage: requestedPage)
    }

    private var visibleEntries: [GroundItemStack] {
        Array(entries[page.range])
    }

    override init() {
        super.init()
        name = "hud.quick-loot-bar"
        zPosition = 40
        isHidden = true
        build()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("QuickLootBarNode is created programmatically")
    }

    // MARK: - Presentation

    var isPresented: Bool { !isHidden }

    func present(entries: [GroundItemStack], catalog: ItemCatalog) {
        self.catalog = catalog
        refresh(entries: entries)
        isHidden = false
    }

    func dismiss() {
        isHidden = true
        hoveredTarget = nil
        pressedTarget = nil
    }

    /// Toggle, returning whether the bar is now showing.
    @discardableResult
    func toggle(entries: [GroundItemStack], catalog: ItemCatalog) -> Bool {
        if isPresented {
            dismiss()
            return false
        }
        present(entries: entries, catalog: catalog)
        return true
    }

    func refresh(entries: [GroundItemStack]) {
        self.entries = entries
        if page.pageIndex != requestedPage {
            requestedPage = page.pageIndex
        }
        applyLayout()
        redraw()
    }

    // MARK: - Layout

    func layout(for visibleSize: CGSize) {
        lastVisibleSize = visibleSize
        applyLayout()
    }

    private func applyLayout() {
        currentLayout = HUDChromeLayout.quickLootBarLayout(
            for: lastVisibleSize,
            showsPaging: page.needsPaging
        )
        let rect = currentLayout.panelRect
        plate.size = CGSize(width: rect.width, height: rect.height)
        plate.position = CGPoint(x: rect.midX, y: rect.midY)

        for (index, slot) in slots.enumerated() {
            guard currentLayout.slotArtRects.indices.contains(index) else { continue }
            let art = currentLayout.slotArtRects[index]
            let hit = currentLayout.slotHitRects[index]
            slot.root.position = CGPoint(x: art.midX, y: art.midY)
            slot.frame.size = art.size
            slot.icon.size = CGSize(width: art.width * 0.72, height: art.height * 0.72)
            slot.hit.size = hit.size
            slot.hit.position = CGPoint(x: hit.midX - art.midX, y: hit.midY - art.midY)
            slot.amount.position = CGPoint(x: art.width / 2 - 6, y: -art.height / 2 + 4)
            slot.amount.fontSize = max(8, art.height * 0.22)
        }

        place(
            arrow: previousArrow,
            art: previousArrowArt,
            hit: previousArrowHit,
            artRect: currentLayout.previousArrowArtRect,
            hitRect: currentLayout.previousArrowHitRect
        )
        place(
            arrow: nextArrow,
            art: nextArrowArt,
            hit: nextArrowHit,
            artRect: currentLayout.nextArrowArtRect,
            hitRect: currentLayout.nextArrowHitRect
        )

        emptyLabel.position = CGPoint(x: rect.midX, y: rect.midY)
        emptyLabel.fontSize = max(9, rect.height * 0.26)
    }

    private func place(
        arrow: SKNode,
        art: SKSpriteNode,
        hit: SKSpriteNode,
        artRect: CGRect,
        hitRect: CGRect
    ) {
        arrow.isHidden = !currentLayout.showsPaging
        guard currentLayout.showsPaging else { return }
        arrow.position = CGPoint(x: artRect.midX, y: artRect.midY)
        art.size = artRect.size
        hit.size = hitRect.size
        hit.position = CGPoint(x: hitRect.midX - artRect.midX, y: hitRect.midY - artRect.midY)
    }

    // MARK: - Hit testing

    func containsBar(at point: CGPoint) -> Bool {
        guard isPresented else { return false }
        return currentLayout.panelRect.contains(point)
    }

    func hitTest(_ point: CGPoint) -> Target? {
        guard isPresented else { return nil }
        if currentLayout.showsPaging {
            if currentLayout.previousArrowHitRect.contains(point), page.pageIndex > 0 {
                return .previousPage
            }
            if currentLayout.nextArrowHitRect.contains(point),
               page.pageIndex < page.pageCount - 1 {
                return .nextPage
            }
        }
        let visible = visibleEntries
        for (index, rect) in currentLayout.slotHitRects.enumerated()
        where rect.contains(point) && visible.indices.contains(index) {
            return .stack(visible[index])
        }
        return nil
    }

    @discardableResult
    func updateHover(at point: CGPoint) -> Target? {
        let target = hitTest(point)
        guard target != hoveredTarget else { return target }
        hoveredTarget = target
        redraw()
        return target
    }

    /// Pointer-up activation, matching the container strip.
    @discardableResult
    func activate(at point: CGPoint) -> Bool {
        guard let target = hitTest(point) else { return containsBar(at: point) }
        switch target {
        case .previousPage:
            requestedPage = max(0, page.pageIndex - 1)
            applyLayout()
            redraw()
        case .nextPage:
            requestedPage = min(page.pageCount - 1, page.pageIndex + 1)
            applyLayout()
            redraw()
        case .stack(let entry):
            onTakeGroundStack?(entry)
        }
        return true
    }

    // MARK: - Building

    private func build() {
        if let texture = GameArt.texture(named: "hud_loot_container_panel_v02") {
            texture.filteringMode = .linear
            plate.texture = texture
        } else {
            assertionFailure("Missing hud_loot_container_panel_v02.png")
        }
        plate.name = "quick-loot.plate"
        plate.zPosition = -10
        addChild(plate)

        for index in 0..<QuickLootPage.slotsPerPage {
            slots.append(makeSlot(index: index))
        }

        buildArrow(
            root: previousArrow,
            art: previousArrowArt,
            hit: previousArrowHit,
            artName: "inventory_page_arrow_prev_v05",
            name: "quick-loot.previous"
        )
        buildArrow(
            root: nextArrow,
            art: nextArrowArt,
            hit: nextArrowHit,
            artName: "inventory_page_arrow_next_v05",
            name: "quick-loot.next"
        )

        emptyLabel.text = "NOTHING WITHIN REACH"
        emptyLabel.fontColor = UITheme.Color.parchmentMuted
        emptyLabel.verticalAlignmentMode = .center
        emptyLabel.horizontalAlignmentMode = .center
        emptyLabel.zPosition = 2
        addChild(emptyLabel)
    }

    private func makeSlot(index: Int) -> SlotNodes {
        let root = SKNode()
        root.name = "quick-loot.slot.\(index)"
        root.zPosition = 1

        let hit = SKSpriteNode(color: SKColor(white: 1, alpha: 0.001), size: .zero)
        hit.zPosition = -2
        root.addChild(hit)

        let frame = SKSpriteNode()
        if let texture = GameArt.texture(named: "inventory_slot_frame_v05") {
            texture.filteringMode = .linear
            frame.texture = texture
        }
        frame.zPosition = -1
        root.addChild(frame)

        let icon = SKSpriteNode()
        icon.zPosition = 1
        root.addChild(icon)

        let amount = SKLabelNode(fontNamed: UITheme.Font.hudVital)
        amount.fontColor = UITheme.Color.paper
        amount.horizontalAlignmentMode = .right
        amount.verticalAlignmentMode = .baseline
        amount.zPosition = 2
        root.addChild(amount)

        addChild(root)
        return SlotNodes(root: root, hit: hit, frame: frame, icon: icon, amount: amount)
    }

    private func buildArrow(
        root: SKNode,
        art: SKSpriteNode,
        hit: SKSpriteNode,
        artName: String,
        name: String
    ) {
        root.name = name
        root.zPosition = 2
        hit.color = SKColor(white: 1, alpha: 0.001)
        hit.zPosition = -1
        root.addChild(hit)
        if let texture = GameArt.texture(named: artName) {
            texture.filteringMode = .linear
            art.texture = texture
        } else {
            assertionFailure("Missing \(artName).png")
        }
        root.addChild(art)
        addChild(root)
    }

    // MARK: - Drawing

    private func redraw() {
        let visible = visibleEntries
        emptyLabel.isHidden = !entries.isEmpty

        for (index, slot) in slots.enumerated() {
            guard visible.indices.contains(index) else {
                slot.root.isHidden = true
                continue
            }
            slot.root.isHidden = false
            let entry = visible[index]
            let definition = catalog.definition(for: entry.stack.id)
            if let artName = definition?.groundTextureName,
               let texture = GameArt.texture(named: artName) {
                texture.filteringMode = .linear
                slot.icon.texture = texture
                slot.icon.isHidden = false
            } else {
                slot.icon.isHidden = true
            }
            slot.amount.text = entry.stack.quantity > 1 ? "×\(entry.stack.quantity)" : nil

            let isHovered = hoveredTarget == .stack(entry)
            slot.frame.color = UITheme.Tint.hoverColor
            slot.frame.colorBlendFactor = isHovered ? UITheme.Tint.hoverBlend : 0
        }

        previousArrow.alpha = page.pageIndex > 0 ? 1 : 0.35
        nextArrow.alpha = page.pageIndex < page.pageCount - 1 ? 1 : 0.35
    }
}
