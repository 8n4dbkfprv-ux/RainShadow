import SpriteKit

struct CaseDialogueLine {
    let speaker: String
    let text: String
}

@MainActor
final class CaseIntroductionPresenter: SKNode {
    private let panel = SKShapeNode()
    private let speakerLabel = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
    private let dialogueLabel = SKLabelNode(fontNamed: "AvenirNext-Regular")
    private let continueLabel = SKLabelNode(fontNamed: "AvenirNext-Medium")
    private var lines: [CaseDialogueLine] = []
    private var currentIndex = 0

    private(set) var isPresenting = false
    var onComplete: (() -> Void)?

    override init() {
        super.init()

        panel.fillColor = SKColor(red: 0.018, green: 0.02, blue: 0.026, alpha: 0.96)
        panel.strokeColor = SKColor(red: 0.48, green: 0.34, blue: 0.22, alpha: 0.88)
        panel.lineWidth = 2
        addChild(panel)

        speakerLabel.fontSize = 19
        speakerLabel.fontColor = SKColor(red: 0.8, green: 0.6, blue: 0.38, alpha: 1)
        speakerLabel.horizontalAlignmentMode = .left
        addChild(speakerLabel)

        dialogueLabel.fontSize = 22
        dialogueLabel.fontColor = SKColor(white: 0.91, alpha: 1)
        dialogueLabel.horizontalAlignmentMode = .left
        dialogueLabel.verticalAlignmentMode = .top
        dialogueLabel.numberOfLines = 3
        addChild(dialogueLabel)

        continueLabel.text = "TAP / CLICK / RETURN TO CONTINUE"
        continueLabel.fontSize = 13
        continueLabel.fontColor = SKColor(white: 0.58, alpha: 1)
        continueLabel.horizontalAlignmentMode = .right
        addChild(continueLabel)

        alpha = 0
        isHidden = true
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("CaseIntroductionPresenter is created programmatically")
    }

    func layout(for visibleSize: CGSize) {
        let width = min(1_100, max(620, visibleSize.width - 80))
        let height: CGFloat = 174
        panel.path = CGPath(
            roundedRect: CGRect(x: -width / 2, y: -height / 2, width: width, height: height),
            cornerWidth: 14,
            cornerHeight: 14,
            transform: nil
        )
        position = CGPoint(x: 0, y: -visibleSize.height / 2 + height / 2 + 24)
        speakerLabel.position = CGPoint(x: -width / 2 + 30, y: 45)
        dialogueLabel.position = CGPoint(x: -width / 2 + 30, y: 19)
        dialogueLabel.preferredMaxLayoutWidth = width - 60
        continueLabel.position = CGPoint(x: width / 2 - 26, y: -62)
    }

    func present(_ lines: [CaseDialogueLine]) {
        guard !lines.isEmpty else {
            onComplete?()
            return
        }
        removeAllActions()
        self.lines = lines
        currentIndex = 0
        isPresenting = true
        isHidden = false
        showCurrentLine()
        run(.fadeIn(withDuration: 0.22))
    }

    func advance() {
        guard isPresenting else { return }
        currentIndex += 1
        guard currentIndex < lines.count else {
            isPresenting = false
            run(.sequence([
                .fadeOut(withDuration: 0.25),
                .hide(),
                .run { [weak self] in self?.onComplete?() }
            ]))
            return
        }
        showCurrentLine()
    }

    private func showCurrentLine() {
        let line = lines[currentIndex]
        speakerLabel.text = line.speaker.uppercased()
        dialogueLabel.text = line.text

        let isCaseTitle = line.speaker == "Case opened"
        speakerLabel.fontColor = isCaseTitle
            ? SKColor(red: 0.78, green: 0.62, blue: 0.35, alpha: 1)
            : SKColor(red: 0.8, green: 0.6, blue: 0.38, alpha: 1)
        dialogueLabel.fontName = isCaseTitle ? "AvenirNextCondensed-DemiBold" : "AvenirNext-Regular"
        dialogueLabel.fontSize = isCaseTitle ? 27 : 22
    }
}
