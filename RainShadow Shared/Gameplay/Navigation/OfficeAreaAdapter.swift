import CoreGraphics
import Foundation

/// The Blender-authored office area record is now the geometry authority.
/// Rebuild with integrate_office_noir_v14.py; do not run the retired painting planner.
enum OfficeAreaAdapter {
    static let cityArrivalEntrance = CityDistrictAreaAdapter.officeArrivalEntrance
    static func area() -> AreaDefinition {
        do { return try AreaCatalogLoader.load(HarborpointAreas.office) }
        catch { preconditionFailure("Missing authored V14 office: \(error)") }
    }
    static func approachPair(from point: CGPoint, step: CGFloat = 36) -> [AreaPoint] {
        [AreaPoint(point), AreaPoint(x: point.x, y: point.y - step)]
    }
    static var propsSourceURL: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("ArtSource/Generated/Office/office_props_v01.json")
    }
    static func props() -> [AreaProp] { area().props }
}
