import SpriteKit

@MainActor
final class DialogueScrollbarNode: SKNode {
    private enum Part {
        case upButton
        case downButton
        case track
        case thumb
    }

    private let upButton = SKSpriteNode()
    private let downButton = SKSpriteNode()
    private let track = SKSpriteNode()
    private let thumb = SKSpriteNode()

    private var upNormalTexture: SKTexture?
    private var upPressedTexture: SKTexture?
    private var downNormalTexture: SKTexture?
    private var downPressedTexture: SKTexture?
    private var areaDitherTexture: SKTexture?
    private var areaSolidTexture: SKTexture?

    private var controlBounds = CGRect.zero
    private var upButtonRect = CGRect.zero
    private var downButtonRect = CGRect.zero
    private var trackRect = CGRect.zero
    private var thumbRect = CGRect.zero
    private var viewportExtent: CGFloat = 1
    private var contentExtent: CGFloat = 1
    private var scrollOffset: CGFloat = 0
    private var scrollUnit: CGFloat = DialoguePanelLayout.Typography.bodyFontSize * 1.25
    private var activePart: Part?
    private var pointerInside = false
    private var dragGrabOffsetY: CGFloat = 0

    var onScroll: ((CGFloat) -> Void)?

    private var maximumScrollOffset: CGFloat {
        max(0, contentExtent - viewportExtent)
    }

    private var isScrollable: Bool {
        DialogueScrollbarGeometry.isScrollable(
            viewportExtent: viewportExtent,
            contentExtent: contentExtent
        )
    }

    /// Exposed for tests that inspect the last laid-out thumb without SpriteKit scene bootstrap.
    private(set) var lastThumbLayout = DialogueScrollbarGeometry.ThumbLayout(
        isScrollable: false,
        thumbVisible: false,
        thumbRect: .zero
    )

    override init() {
        super.init()
        name = "dialogue.scrollbar"
        upNormalTexture = loadTexture(named: "dialogue_scroll_up_v06", fallback: "dialogue_scroll_up_v05")
        upPressedTexture = loadTexture(named: "dialogue_scroll_up_pressed_v06", fallback: "dialogue_scroll_up_v05")
        downNormalTexture = loadTexture(named: "dialogue_scroll_down_v06", fallback: "dialogue_scroll_down_v05")
        downPressedTexture = loadTexture(
            named: "dialogue_scroll_down_pressed_v06",
            fallback: "dialogue_scroll_down_v05"
        )
        areaDitherTexture = loadTexture(
            named: "dialogue_scroll_area_v06",
            fallback: "dialogue_scroll_track_v05",
            filtering: .nearest
        )
        areaSolidTexture = loadTexture(
            named: "dialogue_scroll_area_solid_v06",
            fallback: "dialogue_scroll_track_v05",
            filtering: .nearest
        )
        installTexture(upNormalTexture, on: upButton)
        installTexture(downNormalTexture, on: downButton)
        installTexture(areaDitherTexture, on: track)
        installTexture(
            loadTexture(named: "dialogue_scroll_box_v06", fallback: "dialogue_scroll_thumb_v07"),
            on: thumb
        )

        track.zPosition = 0
        upButton.zPosition = 1
        downButton.zPosition = 1
        thumb.zPosition = 2

        [track, upButton, downButton, thumb].forEach(addChild)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("DialogueScrollbarNode is created programmatically")
    }

    func layout(in rect: CGRect) {
        position = CGPoint(x: rect.midX, y: rect.midY)
        controlBounds = CGRect(x: -rect.width / 2, y: -rect.height / 2, width: rect.width, height: rect.height)

        let chrome = DialogueScrollbarGeometry.chromeLayout(bounds: controlBounds)
        upButtonRect = chrome.upButton
        downButtonRect = chrome.downButton
        trackRect = chrome.track

        upButton.position = CGPoint(x: upButtonRect.midX, y: upButtonRect.midY)
        upButton.size = upButtonRect.size
        downButton.position = CGPoint(x: downButtonRect.midX, y: downButtonRect.midY)
        downButton.size = downButtonRect.size
        track.position = CGPoint(x: trackRect.midX, y: trackRect.midY)
        track.size = trackRect.size
        refreshTrackTexture()
        refreshThumbGeometry()
    }

    func configure(
        viewportExtent: CGFloat,
        contentExtent: CGFloat,
        scrollOffset: CGFloat = 0,
        scrollUnit: CGFloat = DialoguePanelLayout.Typography.bodyFontSize * 1.25
    ) {
        self.viewportExtent = max(1, viewportExtent)
        self.contentExtent = max(self.viewportExtent, contentExtent)
        self.scrollUnit = max(1, scrollUnit)
        setScrollOffset(scrollOffset, notify: false)
        refreshTrackTexture()
        refreshThumbGeometry()
        refreshAppearance()
    }

    @discardableResult
    func scroll(by points: CGFloat) -> Bool {
        guard isScrollable else { return false }
        let previous = scrollOffset
        setScrollOffset(scrollOffset + points, notify: true)
        return abs(scrollOffset - previous) > 0.01
    }

