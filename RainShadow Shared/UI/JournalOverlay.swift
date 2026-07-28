import SpriteKit

/// A camera-fixed casebook with the compact index/detail hierarchy of classic
/// CRPG journals, translated into RainShadow's noir evidence-file language.
///
/// Case copy for M01 comes from `EmptyCoatJournalContent` (GDD §4.3.2 dossier).
@MainActor
final class JournalOverlay: SKNode {
    private enum Mode: String {
        case cases = "CASE FILES"
        case chronology = "CHRONOLOGY"
    }

    private enum Metrics {
        static let canvas = CGSize(width: 1_920, height: 1_080)
        static let leftCenterX: CGFloat = -625
        static let leftWidth: CGFloat = 520
        static let rightLeftX: CGFloat = -150
        static let rightWidth: CGFloat = 920
        static let indexTopY: CGFloat = 294
        static let indexBottomY: CGFloat = -365
        static let sectionHeight: CGFloat = 40
        static let entryHeight: CGFloat = 43
    }

    private enum Palette {
        static let paper = SKColor(red: 0.78, green: 0.78, blue: 0.76, alpha: 1)
        static let paperMuted = SKColor(red: 0.55, green: 0.55, blue: 0.54, alpha: 1)
        static let ink = SKColor(red: 0.08, green: 0.08, blue: 0.09, alpha: 1)
        static let inkMuted = SKColor(red: 0.22, green: 0.22, blue: 0.24, alpha: 0.82)
        static let charcoal = SKColor(red: 0.035, green: 0.038, blue: 0.040, alpha: 0.94)
        static let raised = SKColor(red: 0.11, green: 0.11, blue: 0.12, alpha: 0.96)
        static let selected = SKColor(red: 0.22, green: 0.085, blue: 0.08, alpha: 0.92)
        static let brass = SKColor(red: 0.72, green: 0.72, blue: 0.70, alpha: 1)
        static let redPencil = SKColor(red: 0.46, green: 0.12, blue: 0.105, alpha: 0.88)
        static let steel = SKColor(red: 0.43, green: 0.45, blue: 0.46, alpha: 0.62)
    }

    var onDismiss: (() -> Void)?

    private let sheet = SKNode()
    private let indexRoot = SKNode()
    private let detailRoot = SKNode()
    private let tabRoot = SKNode()
    private var mode: Mode = .cases
    private var caseSections: [CaseJournalSection] = []
    private var chronologySections: [CaseJournalSection] = []
    private var expandedSectionIDs: Set<String> = ["active", "people", "evidence", "notes", "log"]
    private var selectedEntryID = EmptyCoatJournalContent.defaultSelectedEntryID

    override init() {
        super.init()
        name = "journal.overlay"
        buildInterface()
        refresh(inspectedHotspotIDs: [])
        isHidden = true
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("JournalOverlay is created programmatically")
    }

    func layout(for visibleSize: CGSize) {
        let horizontalFit = (visibleSize.width - 28) / Metrics.canvas.width
        let verticalFit = (visibleSize.height - 22) / Metrics.canvas.height
        setScale(min(1, horizontalFit, verticalFit))
    }

    func refresh(inspectedHotspotIDs: Set<String>) {
        caseSections = EmptyCoatJournalContent.caseSections(inspectedHotspotIDs: inspectedHotspotIDs)
        chronologySections = EmptyCoatJournalContent.chronologySections(inspectedHotspotIDs: inspectedHotspotIDs)
        if entry(withID: selectedEntryID) == nil {
            selectedEntryID = visibleEntries().first?.id ?? EmptyCoatJournalContent.defaultSelectedEntryID
        }
        rebuildTabs()
        rebuildIndex()
        rebuildDetail()
    }

    func present(inspectedHotspotIDs: Set<String>) {
        refresh(inspectedHotspotIDs: inspectedHotspotIDs)
        removeAllActions()
        isHidden = false
        alpha = 0
        sheet.setScale(0.985)
        sheet.run(.scale(to: 1, duration: 0.18))
        run(.fadeIn(withDuration: 0.16))
    }

    func hideAnimated() {
        removeAllActions()
        run(.sequence([
            .fadeOut(withDuration: 0.13),
            .run { [weak self] in self?.isHidden = true }
        ]))
    }

    @discardableResult
    func handlePointer(at point: CGPoint) -> Bool {
        guard !isHidden else { return false }
        guard let target = targetName(at: point) else { return true }
        if target == "journal.close" {
            onDismiss?()
        } else if target == "journal.tab.cases" {
            setMode(.cases)
        } else if target == "journal.tab.chronology" {
            setMode(.chronology)
        } else if target.hasPrefix("journal.section.") {
            let id = String(target.dropFirst("journal.section.".count))
            if expandedSectionIDs.contains(id) {
                expandedSectionIDs.remove(id)
            } else {
                expandedSectionIDs.insert(id)
            }
            rebuildIndex()
        } else if target.hasPrefix("journal.entry.") {
            selectedEntryID = String(target.dropFirst("journal.entry.".count))
            rebuildIndex()
            rebuildDetail()
        }
        return true
    }

