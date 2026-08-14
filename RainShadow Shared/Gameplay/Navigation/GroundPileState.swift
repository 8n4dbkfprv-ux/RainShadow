import CoreGraphics
import Foundation

/// One stack lying on the floor of an area.
///
/// BG drops items at the dropper's feet and leaves them there; the pile is part
/// of the area, not of any container, and it survives leaving and coming back.
/// Position is kept so a future world-space pile sprite has somewhere to stand —
/// the quick-loot bar only needs the radius test.
struct GroundItemStack: Hashable, Codable, Sendable {
    let stack: CarriedItemStack
    let x: CGFloat
    let y: CGFloat

    init(stack: CarriedItemStack, position: CGPoint) {
        self.stack = stack
        self.x = position.x
        self.y = position.y
    }

    var position: CGPoint { CGPoint(x: x, y: y) }

    func distance(to point: CGPoint) -> CGFloat {
        let dx = x - point.x
        let dy = y - point.y
        return (dx * dx + dy * dy).squareRoot()
    }
}

/// Ground piles for every area, keyed by area id.
///
/// Deliberately shaped like `LootContainerState`: a persisted map the session
/// owns, mutated through copy-then-commit, never re-rolled. A ground pile *is* a
/// container in every way that matters — the only difference is that nothing
/// authored it.
struct GroundPileState: Hashable, Codable, Sendable {
    private(set) var pilesByArea: [String: [GroundItemStack]]

    init(pilesByArea: [String: [GroundItemStack]] = [:]) {
        self.pilesByArea = pilesByArea
    }

    var isEmpty: Bool { pilesByArea.allSatisfy { $0.value.isEmpty } }

    func stacks(in areaID: String) -> [GroundItemStack] {
        pilesByArea[areaID] ?? []
    }

    /// Stacks within `radius` of a point, nearest first. BG's quick-loot bar
    /// gathers everything on the ground near the selected character rather than
    /// only what is underfoot.
    func stacks(in areaID: String, near point: CGPoint, radius: CGFloat) -> [GroundItemStack] {
        stacks(in: areaID)
            .filter { $0.distance(to: point) <= radius }
            .sorted { $0.distance(to: point) < $1.distance(to: point) }
    }

    mutating func drop(
        _ stack: CarriedItemStack,
        in areaID: String,
        at position: CGPoint
    ) {
        guard stack.quantity > 0 else { return }
        var pile = pilesByArea[areaID] ?? []
        pile.append(GroundItemStack(stack: stack, position: position))
        pilesByArea[areaID] = pile
    }

    /// Remove one stack by identity. Index-based removal would race the radius
    /// sort the quick-loot bar applies, and pick up the wrong thing.
    @discardableResult
    mutating func take(_ entry: GroundItemStack, from areaID: String) -> CarriedItemStack? {
        guard var pile = pilesByArea[areaID],
              let index = pile.firstIndex(of: entry) else { return nil }
        let taken = pile.remove(at: index)
        pilesByArea[areaID] = pile
        return taken.stack
    }

    mutating func clear(areaID: String) {
        pilesByArea[areaID] = nil
    }
}

/// Paging for the quick-loot bar.
///
/// BG:EE shows nearby ground items in a strip and grows scroll buttons only once
/// there are more than fit. Ten is the engine's row length.
struct QuickLootPage: Equatable, Sendable {
    static let slotsPerPage = 10

    let pageIndex: Int
    let pageCount: Int
    let range: Range<Int>

    var needsPaging: Bool { pageCount > 1 }

    init(itemCount: Int, requestedPage: Int) {
        let count = max(0, itemCount)
        let pages = max(1, Int(ceil(Double(count) / Double(Self.slotsPerPage))))
        let page = min(max(0, requestedPage), pages - 1)
        let start = min(page * Self.slotsPerPage, count)
        let end = min(start + Self.slotsPerPage, count)
        self.pageIndex = page
        self.pageCount = pages
        self.range = start..<end
    }
}
