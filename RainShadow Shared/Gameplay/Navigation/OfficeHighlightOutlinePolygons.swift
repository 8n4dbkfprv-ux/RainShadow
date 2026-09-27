import CoreGraphics

/// Registered Blender silhouettes, shared by hover and the area record.
extension OfficeHighlightOutlines {
    static var refinedPolygons: [String: [CGPoint]] {
        Dictionary(uniqueKeysWithValues: OfficeAreaAdapter.area().regions.map { ($0.id, $0.polygon.map(\.cgPoint)) })
    }
}
