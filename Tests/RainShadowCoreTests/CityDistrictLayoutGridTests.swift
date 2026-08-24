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

    /// Rule 4: Baldur's Gate city districts run roughly 30–45 % walkable. Too
    /// high and the blocks read as fields; too low and the district is sealed.
    /// This is the one number that catches both.
    @Test func walkableFractionSitsInTheInfinityEngineBand() {
        let band: ClosedRange<Double> = 0.30...0.50
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
        let adult = CityDistrictLayout.standingAdultBodyHeight
        for sprite in Self.facades(CityDistrictCatalog.sableRow) {
            // Lot crops stack a near terrace and a far rank; height is not one block.
            if sprite.textureName.hasPrefix("city_sable_lot_") { continue }
            guard let height = sprite.worldSize?.height else { continue }
            let multiple = height / adult
            #expect(
                (5.0...7.0).contains(multiple),
                "\(sprite.textureName) is \(multiple)× adult, not IE city scale"
            )
        }
    }

    /// A Baldur's Gate block has a camera-near street wall. A terrace, south
    /// canyon, skyline or corner-shop seated on the near tip counts; otherwise
    /// the near edges must carry at least two facades. One cube on the far
    /// half is a shed on a lot, which is what Sable used to look like.
    @Test func everySableBlockHasACameraNearStreetWall() {
        let district = CityDistrictCatalog.sableRow
        let facades = Self.facades(district)
        let nearTipMass: Set<String> = [
            "city_terrace_sable_sw", "city_terrace_sable_se",
            "city_terrace_sable_nw", "city_terrace_sable_ne",
            "city_terrace_sable_south_w", "city_terrace_sable_south_e",
            "city_district_sable_north_skyline",
            "city_district_sable_corner_shops"
        ]
        for block in CityBlockGrid.surveyed where block.isOnPlate {
            // A punched lot crop is the whole diamond, including the street wall.
            // Edge crops sit on their opaque bbox, not the surveyed near tip.
            if facades.contains(where: { Self.lotBlock(for: $0) == block }) {
                continue
            }
            let nearTipCovered = facades.contains { sprite in
                let isMass = nearTipMass.contains(sprite.textureName)
                    || sprite.textureName.hasPrefix("city_sable_lot_")
                guard isMass else { return false }
                let dx = sprite.groundPoint.x - block.nearTip.x
                let dy = sprite.groundPoint.y - block.nearTip.y
                // South lots clamp the painted foot from y = −24 to 0.
                return abs(dx) <= 16 && abs(dy) <= 32
            }
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
                nearTipCovered || nearEdgeCount >= 2,
                "Sable block (\(block.i),\(block.j)) has no camera-near street wall"
            )
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

    /// Catalog lot crops must stay seated on the bake's opaque-bbox feet.
    /// A tidy-number rewrite here is how three city spawns used to fail.
    @Test func sableCatalogLotsMatchTheAreaBake() throws {
        struct BakePoint: Decodable { let x: CGFloat; let y: CGFloat }
        struct BakeSize: Decodable { let w: CGFloat; let h: CGFloat }
        struct BakeLot: Decodable {
            let textureName: String
            let groundPoint: BakePoint
            let worldSize: BakeSize
            let depthSliceWidth: CGFloat?
            let depthSortLot: String?
        }
        struct Bake: Decodable {
            let streetsTexture: String
            let lots: [BakeLot]
            let counts: Counts
            struct Counts: Decodable {
                let furniture: Int
                let architecture: Int
            }
        }
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let bake = try JSONDecoder().decode(
            Bake.self,
            from: Data(contentsOf: root.appendingPathComponent(
                "ArtSource/Generated/CityDistrict/V2/SableRow/sable_area_bake.json"
            ))
        )
        #expect(bake.streetsTexture == CityDistrictCatalog.sableRow.groundTextureName)
        #expect(bake.lots.count == 12)
        #expect(bake.counts.furniture == 45)
        #expect(bake.counts.architecture == 18)

        let placed = Dictionary(
            uniqueKeysWithValues: CityDistrictCatalog.sableRow.visualSprites
                .filter { $0.textureName.hasPrefix("city_sable_lot_") }
                .map { ($0.textureName, $0) }
        )
        #expect(placed.count == bake.lots.count)
        for lot in bake.lots {
            let sprite = placed[lot.textureName]
            #expect(sprite != nil, "catalog is missing \(lot.textureName)")
            guard let sprite else { continue }
            #expect(sprite.groundPoint.x == lot.groundPoint.x, "\(lot.textureName) foot x")
            #expect(sprite.groundPoint.y == lot.groundPoint.y, "\(lot.textureName) foot y")
            #expect(sprite.worldSize?.width == lot.worldSize.w, "\(lot.textureName) width")
            #expect(sprite.worldSize?.height == lot.worldSize.h, "\(lot.textureName) height")
            #expect(sprite.depthSliceWidth == lot.depthSliceWidth, "\(lot.textureName) slice")
            #expect(sprite.depthSortLot == lot.depthSortLot, "\(lot.textureName) sort lot")
            let art = root.appendingPathComponent(
                "RainShadow Shared/Resources/Art/Props/CityDistrict/V2/\(lot.textureName).png"
            )
            #expect(FileManager.default.fileExists(atPath: art.path), "missing \(lot.textureName).png")
        }
        let streets = root.appendingPathComponent(
            "RainShadow Shared/Resources/Art/Areas/CityDistrict/V2/city_sable_row_area_streets_v01.png"
        )
        #expect(FileManager.default.fileExists(atPath: streets.path))
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
                CityBlockGrid.isOnStreet(sprite.groundPoint),
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
            #expect(CityBlockGrid.isOnStreet(south), "south spawn \(south) is inside a pad")
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

    /// Obstacles have to be the painted blocks, not a shape of their own — that
    /// was the whole failure. Checked at each block's centre (must be blocked)
    /// and at every road crossing (must not be).
    @Test func obstaclesFollowThePaintedBlocks() {
        for id in CityDistrictID.allCases {
            let district = CityDistrictCatalog.definition(for: id)
            for block in CityBlockGrid.all where CityDistrictLayout.worldBounds.contains(block.centre) {
                #expect(
                    district.obstacles.contains { $0.contains(block.centre) },
                    "\(id) block (\(block.i),\(block.j)) centre is walkable"
                )
            }
            for crossing in CityBlockGrid.crossings {
                #expect(
                    !district.obstacles.contains { $0.contains(crossing) },
                    "\(id) road crossing \(crossing) is blocked"
                )
            }
        }
    }
}
