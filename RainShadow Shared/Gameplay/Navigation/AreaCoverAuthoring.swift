import CoreGraphics

/// WED-style actor-cover outlines, derived from the same geometry the search
/// map already uses.
///
/// Baldur's Gate does not sort scenery sprites against creatures. A wall
/// polygon marks the painted mass, and a creature whose feet fall in it is
/// stippled through. RainShadow's plates already paint that mass; this is the
/// outline the runtime feeds to `ActorCover`.
enum AreaCoverAuthoring {
    /// How far camera-far of a furniture footprint it still covers an actor.
    /// Three search-map rows on the 16×12 grid — about a body's depth on the
    /// 0.75 ground foreshortening.
    static let furnitureCoverDepth: CGFloat = 36

    /// Visual height of a district block, matching the 3-storey terrace spec.
    static let buildingHeight: CGFloat = CityDistrictLayout.TerraceSpec.worldHeight

    /// Tall office furniture that hides a standing adult. The desk cluster is
    /// excluded: it owns hand-tuned apron ordering, and lifting the seated body
    /// out of it would put Voss on top of his own desk.
    static func officeWallPolygons() -> [AreaWallPolygon] {
        [
            furnitureCover(
                id: "office.bookshelf",
                authored: OfficeNavigationLayout.authoredBookshelfObstacle,
                height: OfficeInteriorScale.standingAdultBodyHeight * 1.3
            ),
            furnitureCover(
                id: "office.filingCabinet",
                authored: OfficeNavigationLayout.authoredFilingCabinetObstacle,
                height: OfficeInteriorScale.standingAdultBodyHeight
            ),
            furnitureCover(
                id: "office.filingCabinetB",
                authored: OfficeNavigationLayout.authoredFilingCabinetBObstacle,
                height: OfficeInteriorScale.standingAdultBodyHeight
            )
        ]
    }

    /// One parallelogram per painted building mass.
    static func districtWallPolygons() -> [AreaWallPolygon] {
        CityStreetPlan.all.map { mass in
            AreaWallPolygon(
                id: mass.id,
                polygon: mass.vertices.map(AreaPoint.init),
                coversActors: true,
                height: buildingHeight
            )
        }
    }

    private static func furnitureCover(
        id: String,
        authored: CGRect,
        height: CGFloat
    ) -> AreaWallPolygon {
        let world = OfficeInteriorScale.mapRect(authored)
        let expanded = CGRect(
            x: world.minX,
            y: world.minY,
            width: world.width,
            height: world.height + furnitureCoverDepth
        )
        return AreaWallPolygon(
            id: id,
            rect: expanded,
            coversActors: true,
            height: height
        )
    }
}
