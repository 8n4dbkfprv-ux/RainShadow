import SpriteKit

struct CaseDialogueChoice {
    let text: String
    let destinationID: String
}

struct CaseDialogueNode {
    let id: String
    let speaker: String
    let text: String
    let portraitName: String?
    let choices: [CaseDialogueChoice]
    let nextNodeID: String?
    let endsDialogue: Bool

    init(
        id: String,
        speaker: String,
        text: String,
        portraitName: String? = nil,
        choices: [CaseDialogueChoice] = [],
        nextNodeID: String? = nil,
        endsDialogue: Bool = false
    ) {
        self.id = id
        self.speaker = speaker
        self.text = text
        self.portraitName = portraitName
        self.choices = choices
        self.nextNodeID = nextNodeID
        self.endsDialogue = endsDialogue
    }
}

@MainActor
final class CaseIntroductionPresenter: SKNode {
    private enum Palette {
        static let veil = SKColor.clear
        static let shadow = SKColor(white: 0, alpha: 0.78)
        static let well = SKColor(red: 0.012, green: 0.018, blue: 0.017, alpha: 0.96)
        static let innerWell = SKColor(red: 0.018, green: 0.027, blue: 0.024, alpha: 0.80)
        static let gunmetal = SKColor(red: 0.24, green: 0.27, blue: 0.27, alpha: 1)
        static let edge = SKColor(red: 0.50, green: 0.51, blue: 0.48, alpha: 0.84)
        static let darkEdge = SKColor(red: 0.075, green: 0.085, blue: 0.082, alpha: 1)
        static let parchment = SKColor(red: 0.86, green: 0.84, blue: 0.70, alpha: 1)
        static let response = SKColor(red: 0.76, green: 0.19, blue: 0.13, alpha: 1)
        static let responseHot = SKColor(red: 0.96, green: 0.69, blue: 0.28, alpha: 1)
        static let vivian = SKColor(red: 0.72, green: 0.16, blue: 0.36, alpha: 1)
        static let elias = SKColor(red: 0.78, green: 0.55, blue: 0.25, alpha: 1)
        static let caseTitle = SKColor(red: 0.82, green: 0.68, blue: 0.34, alpha: 1)
    }

    private struct ChoiceRow {
        let background: SKShapeNode
        let label: SKLabelNode
        let hitRect: CGRect
    }

    private enum CommandKind {
        case hidden
        case next(String)
        case end
    }

    private let veil = SKShapeNode()
    private let panelRoot = SKNode()
    private let panelShadow = SKShapeNode()
    private let panel = SKShapeNode()
    private let innerPanel = SKShapeNode()
    private let innerBorder = SKShapeNode()
    private let frameOverlay = SKSpriteNode()
    private let topClasp = SKShapeNode()
    private let cornerBrackets = SKShapeNode()
    private let dialogueScrollbar = DialogueScrollbarNode()
    private let portraitShadow = SKShapeNode()
    private let portraitBacking = SKShapeNode()
    private let portraitBorder = SKShapeNode()
    private let portraitPins = SKShapeNode()
    private let portrait = SKSpriteNode()
    private let speakerLabel = SKLabelNode(fontNamed: "Palatino-Bold")
    private let contentCrop = SKCropNode()
    private let contentMask = SKShapeNode()
    private let scrollContentRoot = SKNode()
    private let dialogueLabel = SKLabelNode(fontNamed: "Palatino-Roman")
    private let choicesRoot = SKNode()
    private let commandShadow = SKShapeNode()
    private let commandButton = SKShapeNode()
    private let commandInnerBorder = SKShapeNode()
    private let commandLabel = SKLabelNode(fontNamed: "Palatino-Bold")

