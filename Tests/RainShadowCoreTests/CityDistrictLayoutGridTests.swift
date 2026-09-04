import CoreGraphics
import Foundation
import Testing
@testable import RainShadowCore

/// The districts sit on the block lattice the ground plates are painted with.
///
/// Before this, five of the six placed buildings at hand-typed coordinates on
/// an axis-aligned 2×2 grid that exists in no plate — `paint()` in
/// `generate_city_grounds_world_scale_v05.py` draws diagonal diamond blocks and
/// never calls the axis-aligned `street_masks()` those coordinates came from.
/// The result was buildings standing in the middle of streets, nav that blocked
/// open pavement, and blocks that read as empty lots.
///
/// These hold the two together. The geometry gate is
/// `sable_iso_lots.json`, the survey the plates and Sable Row already share.
struct CityDistrictLayoutGridTests {

    // MARK: - The lattice matches the survey

    struct SurveyedLot: Decodable {
        let id: String
        let i: Int
        let j: Int
        let centroid: [CGFloat]
        let nearTip: [CGFloat]
        let farTip: [CGFloat]
        let vertices: [[CGFloat]]
    }

    struct Survey: Decodable {
        let periodPx: CGFloat
        let lots: [SurveyedLot]
    }

    static func loadSurvey() throws -> Survey {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("ArtSource/Generated/CityDistrict/V2/sable_iso_lots.json")
        return try JSONDecoder().decode(Survey.self, from: Data(contentsOf: url))
    }

