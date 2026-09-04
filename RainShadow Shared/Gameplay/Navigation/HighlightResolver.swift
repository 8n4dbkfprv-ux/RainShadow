import CoreGraphics

/// Pure transliteration of GemRB `GameControl::OutlineDoors/Containers/InfoPoints`
/// plus `Map::DrawHighlightables` Tab colours.
enum HighlightResolver {
    struct Result: Equatable, Sendable {
        var hoverID: String?
        var outlines: [ObjectHighlight]

        static let empty = Result(hoverID: nil, outlines: [])
    }

    static func resolve(
        hoverPoint: CGPoint?,
        revealAll: Bool,
        worldInteractionBlocked: Bool,
        targetModeActive: Bool = false,
        objects: [HighlightableObject]
    ) -> Result {
        guard !worldInteractionBlocked else { return .empty }

        let hover = hoverPoint.flatMap { HighlightableObject.hit(at: $0, among: objects) }
        var outlines: [ObjectHighlight] = []
        var seen = Set<String>()

        func append(_ object: HighlightableObject, color: HighlightColor) {
            guard seen.insert(object.id).inserted else { return }
            outlines.append(ObjectHighlight(id: object.id, color: color))
        }

        for object in objects {
            if let trap = trapHighlight(object) {
                append(object, color: trap)
                continue
            }
            if object.kind == .door, object.isSecretFound {
                append(object, color: HighlightPalette.hiddenDoor)
                continue
            }
            if hover?.id == object.id, let color = hoverColor(object, targetModeActive: targetModeActive) {
                append(object, color: color)
            }
        }

        if revealAll {
            for object in objects {
                if object.kind == .container, object.suppressedByClosedDoor { continue }
                if let color = revealColor(object) {
                    append(object, color: color)
                }
            }
        }

        return Result(hoverID: hover?.id, outlines: outlines)
    }

    private static func trapHighlight(_ object: HighlightableObject) -> HighlightColor? {
        object.trapIsVisible ? HighlightPalette.trap : nil
    }

    /// Hover colours. Info/travel use the door cyan so inspectables light like PST:EE
    /// while doors/containers keep BG2 `HOVERDOOR` / `HOVERCONTAINER`.
    private static func hoverColor(
        _ object: HighlightableObject,
        targetModeActive: Bool
    ) -> HighlightColor? {
        if object.trapIsVisible { return HighlightPalette.trap }
        if targetModeActive, object.isLocked {
            return HighlightPalette.hoverTargetable
        }
        switch object.kind {
        case .door:
            return HighlightPalette.hoverDoor
        case .container:
            return HighlightPalette.hoverContainer
        case .infoPoint, .travel:
            return HighlightPalette.hoverDoor
        }
    }

    private static func revealColor(_ object: HighlightableObject) -> HighlightColor? {
        switch object.kind {
        case .door:
            return HighlightPalette.altDoor
        case .container:
            return object.isEmpty ? HighlightPalette.emptyContainer : HighlightPalette.altContainer
        case .infoPoint, .travel:
            return nil
        }
    }
}