    private var nodesByID: [String: CaseDialogueNode] = [:]
    private var currentNodeID: String?
    private var choiceRows: [ChoiceRow] = []
    private var commandKind = CommandKind.hidden
    private var commandHitRect = CGRect.zero
    private var focusedChoiceIndex: Int?
    private var hoveredChoiceIndex: Int?
    private var commandIsHovered = false
    private var panelRect = CGRect.zero
    private var contentViewportRect = CGRect.zero
    private var panelLayout = DialoguePanelLayout.layout(panelRect: CGRect(x: 0, y: 0, width: 1_000, height: 320))
    private var scrollOffset: CGFloat = 0
    private var usesGeneratedFrame = false
    private var presentationCompletion: (() -> Void)?

    private(set) var isPresenting = false

    override init() {
        super.init()
        name = "dialogue.presenter"
        buildInterface()
        alpha = 0
        isHidden = true
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("CaseIntroductionPresenter is created programmatically")
    }

    func layout(for visibleSize: CGSize) {
        let geometry = DialoguePanelLayout.layout(for: visibleSize)
        panelLayout = geometry
        panelRect = geometry.panelRect
        contentViewportRect = geometry.contentViewportRect

        let panelWidth = panelRect.width
        let commandSize = CGSize(width: min(380, panelWidth * 0.32), height: 46)
        let commandY = -visibleSize.height / 2 + 25

        veil.path = CGPath(
            rect: CGRect(
                x: -visibleSize.width / 2 - 80,
                y: -visibleSize.height / 2 - 80,
                width: visibleSize.width + 160,
                height: visibleSize.height + 160
            ),
            transform: nil
        )

        panelShadow.path = roundedRect(panelRect.offsetBy(dx: 10, dy: -13), radius: 7)
        panel.path = roundedRect(panelRect, radius: 5)
        innerPanel.path = roundedRect(panelRect.insetBy(dx: 12, dy: 12), radius: 2)
        innerBorder.path = roundedRect(panelRect.insetBy(dx: 20, dy: 20), radius: 1)
        frameOverlay.position = CGPoint(x: panelRect.midX, y: panelRect.midY)
        frameOverlay.size = panelRect.size
        layoutOrnament()

        dialogueScrollbar.layout(in: geometry.scrollbarRect)

        let portraitRect = geometry.portraitRect
        let portraitOuterRect = portraitRect.insetBy(dx: -10, dy: -10)
        portraitShadow.path = roundedRect(portraitOuterRect.offsetBy(dx: 4, dy: -5), radius: 2)
        portraitBorder.path = roundedRect(portraitOuterRect, radius: 2)
        portraitBacking.path = roundedRect(portraitRect.insetBy(dx: -4, dy: -4), radius: 1)
        let pinPath = CGMutablePath()
        let pinInset: CGFloat = 5
        for center in [
            CGPoint(x: portraitOuterRect.minX + pinInset, y: portraitOuterRect.minY + pinInset),
            CGPoint(x: portraitOuterRect.maxX - pinInset, y: portraitOuterRect.minY + pinInset),
            CGPoint(x: portraitOuterRect.minX + pinInset, y: portraitOuterRect.maxY - pinInset),
            CGPoint(x: portraitOuterRect.maxX - pinInset, y: portraitOuterRect.maxY - pinInset)
        ] {
            pinPath.addEllipse(in: CGRect(x: center.x - 2.2, y: center.y - 2.2, width: 4.4, height: 4.4))
        }
        portraitPins.path = pinPath
        portrait.position = CGPoint(x: portraitRect.midX, y: portraitRect.midY)
        portrait.size = CGSize(width: portraitRect.width - 8, height: portraitRect.height - 8)

        let textLeft = contentViewportRect.minX
        speakerLabel.position = CGPoint(x: textLeft, y: panelRect.maxY - 42)
        // Crop matches the content viewport so scrolled text cannot paint into the scrollbar gutter.
        contentMask.path = CGPath(rect: contentViewportRect, transform: nil)
        dialogueLabel.position = CGPoint(x: textLeft, y: contentViewportRect.maxY)
        dialogueLabel.preferredMaxLayoutWidth = geometry.bodyTextMaxWidth

        commandHitRect = CGRect(
            x: -commandSize.width / 2,
            y: commandY - commandSize.height / 2,
            width: commandSize.width,
            height: commandSize.height
        )
        commandShadow.path = roundedRect(commandHitRect.offsetBy(dx: 7, dy: -8), radius: 5)
        commandButton.path = roundedRect(commandHitRect, radius: 4)
        commandInnerBorder.path = roundedRect(commandHitRect.insetBy(dx: 7, dy: 7), radius: 2)
        commandLabel.position = CGPoint(x: 0, y: commandY - 2)

        if isPresenting {
            showCurrentNode(animated: false)
        }
    }

