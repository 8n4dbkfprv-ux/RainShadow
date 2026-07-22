import CoreGraphics

/// Chooses which authored office hotspot should display its pre-baked hover texture.
enum HotspotHoverHighlight {
    struct Target: Equatable {
        let id: String
        let hitArea: CGRect
    }

    struct Presentation: Equatable {
        let isVisible: Bool
        let hotspotID: String?

        static let hidden = Presentation(isVisible: false, hotspotID: nil)
    }

    static func selectedID(at point: CGPoint, among targets: [Target]) -> String? {
        targets.first { $0.hitArea.contains(point) }?.id
    }

    static func presentation(
        at point: CGPoint?,
        among targets: [Target],
        worldInteractionBlocked: Bool
    ) -> Presentation {
        guard !worldInteractionBlocked,
              let point,
              let id = selectedID(at: point, among: targets) else {
            return .hidden
        }
        return Presentation(isVisible: true, hotspotID: id)
    }

    static func targets(from authored: [(id: String, hitArea: CGRect)]) -> [Target] {
        authored.map { Target(id: $0.id, hitArea: $0.hitArea) }
    }
}
