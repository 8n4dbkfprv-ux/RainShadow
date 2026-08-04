import SpriteKit
#if os(macOS)
import AppKit
#else
import UIKit
#endif

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

    private enum ScrollTarget: Equatable {
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
    private let commandLabelShadow = SKLabelNode(fontNamed: UITheme.Font.dialogueCommand)
    private let commandLabel = SKLabelNode(fontNamed: UITheme.Font.dialogueCommand)

    /// Pure multi-graph walker (Phase 4). Presenter is a view over this session.
    private var session: DialogueSession?
    /// Case/dialogue flags and queued journal fragments.
    /// Scene merges `caseState` into `GameSession` when dialogue completes.
    var runtimeContext: DialogueRuntimeContext {
        session?.context
            ?? DialogueRuntimeContext(
                caseState: CaseState(caseID: EmptyCoatJournalContent.caseID),
                dialogueState: DialogueState(graphID: EmptyCoatDialogueKeys.graphID)
            )
    }
    private var nodesByID: [String: CaseDialogueNode] {
        session?.graph.nodesByID ?? [:]
    }
    private var currentNodeID: String? {
        session?.currentNodeID
    }
    private var visibleChoices: [CaseDialogueChoice] {
        session?.visibleChoices ?? []
    }
    private var choiceRows: [ChoiceRow] = []
    private var commandKind = CommandKind.hidden
    private var commandHitRect = CGRect.zero
    private var focusedChoiceIndex: Int?
    private var hoveredChoiceIndex: Int?
    private var commandIsHovered = false
    private var commandIsPressed = false
    private var commandPressIsInside = false
    private var commandIdleTexture: SKTexture?
    private var commandHoverTexture: SKTexture?
    private var commandPressedTexture: SKTexture?
    private var commandLabelText = ""
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
    private var bodyCanScroll = false
    private var choicesCanScroll = false
    private var choicesContentExtent: CGFloat = 0
    /// Scrollbar currently capturing a pointer drag (body or choices).
    private weak var activeScrollbar: DialogueScrollbarNode?
    private var usesGeneratedFrame = false
    private var usesWideCommandPlate = false
    private var presentationCompletion: (() -> Void)?
    private var lastVisibleSize: CGSize = .zero
    private var currentPanelOffsetY: CGFloat = 0
    /// Last node ID for which `onNodeShown` was delivered (avoids re-fire on layout-only refresh).
    private var lastNotifiedNodeID: String?
    /// Fired when a dialogue node is newly shown (initial present and each advance, not layout refresh).
    var onNodeShown: ((CaseDialogueNode) -> Void)?
    /// Called before Continue (or a choice) leaves `from` for `toDestinationID`.
    /// Return `true` to defer the transition (e.g. play a BG-style walk cinematic with
    /// no dialogue); the scene later calls `resumeAfterCutscene(advancingTo:)`.
    var shouldDeferAdvance: ((_ from: CaseDialogueNode, _ toDestinationID: String) -> Bool)?

    private(set) var isPresenting = false
    /// True while an authored walk/cutscene owns the screen (BG cutscene mode).
    /// Presentation graph stays live; panel and input are suppressed until resume.
    private(set) var isCutsceneSuppressed = false

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

        // Square plate under the slim metal rim — no corner radius gap at the top of the well.
        contentWell.path = roundedRect(geometry.contentWellRect, radius: 0)
        frameOverlay.position = CGPoint(x: panelRect.midX, y: panelRect.midY)
        frameOverlay.size = panelRect.size

        let portraitRect = geometry.portraitRect
        let photoRect = DialoguePanelLayout.portraitPhotoRect(in: geometry.panelRect)
        // Backing + photo both fill the measured portrait hole; frame metal draws the rim on top.
        portraitBacking.path = roundedRect(portraitRect, radius: 0)
        portrait.position = CGPoint(x: photoRect.midX, y: photoRect.midY)
        portrait.size = CGSize(width: photoRect.width, height: photoRect.height)

        // Speaker + body share one text-column left edge (no stair-step indent).
        // Top inset clears the painted metal rim so the name never overlaps the frame.
        let textColumnX = geometry.contentViewportRect.minX
            + DialoguePanelLayout.bodyTextHorizontalInset
        let speakerTop = panelRect.maxY
            - DialoguePanelLayout.speakerTopInset(forPanelHeight: panelRect.height)
        speakerLabel.position = CGPoint(x: textColumnX, y: speakerTop)
        // Default to full-column width; `rebuildChoices` re-resolves after measure so short
        // monologues keep even left/right padding and long bodies still clear the scrollbar.
        dialogueLabel.preferredMaxLayoutWidth = DialoguePanelLayout.bodyTextMaxWidth(
            contentViewport: geometry.contentViewportRect
        )
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
        // Match speaker X exactly (same inset from the shared content column).
        let textLeft = bodyViewport.minX + DialoguePanelLayout.bodyTextHorizontalInset
        contentMask.path = CGPath(rect: bodyViewport, transform: nil)
        dialogueLabel.position = CGPoint(x: textLeft, y: bodyViewport.maxY)
        if abs(speakerLabel.position.x - textLeft) > 0.01 {
            speakerLabel.position.x = textLeft
        }

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
        commandPlate.size = usesWideCommandPlate
            ? DialoguePanelLayout.commandPlateSize(in: commandHitRect)
            : commandHitRect.size
        // Palatino's centered glyph bounds need no legacy condensed-sans baseline offset.
        let labelPosition = CGPoint(x: commandHitRect.midX, y: commandY)
        commandLabel.position = labelPosition
        commandLabelShadow.position = CGPoint(
            x: labelPosition.x + DialoguePanelLayout.Typography.commandShadowOffset.x,
            y: labelPosition.y + DialoguePanelLayout.Typography.commandShadowOffset.y
        )
    }

    /// Present any authored graph through the shared session (Phase 4).
    func present(
        graph: DialogueGraph,
        context: DialogueRuntimeContext? = nil,
        onComplete: (() -> Void)? = nil
    ) {
        guard !graph.nodes.isEmpty, graph.node(id: graph.startNodeID) != nil else {
            onComplete?()
            return
        }

        removeAllActions()
        presentationCompletion = onComplete
        var seed = context
        if seed != nil {
            seed?.dialogueState.currentNodeID = graph.startNodeID
        }
        session = DialogueSession(graph: graph, context: seed)
        lastNotifiedNodeID = nil
        isPresenting = true
        isCutsceneSuppressed = false
        isHidden = false
        showCurrentNode(animated: false)
        run(.fadeIn(withDuration: 0.22))
    }

    /// Compatibility wrapper — builds an ad-hoc graph for legacy call sites.
    func present(
        _ nodes: [CaseDialogueNode],
        startingAt startID: String,
        context: DialogueRuntimeContext? = nil,
        onComplete: (() -> Void)? = nil
    ) {
        let graphID = context?.dialogueState.graphID.isEmpty == false
            ? (context?.dialogueState.graphID ?? "ad-hoc")
            : "ad-hoc"
        present(
            graph: DialogueGraph(id: graphID, startNodeID: startID, nodes: nodes),
            context: context,
            onComplete: onComplete
        )
    }

    /// Baldur’s Gate cutscene mode: hide the dialogue panel and block input without
    /// ending the graph (walk/cinematic owns the screen).
    func setCutsceneSuppressed(_ suppressed: Bool, animated: Bool = true) {
        guard isPresenting, isCutsceneSuppressed != suppressed else { return }
        isCutsceneSuppressed = suppressed
        removeAction(forKey: "cutsceneVisibility")
        if suppressed {
            commandIsPressed = false
            commandPressIsInside = false
            commandIsHovered = false
            refreshInteractionColors()
            if animated {
                isHidden = false
                run(.sequence([
                    .fadeOut(withDuration: 0.2),
                    .run { [weak self] in
                        self?.alpha = 0
                        self?.isHidden = true
                    }
                ]), withKey: "cutsceneVisibility")
            } else {
                alpha = 0
                isHidden = true
            }
        } else {
            isHidden = false
            if animated {
                if alpha >= 0.99 { return }
                run(.fadeIn(withDuration: 0.22), withKey: "cutsceneVisibility")
            } else {
                alpha = 1
            }
        }
    }

    /// After a walk cinematic: optionally jump to the deferred destination, then re-show dialogue.
    func resumeAfterCutscene(advancingTo destinationID: String? = nil) {
        guard isPresenting, var session else { return }
        if let destinationID, session.graph.node(id: destinationID) != nil {
            _ = session.jump(to: destinationID)
            self.session = session
            lastNotifiedNodeID = nil
            showCurrentNode(animated: false)
        }
        setCutsceneSuppressed(false)
    }

    /// Legacy name kept for call sites that still pass the cue id; prefers deferred advance.
    func resumeAfterCutscene(advancingIfOn cueNodeID: String?) {
        if let cueNodeID,
           currentNodeID == cueNodeID,
           let nextID = nodesByID[cueNodeID]?.nextNodeID {
            resumeAfterCutscene(advancingTo: nextID)
            return
        }
        resumeAfterCutscene(advancingTo: nil)
    }

    @discardableResult
    func handlePointer(at point: CGPoint) -> Bool {
        guard isPresenting, !isCutsceneSuppressed else { return false }
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
        guard isPresenting, !isCutsceneSuppressed else { return false }
        let panelPoint = panelRoot.convert(point, from: self)
        // Mouse hover normally selects the active region. A tap must do the same
        // for touch input, where no pointer-move event precedes the press.
        if choicesCanScroll, choicesBandRect.contains(panelPoint) {
            setScrollTarget(.choices)
        } else if bodyCanScroll, bodyViewportRect.contains(panelPoint) {
            setScrollTarget(.body)
        }
        // Hit-test the bar under the cursor — body and choices no longer share a rail.
        if bodyCanScroll {
            let bodyPoint = bodyScrollbar.convert(panelPoint, from: panelRoot)
            if bodyScrollbar.handlePointerDown(at: bodyPoint) {
                activeScrollbar = bodyScrollbar
                setScrollTarget(.body)
                return true
            }
        }
        if choicesCanScroll {
            let choicesPoint = choicesScrollbar.convert(panelPoint, from: panelRoot)
            if choicesScrollbar.handlePointerDown(at: choicesPoint) {
                activeScrollbar = choicesScrollbar
                setScrollTarget(.choices)
                return true
            }
        }
        activeScrollbar = nil

        if !commandPlate.isHidden, commandHitRect.contains(point) {
            commandIsPressed = true
            commandPressIsInside = true
            commandIsHovered = true
            refreshInteractionColors()
            return true
        }
        return false
    }

    @discardableResult
    func handlePointerDragged(at point: CGPoint) -> Bool {
        guard isPresenting, !isCutsceneSuppressed else { return false }
        if let bar = activeScrollbar {
            let panelPoint = panelRoot.convert(point, from: self)
            let localPoint = bar.convert(panelPoint, from: panelRoot)
            return bar.handlePointerDragged(at: localPoint)
        }
        if commandIsPressed {
            commandPressIsInside = commandHitRect.contains(point) && !commandPlate.isHidden
            commandIsHovered = commandPressIsInside
            refreshInteractionColors()
            return true
        }
        return false
    }

    @discardableResult
    func handlePointerUp(at point: CGPoint) -> Bool {
        guard isPresenting, !isCutsceneSuppressed else { return false }
        if let bar = activeScrollbar {
            let panelPoint = panelRoot.convert(point, from: self)
            let localPoint = bar.convert(panelPoint, from: panelRoot)
            let handled = bar.handlePointerUp(at: localPoint)
            activeScrollbar = nil
            return handled
        }
        if commandIsPressed {
            let activate = commandPressIsInside && commandHitRect.contains(point) && !commandPlate.isHidden
            commandIsPressed = false
            commandPressIsInside = false
            commandIsHovered = commandHitRect.contains(point) && !commandPlate.isHidden
            refreshInteractionColors()
            if activate {
                activateFocusedControl()
            }
            return true
        }
        return false
    }

    @discardableResult
    func updatePointer(at point: CGPoint) -> Bool {
        guard isPresenting, !isCutsceneSuppressed else { return false }
        let panelPoint = panelRoot.convert(point, from: self)
        hoveredChoiceIndex = choiceIndex(at: panelPoint)
        commandIsHovered = commandHitRect.contains(point) && !commandPlate.isHidden
        if choicesCanScroll, choicesBandRect.contains(panelPoint) {
            setScrollTarget(.choices)
        } else if bodyCanScroll, bodyViewportRect.contains(panelPoint) {
            setScrollTarget(.body)
        }

        var scrollbarIsHovered = false
        if bodyCanScroll {
            let bodyPoint = bodyScrollbar.convert(panelPoint, from: panelRoot)
            scrollbarIsHovered = bodyScrollbar.updatePointer(at: bodyPoint) || scrollbarIsHovered
        }
        if choicesCanScroll {
            let choicesPoint = choicesScrollbar.convert(panelPoint, from: panelRoot)
            scrollbarIsHovered = choicesScrollbar.updatePointer(at: choicesPoint) || scrollbarIsHovered
        }
        refreshInteractionColors()
        return hoveredChoiceIndex != nil
            || commandIsHovered
            || scrollbarIsHovered
    }

    @discardableResult
    func moveSelection(_ direction: Int) -> Bool {
        guard isPresenting, !isCutsceneSuppressed, !choiceRows.isEmpty else { return false }
        let current = focusedChoiceIndex ?? (direction < 0 ? 0 : -1)
        focusedChoiceIndex = (current + direction + choiceRows.count) % choiceRows.count
        if choicesCanScroll {
            setScrollTarget(.choices)
        }
        revealFocusedChoice()
        refreshInteractionColors()
        return true
    }

    @discardableResult
    func scrollContent(by points: CGFloat) -> Bool {
        guard isPresenting, !isCutsceneSuppressed else { return false }
        switch scrollTarget {
        case .body:
            if bodyCanScroll, bodyScrollbar.scroll(by: points) { return true }
            guard choicesCanScroll else { return false }
            setScrollTarget(.choices)
            return choicesScrollbar.scroll(by: points)
        case .choices:
            if choicesCanScroll, choicesScrollbar.scroll(by: points) { return true }
            guard bodyCanScroll else { return false }
            setScrollTarget(.body)
            return bodyScrollbar.scroll(by: points)
        }
    }

    func activateFocusedControl() {
        guard isPresenting, !isCutsceneSuppressed, var session else { return }

        if !choiceRows.isEmpty {
            let index = focusedChoiceIndex ?? hoveredChoiceIndex ?? 0
            guard
                let node = session.currentNode,
                session.visibleChoices.indices.contains(index)
            else { return }
            let destinationID = session.visibleChoices[index].destinationID
            // Apply select (actions + advance) then optionally defer presentation for cutscene.
            let result = session.selectChoice(at: index)
            self.session = session
            if shouldDeferAdvance?(node, destinationID) == true {
                return
            }
            applyStepResult(result, animated: true)
            return
        }

        switch commandKind {
        case .hidden:
            return
        case .next(let destinationID):
            guard let node = session.currentNode else {
                let result = session.jump(to: destinationID)
                self.session = session
                applyStepResult(result, animated: true)
                return
            }
            if shouldDeferAdvance?(node, destinationID) == true {
                return
            }
            let result = session.advanceContinue()
            self.session = session
            applyStepResult(result, animated: true)
        case .end:
            finish()
        }
    }

    /// Map pure session steps to presentation.
    private func applyStepResult(_ result: DialogueStepResult, animated: Bool) {
        switch result {
        case .showing:
            showCurrentNode(animated: animated)
        case .finished, .invalid:
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

        // Body scrolls on an inline bar beside the text crop; player choices keep the
        // painted right-hand rail. Both can be visible at once when each region overflows.
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

        if let texture = UIPaintedChrome.texture(named: "dialogue_command_button_plate_v07")
            ?? UIPaintedChrome.texture(named: "dialogue_command_button_plate_v06")
            ?? UIPaintedChrome.texture(named: "dialogue_command_button_plate_v05") {
            commandIdleTexture = texture
            commandHoverTexture = UIPaintedChrome.texture(named: "dialogue_command_button_plate_v07_hover")
            commandPressedTexture = UIPaintedChrome.texture(named: "dialogue_command_button_plate_v07_pressed")
            commandPlate.texture = texture
            commandPlate.centerRect = DialoguePanelLayout.commandFrameCenterRect
            commandPlate.color = .white
            commandPlate.colorBlendFactor = 0
            commandPlate.alpha = 1
            usesWideCommandPlate = true
        } else if let texture = UIPaintedChrome.texture(named: "dialogue_command_button_plate_v04")
            ?? UIPaintedChrome.texture(named: "dialogue_command_button_plate_v03") {
            commandIdleTexture = texture
            commandHoverTexture = nil
            commandPressedTexture = nil
            commandPlate.texture = texture
            commandPlate.centerRect = CGRect(x: 0.12, y: 0.28, width: 0.76, height: 0.44)
            commandPlate.color = .white
            commandPlate.colorBlendFactor = 0
            commandPlate.alpha = 1
        }
        commandPlate.zPosition = 51
        addChild(commandPlate)

        for label in [commandLabelShadow, commandLabel] {
            label.fontSize = DialoguePanelLayout.Typography.commandFontSize
            label.fontName = UITheme.Font.dialogueCommand
            label.horizontalAlignmentMode = .center
            label.verticalAlignmentMode = .center
        }
        commandLabelShadow.fontColor = Palette.shadow
        commandLabelShadow.zPosition = 52
        addChild(commandLabelShadow)
        commandLabel.fontColor = UITheme.Color.commandLabel
        commandLabel.zPosition = 53
        addChild(commandLabel)
    }

    private func assertionFailureIfMissingFrame() {
        if !usesGeneratedFrame {
            assertionFailure("Missing dialogue_outer_frame_overlay_v11.png")
        }
    }

    @discardableResult
    private func addGeneratedFrameOverlay() -> Bool {
        // v11 = v10 plaque with a thinner portrait bezel (same square aperture / metal style).
        let texture = UIPaintedChrome.texture(named: "dialogue_outer_frame_overlay_v11")
            ?? UIPaintedChrome.texture(named: "dialogue_outer_frame_overlay_v10")
            ?? UIPaintedChrome.texture(named: "dialogue_outer_frame_overlay_v08")
            ?? UIPaintedChrome.texture(named: "dialogue_outer_frame_overlay_v09")
            ?? UIPaintedChrome.texture(named: "dialogue_outer_frame_overlay_v07")
            ?? UIPaintedChrome.texture(named: "dialogue_outer_frame_overlay_v06")
            ?? UIPaintedChrome.texture(named: "dialogue_outer_frame_overlay_v05")
            ?? UIPaintedChrome.texture(named: "dialogue_outer_frame_overlay_v04")
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
        guard var session, let node = session.currentNode else {
            finish()
            return
        }
        session.noteCurrentNodeShown()
        self.session = session

        focusedChoiceIndex = nil
        hoveredChoiceIndex = nil
        commandIsHovered = false
        commandIsPressed = false
        commandPressIsInside = false
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
        let choices = session.visibleChoices
        #if DEBUG
        if session.isSoftStuck {
            assertionFailure(
                "Dialogue node \(node.id) has no visible choices, nextNodeID, or endsDialogue (authoring/gate error)"
            )
        }
        #endif
        rebuildChoices(choices)

        let hasVisibleChoices = !choices.isEmpty
        let visibleHeight = lastVisibleSize.height > 1 ? lastVisibleSize.height : 820
        let panelTargetY = DialoguePanelLayout.panelPresentationOffsetY(
            hasChoices: hasVisibleChoices,
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

        if hasVisibleChoices {
            commandKind = .hidden
            setCommandHidden(true)
        } else if node.endsDialogue {
            commandKind = .end
            setCommandLabelText("END DIALOGUE")
            setCommandHidden(false)
        } else if let nextNodeID = node.nextNodeID {
            commandKind = .next(nextNodeID)
            setCommandLabelText("CONTINUE")
            setCommandHidden(false)
        } else {
            commandKind = .end
            setCommandLabelText("END DIALOGUE")
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
        bodyCanScroll = false
        choicesCanScroll = false
        activeScrollbar = nil
        refreshVisibleScrollbar()
        applyBodyScrollOffset(0)
        applyChoicesScrollOffset(0)

        let labelInset = DialoguePanelLayout.choiceLabelHorizontalInset
        let fontSize = DialoguePanelLayout.Typography.choiceFontSize
        let maxWidth = panelLayout.choiceTextMaxWidth

        // CoreText multi-line measure (+ SK verify pass) — never scale rows below text height.
        var measuredHeights: [CGFloat] = []
        var labels: [SKLabelNode] = []
        for (index, choice) in choices.enumerated() {
            // Body may include GDD gate disclosure; metrics helper adds the "n:  " prefix.
            let body = choice.labeledBodyText
            let numbered = choice.displayText(index: index)
            let rowH = DialogueTextMetrics.choiceRowHeight(
                choiceText: body,
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

        func measureBodyHeight(maxWidth: CGFloat) -> CGFloat {
            max(
                dialogueLabel.fontSize * 1.25,
                max(
                    dialogueLabel.frame.height,
                    DialogueTextMetrics.height(
                        text: dialogueLabel.text ?? "",
                        fontName: dialogueLabel.fontName ?? "Palatino-Roman",
                        fontSize: dialogueLabel.fontSize,
                        maxWidth: maxWidth
                    )
                )
            )
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

            // Pass 1: measure at full symmetric column width (even left/right padding).
            let fullWidth = DialoguePanelLayout.bodyTextMaxWidth(
                contentViewport: contentViewportRect
            )
            dialogueLabel.preferredMaxLayoutWidth = fullWidth
            var bodyContent = measureBodyHeight(maxWidth: fullWidth) + 12
            var snug = DialoguePanelLayout.snugBodyAndChoices(
                contentViewport: contentViewportRect,
                bodyContentHeight: bodyContent,
                naturalChoicesBandHeight: natural
            )

            // Pass 2: if body overflows its viewport, shrink to the inline-scrollbar width
            // so glyphs clear the scroll chrome, then re-snug.
            let bodyTextMaxWidth = DialoguePanelLayout.resolvedBodyTextMaxWidth(
                contentViewport: contentViewportRect,
                bodyContentHeight: bodyContent,
                bodyViewportHeight: snug.body.height
            )
            if abs(bodyTextMaxWidth - fullWidth) > 0.5 {
                dialogueLabel.preferredMaxLayoutWidth = bodyTextMaxWidth
                bodyContent = measureBodyHeight(maxWidth: bodyTextMaxWidth) + 12
                snug = DialoguePanelLayout.snugBodyAndChoices(
                    contentViewport: contentViewportRect,
                    bodyContentHeight: bodyContent,
                    naturalChoicesBandHeight: natural
                )
            }

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
        bodyCanScroll = DialogueScrollbarGeometry.isScrollable(
            viewportExtent: bodyViewport.height,
            contentExtent: bodyContentExtent
        )
        let hasResponseChoices = !choicesViewport.isEmpty
        choicesCanScroll = hasResponseChoices && choicesNeedScroll

        if bodyCanScroll {
            bodyScrollbar.layout(
                in: DialoguePanelLayout.inlineBodyScrollbarRect(bodyViewport: bodyViewport)
            )
            bodyScrollbar.configure(
                viewportExtent: bodyViewport.height,
                contentExtent: bodyContentExtent,
                scrollOffset: 0,
                scrollUnit: DialoguePanelLayout.Typography.bodyFontSize * 1.25
            )
        }
        if choicesCanScroll {
            choicesScrollbar.layout(in: panelLayout.scrollbarRect)
            choicesScrollbar.configure(
                viewportExtent: choicesViewport.height,
                contentExtent: choicesContentExtent,
                scrollOffset: 0,
                scrollUnit: DialoguePanelLayout.Typography.choiceFontSize * 1.25
            )
        }

        // Prefer body for wheel/keyboard; hover still reassigns when over choices.
        if bodyCanScroll {
            setScrollTarget(.body)
        } else if choicesCanScroll {
            setScrollTarget(.choices)
        } else {
            setScrollTarget(.body)
        }
    }

    /// Body copy and response choices scroll independently: body uses an inline bar,
    /// choices use the painted rail. `scrollTarget` only selects which region receives
    /// wheel / keyboard scroll input.
    private func setScrollTarget(_ target: ScrollTarget) {
        switch target {
        case .body where bodyCanScroll:
            scrollTarget = .body
        case .choices where choicesCanScroll:
            scrollTarget = .choices
        case .body where choicesCanScroll:
            scrollTarget = .choices
        case .choices where bodyCanScroll:
            scrollTarget = .body
        default:
            scrollTarget = target
        }
        refreshVisibleScrollbar()
    }

    private func refreshVisibleScrollbar() {
        bodyScrollbar.isHidden = !bodyCanScroll
        choicesScrollbar.isHidden = !choicesCanScroll
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
        guard choicesCanScroll,
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

        updateCommandLabelAppearance()
        updateCommandPlateAppearance()
    }

    private func updateCommandPlateAppearance() {
        let isPressed = commandIsPressed && commandPressIsInside
        let isHot = commandIsHovered || isPressed
        if isPressed, let pressed = commandPressedTexture {
            commandPlate.texture = pressed
            commandPlate.color = .white
            commandPlate.colorBlendFactor = 0
        } else if isHot, let hover = commandHoverTexture {
            commandPlate.texture = hover
            commandPlate.color = .white
            commandPlate.colorBlendFactor = 0
        } else if let idle = commandIdleTexture {
            commandPlate.texture = idle
            commandPlate.color = .white
            commandPlate.colorBlendFactor = 0
        } else if isPressed {
            commandPlate.color = UITheme.Tint.pressedColor
            commandPlate.colorBlendFactor = UITheme.Tint.pressedBlend
        } else if isHot {
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
        // Square photo rect + square source: use the full texture (identity crop).
        // Linear filter keeps the hand-painted portrait smooth at UI scale.
        let mapped = SKTexture(rect: DialoguePanelLayout.portraitTextureCropRect, in: texture)
        mapped.filteringMode = .linear
        portrait.texture = mapped
        portrait.colorBlendFactor = 0
        // Re-assert square size in case geometry was laid out before the texture arrived.
        let photo = DialoguePanelLayout.portraitPhotoRect(in: panelRect)
        if photo.width > 1, photo.height > 1 {
            portrait.size = CGSize(width: photo.width, height: photo.height)
            portrait.position = CGPoint(x: photo.midX, y: photo.midY)
        }
    }

    private func setCommandHidden(_ hidden: Bool) {
        [commandPlate, commandLabelShadow, commandLabel].forEach { $0.isHidden = hidden }
    }

    private func setCommandLabelText(_ text: String) {
        commandLabelText = text.uppercased()
        commandLabel.text = commandLabelText
        commandLabelShadow.text = commandLabelText
        updateCommandLabelAppearance()
    }

    private func updateCommandLabelAppearance() {
        guard !commandLabelText.isEmpty else { return }
        let isHot = commandIsHovered || (commandIsPressed && commandPressIsInside)
        let foreground = isHot ? Palette.responseHot : UITheme.Color.commandLabel
        commandLabel.attributedText = commandAttributedText(commandLabelText, color: foreground)
        commandLabelShadow.attributedText = commandAttributedText(
            commandLabelText,
            color: SKColor(white: 0, alpha: 0.82)
        )
    }

    private func commandAttributedText(_ text: String, color: SKColor) -> NSAttributedString {
        let size = DialoguePanelLayout.Typography.commandFontSize
#if os(macOS)
        let font = NSFont(name: UITheme.Font.dialogueCommand, size: size)
            ?? NSFont.boldSystemFont(ofSize: size)
#else
        let font = UIFont(name: UITheme.Font.dialogueCommand, size: size)
            ?? UIFont.boldSystemFont(ofSize: size)
#endif
        let attributed = NSMutableAttributedString(
            string: text,
            attributes: [
                .font: font,
                .foregroundColor: color,
            ]
        )
        if attributed.length > 1 {
            attributed.addAttribute(
                .kern,
                value: DialoguePanelLayout.Typography.commandLetterSpacing,
                range: NSRange(location: 0, length: attributed.length - 1)
            )
        }
        return attributed
    }

    private func finish() {
        guard isPresenting else { return }
        isPresenting = false
        isCutsceneSuppressed = false
        lastNotifiedNodeID = nil
        onNodeShown = nil
        shouldDeferAdvance = nil
        // Keep session until next present so callers can still read runtimeContext.caseState.
        let completion = presentationCompletion
        presentationCompletion = nil
        removeAction(forKey: "cutsceneVisibility")
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