    func present(
        _ nodes: [CaseDialogueNode],
        startingAt startID: String,
        onComplete: (() -> Void)? = nil
    ) {
        guard !nodes.isEmpty, nodes.contains(where: { $0.id == startID }) else {
            onComplete?()
            return
        }

        removeAllActions()
        presentationCompletion = onComplete
        nodesByID = Dictionary(uniqueKeysWithValues: nodes.map { ($0.id, $0) })
        currentNodeID = startID
        isPresenting = true
        isHidden = false
        showCurrentNode(animated: false)
        run(.fadeIn(withDuration: 0.22))
    }

    @discardableResult
    func handlePointer(at point: CGPoint) -> Bool {
        guard isPresenting else { return false }
        let panelPoint = panelRoot.convert(point, from: self)
        let contentPoint = scrollContentRoot.convert(panelPoint, from: panelRoot)

        if contentViewportRect.contains(panelPoint),
           let index = choiceRows.firstIndex(where: { $0.hitRect.contains(contentPoint) }) {
            focusedChoiceIndex = index
            activateFocusedControl()
            return true
        }

        if commandHitRect.contains(point), !commandButton.isHidden {
            activateFocusedControl()
            return true
        }

        return panelRect.contains(panelPoint)
    }

    @discardableResult
    func handlePointerDown(at point: CGPoint) -> Bool {
        guard isPresenting else { return false }
        let panelPoint = panelRoot.convert(point, from: self)
        let scrollbarPoint = dialogueScrollbar.convert(panelPoint, from: panelRoot)
        return dialogueScrollbar.handlePointerDown(at: scrollbarPoint)
    }

    @discardableResult
    func handlePointerDragged(at point: CGPoint) -> Bool {
        guard isPresenting else { return false }
        let panelPoint = panelRoot.convert(point, from: self)
        let scrollbarPoint = dialogueScrollbar.convert(panelPoint, from: panelRoot)
        return dialogueScrollbar.handlePointerDragged(at: scrollbarPoint)
    }

    @discardableResult
    func handlePointerUp(at point: CGPoint) -> Bool {
        guard isPresenting else { return false }
        let panelPoint = panelRoot.convert(point, from: self)
        let scrollbarPoint = dialogueScrollbar.convert(panelPoint, from: panelRoot)
        return dialogueScrollbar.handlePointerUp(at: scrollbarPoint)
    }

    @discardableResult
    func updatePointer(at point: CGPoint) -> Bool {
        guard isPresenting else { return false }
        let panelPoint = panelRoot.convert(point, from: self)
        let contentPoint = scrollContentRoot.convert(panelPoint, from: panelRoot)
        hoveredChoiceIndex = contentViewportRect.contains(panelPoint)
            ? choiceRows.firstIndex { $0.hitRect.contains(contentPoint) }
            : nil
        commandIsHovered = commandHitRect.contains(point) && !commandButton.isHidden
        let scrollbarPoint = dialogueScrollbar.convert(panelPoint, from: panelRoot)
        let scrollbarIsHovered = dialogueScrollbar.updatePointer(at: scrollbarPoint)
        refreshInteractionColors()
        return hoveredChoiceIndex != nil || commandIsHovered || scrollbarIsHovered
    }

    @discardableResult
    func moveSelection(_ direction: Int) -> Bool {
        guard !choiceRows.isEmpty else { return false }
        let current = focusedChoiceIndex ?? (direction < 0 ? 0 : -1)
        focusedChoiceIndex = (current + direction + choiceRows.count) % choiceRows.count
        ensureFocusedChoiceIsVisible()
        refreshInteractionColors()
        return true
    }

