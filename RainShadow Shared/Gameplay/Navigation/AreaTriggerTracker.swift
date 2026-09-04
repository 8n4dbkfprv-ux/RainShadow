import CoreGraphics
import Foundation

/// Walks the ARE proximity-trigger list each tick and reports entries.
///
/// A Baldur's Gate trigger region fires its script when the party steps inside
/// the polygon. The Reset flag lets it fire again on a later entry; without it
/// the region is spent for the life of the visit (and, via area variables, of
/// the save — the scene records the fire as a variable).
struct AreaTriggerTracker: Equatable, Sendable {
    private(set) var insideIDs: Set<String> = []
    private(set) var spentIDs: Set<String> = []

    mutating func evaluate(regions: [AreaRegion], at point: CGPoint) -> [AreaRegion] {
        let candidates = regions.filter { region in
            region.kind == .trigger
                && !region.isDeactivated
                && region.contains(point)
        }
        let now = Set(candidates.map(\.id))
        var fired: [AreaRegion] = []
        for region in candidates where !insideIDs.contains(region.id) {
            if !region.resets && spentIDs.contains(region.id) { continue }
            fired.append(region)
            spentIDs.insert(region.id)
        }
        insideIDs = now
        return fired
    }
}
