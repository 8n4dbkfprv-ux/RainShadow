import CoreGraphics

/// Offline WED-style wall polygons for Act I city wards.
///
/// Infinity Engine outdoor areas mark each building diamond as a wall polygon
/// with "Cover animations" so actors walking behind the painted mass stipple
/// through. Harborpoint's districts share one lattice (`CityBlockGrid`), so one
/// authoring pass covers every ward without per-district hand outlines.
enum AreaCoverAuthoring {
    /// One covering diamond per lattice block, matching
    /// `generate_city_ward_rebuild_v01.wall_polygons`.
    static func districtWallPolygons(
        blocks: [CityBlockGrid.Block] = CityBlockGrid.all,
        height: CGFloat = 420
    ) -> [AreaWallPolygon] {
        _ = height // Authored into JSON by the Python rebuild; Swift cover only needs the outline.
        return blocks.map { block in
            AreaWallPolygon(
                id: "block.\(block.i).\(block.j)",
                polygon: block.vertices.map(AreaPoint.init),
                coversActors: true,
                shadesBothSides: false
            )
        }
    }
}