    @discardableResult
    func scrollContent(by points: CGFloat) -> Bool {
        dialogueScrollbar.scroll(by: points)
    }

    func activateFocusedControl() {
        guard isPresenting else { return }

        if !choiceRows.isEmpty {
            let index = focusedChoiceIndex ?? hoveredChoiceIndex ?? 0
            guard
                let node = currentNodeID.flatMap({ nodesByID[$0] }),
                node.choices.indices.contains(index)
            else { return }
            transition(to: node.choices[index].destinationID)
            return
        }

        switch commandKind {
        case .hidden:
            return
        case .next(let destinationID):
            transition(to: destinationID)
        case .end:
            finish()
        }
    }

    private func buildInterface() {
        veil.fillColor = Palette.veil
        veil.strokeColor = .clear
        veil.zPosition = -30
        addChild(veil)
        addChild(panelRoot)

        panelShadow.fillColor = Palette.shadow
        panelShadow.strokeColor = .clear
        panelShadow.zPosition = -20
        panelRoot.addChild(panelShadow)

        panel.fillColor = Palette.darkEdge
        panel.strokeColor = Palette.gunmetal
        panel.lineWidth = 7
        panel.zPosition = -15
        panelRoot.addChild(panel)

        innerPanel.fillColor = Palette.well
        innerPanel.strokeColor = Palette.edge
        innerPanel.lineWidth = 2
        innerPanel.zPosition = -14
        panelRoot.addChild(innerPanel)

        innerBorder.fillColor = Palette.innerWell
        innerBorder.strokeColor = SKColor(red: 0.12, green: 0.15, blue: 0.14, alpha: 1)
        innerBorder.lineWidth = 2
        innerBorder.zPosition = -13
        panelRoot.addChild(innerBorder)

        usesGeneratedFrame = addGeneratedFrameOverlay()
        if usesGeneratedFrame {
            panel.strokeColor = .clear
            innerPanel.strokeColor = .clear
            innerBorder.strokeColor = .clear
        }

        [topClasp, cornerBrackets].forEach {
            $0.fillColor = .clear
            $0.strokeColor = Palette.edge
            $0.lineWidth = 4
            $0.lineJoin = .round
            panelRoot.addChild($0)
        }
        topClasp.isHidden = usesGeneratedFrame
        cornerBrackets.isHidden = usesGeneratedFrame
        dialogueScrollbar.zPosition = 3
        dialogueScrollbar.onScroll = { [weak self] offset in
            self?.applyScrollOffset(offset)
        }
        panelRoot.addChild(dialogueScrollbar)

        portraitShadow.fillColor = SKColor(white: 0, alpha: 0.72)
        portraitShadow.strokeColor = .clear
        portraitShadow.zPosition = -4
        panelRoot.addChild(portraitShadow)

        portraitBacking.fillColor = SKColor(white: 0.012, alpha: 1)
        portraitBacking.strokeColor = SKColor(red: 0.34, green: 0.10, blue: 0.11, alpha: 1)
        portraitBacking.lineWidth = 3
        portraitBacking.zPosition = -2
        panelRoot.addChild(portraitBacking)

        portraitBorder.fillColor = Palette.darkEdge
        portraitBorder.strokeColor = Palette.edge
        portraitBorder.lineWidth = 2
        portraitBorder.zPosition = -3
        panelRoot.addChild(portraitBorder)
        portrait.zPosition = -1
        panelRoot.addChild(portrait)

        portraitPins.fillColor = SKColor(red: 0.51, green: 0.42, blue: 0.29, alpha: 1)
        portraitPins.strokeColor = SKColor(red: 0.16, green: 0.13, blue: 0.10, alpha: 1)
        portraitPins.lineWidth = 1
        portraitPins.zPosition = 0
        panelRoot.addChild(portraitPins)

        speakerLabel.fontSize = 24
        speakerLabel.horizontalAlignmentMode = .left
        speakerLabel.verticalAlignmentMode = .top
        panelRoot.addChild(speakerLabel)

        contentMask.fillColor = .white
        contentMask.strokeColor = .clear
        contentCrop.maskNode = contentMask
        contentCrop.zPosition = 1
        panelRoot.addChild(contentCrop)
        contentCrop.addChild(scrollContentRoot)

        dialogueLabel.fontSize = 20
        dialogueLabel.fontColor = Palette.parchment
        dialogueLabel.horizontalAlignmentMode = .left
        dialogueLabel.verticalAlignmentMode = .top
        dialogueLabel.numberOfLines = 0
        scrollContentRoot.addChild(dialogueLabel)
        scrollContentRoot.addChild(choicesRoot)

        commandShadow.fillColor = Palette.shadow
        commandShadow.strokeColor = .clear
        addChild(commandShadow)

        commandButton.fillColor = SKColor(red: 0.035, green: 0.022, blue: 0.022, alpha: 0.98)
        commandButton.strokeColor = Palette.edge
        commandButton.lineWidth = 4
        addChild(commandButton)

        commandInnerBorder.fillColor = .clear
        commandInnerBorder.strokeColor = SKColor(red: 0.22, green: 0.12, blue: 0.10, alpha: 0.9)
        commandInnerBorder.lineWidth = 2
        addChild(commandInnerBorder)

        commandLabel.fontSize = 23
        commandLabel.fontColor = SKColor(white: 0.88, alpha: 1)
        commandLabel.horizontalAlignmentMode = .center
        commandLabel.verticalAlignmentMode = .center
        addChild(commandLabel)
    }