    @discardableResult
    func handlePointerDown(at point: CGPoint) -> Bool {
        guard controlBounds.contains(point) else { return false }
        let part = part(at: point)
        activePart = part

        let step = DialogueScrollbarGeometry.arrowStep(lineHeight: scrollUnit)
        let page = DialogueScrollbarGeometry.pageStep(
            viewportExtent: viewportExtent,
            lineHeight: scrollUnit
        )
        switch part {
        case .upButton:
            _ = scroll(by: -step)
        case .downButton:
            _ = scroll(by: step)
        case .track:
            if point.y > thumbRect.maxY {
                _ = scroll(by: -page)
            } else if point.y < thumbRect.minY {
                _ = scroll(by: page)
            }
        case .thumb:
            dragGrabOffsetY = point.y - thumb.position.y
        }

        refreshAppearance()
        return true
    }

    @discardableResult
    func handlePointerDragged(at point: CGPoint) -> Bool {
        guard activePart != nil else { return false }
        guard activePart == .thumb, isScrollable else { return true }

        let travel = max(0, trackRect.height - thumbRect.height)
        guard travel > 0 else { return true }
        let topCenter = trackRect.maxY - thumbRect.height / 2
        let bottomCenter = trackRect.minY + thumbRect.height / 2
        let proposedCenter = point.y - dragGrabOffsetY
        let centerY = min(topCenter, max(bottomCenter, proposedCenter))
        let fraction = (topCenter - centerY) / travel
        setScrollOffset(fraction * maximumScrollOffset, notify: true)
        return true
    }

    @discardableResult
    func handlePointerUp(at point: CGPoint) -> Bool {
        let handled = activePart != nil
        activePart = nil
        dragGrabOffsetY = 0
        pointerInside = controlBounds.contains(point)
        refreshAppearance()
        return handled
    }

    @discardableResult
    func updatePointer(at point: CGPoint) -> Bool {
        // System 7 has no hover tint; still report hit so the scene can show a hand cursor.
        pointerInside = controlBounds.contains(point)
        refreshAppearance()
        return pointerInside
    }

    private func loadTexture(
        named name: String,
        fallback: String,
        filtering: SKTextureFilteringMode = .linear
    ) -> SKTexture? {
        if let texture = UIPaintedChrome.texture(named: name, filtering: filtering) {
            return texture
        }
        return UIPaintedChrome.texture(named: fallback, filtering: filtering)
    }

    private func installTexture(_ texture: SKTexture?, on sprite: SKSpriteNode) {
        guard let texture else {
            assertionFailure("Missing scrollbar chrome")
            return
        }
        sprite.texture = texture
        sprite.color = .white
        sprite.colorBlendFactor = 0
    }

    private func part(at point: CGPoint) -> Part {
        if upButtonRect.contains(point) { return .upButton }
        if downButtonRect.contains(point) { return .downButton }
        if thumbRect.contains(point), isScrollable, !thumb.isHidden { return .thumb }
        return .track
    }

    private func setScrollOffset(_ offset: CGFloat, notify: Bool) {
        let clamped = min(maximumScrollOffset, max(0, offset))
        guard abs(clamped - scrollOffset) > 0.01 else {
            scrollOffset = clamped
            refreshThumbGeometry()
            return
        }
        scrollOffset = clamped
        refreshThumbGeometry()
        if notify {
            onScroll?(scrollOffset)
        }
    }

    private func refreshThumbGeometry() {
        guard trackRect.height > 0 else { return }
        let layout = DialogueScrollbarGeometry.thumbLayout(
            trackRect: trackRect,
            viewportExtent: viewportExtent,
            contentExtent: contentExtent,
            scrollOffset: scrollOffset
        )
        lastThumbLayout = layout
        thumbRect = layout.thumbRect
        thumb.isHidden = !layout.thumbVisible
        if layout.thumbVisible {
            thumb.position = CGPoint(x: thumbRect.midX, y: thumbRect.midY)
            thumb.size = thumbRect.size
        }
    }

    /// Crop the pixel-exact dither master instead of stretching — same failure mode as the old grip.
    private func refreshTrackTexture() {
        let master = isScrollable ? areaDitherTexture : areaSolidTexture
        guard let master else { return }
        let masterHeight = max(1, master.size().height)
        let fraction = min(1, trackRect.height / masterHeight)
        let cropped = SKTexture(
            rect: CGRect(x: 0, y: 0, width: 1, height: max(0.001, fraction)),
            in: master
        )
        cropped.filteringMode = .nearest
        track.texture = cropped
    }

    private func refreshAppearance() {
        // System 7 keeps arrows drawn when disabled; only the gray area goes solid and
        // the scroll box disappears.
        upButton.alpha = 1
        downButton.alpha = 1
        track.alpha = 1
        if !thumb.isHidden {
            thumb.alpha = isScrollable ? 1 : 0
        }

        upButton.texture = activePart == .upButton ? upPressedTexture : upNormalTexture
        downButton.texture = activePart == .downButton ? downPressedTexture : downNormalTexture
        upButton.color = .white
        upButton.colorBlendFactor = 0
        downButton.color = .white
        downButton.colorBlendFactor = 0
        track.color = .white
        track.colorBlendFactor = 0
        thumb.color = .white
        thumb.colorBlendFactor = 0
    }
}
