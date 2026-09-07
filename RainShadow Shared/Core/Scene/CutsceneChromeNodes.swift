import SpriteKit

/// Letterbox bars — this project's `StartCutSceneMode` tell.
///
/// The Infinity Engine hides the whole GUI instead, which works because BG's
/// interface is a frame around the viewport rather than an overlay on it. Bars
/// are the equivalent gesture for a scene that draws edge to edge.
///
/// Lifted verbatim out of `DetectiveOfficeScene`, where it was private, so the
/// opening exterior and the city districts can letterbox too.
@MainActor
final class CutsceneLetterboxNode: SKNode {
    /// ~7.5% bars — a readable cue without burying the room.
    private static let barFraction: CGFloat = 0.075
    private static let minimumBarHeight: CGFloat = 28
    private static let fadeDuration: TimeInterval = 0.22

    private let top = SKSpriteNode(color: SKColor(white: 0.02, alpha: 1), size: .zero)
    private let bottom = SKSpriteNode(color: SKColor(white: 0.02, alpha: 1), size: .zero)
    private(set) var isShowing = false

    override init() {
        super.init()
        name = "cutscene.letterbox"
        zPosition = 1
        isHidden = true
        alpha = 0
        top.anchorPoint = CGPoint(x: 0.5, y: 1)
        bottom.anchorPoint = CGPoint(x: 0.5, y: 0)
        addChild(top)
        addChild(bottom)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("CutsceneLetterboxNode is created programmatically")
    }

    func layout(viewport: CGSize) {
        let size = viewport.width > 1 ? viewport : CGSize(width: 1_000, height: 700)
        let barHeight = max(Self.minimumBarHeight, size.height * Self.barFraction)
        // Overscan the width so a mid-fade resize cannot show a seam at the edges.
        top.size = CGSize(width: size.width + 40, height: barHeight)
        top.position = CGPoint(x: 0, y: size.height / 2)
        bottom.size = CGSize(width: size.width + 40, height: barHeight)
        bottom.position = CGPoint(x: 0, y: -size.height / 2)
    }

    /// A broken cutscene cuts the bars rather than easing them — the player asked
    /// for this now. What the bars *end up* doing is identical either way.
    ///
    /// The final alpha is assigned before the fade is queued, not by it. A fade
    /// that starts from zero is invisible until something ticks the scene, and
    /// the QA capture harness deliberately does not tick — it renders one frame
    /// off a launch with no drawable. Chrome that only exists once an `SKAction`
    /// has run is chrome that does not exist in a review capture.
    func setVisible(_ visible: Bool, animated: Bool = true) {
        guard isShowing != visible else { return }
        isShowing = visible
        removeAction(forKey: "visibility")
        let duration: TimeInterval = animated ? Self.fadeDuration : 0
        let from = alpha
        isHidden = !visible
        alpha = visible ? 1 : 0
        guard duration > 0 else { return }
        run(
            .sequence([
                .run { [weak self] in self?.alpha = from },
                .fadeAlpha(to: visible ? 1 : 0, duration: duration)
            ]),
            withKey: "visibility"
        )
    }
}

/// `FadeToColor` / `FadeFromColor`.
///
/// BG's workhorse. A fade to black is how the engine covers a `JumpToPoint`
/// restage, a time skip, or an area change, and it is the only transition the
/// original game uses with any frequency.
///
/// Deliberately dumb: it holds a colour and an alpha and nothing else. The
/// interpolation lives on `CutsceneDirector`, which advances it from the same
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

    /// Full opacity for a colour, as BG's packed-RGB fade would reach it.
    static func fullAlpha(for cutsceneColor: CutsceneColor) -> CGFloat {
        switch cutsceneColor {
        case .black: 1
        case .warmWindowBloom: 0.92
        }
    }

    func show(_ cutsceneColor: CutsceneColor, alpha value: CGFloat) {
        switch cutsceneColor {
        case .black:
            color = .black
            blendMode = .alpha
        case .warmWindowBloom:
            // The lit office window, blown out. Additive so it reads as light
            // rather than as a coloured sheet over the rain.
            color = SKColor(red: 0.78, green: 0.48, blue: 0.2, alpha: 1)
            blendMode = .add
        }
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
        let label = SKLabelNode(fontNamed: "AvenirNextCondensed-DemiBold")
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
