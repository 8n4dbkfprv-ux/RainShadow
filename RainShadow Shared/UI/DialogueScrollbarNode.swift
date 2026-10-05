import SpriteKit

@MainActor
final class DialogueScrollbarNode: SKNode {
    private enum Part {
        case upButton
        case downButton
        case track
        case thumb
    }

    private let upButton = ScrollbarPlateNode(kind: .up)
    private let downButton = ScrollbarPlateNode(kind: .down)
    private let track = ScrollbarPlateNode(kind: .track)
    private let thumb = ScrollbarPlateNode(kind: .thumb)

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
        upButton.layout(size: upButtonRect.size)
        downButton.position = CGPoint(x: downButtonRect.midX, y: downButtonRect.midY)
        downButton.layout(size: downButtonRect.size)
        track.position = CGPoint(x: trackRect.midX, y: trackRect.midY)
        track.layout(size: trackRect.size)
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
        // Report hover so the scene can show a hand cursor.
        pointerInside = controlBounds.contains(point)
        refreshAppearance()
        return pointerInside
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
            thumb.layout(size: thumbRect.size)
        }
    }

    private func refreshAppearance() {
        upButton.alpha = isScrollable ? 1 : 0.72
        downButton.alpha = isScrollable ? 1 : 0.72
        for (part, plate) in [(Part.upButton, upButton), (.downButton, downButton), (.thumb, thumb)] {
            plate.setPressed(activePart == part)
        }
    }
}

/// Platinum geometry uses straight edges and shallow, constant-width bevels.
/// Only the material comes from the generated parchment master: no framed image
/// is stretched, and each paper tile retains the same points-per-texel ratio.
@MainActor
private final class ScrollbarPlateNode: SKNode {
    enum Kind { case up, down, track, thumb }
    private let kind: Kind
    private let materialRoot = SKNode()
    private let bevelRoot = SKNode()
    private let symbolRoot = SKNode()
    private var plateSize = CGSize.zero
    private var pressed = false
    private static let tileExtent: CGFloat = 24
    private static let edge: CGFloat = 1
    private static let outline = SKColor(red: 0.27, green: 0.19, blue: 0.10, alpha: 1)
    private static let light = SKColor(red: 0.98, green: 0.89, blue: 0.69, alpha: 1)
    private static let shadow = SKColor(red: 0.53, green: 0.39, blue: 0.22, alpha: 1)

    private static let paper: SKTexture = {
        let source = UIPaintedChrome.requireTexture(named: "dialogue_scroll_thumb_fantasy_v01")
        // Center contains paper only; exclude every part of the old rounded frame.
        // Flatten this crop before creating partial tiles. Nested SpriteKit
        // subtextures can resolve UVs against the original framed texture.
        let image = source.cgImage()
        let crop = CGRect(x: image.width / 4, y: image.height / 4,
                          width: image.width / 2, height: image.height / 2)
        guard let paper = image.cropping(to: crop) else { return source }
        let texture = SKTexture(cgImage: paper)
        texture.filteringMode = .linear
        return texture
    }()

    init(kind: Kind) {
        self.kind = kind
        super.init()
        addChild(materialRoot)
        bevelRoot.zPosition = 1
        addChild(bevelRoot)
        symbolRoot.zPosition = 2
        addChild(symbolRoot)
    }

    required init?(coder: NSCoder) { fatalError("Created programmatically") }

    func layout(size: CGSize) {
        guard size != plateSize else { return }
        plateSize = size
        materialRoot.removeAllChildren()
        // Tile at a fixed scale, cropping the last row/column instead of stretching.
        let tile = Self.tileExtent
        for y in stride(from: CGFloat(0), to: size.height, by: tile) {
            for x in stride(from: CGFloat(0), to: size.width, by: tile) {
                let width = min(tile, size.width - x)
                let height = min(tile, size.height - y)
                let crop = CGRect(x: 0, y: 0, width: width / tile, height: height / tile)
                let sprite = SKSpriteNode(texture: SKTexture(rect: crop, in: Self.paper),
                                          size: CGSize(width: width, height: height))
                sprite.position = CGPoint(x: x + width / 2 - size.width / 2,
                                          y: y + height / 2 - size.height / 2)
                materialRoot.addChild(sprite)
            }
        }
        refreshBevel()
        refreshSymbol()
        refreshMaterial()
    }