    func handleDirectionalInput(_ direction: CGVector) {
        if abs(direction.dx) > abs(direction.dy), direction.dx != 0 {
            setMode(mode == .cases ? .chronology : .cases)
            return
        }
        let entries = visibleEntries()
        guard !entries.isEmpty else { return }
        let current = entries.firstIndex { $0.id == selectedEntryID } ?? 0
        let delta = direction.dy > 0 ? -1 : 1
        let next = (current + delta + entries.count) % entries.count
        selectedEntryID = entries[next].id
        rebuildIndex()
        rebuildDetail()
    }

    func moveSelection(_ direction: Int) {
        handleDirectionalInput(CGVector(dx: 0, dy: direction < 0 ? 1 : -1))
    }

    func isInteractive(at point: CGPoint) -> Bool {
        guard let target = targetName(at: point) else { return false }
        return target == "journal.close"
            || target.hasPrefix("journal.tab.")
            || target.hasPrefix("journal.section.")
            || target.hasPrefix("journal.entry.")
    }

    private var activeSections: [CaseJournalSection] {
        mode == .cases ? caseSections : chronologySections
    }

    private func buildInterface() {
        let veil = SKShapeNode(rectOf: CGSize(width: 3_000, height: 1_700))
        veil.fillColor = SKColor(white: 0.004, alpha: 0.86)
        veil.strokeColor = .clear
        veil.zPosition = -30
        addChild(veil)

        let shadow = SKShapeNode(rectOf: Metrics.canvas, cornerRadius: 15)
        shadow.fillColor = SKColor(white: 0, alpha: 0.72)
        shadow.strokeColor = .clear
        shadow.position = CGPoint(x: 12, y: -15)
        shadow.zPosition = -12
        sheet.addChild(shadow)

        if let texture = GameArt.texture(named: "journal_casebook_plate_v03")
            ?? GameArt.texture(named: "journal_casebook_plate_v02") {
            texture.filteringMode = .linear
            let plate = SKSpriteNode(texture: texture, size: Metrics.canvas)
            plate.zPosition = -10
            sheet.addChild(plate)
        } else {
            assertionFailure("Missing journal_casebook_plate_v03.png")
        }

        let title = Self.label(text: "CASE JOURNAL", size: 37, color: Palette.paper, font: "AvenirNextCondensed-DemiBold")
        title.position = CGPoint(x: 0, y: 463)
        sheet.addChild(title)

        let subtitle = Self.label(
            text: EmptyCoatJournalContent.agencyLetterhead,
            size: 12,
            color: Palette.paperMuted,
            font: "AvenirNext-DemiBold"
        )
        subtitle.position = CGPoint(x: 0, y: 431)
        sheet.addChild(subtitle)

        let close = ClassicMacCloseButtonNode(
            targetName: "journal.close",
            fill: Palette.raised,
            stroke: Palette.steel,
            highlight: Palette.paper,
            accent: Palette.redPencil
        )
        close.position = CGPoint(x: -872, y: 468)
        sheet.addChild(close)

        indexRoot.position = CGPoint(x: Metrics.leftCenterX, y: 0)
        sheet.addChild(tabRoot)
        sheet.addChild(indexRoot)
        sheet.addChild(detailRoot)

        let controlHint = Self.label(text: "J  CLOSE    •    ↑↓  SELECT    •    ←→  CHANGE VIEW", size: 13, color: Palette.paperMuted, font: "AvenirNext-DemiBold")
        controlHint.position = CGPoint(x: 0, y: -479)
        sheet.addChild(controlHint)
        addChild(sheet)
    }

    private func rebuildTabs() {
        tabRoot.removeAllChildren()
        let tabs: [(Mode, CGFloat)] = [(.cases, -745), (.chronology, -505)]
        for (tabMode, x) in tabs {
            let selected = mode == tabMode
            let tab = Self.button(
                size: CGSize(width: 220, height: 48),
                fill: selected ? Palette.selected : Palette.raised,
                stroke: selected ? Palette.brass : Palette.steel
            )
            tab.name = tabMode == .cases ? "journal.tab.cases" : "journal.tab.chronology"
            tab.position = CGPoint(x: x, y: 362)
            let label = Self.label(text: tabMode.rawValue, size: 16, color: selected ? Palette.paper : Palette.paperMuted, font: "AvenirNext-DemiBold")
            label.verticalAlignmentMode = .center
            label.position.y = 1
            tab.addChild(label)
            tabRoot.addChild(tab)
        }
    }

