import SpriteKit

@MainActor
final class ObservationPresenter: SKNode {
    private let panel: SKShapeNode
    private let nameLabel: SKLabelNode
    private let observationLabel: SKLabelNode

    override init() {
        panel = SKShapeNode(rectOf: CGSize(width: 1_240, height: 150), cornerRadius: 18)
        panel.fillColor = SKColor(red: 0.025, green: 0.025, blue: 0.03, alpha: 0.9)
        panel.strokeColor = SKColor(red: 0.36, green: 0.28, blue: 0.2, alpha: 0.75)
        panel.lineWidth = 3

        nameLabel = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        nameLabel.fontSize = 26
        nameLabel.fontColor = SKColor(red: 0.78, green: 0.62, blue: 0.42, alpha: 1)
        nameLabel.horizontalAlignmentMode = .left
        nameLabel.position = CGPoint(x: -580, y: 28)

        observationLabel = SKLabelNode(fontNamed: "AvenirNext-Regular")
        observationLabel.fontSize = 24
        observationLabel.fontColor = SKColor(white: 0.9, alpha: 1)
        observationLabel.horizontalAlignmentMode = .left
        observationLabel.verticalAlignmentMode = .top
        observationLabel.preferredMaxLayoutWidth = 1_150
        observationLabel.numberOfLines = 2
        observationLabel.position = CGPoint(x: -580, y: 4)

        super.init()
        addChild(panel)
        addChild(nameLabel)
        addChild(observationLabel)
        position = CGPoint(x: 0, y: -450)
        alpha = 0
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("ObservationPresenter is created programmatically")
    }

    func show(name: String, observation: String) {
        removeAction(forKey: "observation")
        nameLabel.text = name.uppercased()
        observationLabel.text = observation
        run(.sequence([
            .fadeIn(withDuration: 0.2),
            .wait(forDuration: 4.5),
            .fadeOut(withDuration: 0.45)
        ]), withKey: "observation")
    }
}