    @discardableResult
    private func addGeneratedFrameOverlay() -> Bool {
        guard let texture = GameArt.texture(named: "dialogue_outer_frame_overlay_v02") else { return false }
        texture.filteringMode = .linear
        frameOverlay.texture = texture
        frameOverlay.name = "dialogue.outer-frame-overlay"
        frameOverlay.centerRect = CGRect(x: 0.11, y: 0.15, width: 0.78, height: 0.70)
        frameOverlay.zPosition = -10
        panelRoot.addChild(frameOverlay)
        return true
    }

    private func layoutOrnament() {
        let claspWidth: CGFloat = 88
        let claspTop = panelRect.maxY + 3
        let claspBottom = panelRect.maxY - 32
        let claspRight = panelRect.maxX - 54
        let claspLeft = claspRight - claspWidth
        let clasp = CGMutablePath()
        clasp.move(to: CGPoint(x: claspLeft, y: claspTop))
        clasp.addLine(to: CGPoint(x: claspLeft + 18, y: claspBottom))
        clasp.addLine(to: CGPoint(x: claspRight - 18, y: claspBottom))
        clasp.addLine(to: CGPoint(x: claspRight, y: claspTop))
        clasp.move(to: CGPoint(x: claspLeft + 32, y: claspBottom + 10))
        clasp.addLine(to: CGPoint(x: claspLeft + 44, y: claspBottom + 23))
        clasp.addLine(to: CGPoint(x: claspLeft + 56, y: claspBottom + 10))
        topClasp.path = clasp

        let brackets = CGMutablePath()
        let inset: CGFloat = 13
        let length: CGFloat = 34
        let corners = [
            CGPoint(x: panelRect.minX + inset, y: panelRect.minY + inset),
            CGPoint(x: panelRect.maxX - inset, y: panelRect.minY + inset),
            CGPoint(x: panelRect.minX + inset, y: panelRect.maxY - inset),
            CGPoint(x: panelRect.maxX - inset, y: panelRect.maxY - inset)
        ]
        for (index, corner) in corners.enumerated() {
            let horizontalDirection: CGFloat = index % 2 == 0 ? 1 : -1
            let verticalDirection: CGFloat = index < 2 ? 1 : -1
            brackets.move(to: corner)
            brackets.addLine(to: CGPoint(x: corner.x + horizontalDirection * length, y: corner.y))
            brackets.move(to: corner)
            brackets.addLine(to: CGPoint(x: corner.x, y: corner.y + verticalDirection * length))
        }
        cornerBrackets.path = brackets

    }