    private func rebuildIndex() {
        indexRoot.removeAllChildren()
        var y = Metrics.indexTopY
        for section in activeSections {
            guard y - Metrics.sectionHeight >= Metrics.indexBottomY else { break }
            let expanded = expandedSectionIDs.contains(section.id)
            let header = Self.button(
                size: CGSize(width: Metrics.leftWidth, height: Metrics.sectionHeight - 4),
                fill: Palette.raised,
                stroke: Palette.steel
            )
            header.name = "journal.section.\(section.id)"
            header.position = CGPoint(x: 0, y: y)
            let chevron = Self.label(text: expanded ? "▾" : "▸", size: 18, color: Palette.brass, font: "AvenirNext-DemiBold")
            chevron.horizontalAlignmentMode = .left
            chevron.verticalAlignmentMode = .center
            chevron.position = CGPoint(x: -238, y: 1)
            header.addChild(chevron)
            let headerLabel = Self.label(text: section.title, size: 15, color: Palette.paper, font: "AvenirNext-DemiBold")
            headerLabel.horizontalAlignmentMode = .left
            headerLabel.verticalAlignmentMode = .center
            headerLabel.position = CGPoint(x: -208, y: 1)
            header.addChild(headerLabel)
            let count = Self.label(text: String(format: "%02d", section.entries.count), size: 13, color: Palette.paperMuted, font: "AvenirNext-DemiBold")
            count.horizontalAlignmentMode = .right
            count.verticalAlignmentMode = .center
            count.position = CGPoint(x: 235, y: 1)
            header.addChild(count)
            indexRoot.addChild(header)
            y -= Metrics.sectionHeight

            guard expanded else { continue }
            for entry in section.entries {
                guard y - Metrics.entryHeight / 2 >= Metrics.indexBottomY else { break }
                let selected = entry.id == selectedEntryID
                let row = Self.button(
                    size: CGSize(width: Metrics.leftWidth - 18, height: Metrics.entryHeight - 4),
                    fill: selected ? Palette.selected : Palette.charcoal,
                    stroke: selected ? Palette.brass : SKColor(white: 0.24, alpha: 0.36)
                )
                row.name = "journal.entry.\(entry.id)"
                row.position = CGPoint(x: 9, y: y)
                if let markerTexture = UIPaintedChrome.texture(named: "journal_row_marker_v03") {
                    let marker = SKSpriteNode(texture: markerTexture, size: CGSize(width: 18, height: 18))
                    marker.position = CGPoint(x: -231, y: 1)
                    marker.alpha = selected ? 1 : 0.7
                    row.addChild(marker)
                }
                let rowLabel = Self.label(text: entry.title, size: 16, color: selected ? Palette.paper : Palette.paperMuted, font: "AvenirNext-Medium")
                rowLabel.horizontalAlignmentMode = .left
                rowLabel.verticalAlignmentMode = .center
                rowLabel.position = CGPoint(x: -203, y: 1)
                row.addChild(rowLabel)
                if entry.isNew {
                    let dot = SKShapeNode(circleOfRadius: 4)
                    dot.fillColor = Palette.redPencil
                    dot.strokeColor = Palette.paper.withAlphaComponent(0.55)
                    dot.lineWidth = 1
                    dot.position = CGPoint(x: 229, y: 0)
                    row.addChild(dot)
                }
                indexRoot.addChild(row)
                y -= Metrics.entryHeight
            }
            y -= 5
        }
    }

