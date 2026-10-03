import SpriteKit

/// `FadeToColor` / `FadeFromColor`.
///
/// BG's workhorse. A fade to black is how the engine covers a `JumpToPoint`
/// restage, a time skip, or an area change, and it is the only transition the
/// original game uses with any frequency.
///
/// Deliberately dumb: it holds a colour and an alpha and nothing else. The
/// byte alpha comes from `CutsceneFadeTimer`, which advances on the same
/// clock as every other beat. An `SKAction` here would put presentation on a
/// second timeline — the thing `LogicTickClock` exists to avoid for locomotion —
/// and it would leave the fade frozen in a review capture, which renders one
/// frame and never runs the action scheduler.
@MainActor
final class CutsceneFadeNode: SKSpriteNode {

    init() {
        super.init(texture: nil, color: .black, size: .zero)
        name = "cutscene.fade"
        zPosition = 2
        alpha = 0
        isHidden = true
        blendMode = .alpha
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("CutsceneFadeNode is created programmatically")
    }

    func layout(viewport: CGSize) {
        let bounds = viewport.width > 1 ? viewport : CGSize(width: 1_000, height: 700)
        // Oversized so a camera scale change cannot reveal an uncovered corner.
        size = CGSize(width: bounds.width * 2, height: bounds.height * 2)
    }

    func show(_ cutsceneColor: CutsceneColor, alpha value: CGFloat) {
        color = .black
        blendMode = .alpha
        alpha = value
        isHidden = value <= 0
    }

    func clear() {
        alpha = 0
        isHidden = true
        blendMode = .alpha
    }
}

/// Shared floater for GemRB `DisplayString` / `DisplayStringHead`.
///
/// Head-text parents this node to an actor. InfoPoint examine text parents it
/// to the world at the region. Same plate, same fade; the call site is what
/// distinguishes the two engine actions.
@MainActor
final class OverheadTextNode: SKNode {
    /// Roughly a head above a standing adult at the shipped body height.
    /// InfoPoint examine reuses it as "above the thing."
    static let heightAboveActor: CGFloat = 96

    init(
        text: String,
        name: String = "cutscene.overheadText",
        maxLayoutWidth: CGFloat = 340,
        numberOfLines: Int = 2
    ) {
        super.init()
        self.name = name
        let label = SKLabelNode(fontNamed: UITheme.Font.overlayBodyBold)
        label.text = text
        label.fontSize = 19
        label.fontColor = SKColor(white: 0.93, alpha: 1)
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        label.preferredMaxLayoutWidth = maxLayoutWidth
        label.numberOfLines = numberOfLines
        label.zPosition = 1

        // A soft plate behind the line: rain and a painted floor are a poor
        // background for unbacked text at this size.
        let padding = CGSize(width: 18, height: 10)
        let plate = SKShapeNode(
            rectOf: CGSize(
                width: label.frame.width + padding.width * 2,
                height: label.frame.height + padding.height * 2
            ),
            cornerRadius: 5
        )
        plate.fillColor = SKColor(white: 0.04, alpha: 0.62)
        plate.strokeColor = SKColor(white: 0.32, alpha: 0.5)
        plate.lineWidth = 1

        addChild(plate)
        addChild(label)
        alpha = 0
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("OverheadTextNode is created programmatically")
    }

    /// Fades in, holds for the authored beat, fades out, and removes itself.
    func play(for seconds: TimeInterval) {
        let fade = DisplayStringDuration.fadeDuration
        let hold = max(0, seconds - fade * 2)
        run(.sequence([
            .fadeIn(withDuration: fade),
            .wait(forDuration: hold),
            .fadeOut(withDuration: fade),
            .removeFromParent()
        ]))
    }
}
