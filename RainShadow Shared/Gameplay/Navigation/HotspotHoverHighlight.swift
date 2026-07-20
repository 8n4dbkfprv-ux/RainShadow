import CoreGraphics

/// Baldur's Gate / Infinity Engine–style hover selection for office hotspots.
/// Pure hit-test + presentation contract so tests and the scene share one entry.
enum HotspotHoverHighlight {
    struct Target: Equatable {
        let id: String
        let hitArea: CGRect
    }

    /// Classic IE selection blue (cyan-leaning outline, not UI chrome gray).
    static let outlineRed: CGFloat = 0.22
    static let outlineGreen: CGFloat = 0.58
    static let outlineBlue: CGFloat = 0.98
    static let outlineAlpha: CGFloat = 0.95
    /// Soft fill so the rect reads as a selected region without hiding art.
    static let fillAlpha: CGFloat = 0.12
    static let lineWidth: CGFloat = 2.5

    /// Inclusive sRGB band for “BG blue” regression checks (stroke components).
    static let blueRedBand: ClosedRange<CGFloat> = 0.05...0.45
    static let blueGreenBand: ClosedRange<CGFloat> = 0.35...0.80
    static let blueBlueBand: ClosedRange<CGFloat> = 0.75...1.0

    struct Presentation: Equatable {
        let isVisible: Bool
        let hotspotID: String?
        let hitArea: CGRect?
        let red: CGFloat
        let green: CGFloat
        let blue: CGFloat
        let alpha: CGFloat

        static let hidden = Presentation(
            isVisible: false,
            hotspotID: nil,
            hitArea: nil,
            red: outlineRed,
            green: outlineGreen,
            blue: outlineBlue,
            alpha: 0
        )

        var isBGBlueStroke: Bool {
            guard isVisible else { return false }
            return blueRedBand.contains(red)
                && blueGreenBand.contains(green)
                && blueBlueBand.contains(blue)
                && alpha > 0.5
        }
    }

    /// First matching hotspot in list order (same order as click hit-testing).
    static func selectedID(at point: CGPoint, among targets: [Target]) -> String? {
        targets.first { $0.hitArea.contains(point) }?.id
    }

    /// Full presentation for pointer position. Blocked world UI forces hidden.
    static func presentation(
        at point: CGPoint?,
        among targets: [Target],
        worldInteractionBlocked: Bool
    ) -> Presentation {
        guard !worldInteractionBlocked, let point else {
            return .hidden
        }
        guard let id = selectedID(at: point, among: targets),
              let target = targets.first(where: { $0.id == id }) else {
            return .hidden
        }
        return Presentation(
            isVisible: true,
            hotspotID: id,
            hitArea: target.hitArea,
            red: outlineRed,
            green: outlineGreen,
            blue: outlineBlue,
            alpha: outlineAlpha
        )
    }

    /// Converts office hotspots to selection targets (id + hit rect only).
    static func targets(
        from hotspots: [(id: String, hitArea: CGRect)]
    ) -> [Target] {
        hotspots.map { Target(id: $0.id, hitArea: $0.hitArea) }
    }
}
