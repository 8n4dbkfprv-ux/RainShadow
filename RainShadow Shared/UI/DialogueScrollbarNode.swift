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

    private var controlBounds = CGRect.zero
    private var upButtonRect = CGRect.zero
    private var downButtonRect = CGRect.zero
    private var trackRect = CGRect.zero
    private var thumbRect = CGRect.zero
    private var viewportExtent: CGFloat = 1
    private var contentExtent: CGFloat = 1
    private var scrollOffset: CGFloat = 0
    private var activePart: Part?
    private var hoveredPart: Part?
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
        installTexture(named: "dialogue_scroll_up_v01", on: upButton)
        installTexture(named: "dialogue_scroll_down_v01", on: downButton)
        installTexture(named: "dialogue_scroll_track_v01", on: track)
        installTexture(named: "dialogue_scroll_thumb_v01", on: thumb)

        // Track nine-slices cleanly. Thumb uses a larger fixed end-cap fraction so the
        // diamond and beveled caps never squash into a thin stretched strip.
        track.centerRect = CGRect(x: 0.23, y: 0.12, width: 0.54, height: 0.76)
        thumb.centerRect = CGRect(x: 0.28, y: 0.22, width: 0.44, height: 0.56)
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

        let buttonExtent = min(rect.width, 30)
        let gap: CGFloat = 3
        upButtonRect = CGRect(
            x: controlBounds.midX - buttonExtent / 2,
            y: controlBounds.maxY - buttonExtent,
            width: buttonExtent,
            height: buttonExtent
        )
        downButtonRect = CGRect(
            x: controlBounds.midX - buttonExtent / 2,
            y: controlBounds.minY,
            width: buttonExtent,
            height: buttonExtent
        )
        trackRect = CGRect(
            x: controlBounds.minX,
            y: downButtonRect.maxY + gap,
            width: controlBounds.width,
            height: max(1, upButtonRect.minY - downButtonRect.maxY - gap * 2)
        )

        upButton.position = CGPoint(x: upButtonRect.midX, y: upButtonRect.midY)
        upButton.size = upButtonRect.size
        downButton.position = CGPoint(x: downButtonRect.midX, y: downButtonRect.midY)
        downButton.size = downButtonRect.size
        track.position = CGPoint(x: trackRect.midX, y: trackRect.midY)
        track.size = trackRect.size
        refreshThumbGeometry()
    }

    func configure(viewportExtent: CGFloat, contentExtent: CGFloat, scrollOffset: CGFloat = 0) {
        self.viewportExtent = max(1, viewportExtent)
        self.contentExtent = max(self.viewportExtent, contentExtent)
        setScrollOffset(scrollOffset, notify: false)
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

        switch part {
        case .upButton:
            _ = scroll(by: -34)
        case .downButton:
            _ = scroll(by: 34)
        case .track:
            if point.y > thumbRect.maxY {
                _ = scroll(by: -viewportExtent * 0.86)
            } else if point.y < thumbRect.minY {
                _ = scroll(by: viewportExtent * 0.86)
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
        hoveredPart = controlBounds.contains(point) ? part(at: point) : nil
        refreshAppearance()
        return handled
    }

    @discardableResult
    func updatePointer(at point: CGPoint) -> Bool {
        hoveredPart = controlBounds.contains(point) ? part(at: point) : nil
        refreshAppearance()
        return hoveredPart != nil
    }

    private func installTexture(named name: String, on sprite: SKSpriteNode) {
        guard let texture = GameArt.texture(named: name) else {
            sprite.color = SKColor(white: 0.16, alpha: 1)
            sprite.colorBlendFactor = 1
            return
        }
        texture.filteringMode = .linear
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

    private func refreshAppearance() {
        let disabledAlpha: CGFloat = isScrollable ? 1 : 0.42
        upButton.alpha = disabledAlpha
        downButton.alpha = disabledAlpha
        track.alpha = 1
        // Hidden when not scrollable — never show a stretched full-track “handle”.
        if !thumb.isHidden {
            thumb.alpha = isScrollable ? 1 : 0
        }

        applyAppearance(to: upButton, for: .upButton)
        applyAppearance(to: downButton, for: .downButton)
        applyAppearance(to: track, for: .track)
        applyAppearance(to: thumb, for: .thumb)
    }

    private func applyAppearance(to sprite: SKSpriteNode, for part: Part) {
        if activePart == part {
            sprite.color = .black
            sprite.colorBlendFactor = 0.34
        } else if hoveredPart == part, isScrollable {
            sprite.color = SKColor(red: 0.55, green: 0.31, blue: 0.22, alpha: 1)
            sprite.colorBlendFactor = 0.12
        } else {
            sprite.color = .white
            sprite.colorBlendFactor = 0
        }
    }
}