    private func showCurrentNode(animated: Bool) {
        guard let node = currentNodeID.flatMap({ nodesByID[$0] }) else {
            finish()
            return
        }

        focusedChoiceIndex = nil
        hoveredChoiceIndex = nil
        commandIsHovered = false
        speakerLabel.text = node.speaker
        speakerLabel.fontColor = speakerColor(for: node.speaker)
        applyScrollOffset(0)
        dialogueLabel.text = node.text

        let isCaseTitle = node.speaker == "Case opened"
        dialogueLabel.fontName = isCaseTitle ? "Palatino-Bold" : "Palatino-Roman"
        dialogueLabel.fontSize = isCaseTitle ? 28 : 20
        dialogueLabel.fontColor = isCaseTitle ? Palette.caseTitle : Palette.parchment
        setPortrait(named: node.portraitName)
        rebuildChoices(node.choices)

        let panelTargetY: CGFloat = node.choices.isEmpty ? 0 : -60
        panelRoot.removeAction(forKey: "dialoguePanelPosition")
        if animated {
            panelRoot.run(.moveTo(y: panelTargetY, duration: 0.16), withKey: "dialoguePanelPosition")
        } else {
            panelRoot.position.y = panelTargetY
        }

        if !node.choices.isEmpty {
            commandKind = .hidden
            setCommandHidden(true)
        } else if node.endsDialogue {
            commandKind = .end
            commandLabel.text = "END DIALOGUE"
            setCommandHidden(false)
        } else if let nextNodeID = node.nextNodeID {
            commandKind = .next(nextNodeID)
            commandLabel.text = "CONTINUE"
            setCommandHidden(false)
        } else {
            commandKind = .end
            commandLabel.text = "END DIALOGUE"
            setCommandHidden(false)
        }

        refreshInteractionColors()
        if animated {
            let contentNodes: [SKNode] = [
                speakerLabel,
                dialogueLabel,
                portrait,
                portraitShadow,
                portraitBacking,
                portraitBorder,
                portraitPins,
                choicesRoot
            ]
            contentNodes.forEach { $0.alpha = 0 }
            contentNodes.forEach { $0.run(.fadeIn(withDuration: 0.13)) }
        }
    }

    private func rebuildChoices(_ choices: [CaseDialogueChoice]) {
        choicesRoot.removeAllChildren()
        choiceRows.removeAll()

        let left = contentViewportRect.minX
        let right = contentViewportRect.maxX
        let labelInset = DialoguePanelLayout.choiceLabelHorizontalInset
        let minimumRowHeight: CGFloat = 44
        let rowSpacing: CGFloat = 4
        // Body preferred width is set in layout(); re-assert so choice stacking uses the shipped contract.
        dialogueLabel.preferredMaxLayoutWidth = panelLayout.bodyTextMaxWidth
        let dialogueHeight = max(dialogueLabel.fontSize * 1.25, dialogueLabel.frame.height)
        var rowTop = contentViewportRect.maxY - dialogueHeight - 14
        var choicesHeight: CGFloat = 0

        for (index, choice) in choices.enumerated() {
            let label = SKLabelNode(fontNamed: "Palatino-Roman")
            label.text = "\(index + 1):  \(choice.text)"
            label.fontSize = 20
            label.fontColor = Palette.response
            label.horizontalAlignmentMode = .left
            label.verticalAlignmentMode = .center
            // Unlimited lines + max width from layout so long choices wrap inside the content viewport.
            label.numberOfLines = 0
            label.preferredMaxLayoutWidth = panelLayout.choiceTextMaxWidth
            let rowHeight = max(minimumRowHeight, label.frame.height + 12)
            let hitRect = CGRect(x: left, y: rowTop - rowHeight, width: right - left, height: rowHeight)

            let background = SKShapeNode(path: roundedRect(hitRect, radius: 2))
            background.fillColor = .clear
            background.strokeColor = .clear
            choicesRoot.addChild(background)

            label.position = CGPoint(x: hitRect.minX + labelInset, y: hitRect.midY - 2)
            choicesRoot.addChild(label)

            choiceRows.append(ChoiceRow(background: background, label: label, hitRect: hitRect))
            rowTop -= rowHeight + rowSpacing
            choicesHeight += rowHeight + (index == 0 ? 0 : rowSpacing)
        }

        let contentHeight = dialogueHeight + (choices.isEmpty ? 0 : choicesHeight + 14) + 12
        dialogueScrollbar.configure(
            viewportExtent: contentViewportRect.height,
            contentExtent: contentHeight,
            scrollOffset: 0
        )
        applyScrollOffset(0)
    }

