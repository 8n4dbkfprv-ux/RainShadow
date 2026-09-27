import CoreGraphics
@testable import RainShadowCore

/// These scale-unit tests exercise the retained modular authoring fixtures.
/// Runtime rebuilt districts use the ARE geometry below instead of old sprites.
enum LegacyCityScaleFixtures {
    static func anyDistrictScale(forTextureName name: String) -> CGFloat? {
        [CityDistrictCatalog.sableRow, CityDistrictCatalog.wharfLadder,
         CityDistrictCatalog.riverside, CityDistrictCatalog.lilaStreet,
         CityDistrictCatalog.civicRecords].lazy.compactMap {
            ($0.visualSprites + $0.measuredDoorLeaves).first { $0.textureName == name }?.scale
        }.first
    }
    static func bodyMultiple(contentHeight: CGFloat, scale: CGFloat) -> CGFloat {
        CityDistrictLayout.bodyMultiple(contentHeight: contentHeight, scale: scale)
    }
    static func bodyMultiple(contentHeight: CGFloat, textureName: String) -> CGFloat? {
        anyDistrictScale(forTextureName: textureName).map { bodyMultiple(contentHeight: contentHeight, scale: $0) }
    }
    static func doorBodyMultiple(doorLeafHeight: CGFloat, textureName: String) -> CGFloat? {
        bodyMultiple(contentHeight: doorLeafHeight, textureName: textureName)
    }
}

enum RebuiltDoorMeasurement {
    static func height(district: CityDistrictID, portalID: String) -> CGFloat? {
        guard RebuiltCityAreas.districts.contains(district) else {
            return CityDoorPaintedAperture.height(for: portalID)
        }
        let area = CityDistrictAreaAdapter.area(for: district)
        if let height = area.doors.first(where: { $0.id == portalID })?.paintedApertureHeight { return height }
        // V30's static Sable doorway exports its evaluated aperture outline:
        // the near-vertical jamb measures 89.33 world units (not the sloped AABB).
        guard let p = area.region(id: portalID)?.polygon, !p.isEmpty else { return nil }
        return zip(p, Array(p.dropFirst()) + [p[0]])
            .filter { abs($0.x - $1.x) < 0.1 }
            .map { CGFloat(abs($0.y - $1.y)) }.max()
    }
}