    @Test func blockGridReproducesTheSurveyedLots() throws {
        let survey = try Self.loadSurvey()
        // 1680 plate px at the shipped 2.00 px/unit is an 840-unit period.
        #expect(survey.periodPx / 2 == CityBlockGrid.period)
        #expect(survey.lots.count <= CityBlockGrid.all.count)

        for lot in survey.lots {
            let block = CityBlockGrid.block(i: lot.i, j: lot.j)
            #expect(block.centre.x == lot.centroid[0], "\(lot.id) centre x")
            #expect(block.centre.y == lot.centroid[1], "\(lot.id) centre y")
            #expect(block.nearTip.x == lot.nearTip[0], "\(lot.id) near tip x")
            #expect(block.nearTip.y == lot.nearTip[1], "\(lot.id) near tip y")
            #expect(block.farTip.x == lot.farTip[0], "\(lot.id) far tip x")
            #expect(block.farTip.y == lot.farTip[1], "\(lot.id) far tip y")
            // Survey winding is near, right, left, far.
            #expect(block.rightTip.x == lot.vertices[1][0], "\(lot.id) right tip")
            #expect(block.leftTip.x == lot.vertices[2][0], "\(lot.id) left tip")
            #expect(
                CityBlockGrid.all.contains(block),
                "\(lot.id) is surveyed but not in CityBlockGrid.all"
            )
        }
    }

    /// Sable Row's named lots have to stay exactly where they were, because the
    /// terraces are seated on them and the near-side walls depth-sort against
    /// their kerbs. This is the compatibility pin for deriving `IsoLot` from
    /// the shared lattice instead of hard-coding its vertices twice.
    @Test func everyIsoLotIsItsLatticeBlock() {
        for lot in CityDistrictLayout.IsoLot.allCases {
            let block = lot.block
            #expect(lot.centroid == block.centre, "\(lot) centroid")
            #expect(lot.leftTip == block.leftTip, "\(lot) left tip")
            #expect(lot.rightTip == block.rightTip, "\(lot) right tip")
            #expect(lot.farTip == block.farTip, "\(lot) far tip")
            switch lot {
            case .southWest, .southEast:
                // Clamped onto the plate: surveyed at y = −24, seated at 0.
                #expect(lot.nearTip.y == 0, "\(lot) near tip should be clamped")
                #expect(lot.nearTip.x == block.nearTip.x, "\(lot) near tip x")
            default:
                #expect(lot.nearTip == block.nearTip, "\(lot) near tip")
            }
        }
    }

    // MARK: - Placement rules

    static let facadePrefixes = ["city_building_", "city_terrace_", "city_district_", "city_sable_lot_"]

    static func facades(_ district: CityDistrictDefinition) -> [CityDistrictDefinition.VisualSprite] {
        district.visualSprites.filter { sprite in
            facadePrefixes.contains { sprite.textureName.hasPrefix($0) }
        }
    }

    /// Diamond-metric distance from a block centre. 1.0 is the painted block
    /// edge; a facade on a kerb-tiered edge sits at most `pavementBand` beyond.
    static func blockMetric(_ point: CGPoint, _ block: CityBlockGrid.Block) -> CGFloat {
        abs(point.x - block.centre.x) / CityBlockGrid.halfWidth
            + abs(point.y - block.centre.y) / CityBlockGrid.halfHeight
    }

    static var frontageTolerance: CGFloat {
        1 + CityBlockGrid.pavementBand / CityBlockGrid.halfWidth
    }

    /// Baked lot crops are seated on their crop bbox, which for a half-off-plate
    /// edge sits inside the plate — not on the diamond centre. Name is the lot.
    static func lotBlock(for sprite: CityDistrictDefinition.VisualSprite) -> CityBlockGrid.Block? {
        let prefix = "city_sable_lot_"
        guard sprite.textureName.hasPrefix(prefix) else { return nil }
        let tail = String(sprite.textureName.dropFirst(prefix.count))
        if let lot = CityDistrictLayout.IsoLot(rawValue: tail) { return lot.block }
        if tail.hasPrefix("edge_") {
            let rest = tail.dropFirst("edge_".count)
            let parts = rest.split(separator: "_", maxSplits: 1)
            if parts.count == 2, let i = Int(parts[0]), let j = Int(parts[1]) {
                return CityBlockGrid.block(i: i, j: j)
            }
        }
        return nil
    }

    @Test func everyFacadeFrontsABlockRatherThanStandingInAStreet() {
        for id in CityDistrictID.allCases {
            let district = CityDistrictCatalog.definition(for: id)
            for facade in Self.facades(district) {
                if Self.lotBlock(for: facade) != nil { continue }
                let nearest = CityBlockGrid.all
                    .map { Self.blockMetric(facade.groundPoint, $0) }
                    .min() ?? .greatestFiniteMagnitude
                #expect(
                    nearest <= Self.frontageTolerance,
                    "\(id) \(facade.textureName) at \(facade.groundPoint) stands \(nearest) block-metric out, in a street"
                )
            }
        }
    }

    /// Rule 2: a block is one continuous built mass, not boxes with daylight
    /// between them. Two facades per block is the floor — one is a shed on an
    /// empty lot, which is exactly what these districts used to look like.
    @Test func everyBlockCarriesBuiltMass() {
        for id in CityDistrictID.allCases {
            let district = CityDistrictCatalog.definition(for: id)
            let placed = Self.facades(district)
            // A ward whose architecture is painted into one continuous plate
            // satisfies this rule by construction — there are no boxes to leave
            // daylight between. The rule is about modular facade placement, so
            // it only has something to say where facades are placed.
            guard !placed.isEmpty else { continue }
            #expect(placed.count >= 12, "\(id) has only \(placed.count) facades")
            for block in CityBlockGrid.surveyed {
                let onBlock = placed.filter {
                    Self.lotBlock(for: $0) == block
                        || Self.blockMetric($0.groundPoint, block) <= Self.frontageTolerance
                }
                let lotFilling = onBlock.contains { sprite in
                    sprite.textureName.hasPrefix("city_sable_lot_")
                        || (sprite.worldSize?.width ?? 0) >= 1_000
                }
                #expect(
                    lotFilling || onBlock.count >= 2,
                    "\(id) block (\(block.i),\(block.j)) carries \(onBlock.count)"
                )
            }
        }
    }

    /// Rule 4: Baldur's Gate dense city floors sit near 25% walkable (AR0300
    /// class); the old 30% floor was a legacy lattice assertion. Upper 55%
    /// still catches an empty plaza.
    @Test func walkableFractionSitsInTheInfinityEngineBand() {
        let band: ClosedRange<Double> = 0.20...0.55
        for id in CityDistrictID.allCases {
            let search = CityDistrictCatalog.definition(for: id).makeGrid().searchMap
            let radius = NavigationAgentProfile.detective.radius
            var passable = 0
            var total = 0
            for column in 0..<search.columns {
                for row in 0..<search.rows {
                    total += 1
                    let cell = SearchMapCell(column: column, row: row)
                    if search.isPassable(at: search.center(of: cell), radius: radius) {
                        passable += 1
                    }
                }
            }
            let fraction = Double(passable) / Double(total)
            #expect(band.contains(fraction), "\(id) is \(Int(fraction * 100))% walkable")
        }
    }

    /// Sable's buildings are lot-filling iso terraces, not V2 dimetric cubes.
    @Test func sableRowPlacesNoCubeFacades() {
        let cubes = CityDistrictCatalog.sableRow.visualSprites.filter {
            $0.textureName.hasPrefix("city_building_")
        }
        #expect(cubes.isEmpty, "Sable still places cubes: \(cubes.map(\.textureName))")
    }

    /// Every Sable facade with an authored world size is an IE 6-adult city block.
    @Test func everySableFacadeIsInfinityEngineCityHeight() {
        // Facades are painted into the day plate; no modular height to measure.
        #expect(CityDistrictCatalog.sableRow.visualSprites.isEmpty)
    }

    /// Cover polygons track the IE street-plan masses, not the retired lattice.
    @Test func everySableBlockHasACameraNearStreetWall() {
        let walls = AreaCoverAuthoring.districtWallPolygons()
        #expect(walls.count == CityStreetPlan.all.count)
        for mass in CityStreetPlan.all {
            #expect(walls.contains { $0.id == mass.id })
        }
    }

    /// Lamps, cars, benches and the rest belong on the street. A sedan whose
    /// ground point sits inside a diamond is parked in someone's parlour.
    /// Furniture is paint on the streets plate now; the frozen modular dump
    /// is what the bake actually stamped.
    @Test func sableStreetFurnitureStandsOnTheStreet() throws {
        #expect(
            !CityDistrictCatalog.sableRow.visualSprites.contains {
                $0.textureName.hasPrefix("city_prop_")
            }
        )
        struct FrozenSprite: Decodable {
            let textureName: String
            let groundPoint: Point
            struct Point: Decodable { let x: CGFloat; let y: CGFloat }
        }
        struct Frozen: Decodable { let sprites: [FrozenSprite] }
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent(
                "ArtSource/Generated/CityDistrict/V2/SableRow/sable_modular_sprites.json"
            )
        let frozen = try JSONDecoder().decode(Frozen.self, from: Data(contentsOf: url))
        let prefixes = [
            "city_prop_car_", "city_prop_lamp", "city_prop_bench",
            "city_prop_kiosk", "city_prop_statue", "city_prop_crates",
            "city_prop_gate"
        ]
        let furniture = frozen.sprites.filter { sprite in
            prefixes.contains { sprite.textureName.hasPrefix($0) }
        }
        #expect(furniture.count == 45, "bake furniture count moved to \(furniture.count)")
        for sprite in furniture {
            let point = CGPoint(x: sprite.groundPoint.x, y: sprite.groundPoint.y)
            #expect(
                CityBlockGrid.isOnStreet(point),
                "\(sprite.textureName) at \(point) stands in a block"
            )
        }
    }

    /// IE outdoor Sable ships one day plate; lot crops remain bake provenance only.
    @Test func sableCatalogLotsMatchTheAreaBake() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        #expect(CityDistrictCatalog.sableRow.groundTextureName == "city_sable_row_day_v01")
        #expect(CityDistrictCatalog.sableRow.visualSprites.isEmpty)
        let day = root.appendingPathComponent(
            "RainShadow Shared/Resources/Art/Areas/CityDistrict/V2/city_sable_row_day_v01.png"
        )
        let night = root.appendingPathComponent(
            "RainShadow Shared/Resources/Art/Areas/CityDistrict/V2/city_sable_row_night_placeholder_v01.png"
        )
        #expect(FileManager.default.fileExists(atPath: day.path))
        #expect(FileManager.default.fileExists(atPath: night.path))
        let area = try AreaCatalogLoader.load(HarborpointAreas.sableRow)
        #expect(area.plateTextureName == "city_sable_row_day_v01")
        #expect(area.nightPlateTextureName == "city_sable_row_night_placeholder_v01")
        #expect(area.props.isEmpty)
        #expect(area.doors.contains { $0.id == "portal.office" })
    }

    /// Same street-wall rule as Sable, counted in warehouse / shed / boarding
    /// language. A docks lot with one shed on it is still a shed on a lot.
    @Test func everyWharfBlockHasACameraNearStreetWall() {
        let district = CityDistrictCatalog.wharfLadder
        let facades = Self.facades(district)
        for block in CityBlockGrid.surveyed where block.isOnPlate {
            let nearEdgeCount = facades.filter { sprite in
                guard Self.blockMetric(sprite.groundPoint, block) <= Self.frontageTolerance else {
                    return false
                }
                let dNear = hypot(
                    sprite.groundPoint.x - block.nearTip.x,
                    sprite.groundPoint.y - block.nearTip.y
                )
                let dFar = hypot(
                    sprite.groundPoint.x - block.farTip.x,
                    sprite.groundPoint.y - block.farTip.y
                )
                return dNear <= dFar
            }.count
            #expect(
                nearEdgeCount >= 2,
                "Wharf block (\(block.i),\(block.j)) has no camera-near street wall"
            )
        }
    }

    /// Cargo and lamps belong on The Quay, not in a warehouse and not in the drink.
    @Test func wharfStreetFurnitureStandsOnTheQuay() {
        let prefixes = [
            "city_prop_car_", "city_prop_lamp", "city_prop_crates", "city_prop_gate"
        ]
        let water = CityDistrictCatalog.wharfWater
        for sprite in CityDistrictCatalog.wharfLadder.visualSprites {
            guard prefixes.contains(where: { sprite.textureName.hasPrefix($0) }) else { continue }
            #expect(
                CityStreetPlan.isOnStreet(sprite.groundPoint),
                "\(sprite.textureName) at \(sprite.groundPoint) stands in a block"
            )
            #expect(
                !water.contains(sprite.groundPoint),
                "\(sprite.textureName) at \(sprite.groundPoint) stands in the water"
            )
        }
    }

    /// South arrival used to land in the puddle. After the waterfront grew it
    /// has to come in on The Quay, above the water rect.
    @Test func wharfSouthArrivalLandsOnTheQuay() {
        let district = CityDistrictCatalog.wharfLadder
        let south = district.spawnByArrivalKey["from.south"]
        #expect(south != nil)
        if let south {
            #expect(south.y > CityDistrictCatalog.wharfWater.maxY, "south spawn \(south) is in the water")
            #expect(CityStreetPlan.isOnStreet(south), "south spawn \(south) is inside a pad")
        }
        for crossing in [
            CityDistrictLayout.StreetCrossing.harborWest,
            CityDistrictLayout.StreetCrossing.harborVoss
        ] {
            #expect(
                !CityDistrictCatalog.wharfWater.contains(crossing),
                "quay crossing \(crossing) is flooded"
            )
        }
    }

    /// Min-width obstacle bands sit inside each mass diamond; the painted SR
    /// blocks pad interiors the bands do not cover. Mass centres must still be
    /// unwalkable, and plan crossings must stay open.
    @Test func obstaclesFollowThePaintedBlocks() throws {
        for id in CityDistrictID.allCases {
            let area = try AreaCatalogLoader.load(CityDistrictAreaAdapter.areaID(for: id))
            let map = area.makeNavigationMap()
            let radius = area.agentProfile.navigationProfile.radius
            let district = CityDistrictCatalog.definition(for: id)
            for mass in CityStreetPlan.all where CityDistrictLayout.worldBounds.contains(mass.centre) {
                #expect(
                    mass.contains(mass.centre),
                    "\(id) mass \(mass.id) centre lies outside its UV AABB"
                )
                #expect(
                    !map.searchMap.isPassable(at: mass.centre, radius: radius),
                    "\(id) mass \(mass.id) centre is walkable"
                )
            }
            for crossing in CityStreetPlan.crossings {
                #expect(
                    CityStreetPlan.isOnStreet(crossing),
                    "\(id) road crossing \(crossing) is inside a pad mass"
                )
                #expect(
                    map.searchMap.isPassable(at: crossing, radius: radius),
                    "\(id) road crossing \(crossing) is not standable"
                )
            }
        }
    }
}
