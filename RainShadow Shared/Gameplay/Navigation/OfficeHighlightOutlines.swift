import CoreGraphics

/// Office ARE-style outline polygons. Refined silhouettes come from
/// `generate_highlight_outline_polygons.py`; missing ids fall back to the
/// authored hotspot quad so click and hover stay on the same region.
enum OfficeHighlightOutlines {
    static func objects() -> [HighlightableObject] {
        let containerIDs = Set(OfficeNavigationLayout.lootContainers.map(\.id))
        return OfficeNavigationLayout.authoredHotspots.map { hotspot in
            let worldRect = OfficeInteriorScale.mapRect(hotspot.hitArea)
            let polygon = refinedPolygons[hotspot.id] ?? HighlightGeometry.quad(from: worldRect)
            let kind: HighlightableKind
            if hotspot.id == "office.door" {
                kind = .door
            } else if containerIDs.contains(hotspot.id) {
                kind = .container
            } else {
                kind = .infoPoint
            }
            return HighlightableObject(id: hotspot.id, kind: kind, polygon: polygon)
        }
    }
}