    private func applyScrollOffset(_ offset: CGFloat) {
        scrollOffset = max(0, offset)
        scrollContentRoot.position.y = scrollOffset
    }

    private func ensureFocusedChoiceIsVisible() {
        guard let focusedChoiceIndex, choiceRows.indices.contains(focusedChoiceIndex) else { return }
        let rowRect = choiceRows[focusedChoiceIndex].hitRect.offsetBy(dx: 0, dy: scrollOffset)
        if rowRect.minY < contentViewportRect.minY {
            _ = dialogueScrollbar.scroll(by: contentViewportRect.minY - rowRect.minY + 4)
        } else if rowRect.maxY > contentViewportRect.maxY {
            _ = dialogueScrollbar.scroll(by: -(rowRect.maxY - contentViewportRect.maxY + 4))
        }
    }

    private func refreshInteractionColors() {
        for (index, row) in choiceRows.enumerated() {
            let isHot = index == focusedChoiceIndex || index == hoveredChoiceIndex
            row.label.fontColor = isHot ? Palette.responseHot : Palette.response
            row.background.fillColor = isHot
                ? SKColor(red: 0.22, green: 0.10, blue: 0.055, alpha: 0.52)
                : .clear
            row.background.strokeColor = isHot
                ? SKColor(red: 0.53, green: 0.34, blue: 0.16, alpha: 0.62)
                : .clear
            row.background.lineWidth = 1
        }

        commandLabel.fontColor = commandIsHovered ? Palette.responseHot : SKColor(white: 0.88, alpha: 1)
        commandButton.strokeColor = commandIsHovered ? Palette.responseHot : Palette.edge
    }

    private func setPortrait(named name: String?) {
        guard let name, let texture = GameArt.texture(named: name) else {
            portrait.texture = nil
            portrait.color = SKColor(white: 0.015, alpha: 1)
            portrait.colorBlendFactor = 1
            return
        }
        texture.filteringMode = .linear
        portrait.texture = texture
        portrait.colorBlendFactor = 0
    }

    private func setCommandHidden(_ hidden: Bool) {
        [commandShadow, commandButton, commandInnerBorder, commandLabel].forEach { $0.isHidden = hidden }
    }

    private func transition(to destinationID: String) {
        guard nodesByID[destinationID] != nil else {
            finish()
            return
        }
        currentNodeID = destinationID
        showCurrentNode(animated: true)
    }

    private func finish() {
        guard isPresenting else { return }
        isPresenting = false
        let completion = presentationCompletion
        presentationCompletion = nil
        run(.sequence([
            .fadeOut(withDuration: 0.24),
            .hide(),
            .run { completion?() }
        ]))
    }

    private func speakerColor(for speaker: String) -> SKColor {
        switch speaker {
        case "Vivian Hart": Palette.vivian
        case "Elias Vale": Palette.elias
        case "Case opened": Palette.caseTitle
        default: Palette.elias
        }
    }

    private func roundedRect(_ rect: CGRect, radius: CGFloat) -> CGPath {
        CGPath(
            roundedRect: rect,
            cornerWidth: radius,
            cornerHeight: radius,
            transform: nil
        )
    }
}