    private func rebuildDetail() {
        detailRoot.removeAllChildren()
        guard let entry = entry(withID: selectedEntryID) ?? visibleEntries().first else { return }

        let pin = Self.label(text: entry.eyebrow.uppercased(), size: 14, color: Palette.redPencil, font: "AvenirNext-DemiBold")
        pin.horizontalAlignmentMode = .left
        pin.position = CGPoint(x: Metrics.rightLeftX, y: 351)
        detailRoot.addChild(pin)

        let status = Self.label(text: entry.status.uppercased(), size: 13, color: Palette.inkMuted, font: "AvenirNext-DemiBold")
        status.horizontalAlignmentMode = .right
        status.position = CGPoint(x: Metrics.rightLeftX + Metrics.rightWidth, y: 351)
        detailRoot.addChild(status)

        let title = Self.label(text: entry.title.uppercased(), size: 34, color: Palette.ink, font: "AvenirNextCondensed-DemiBold")
        title.horizontalAlignmentMode = .left
        title.position = CGPoint(x: Metrics.rightLeftX, y: 302)
        detailRoot.addChild(title)

        let rule = SKShapeNode(rectOf: CGSize(width: Metrics.rightWidth, height: 2))
        rule.fillColor = Palette.redPencil
        rule.strokeColor = .clear
        rule.position = CGPoint(x: Metrics.rightLeftX + Metrics.rightWidth / 2, y: 273)
        detailRoot.addChild(rule)

        var y: CGFloat = 238
        y = addWrapped(entry.summary, atY: y, size: 20, color: Palette.ink, font: "AvenirNext-DemiBold", maxCharacters: 81, lineHeight: 27)
        y -= 21
        for paragraph in entry.body {
            y = addWrapped(paragraph, atY: y, size: 18, color: Palette.inkMuted, font: "AvenirNext-Medium", maxCharacters: 88, lineHeight: 26)
            y -= 16
        }

        if !entry.leads.isEmpty, y > -265 {
            let leadsTitle = Self.label(text: mode == .chronology ? "CONSEQUENCE" : "LEADS / NEXT STEPS", size: 13, color: Palette.redPencil, font: "AvenirNext-DemiBold")
            leadsTitle.horizontalAlignmentMode = .left
            leadsTitle.position = CGPoint(x: Metrics.rightLeftX, y: y)
            detailRoot.addChild(leadsTitle)
            y -= 35
            for lead in entry.leads.prefix(4) {
                let bullet = Self.label(text: "◆", size: 9, color: Palette.redPencil, font: "AvenirNext-DemiBold")
                bullet.horizontalAlignmentMode = .left
                bullet.position = CGPoint(x: Metrics.rightLeftX + 2, y: y + 3)
                detailRoot.addChild(bullet)
                y = addWrapped(lead, atY: y, x: Metrics.rightLeftX + 25, size: 17, color: Palette.inkMuted, font: "AvenirNext-Medium", maxCharacters: 82, lineHeight: 24)
                y -= 8
            }
        }

        let pageMark = Self.label(
            text: EmptyCoatJournalContent.pageMark,
            size: 12,
            color: Palette.inkMuted.withAlphaComponent(0.68),
            font: "AvenirNext-DemiBold"
        )
        pageMark.position = CGPoint(x: Metrics.rightLeftX + Metrics.rightWidth / 2, y: -372)
        detailRoot.addChild(pageMark)
    }

    private func addWrapped(
        _ text: String,
        atY startY: CGFloat,
        x: CGFloat? = nil,
        size: CGFloat,
        color: SKColor,
        font: String,
        maxCharacters: Int,
        lineHeight: CGFloat
    ) -> CGFloat {
        var y = startY
        let resolvedX = x ?? Metrics.rightLeftX
        for line in Self.wrappedLines(text, maxCharacters: maxCharacters) {
            let label = Self.label(text: line, size: size, color: color, font: font)
            label.horizontalAlignmentMode = .left
            label.position = CGPoint(x: resolvedX, y: y)
            detailRoot.addChild(label)
            y -= lineHeight
        }
        return y
    }

    private func setMode(_ newMode: Mode) {
        guard mode != newMode else { return }
        mode = newMode
        selectedEntryID = activeSections.first?.entries.first?.id ?? selectedEntryID
        rebuildTabs()
        rebuildIndex()
        rebuildDetail()
    }

    private func visibleEntries() -> [CaseJournalEntry] {
        let expanded = activeSections.filter { expandedSectionIDs.contains($0.id) }.flatMap(\.entries)
        return expanded.isEmpty ? activeSections.flatMap(\.entries) : expanded
    }

    private func entry(withID id: String) -> CaseJournalEntry? {
        activeSections.lazy.flatMap(\.entries).first { $0.id == id }
    }

    private func targetName(at point: CGPoint) -> String? {
        let candidates = nodes(at: point).sorted { $0.zPosition > $1.zPosition }
        for candidate in candidates {
            var node: SKNode? = candidate
            while let current = node, current !== self {
                if let name = current.name, name.hasPrefix("journal.") { return name }
                node = current.parent
            }
        }
        return nil
    }

    private static func wrappedLines(_ text: String, maxCharacters: Int) -> [String] {
        var lines: [String] = []
        var current = ""
        for word in text.split(separator: " ").map(String.init) {
            if current.isEmpty {
                current = word
            } else if current.count + word.count + 1 <= maxCharacters {
                current += " " + word
            } else {
                lines.append(current)
                current = word
            }
        }
        if !current.isEmpty { lines.append(current) }
        return lines
    }

    private static func button(size: CGSize, fill: SKColor, stroke: SKColor) -> SKShapeNode {
        let node = SKShapeNode(rectOf: size, cornerRadius: 3)
        node.fillColor = fill
        node.strokeColor = stroke
        node.lineWidth = 1.5
        return node
    }

    private static func label(text: String, size: CGFloat, color: SKColor, font: String) -> SKLabelNode {
        let label = SKLabelNode(fontNamed: font)
        label.text = text
        label.fontSize = size
        label.fontColor = color
        return label
    }
}
