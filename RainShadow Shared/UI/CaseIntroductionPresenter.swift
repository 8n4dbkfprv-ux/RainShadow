import SpriteKit

@MainActor
final class CaseIntroductionPresenter: SKNode {
    private enum Palette {
        static let veil = SKColor.clear
        static let shadow = SKColor(white: 0, alpha: 0.78)
        /// Opaque black plate under the frame content hole only (text/portrait readability).
        static let contentWell = SKColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0)
        static let parchment = UITheme.Color.parchment
        static let response = UITheme.Color.oxblood
        static let responseHot = UITheme.Color.oxbloodHot
        /// Lila March — amber nameplate (noir, not fantasy magenta).
        static let lila = UITheme.Color.brass
        /// Harlan Voss — brass/amber nameplate.
        static let voss = UITheme.Color.brass
        static let caseTitle = UITheme.Color.brass
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

    private enum ScrollTarget {
        case body
        case choices
    }

    private let veil = SKShapeNode()
    private let panelRoot = SKNode()
    private let contentWell = SKShapeNode()
    private let frameOverlay = SKSpriteNode()
    private let bodyScrollbar = DialogueScrollbarNode()
    private let choicesScrollbar = DialogueScrollbarNode()
    private let portraitBacking = SKShapeNode()
    private let portrait = SKSpriteNode()
    private let speakerLabel = SKLabelNode(fontNamed: UITheme.Font.dialogueName)
    private let contentCrop = SKCropNode()
    private let contentMask = SKShapeNode()
    private let scrollContentRoot = SKNode()
    private let dialogueLabel = SKLabelNode(fontNamed: UITheme.Font.dialogueBody)
    private let choicesCrop = SKCropNode()
    private let choicesMask = SKShapeNode()
    private let choicesRoot = SKNode()
    private let commandPlate = SKSpriteNode()
    private let commandLabel = SKLabelNode(fontNamed: UITheme.Font.dialogueBodyBold)

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
    private var bodyScrollOffset: CGFloat = 0
    private var choicesScrollOffset: CGFloat = 0
    private var scrollTarget = ScrollTarget.body
    private var choicesContentExtent: CGFloat = 0
    private var usesGeneratedFrame = false
    private var presentationCompletion: (() -> Void)?
    private var lastVisibleSize: CGSize = .zero
    private var currentPanelOffsetY: CGFloat = 0
    /// Last node ID for which `onNodeShown` was delivered (avoids re-fire on layout-only refresh).
    private var lastNotifiedNodeID: String?
    /// Fired when a dialogue node is newly shown (initial present and each advance, not layout refresh).
    var onNodeShown: ((CaseDialogueNode) -> Void)?

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

        contentWell.path = roundedRect(geometry.contentWellRect, radius: 2)
        frameOverlay.position = CGPoint(x: panelRect.midX, y: panelRect.midY)
        frameOverlay.size = panelRect.size

        let portraitRect = geometry.portraitRect
        let photoRect = DialoguePanelLayout.portraitPhotoRect(in: geometry.panelRect)
        // Backing fills the painted window; live photo is a square fully inside the rim.
        portraitBacking.path = roundedRect(portraitRect, radius: 1)
        portrait.position = CGPoint(x: photoRect.midX, y: photoRect.midY)
        portrait.size = CGSize(width: photoRect.width, height: photoRect.height)

        // Speaker sits in the text column only — never over the portrait gold rails.
        let speakerX = geometry.contentViewportRect.minX
            + DialoguePanelLayout.bodyTextHorizontalInset
        let speakerTop = panelRect.maxY - DialoguePanelLayout.speakerTopInset
        speakerLabel.position = CGPoint(x: speakerX, y: speakerTop)
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

