import CoreGraphics

/// City portal outlines: door-leaf silhouettes traced from the ARE door records.
///
/// The rings in `CityHighlightOutlinePolygons` come from each leaf's RGBA alpha,
/// seated through the same registration the runtime draws the leaf with. Portals
/// without a traced ring fall back to the painted aperture quad, so hover and
/// click stay on the same region either way.
enum CityHighlightOutlines {
    static func objects(for district: CityDistrictID) -> [HighlightableObject] {
        CityDistrictCatalog.definition(for: district).portals.map { portal in
            let fallback: [CGPoint]
            if let aperture = CityDoorPaintedAperture.rect(for: portal.id)?.cgRect {
                fallback = HighlightGeometry.quad(from: CityDistrictLayout.portalHitArea(paintedAperture: aperture))
            } else {
                fallback = HighlightGeometry.quad(from: portal.hitArea)
            }
            return HighlightableObject(
                id: portal.id,
                kind: .door,
                polygon: closedPolygons[portal.id] ?? fallback,
                openPolygon: openPolygons[portal.id],
                isLocked: portal.requiresCityOpen
            )
        }
    }
}