    func setPressed(_ value: Bool) {
        guard pressed != value else { return }
        pressed = value
        refreshBevel()
        refreshMaterial()
        symbolRoot.position = value ? CGPoint(x: 0.75, y: -0.75) : .zero
    }

    private func refreshMaterial() {
        let tint: SKColor
        let blend: CGFloat
        if kind == .track {
            tint = Self.outline; blend = 0.40
        } else if pressed {
            tint = Self.shadow; blend = 0.35
        } else if kind == .thumb {
            tint = SKColor(red: 0.74, green: 0.52, blue: 0.22, alpha: 1); blend = 0.30
        } else {
            tint = .white; blend = 0
        }
        for case let sprite as SKSpriteNode in materialRoot.children {
            sprite.color = tint
            sprite.colorBlendFactor = blend
        }
    }

    private func strip(_ rect: CGRect, color: SKColor, parent: SKNode) {
        guard rect.width > 0, rect.height > 0 else { return }
        let sprite = SKSpriteNode(color: color, size: rect.size)
        sprite.position = CGPoint(x: rect.midX, y: rect.midY)
        parent.addChild(sprite)
    }

    private func refreshBevel() {
        bevelRoot.removeAllChildren()
        let w = plateSize.width, h = plateSize.height
        guard w > 0, h > 0 else { return }
        let e = Self.edge
        let recessed = kind == .track || pressed
        // A single dark outline followed by a one-point highlight/shadow pair.
        // These dimensions are independent of texture resolution and thumb height.
        for inset in [CGFloat(0), e, e * 2] {
            let outer = inset == 0
            let hi = outer ? Self.outline : (recessed ? Self.shadow : Self.light)
            let lo = outer ? Self.outline : (recessed ? Self.light : Self.shadow)
            let r = CGRect(x: -w / 2 + inset, y: -h / 2 + inset,
                           width: w - inset * 2, height: h - inset * 2)
            strip(CGRect(x: r.minX, y: r.maxY - e, width: r.width, height: e), color: hi, parent: bevelRoot)
            strip(CGRect(x: r.minX, y: r.minY, width: e, height: r.height), color: hi, parent: bevelRoot)
            strip(CGRect(x: r.minX, y: r.minY, width: r.width, height: e), color: lo, parent: bevelRoot)
            strip(CGRect(x: r.maxX - e, y: r.minY, width: e, height: r.height), color: lo, parent: bevelRoot)
        }
    }

    private func refreshSymbol() {
        symbolRoot.removeAllChildren()
        if kind == .up || kind == .down {
            let sign: CGFloat = kind == .up ? 1 : -1
            let path = CGMutablePath()
            path.move(to: CGPoint(x: -6, y: -3.5 * sign))
            path.addLine(to: CGPoint(x: 6, y: -3.5 * sign))
            path.addLine(to: CGPoint(x: 0, y: 4 * sign))
            path.closeSubpath()
            let arrow = SKShapeNode(path: path)
            arrow.fillColor = Self.outline
            arrow.strokeColor = .clear
            arrow.lineWidth = 0
            symbolRoot.addChild(arrow)
        } else if kind == .thumb {
            // Fixed-size horizontal grip lines; never part of the resizable surface.
            for y in [CGFloat(-3), 0, 3] {
                strip(CGRect(x: -6, y: y - 0.75, width: 12, height: 0.75), color: Self.light, parent: symbolRoot)
                strip(CGRect(x: -6, y: y, width: 12, height: 0.75), color: Self.shadow, parent: symbolRoot)
            }
        }
    }
}