        _ = bodyContentHeight
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
        commandPlate.position = CGPoint(x: commandHitRect.midX, y: commandY)
        commandPlate.size = commandHitRect.size
        commandLabel.position = CGPoint(x: commandHitRect.midX, y: commandY - 2)
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
        lastNotifiedNodeID = nil
        isPresenting = true
        isHidden = false
        showCurrentNode(animated: false)
        run(.fadeIn(withDuration: 0.22))
    }

    @discardableResult
    func handlePointer(at point: CGPoint) -> Bool {
        guard isPresenting else { return false }
        let panelPoint = panelRoot.convert(point, from: self)

        if let index = choiceIndex(at: panelPoint) {
            focusedChoiceIndex = index
            activateFocusedControl()
            return true
        }

        if commandHitRect.contains(point), !commandPlate.isHidden {
            activateFocusedControl()
            return true
        }

        return panelRect.contains(panelPoint)
    }

    @discardableResult
    func handlePointerDown(at point: CGPoint) -> Bool {
        guard isPresenting else { return false }
        let panelPoint = panelRoot.convert(point, from: self)
        let choicesPoint = choicesScrollbar.convert(panelPoint, from: panelRoot)
        if !choicesScrollbar.isHidden,
           choicesScrollbar.handlePointerDown(at: choicesPoint) {
            scrollTarget = .choices
            return true
        }
        let bodyPoint = bodyScrollbar.convert(panelPoint, from: panelRoot)
        if !bodyScrollbar.isHidden,
           bodyScrollbar.handlePointerDown(at: bodyPoint) {
            scrollTarget = .body
            return true
        }
        return false
    }

    @discardableResult
    func handlePointerDragged(at point: CGPoint) -> Bool {
        guard isPresenting else { return false }
        let panelPoint = panelRoot.convert(point, from: self)
        let bodyPoint = bodyScrollbar.convert(panelPoint, from: panelRoot)
        let choicesPoint = choicesScrollbar.convert(panelPoint, from: panelRoot)
        let bodyHandled = !bodyScrollbar.isHidden
            && bodyScrollbar.handlePointerDragged(at: bodyPoint)
        let choicesHandled = !choicesScrollbar.isHidden
            && choicesScrollbar.handlePointerDragged(at: choicesPoint)
        return bodyHandled || choicesHandled
    }

    @discardableResult
    func handlePointerUp(at point: CGPoint) -> Bool {
        guard isPresenting else { return false }
        let panelPoint = panelRoot.convert(point, from: self)
        let bodyPoint = bodyScrollbar.convert(panelPoint, from: panelRoot)
        let choicesPoint = choicesScrollbar.convert(panelPoint, from: panelRoot)
        let bodyHandled = !bodyScrollbar.isHidden
            && bodyScrollbar.handlePointerUp(at: bodyPoint)
        let choicesHandled = !choicesScrollbar.isHidden
            && choicesScrollbar.handlePointerUp(at: choicesPoint)
        return bodyHandled || choicesHandled
    }

    @discardableResult
    func updatePointer(at point: CGPoint) -> Bool {
        guard isPresenting else { return false }
        let panelPoint = panelRoot.convert(point, from: self)
        hoveredChoiceIndex = choiceIndex(at: panelPoint)
        commandIsHovered = commandHitRect.contains(point) && !commandPlate.isHidden
        let bodyPoint = bodyScrollbar.convert(panelPoint, from: panelRoot)
        let choicesPoint = choicesScrollbar.convert(panelPoint, from: panelRoot)
        let bodyScrollbarIsHovered = !bodyScrollbar.isHidden
            && bodyScrollbar.updatePointer(at: bodyPoint)
        let choicesScrollbarIsHovered = !choicesScrollbar.isHidden
            && choicesScrollbar.updatePointer(at: choicesPoint)
        if choicesBandRect.contains(panelPoint) || choicesScrollbarIsHovered {
            scrollTarget = .choices
        } else if bodyViewportRect.contains(panelPoint) || bodyScrollbarIsHovered {
            scrollTarget = .body
        }
        refreshInteractionColors()
        return hoveredChoiceIndex != nil
            || commandIsHovered
            || bodyScrollbarIsHovered
            || choicesScrollbarIsHovered
    }

    @discardableResult
    func moveSelection(_ direction: Int) -> Bool {
        guard !choiceRows.isEmpty else { return false }
        let current = focusedChoiceIndex ?? (direction < 0 ? 0 : -1)
        focusedChoiceIndex = (current + direction + choiceRows.count) % choiceRows.count
        revealFocusedChoice()
        refreshInteractionColors()
        return true
    }

    @discardableResult
    func scrollContent(by points: CGFloat) -> Bool {
        switch scrollTarget {
        case .body:
            if !bodyScrollbar.isHidden, bodyScrollbar.scroll(by: points) { return true }
            return !choicesScrollbar.isHidden && choicesScrollbar.scroll(by: points)
        case .choices:
            if !choicesScrollbar.isHidden, choicesScrollbar.scroll(by: points) { return true }
            return !bodyScrollbar.isHidden && bodyScrollbar.scroll(by: points)
        }
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

        // Content well sits under text; painted frame rails draw over its edges.
        contentWell.fillColor = Palette.contentWell
        contentWell.strokeColor = .clear
        contentWell.zPosition = 0
        contentWell.name = "dialogue.content-well"
        panelRoot.addChild(contentWell)

        usesGeneratedFrame = addGeneratedFrameOverlay()
        assertionFailureIfMissingFrame()

        // Body and responses scroll independently. When both overflow they split the
        // same painted right-hand rail vertically, matching their on-screen regions.
        bodyScrollbar.name = "dialogue.scrollbar.body"
        bodyScrollbar.zPosition = 40
        bodyScrollbar.isHidden = true
        bodyScrollbar.onScroll = { [weak self] offset in
            self?.applyBodyScrollOffset(offset)
        }
        panelRoot.addChild(bodyScrollbar)
        choicesScrollbar.name = "dialogue.scrollbar.choices"
        choicesScrollbar.zPosition = 40
        choicesScrollbar.isHidden = true
        choicesScrollbar.onScroll = { [weak self] offset in
            self?.applyChoicesScrollOffset(offset)
        }
        panelRoot.addChild(choicesScrollbar)

        // Portrait sits under the frame so the painted gold window rim frames the photo
        // (frame must keep a transparent portrait hole — see process_ui_chrome_v03).
        portraitBacking.fillColor = SKColor(white: 0.012, alpha: 1)
        portraitBacking.strokeColor = .clear
        portraitBacking.lineWidth = 0
        portraitBacking.zPosition = 2
        panelRoot.addChild(portraitBacking)
        portrait.zPosition = 3
        panelRoot.addChild(portrait)

        speakerLabel.fontSize = DialoguePanelLayout.Typography.speakerFontSize
        speakerLabel.horizontalAlignmentMode = .left
        speakerLabel.verticalAlignmentMode = .top
        // Above the frame rails so the name stays readable in the content hole.
        speakerLabel.zPosition = 25
        panelRoot.addChild(speakerLabel)

        contentMask.fillColor = .white
        contentMask.strokeColor = .clear
        // Body text sits under the painted frame so transparent wells reveal it
        // while metal rails still clip any overflow. (Wells must stay transparent —
        // see process_ui_chrome_v03 dialogue pass.)
        contentCrop.maskNode = contentMask
        contentCrop.zPosition = 1
        panelRoot.addChild(contentCrop)
        contentCrop.addChild(scrollContentRoot)

        dialogueLabel.fontSize = DialoguePanelLayout.Typography.bodyFontSize
        dialogueLabel.fontColor = Palette.parchment
        dialogueLabel.horizontalAlignmentMode = .left
        dialogueLabel.verticalAlignmentMode = .top
        dialogueLabel.numberOfLines = 0
        scrollContentRoot.addChild(dialogueLabel)
        choicesMask.fillColor = .white
        choicesMask.strokeColor = .clear
        choicesCrop.maskNode = choicesMask
        choicesCrop.zPosition = 2
        panelRoot.addChild(choicesCrop)
        choicesRoot.zPosition = 0
        choicesRoot.name = "dialogue.choices-band"
        choicesCrop.addChild(choicesRoot)

        if let texture = UIPaintedChrome.texture(named: "dialogue_command_button_plate_v03") {
            commandPlate.texture = texture
            commandPlate.centerRect = CGRect(x: 0.12, y: 0.28, width: 0.76, height: 0.44)
            commandPlate.color = .white
            commandPlate.colorBlendFactor = 0
            commandPlate.alpha = 1
        }
        commandPlate.zPosition = 51
        addChild(commandPlate)

        commandLabel.fontSize = DialoguePanelLayout.Typography.commandFontSize
        commandLabel.fontColor = UITheme.Color.commandLabel
        commandLabel.fontName = UITheme.Font.overlayCondensed
        commandLabel.horizontalAlignmentMode = .center
        commandLabel.verticalAlignmentMode = .center
        commandLabel.zPosition = 53
        addChild(commandLabel)
    }

    private func assertionFailureIfMissingFrame() {
        if !usesGeneratedFrame {
            assertionFailure("Missing dialogue_outer_frame_overlay_v04.png")
        }
    }

    @discardableResult
    private func addGeneratedFrameOverlay() -> Bool {
        let texture = UIPaintedChrome.texture(named: "dialogue_outer_frame_overlay_v04")
            ?? UIPaintedChrome.texture(named: "dialogue_outer_frame_overlay_v03")
            ?? UIPaintedChrome.texture(named: "dialogue_outer_frame_overlay_v02")
        guard let texture else { return false }
        frameOverlay.texture = texture
        frameOverlay.name = "dialogue.outer-frame-overlay"
        // Large top-left fixed corner keeps the painted portrait window from stretching.
        frameOverlay.centerRect = DialoguePanelLayout.frameNineSliceCenterRect
        frameOverlay.zPosition = 10
        panelRoot.addChild(frameOverlay)
        return true
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
        applyBodyScrollOffset(0)
        applyChoicesScrollOffset(0)
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
                portraitBacking,
                choicesRoot
            ]
            contentNodes.forEach { $0.alpha = 0 }
            contentNodes.forEach { $0.run(.fadeIn(withDuration: 0.13)) }
        }
        // Layout-only rebuilds call showCurrentNode for the same ID; notify once per node.
        if lastNotifiedNodeID != node.id {
            lastNotifiedNodeID = node.id
            onNodeShown?(node)
        }
    }

    private func rebuildChoices(_ choices: [CaseDialogueChoice]) {
        choicesRoot.removeAllChildren()
        choicesRoot.position = .zero
        choicesMask.path = nil
        choiceRows.removeAll()
        choicesContentExtent = 0
        scrollTarget = .body
        applyBodyScrollOffset(0)
        applyChoicesScrollOffset(0)

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

        func pack(with heights: [CGFloat]) -> (
            band: CGRect,
            contentBand: CGRect,
            body: CGRect,
            frames: [CGRect],
            bodyContent: CGFloat
        ) {
            let natural = DialoguePanelLayout.naturalChoicesBandHeight(measuredRowHeights: heights)
            // Fixed plaque size (BG-style) — choices pack into the well; frame does not grow.
            let visible = lastVisibleSize.height > 1
                ? lastVisibleSize
                : CGSize(width: 1_000, height: OfficeInteriorScale.cameraVisibleHeight)
            let geometry = DialoguePanelLayout.layout(for: visible)
            applyPanelGeometry(geometry, preserveSplitRegions: false)

            let dialogueHeight = max(
                dialogueLabel.fontSize * 1.25,
                max(
                    dialogueLabel.frame.height,
                    DialogueTextMetrics.height(
                        text: dialogueLabel.text ?? "",
                        fontName: dialogueLabel.fontName ?? "Palatino-Roman",
                        fontSize: dialogueLabel.fontSize,
                        maxWidth: panelLayout.bodyTextMaxWidth
                    )
                )
            )
            let bodyContent = dialogueHeight + 12
            // Snug choices under short body text so the well is not mostly empty black.
            let snug = DialoguePanelLayout.snugBodyAndChoices(
                contentViewport: contentViewportRect,
                bodyContentHeight: bodyContent,
                naturalChoicesBandHeight: natural
            )
            let contentBand = DialoguePanelLayout.scrollableChoicesContentRect(
                visibleBand: snug.choices,
                naturalContentHeight: natural
            )
            let frames = DialoguePanelLayout.choiceRowFrames(
                band: contentBand,
                rowHeights: heights
            )
            return (snug.choices, contentBand, snug.body, frames, bodyContent)
        }

        var heights = measuredHeights
        var packed = pack(with: heights)

        applySplitContentRegions(
            bodyViewport: packed.body,
            choicesBand: packed.band,
            bodyContentHeight: packed.bodyContent
        )
        choicesMask.path = packed.band.isEmpty
            ? nil
            : CGPath(rect: packed.band, transform: nil)

        choiceRows.removeAll()
        choicesRoot.removeAllChildren()
        for (index, label) in labels.enumerated() {
            guard packed.frames.indices.contains(index) else { continue }
            let hitRect = packed.frames[index]
            let background = SKShapeNode(path: roundedRect(hitRect, radius: 2))
            background.fillColor = .clear
            background.strokeColor = .clear
            choicesRoot.addChild(background)
            label.position = CGPoint(x: hitRect.minX + labelInset, y: hitRect.maxY - 6)
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
        // Also re-pack if any row escaped the natural scroll content.
        if !DialoguePanelLayout.choiceFramesFitInBand(packed.frames, band: packed.contentBand) {
            needsRepack = true
        }
        if needsRepack {
            packed = pack(with: heights)
            applySplitContentRegions(
                bodyViewport: packed.body,
                choicesBand: packed.band,
                bodyContentHeight: packed.bodyContent
            )
            choicesMask.path = packed.band.isEmpty
                ? nil
                : CGPath(rect: packed.band, transform: nil)
            choiceRows.removeAll()
            choicesRoot.removeAllChildren()
            for (index, label) in labels.enumerated() {
                guard packed.frames.indices.contains(index) else { continue }
                let hitRect = packed.frames[index]
                let background = SKShapeNode(path: roundedRect(hitRect, radius: 2))
                background.fillColor = .clear
                background.strokeColor = .clear
                choicesRoot.addChild(background)
                label.position = CGPoint(x: hitRect.minX + labelInset, y: hitRect.maxY - 6)
                choicesRoot.addChild(label)
                choiceRows.append(ChoiceRow(background: background, label: label, hitRect: hitRect))
            }
        }

        choicesContentExtent = packed.contentBand.height
        let choicesNeedScroll = !packed.band.isEmpty
            && DialogueScrollbarGeometry.isScrollable(
                viewportExtent: packed.band.height,
                contentExtent: packed.contentBand.height
            )
        configureScrollbars(
            bodyViewport: packed.body,
            bodyContentExtent: packed.bodyContent,
            choicesViewport: packed.band,
            choicesContentExtent: packed.contentBand.height,
            choicesNeedScroll: choicesNeedScroll
        )
        applyBodyScrollOffset(0)
        applyChoicesScrollOffset(0)
    }

    private func configureScrollbars(
        bodyViewport: CGRect,
        bodyContentExtent: CGFloat,
        choicesViewport: CGRect,
        choicesContentExtent: CGFloat,
        choicesNeedScroll: Bool
    ) {
        let bodyNeedsScroll = DialogueScrollbarGeometry.isScrollable(
            viewportExtent: bodyViewport.height,
            contentExtent: bodyContentExtent
        )
        bodyScrollbar.isHidden = !bodyNeedsScroll
        choicesScrollbar.isHidden = !choicesNeedScroll

        let bodyRect: CGRect
        let choicesRect: CGRect
        if bodyNeedsScroll, choicesNeedScroll {
            let split = DialoguePanelLayout.splitScrollbarRects(
                fullScrollbarRect: panelLayout.scrollbarRect,
                contentViewport: contentViewportRect,
                choicesBand: choicesViewport
            )
            bodyRect = split.body
            choicesRect = split.choices
        } else {
            bodyRect = panelLayout.scrollbarRect
            choicesRect = panelLayout.scrollbarRect
        }

        if bodyNeedsScroll {
            bodyScrollbar.layout(in: bodyRect)
            bodyScrollbar.configure(
                viewportExtent: bodyViewport.height,
                contentExtent: bodyContentExtent,
                scrollOffset: 0
            )
        }
        if choicesNeedScroll {
            choicesScrollbar.layout(in: choicesRect)
            choicesScrollbar.configure(
                viewportExtent: choicesViewport.height,
                contentExtent: choicesContentExtent,
                scrollOffset: 0
            )
        }

        if choicesNeedScroll {
            scrollTarget = .choices
        } else {
            scrollTarget = .body
        }
    }

    private func applyBodyScrollOffset(_ offset: CGFloat) {
        bodyScrollOffset = max(0, offset)
        scrollContentRoot.position.y = bodyScrollOffset
    }

    private func applyChoicesScrollOffset(_ offset: CGFloat) {
        choicesScrollOffset = max(0, offset)
        choicesRoot.position.y = choicesScrollOffset
    }

    private func choiceIndex(at panelPoint: CGPoint) -> Int? {
        guard choicesBandRect.contains(panelPoint) else { return nil }
        let choicePoint = choicesRoot.convert(panelPoint, from: panelRoot)
        return choiceRows.firstIndex { $0.hitRect.contains(choicePoint) }
    }

    private func revealFocusedChoice() {
        guard !choicesScrollbar.isHidden,
              let index = focusedChoiceIndex,
              choiceRows.indices.contains(index)
        else { return }

        let visibleFrame = choiceRows[index].hitRect.offsetBy(
            dx: 0,
            dy: choicesRoot.position.y
        )
        var targetOffset = choicesScrollOffset
        if visibleFrame.height > choicesBandRect.height {
            // An unusually tall option cannot fit in one viewport; reveal its beginning
            // instead of snapping to the final line.
            targetOffset += choicesBandRect.maxY - visibleFrame.maxY
        } else if visibleFrame.minY < choicesBandRect.minY {
            targetOffset += choicesBandRect.minY - visibleFrame.minY
        } else if visibleFrame.maxY > choicesBandRect.maxY {
            targetOffset -= visibleFrame.maxY - choicesBandRect.maxY
        }
        let maximumOffset = max(0, choicesContentExtent - choicesBandRect.height)
        targetOffset = min(maximumOffset, max(0, targetOffset))
        _ = choicesScrollbar.scroll(by: targetOffset - choicesScrollOffset)
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

        commandLabel.fontColor = commandIsHovered ? Palette.responseHot : UITheme.Color.commandLabel
        if commandIsHovered {
            commandPlate.color = UITheme.Tint.hoverColor
            commandPlate.colorBlendFactor = UITheme.Tint.hoverBlend
        } else {
            commandPlate.color = .white
            commandPlate.colorBlendFactor = 0
        }
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
        [commandPlate, commandLabel].forEach { $0.isHidden = hidden }
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
        lastNotifiedNodeID = nil
        onNodeShown = nil
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
