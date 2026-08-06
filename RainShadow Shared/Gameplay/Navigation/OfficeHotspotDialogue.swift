import Foundation

/// Authored one-node inspect graphs for office hotspots (PR4).
///
/// Prose lives in `Resources/Dialogue/office.hotspot-inspect.dialogue-catalog.json`.
/// Graph id convention: `inspect.<hotspotID>` (e.g. `inspect.office.desk`).
enum OfficeHotspotDialogue {
    static let catalogResourceName = "office.hotspot-inspect.dialogue-catalog"
    static let vossPortrait = EmptyCoatCaseIntroduction.vossPortrait

    /// Stable graph id for a layout hotspot id (`office.desk` → `inspect.office.desk`).
    static func graphID(forHotspotID hotspotID: String) -> String {
        "inspect.\(hotspotID)"
    }

    /// Start / sole node id for a hotspot inspect package.
    static func startNodeID(forHotspotID hotspotID: String) -> String {
        "inspection.\(hotspotID)"
    }

    /// Load the inspect graph for a hotspot (cached). Fail-fast if missing.
    static func graph(forHotspotID hotspotID: String) -> DialogueGraph {
        let id = graphID(forHotspotID: hotspotID)
        do {
            return try DialogueGraphLoader.loadFromCatalog(
                graphID: id,
                catalogResourceName: catalogResourceName
            )
        } catch {
            preconditionFailure(
                "Missing office hotspot inspect dialogue for '\(hotspotID)' (\(id)): \(error)"
            )
        }
    }

    /// Optional lookup without trapping (tests / tooling).
    static func graphIfPresent(forHotspotID hotspotID: String) -> DialogueGraph? {
        let id = graphID(forHotspotID: hotspotID)
        return try? DialogueGraphLoader.loadFromCatalog(
            graphID: id,
            catalogResourceName: catalogResourceName
        )
    }

    /// All graphs in the shipped catalog.
    static func allGraphs() throws -> [String: DialogueGraph] {
        try DialogueGraphLoader.loadCatalog(resourceName: catalogResourceName)
    }
}
