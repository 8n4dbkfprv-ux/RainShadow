import SpriteKit

@MainActor
final class CaseIntroductionPresenter: SKNode {
    private enum Palette {
        static let veil = SKColor.clear
        static let shadow = SKColor(white: 0, alpha: 0.78)
        static let well = SKColor(red: 0.012, green: 0.018, blue: 0.017, alpha: 0.96)
        static let innerWell = SKColor(red: 0.018, green: 0.027, blue: 0.024, alpha: 0.80)
        /// Opaque black plate under the frame content hole only (text/portrait readability).
        static let contentWell = SKColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0)
        static let gunmetal = SKColor(red: 0.24, green: 0.27, blue: 0.27, alpha: 1)
        static let edge = SKColor(red: 0.50, green: 0.51, blue: 0.48, alpha: 0.84)
        static let darkEdge = SKColor(red: 0.075, green: 0.085, blue: 0.082, alpha: 1)
        static let parchment = SKColor(red: 0.86, green: 0.84, blue: 0.70, alpha: 1)
        static let response = SKColor(red: 0.76, green: 0.19, blue: 0.13, alpha: 1)
        static let responseHot = SKColor(red: 0.96, green: 0.69, blue: 0.28, alpha: 1)
        /// Lila March.
        static let lila = SKColor(red: 0.72, green: 0.16, blue: 0.36, alpha: 1)
        /// Harlan Voss.
        static let voss = SKColor(red: 0.78, green: 0.55, blue: 0.25, alpha: 1)
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
    /// Black fill for the frame's interior content hole only (not outer chrome underlay).
    private let contentWell = SKShapeNode()
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
    /// Scrolling body region (shrinks when a fixed choice band is present).
    private var bodyViewportRect = CGRect.zero
    /// Fixed response strip at the bottom of the content viewport (empty when no choices).
    private var choicesBandRect = CGRect.zero
    private var panelLayout = DialoguePanelLayout.layout(panelRect: CGRect(x: 0, y: 0, width: 1_000, height: 320))
    private var scrollOffset: CGFloat = 0
    private var usesGeneratedFrame = false
    private var presentationCompletion: (() -> Void)?
    private var lastVisibleSize: CGSize = .zero
    private var currentPanelOffsetY: CGFloat = 0

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
        lastVisibleSize = visibleSize
        applyPanelGeometry(
            DialoguePanelLayout.layout(for: visibleSize),
            preserveSplitRegions: true
        )
        layoutCommandControl(panelRootOffsetY: currentPanelOffsetY)
        if isPresenting {
            showCurrentNode(animated: false)
        }
    }

    /// Applies shipped layout geometry to panel chrome, portrait, and text metrics.
    private func applyPanelGeometry(
        _ geometry: DialoguePanelLayout,
        preserveSplitRegions: Bool,
        requiredChoicesBandHeight: CGFloat = 0
    ) {
        _ = requiredChoicesBandHeight
        panelLayout = geometry
        panelRect = geometry.panelRect
        contentViewportRect = geometry.contentViewportRect
        if !preserveSplitRegions || bodyViewportRect.height < 1 {
            bodyViewportRect = contentViewportRect
            choicesBandRect = .zero
        }

        let visibleSize = lastVisibleSize.height > 1
            ? lastVisibleSize
            : CGSize(width: 1_000, height: 700)
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
        contentWell.path = roundedRect(geometry.contentWellRect, radius: 2)
        frameOverlay.position = CGPoint(x: panelRect.midX, y: panelRect.midY)
        frameOverlay.size = panelRect.size
        layoutOrnament()

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

        let textLeft = contentViewportRect.minX + DialoguePanelLayout.bodyTextHorizontalInset
        speakerLabel.position = CGPoint(x: textLeft, y: panelRect.maxY - 42)
        dialogueLabel.preferredMaxLayoutWidth = geometry.bodyTextMaxWidth
        dialogueLabel.lineBreakMode = .byWordWrapping
        applySplitContentRegions(
            bodyViewport: bodyViewportRect.height > 1 ? bodyViewportRect : contentViewportRect,
            choicesBand: choicesBandRect
        )
    }

    /// Body crop + scrollbar track the upper viewport; choices use a separate fixed band.
    private func applySplitContentRegions(
        bodyViewport: CGRect,
        choicesBand: CGRect,
        bodyContentHeight: CGFloat? = nil
    ) {
        bodyViewportRect = bodyViewport
        choicesBandRect = choicesBand
        let textLeft = bodyViewport.minX + DialoguePanelLayout.bodyTextHorizontalInset
        contentMask.path = CGPath(rect: bodyViewport, transform: nil)
        dialogueLabel.position = CGPoint(x: textLeft, y: bodyViewport.maxY)

        let contentH = bodyContentHeight ?? max(dialogueLabel.fontSize * 1.25, dialogueLabel.frame.height) + 12
        let needsScroll = DialogueScrollbarGeometry.isScrollable(
            viewportExtent: bodyViewport.height,
            contentExtent: contentH
        )
        // Hide the whole control when the body fits — no tiny stub between arrows.
        dialogueScrollbar.isHidden = !needsScroll || bodyViewport.height < 48
        if !dialogueScrollbar.isHidden {
            dialogueScrollbar.layout(
                in: DialoguePanelLayout.bodyScrollbarRect(
                    fullScrollbarRect: panelLayout.scrollbarRect,
                    bodyViewport: bodyViewport
                )
            )
        }
    }

    /// Places Continue/End just under the dialogue panel so a lowered panel never covers it.
    private func layoutCommandControl(panelRootOffsetY: CGFloat) {
        let visibleHeight = lastVisibleSize.height > 1
            ? lastVisibleSize.height
            : 820
        commandHitRect = DialoguePanelLayout.commandHitRect(
            panelRect: panelRect,
            panelRootOffsetY: panelRootOffsetY,
            visibleHeight: visibleHeight,
            panelWidth: panelRect.width > 1 ? panelRect.width : 1_000
        )
        let commandY = commandHitRect.midY
        commandShadow.path = roundedRect(commandHitRect.offsetBy(dx: 7, dy: -8), radius: 5)
        commandButton.path = roundedRect(commandHitRect, radius: 4)
        commandInnerBorder.path = roundedRect(commandHitRect.insetBy(dx: 7, dy: 7), radius: 2)
        commandLabel.position = CGPoint(x: 0, y: commandY - 2)
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

        // Choices are fixed in panel space (not scrolled with body).
        if !choiceRows.isEmpty,
           choicesBandRect.contains(panelPoint) || choiceRows.contains(where: { $0.hitRect.contains(panelPoint) }),
           let index = choiceRows.firstIndex(where: { $0.hitRect.contains(panelPoint) }) {
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
        hoveredChoiceIndex = choiceRows.firstIndex { $0.hitRect.contains(panelPoint) }
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
        // Choices are fixed on screen — no scroll chase required.
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

        // Content well sits under text, above outer plates; frame rails draw over its edges.
        contentWell.fillColor = Palette.contentWell
        contentWell.strokeColor = .clear
        contentWell.zPosition = 0
        contentWell.name = "dialogue.content-well"
        panelRoot.addChild(contentWell)

        usesGeneratedFrame = addGeneratedFrameOverlay()
        applyUnderlayStyle(usesGeneratedFrame: usesGeneratedFrame)

        [topClasp, cornerBrackets].forEach {
            $0.fillColor = .clear
            $0.strokeColor = Palette.edge
            $0.lineWidth = 4
            $0.lineJoin = .round
            panelRoot.addChild($0)
        }
        topClasp.isHidden = usesGeneratedFrame
        cornerBrackets.isHidden = usesGeneratedFrame
        // Scrollbar must sit above the ornate frame rails (frame is above body text).
        dialogueScrollbar.zPosition = 40
        dialogueScrollbar.onScroll = { [weak self] offset in
            self?.applyScrollOffset(offset)
        }
        panelRoot.addChild(dialogueScrollbar)

        // Portrait stack above frame chrome so the bezel is never covered by the left rail.
        portraitShadow.fillColor = SKColor(white: 0, alpha: 0.72)
        portraitShadow.strokeColor = .clear
        portraitShadow.zPosition = 30
        panelRoot.addChild(portraitShadow)

        portraitBacking.fillColor = SKColor(white: 0.012, alpha: 1)
        portraitBacking.strokeColor = SKColor(red: 0.34, green: 0.10, blue: 0.11, alpha: 1)
        portraitBacking.lineWidth = 3
        portraitBacking.zPosition = 32
        panelRoot.addChild(portraitBacking)

        portraitBorder.fillColor = Palette.darkEdge
        portraitBorder.strokeColor = Palette.edge
        portraitBorder.lineWidth = 2
        portraitBorder.zPosition = 31
        panelRoot.addChild(portraitBorder)
        portrait.zPosition = 33
        panelRoot.addChild(portrait)

        portraitPins.fillColor = SKColor(red: 0.51, green: 0.42, blue: 0.29, alpha: 1)
        portraitPins.strokeColor = SKColor(red: 0.16, green: 0.13, blue: 0.10, alpha: 1)
        portraitPins.lineWidth = 1
        portraitPins.zPosition = 34
        panelRoot.addChild(portraitPins)

        speakerLabel.fontSize = DialoguePanelLayout.Typography.speakerFontSize
        speakerLabel.horizontalAlignmentMode = .left
        speakerLabel.verticalAlignmentMode = .top
        speakerLabel.zPosition = 25
        panelRoot.addChild(speakerLabel)

        contentMask.fillColor = .white
        contentMask.strokeColor = .clear
        contentCrop.maskNode = contentMask
        // Body text under the frame rails; portrait/scrollbar sit higher.
        contentCrop.zPosition = 1
        panelRoot.addChild(contentCrop)
        contentCrop.addChild(scrollContentRoot)

        dialogueLabel.fontSize = DialoguePanelLayout.Typography.bodyFontSize
        dialogueLabel.fontColor = Palette.parchment
        dialogueLabel.horizontalAlignmentMode = .left
        dialogueLabel.verticalAlignmentMode = .top
        dialogueLabel.numberOfLines = 0
        // Body only scrolls. Choices live in a fixed band under the body viewport.
        scrollContentRoot.addChild(dialogueLabel)
        choicesRoot.zPosition = 2
        choicesRoot.name = "dialogue.choices-band"
        panelRoot.addChild(choicesRoot)

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

        commandLabel.fontSize = DialoguePanelLayout.Typography.commandFontSize
        commandLabel.fontColor = SKColor(white: 0.88, alpha: 1)
        commandLabel.horizontalAlignmentMode = .center
        commandLabel.verticalAlignmentMode = .center
        // Above the dialogue panel so a lowered frame never paints over Continue.
        commandShadow.zPosition = 50
        commandButton.zPosition = 51
        commandInnerBorder.zPosition = 52
        commandLabel.zPosition = 53
        addChild(commandLabel)
    }

    /// When the generated frame art is present, hide full outer geometric plates but keep
    /// an opaque black **content well** under the frame's interior hole for readability.
    private func applyUnderlayStyle(usesGeneratedFrame: Bool) {
        // Content well is always on for readability (matches frame content hole only).
        contentWell.isHidden = false
        contentWell.fillColor = Palette.contentWell
        contentWell.strokeColor = .clear

        if usesGeneratedFrame {
            panel.fillColor = .clear
            panel.strokeColor = .clear
            panel.lineWidth = 0
            panel.isHidden = true
            innerPanel.fillColor = .clear
            innerPanel.strokeColor = .clear
            innerPanel.lineWidth = 0
            innerPanel.isHidden = true
            innerBorder.fillColor = .clear
            innerBorder.strokeColor = .clear
            innerBorder.lineWidth = 0
            innerBorder.isHidden = true
            panelShadow.fillColor = .clear
            panelShadow.strokeColor = .clear
            panelShadow.isHidden = true
        } else {
            panel.isHidden = false
            innerPanel.isHidden = false
            innerBorder.isHidden = false
            panelShadow.isHidden = false
            panel.fillColor = Palette.darkEdge
            panel.strokeColor = Palette.gunmetal
            panel.lineWidth = 7
            innerPanel.fillColor = Palette.well
            innerPanel.strokeColor = Palette.edge
            innerPanel.lineWidth = 2
            innerBorder.fillColor = Palette.innerWell
            innerBorder.strokeColor = SKColor(red: 0.12, green: 0.15, blue: 0.14, alpha: 1)
            innerBorder.lineWidth = 2
            panelShadow.fillColor = Palette.shadow
            panelShadow.strokeColor = .clear
        }
    }

    @discardableResult
    private func addGeneratedFrameOverlay() -> Bool {
        guard let texture = GameArt.texture(named: "dialogue_outer_frame_overlay_v02") else { return false }
        texture.filteringMode = .linear
        frameOverlay.texture = texture
        frameOverlay.name = "dialogue.outer-frame-overlay"
        frameOverlay.centerRect = CGRect(x: 0.11, y: 0.15, width: 0.78, height: 0.70)
        // Above body text (z=1) so overflow cannot paint on chrome; below portrait (z≥30)
        // and scrollbar (z=40) so those controls stay fully visible.
        frameOverlay.zPosition = 10
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

        let isCaseTitle = node.speaker == "Case opened" || node.speaker == EmptyCoatCaseIntroduction.caseOpenedSpeaker
        if isCaseTitle {
            dialogueLabel.fontName = "Palatino-Bold"
            dialogueLabel.fontSize = DialoguePanelLayout.Typography.caseTitleFontSize
            dialogueLabel.fontColor = Palette.caseTitle
        } else if node.isInteriorMonologue {
            // Interior narration: italics so players can tell Voss is thinking, not speaking aloud.
            dialogueLabel.fontName = "Palatino-Italic"
            dialogueLabel.fontSize = DialoguePanelLayout.Typography.bodyFontSize
            dialogueLabel.fontColor = Palette.parchment
        } else {
            dialogueLabel.fontName = "Palatino-Roman"
            dialogueLabel.fontSize = DialoguePanelLayout.Typography.bodyFontSize
            dialogueLabel.fontColor = Palette.parchment
        }
        setPortrait(named: node.portraitName)
        rebuildChoices(node.choices)

        let visibleHeight = lastVisibleSize.height > 1 ? lastVisibleSize.height : 820
        let panelTargetY = DialoguePanelLayout.panelPresentationOffsetY(
            hasChoices: !node.choices.isEmpty,
            panelRect: panelRect,
            visibleHeight: visibleHeight
        )
        currentPanelOffsetY = panelTargetY
        panelRoot.removeAction(forKey: "dialoguePanelPosition")
        if animated {
            panelRoot.run(.moveTo(y: panelTargetY, duration: 0.16), withKey: "dialoguePanelPosition")
        } else {
            panelRoot.position.y = panelTargetY
        }
        // Track the panel so Continue stays visible under the frame, not buried by it.
        layoutCommandControl(panelRootOffsetY: panelTargetY)

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

        dialogueLabel.preferredMaxLayoutWidth = panelLayout.bodyTextMaxWidth
        let labelInset = DialoguePanelLayout.choiceLabelHorizontalInset
        let fontSize = DialoguePanelLayout.Typography.choiceFontSize
        let maxWidth = panelLayout.choiceTextMaxWidth

        // CoreText multi-line measure (+ SK verify pass) — never scale rows below text height.
        var measuredHeights: [CGFloat] = []
        var labels: [SKLabelNode] = []
        for (index, choice) in choices.enumerated() {
            let numbered = "\(index + 1):  \(choice.text)"
            let rowH = DialogueTextMetrics.choiceRowHeight(
                choiceText: choice.text,
                index: index,
                fontSize: fontSize,
                maxWidth: maxWidth,
                minimumRowHeight: DialoguePanelLayout.choiceRowMinimumHeight,
                verticalPadding: DialoguePanelLayout.choiceRowVerticalPadding
            )
            measuredHeights.append(rowH)

            let label = SKLabelNode(fontNamed: "Palatino-Roman")
            label.text = numbered
            label.fontSize = fontSize
            label.fontColor = Palette.response
            label.horizontalAlignmentMode = .left
            label.verticalAlignmentMode = .top
            label.numberOfLines = 0
            label.preferredMaxLayoutWidth = maxWidth
            labels.append(label)
        }

        // SK verify: parent labels, read true wrapped frames, take max with CT heights.
        for (index, label) in labels.enumerated() {
            choicesRoot.addChild(label)
            label.position = .zero
            let skH = label.frame.height + DialoguePanelLayout.choiceRowVerticalPadding
            measuredHeights[index] = max(
                measuredHeights[index],
                max(DialoguePanelLayout.choiceRowMinimumHeight, skH)
            )
            label.removeFromParent()
        }

        func pack(with heights: [CGFloat]) -> (band: CGRect, body: CGRect, frames: [CGRect], bodyContent: CGFloat) {
            let natural = DialoguePanelLayout.naturalChoicesBandHeight(measuredRowHeights: heights)
            // Grow the panel when natural multi-line rows exceed the current well.
            let visible = lastVisibleSize.height > 1
                ? lastVisibleSize
                : CGSize(width: 1_000, height: OfficeInteriorScale.cameraVisibleHeight)
            let geometry = DialoguePanelLayout.layout(
                for: visible,
                requiredChoicesBandHeight: natural
            )
            applyPanelGeometry(geometry, preserveSplitRegions: false)

            let bandHeight = DialoguePanelLayout.choicesBandHeight(
                measuredRowHeights: heights,
                contentViewportHeight: contentViewportRect.height
            )
            // After growth, bandHeight should equal natural (within maxBand of the new well).
            let bodyViewport = DialoguePanelLayout.bodyViewportRect(
                contentViewport: contentViewportRect,
                choicesBandHeight: bandHeight
            )
            let choicesBand = DialoguePanelLayout.choicesBandRect(
                contentViewport: contentViewportRect,
                choicesBandHeight: bandHeight
            )
            let frames = DialoguePanelLayout.choiceRowFrames(band: choicesBand, rowHeights: heights)
            let dialogueHeight = max(
                dialogueLabel.fontSize * 1.25,
                DialogueTextMetrics.height(
                    text: dialogueLabel.text ?? "",
                    fontName: dialogueLabel.fontName ?? "Palatino-Roman",
                    fontSize: dialogueLabel.fontSize,
                    maxWidth: panelLayout.bodyTextMaxWidth
                )
            )
            return (choicesBand, bodyViewport, frames, dialogueHeight + 12)
        }

        var heights = measuredHeights
        var packed = pack(with: heights)

        applySplitContentRegions(
            bodyViewport: packed.body,
            choicesBand: packed.band,
            bodyContentHeight: packed.bodyContent
        )

        choiceRows.removeAll()
        choicesRoot.removeAllChildren()
        for (index, label) in labels.enumerated() {
            guard packed.frames.indices.contains(index) else { continue }
            let hitRect = packed.frames[index]
            let background = SKShapeNode(path: roundedRect(hitRect, radius: 2))
            background.fillColor = .clear
            background.strokeColor = .clear
            choicesRoot.addChild(background)
            label.position = CGPoint(x: hitRect.minX + labelInset, y: hitRect.maxY - 4)
            choicesRoot.addChild(label)
            choiceRows.append(ChoiceRow(background: background, label: label, hitRect: hitRect))
        }

        // Final SK pass: if any label still draws taller than its row, re-pack once.
        var needsRepack = false
        for (index, row) in choiceRows.enumerated() {
            let needed = max(
                heights[index],
                row.label.frame.height + DialoguePanelLayout.choiceRowVerticalPadding
            )
            if needed > heights[index] + 0.5 {
                heights[index] = needed
                needsRepack = true
            }
        }
        if needsRepack {
            packed = pack(with: heights)
            applySplitContentRegions(
                bodyViewport: packed.body,
                choicesBand: packed.band,
                bodyContentHeight: packed.bodyContent
            )
            choiceRows.removeAll()
            choicesRoot.removeAllChildren()
            for (index, label) in labels.enumerated() {
                guard packed.frames.indices.contains(index) else { continue }
                let hitRect = packed.frames[index]
                let background = SKShapeNode(path: roundedRect(hitRect, radius: 2))
                background.fillColor = .clear
                background.strokeColor = .clear
                choicesRoot.addChild(background)
                label.position = CGPoint(x: hitRect.minX + labelInset, y: hitRect.maxY - 4)
                choicesRoot.addChild(label)
                choiceRows.append(ChoiceRow(background: background, label: label, hitRect: hitRect))
            }
        }

        if !dialogueScrollbar.isHidden {
            dialogueScrollbar.configure(
                viewportExtent: packed.body.height,
                contentExtent: packed.bodyContent,
                scrollOffset: 0
            )
        }
        applyScrollOffset(0)
    }

    private func applyScrollOffset(_ offset: CGFloat) {
        scrollOffset = max(0, offset)
        scrollContentRoot.position.y = scrollOffset
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
        case EmptyCoatCaseIntroduction.lilaSpeaker:
            Palette.lila
        case EmptyCoatCaseIntroduction.vossSpeaker:
            Palette.voss
        case EmptyCoatCaseIntroduction.caseOpenedSpeaker, "Case opened":
            Palette.caseTitle
        default:
            Palette.voss
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
