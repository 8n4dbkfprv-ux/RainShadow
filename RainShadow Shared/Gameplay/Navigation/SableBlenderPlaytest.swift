/// Content links for the isolated Blender playtest. The story catalog keeps its
/// original office-to-ward link; only this copy returns to the new street plan.
enum SableBlenderPlaytest {
    static let exteriorID = AreaID("sable_court")
    static let apartmentRegionID = "sable.apartment.entrance"
    static let returnEntrance = "apartment_approach"

    static func office(from original: AreaDefinition) -> AreaDefinition {
        var office = original
        guard let index = office.regions.firstIndex(where: { $0.id == "office.door" }) else {
            preconditionFailure("The office is missing its street door")
        }
        office.regions[index].label = "Return to Sable Row"
        office.regions[index].travel = AreaTravel(
            destination: exteriorID, entrance: returnEntrance
        )
        return office
    }

}
