import CoreGraphics

/// Baldur's Gate / Infinity Engine–style hover selection for office hotspots.
/// Selected props recolor with a blue sprite tint (IE “highlight selected sprite”),
/// not an axis-aligned outline box.
enum HotspotHoverHighlight {
    struct Target: Equatable {
        let id: String
        let hitArea: CGRect
    }

    /// Classic IE selection blue mixed into the prop’s opaque texels.
    static let tintRed: CGFloat = 0.22
    static let tintGreen: CGFloat = 0.58
    static let tintBlue: CGFloat = 0.98

    /// Prior subtle wash (regression floor — new tint must read stronger than this).
    static let legacySubtleColorBlendFactor: CGFloat = 0.42

    /// SpriteKit `colorBlendFactor` when selected (0 = neutral art, 1 = solid tint).
    /// Stronger than the prior 0.42 wash so selection reads clearly while art stays readable.
    static let selectedColorBlendFactor: CGFloat = 0.62
    static let clearedColorBlendFactor: CGFloat = 0

    /// Inclusive bands for “BG blue sprite tint” regression checks.
    static let blueRedBand: ClosedRange<CGFloat> = 0.05...0.45
    static let blueGreenBand: ClosedRange<CGFloat> = 0.35...0.80
    static let blueBlueBand: ClosedRange<CGFloat> = 0.75...1.0
    static let selectedBlendBand: ClosedRange<CGFloat> = 0.50...0.78

    struct Presentation: Equatable {
        let isVisible: Bool
        let hotspotID: String?
        let red: CGFloat
        let green: CGFloat
        let blue: CGFloat
        /// Blend factor to apply on registered prop sprites (0 clears selection).
        let colorBlendFactor: CGFloat
        /// True when the primary visual is sprite recolor (not rect chrome).
        let usesSpriteTint: Bool

        static let hidden = Presentation(
            isVisible: false,
            hotspotID: nil,
            red: tintRed,
            green: tintGreen,
            blue: tintBlue,
            colorBlendFactor: clearedColorBlendFactor,
            usesSpriteTint: true
        )

        /// Selected presentation uses documented BG blue tint parameters.
        var isBGBlueSpriteTint: Bool {
            guard isVisible, usesSpriteTint else { return false }
            return blueRedBand.contains(red)
                && blueGreenBand.contains(green)
                && blueBlueBand.contains(blue)
                && selectedBlendBand.contains(colorBlendFactor)
        }

        /// Neutral / cleared sprite state the scene applies on miss or blocked UI.
        var isClearedSpriteTint: Bool {
            !isVisible && colorBlendFactor == clearedColorBlendFactor
        }
    }

    /// First matching hotspot in list order (same order as click hit-testing).
    static func selectedID(at point: CGPoint, among targets: [Target]) -> String? {
        targets.first { $0.hitArea.contains(point) }?.id
    }

    /// Full presentation for pointer position. Blocked world UI forces cleared tint.
    static func presentation(
        at point: CGPoint?,
        among targets: [Target],
        worldInteractionBlocked: Bool
    ) -> Presentation {
        guard !worldInteractionBlocked, let point else {
            return .hidden
        }
        guard let id = selectedID(at: point, among: targets) else {
            return .hidden
        }
        return Presentation(
            isVisible: true,
            hotspotID: id,
            red: tintRed,
            green: tintGreen,
            blue: tintBlue,
            colorBlendFactor: selectedColorBlendFactor,
            usesSpriteTint: true
        )
    }

    static func targets(
        from hotspots: [(id: String, hitArea: CGRect)]
    ) -> [Target] {
        hotspots.map { Target(id: $0.id, hitArea: $0.hitArea) }
    }
}
