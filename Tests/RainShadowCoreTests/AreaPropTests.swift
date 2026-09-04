import CoreGraphics
import Foundation
import Testing
@testable import RainShadowCore

/// The office's plate/live split as authored data.
///
/// `office_props_v01.json` remains migration history, but the approved V03
/// concept embeds the complete room in `office_suite_plate`.
struct AreaPropTests {

    static func officeProps() throws -> [AreaProp] {
        try AreaCatalogLoader.load(HarborpointAreas.office).props
    }

    private struct PropsDocument: Decodable { let props: [AreaProp] }

    private struct BakeManifest: Decodable {
        let bakedPropIDs: [String]
        let livePropIDs: [String]
        let retiredPropIDs: [String]
        let logicalDoorID: String
        let doorVisual: String
    }

    static func officeSourceProps() throws -> [AreaProp] {
        let data = try Data(contentsOf: OfficeAreaAdapter.propsSourceURL)
        return try JSONDecoder().decode(PropsDocument.self, from: data).props
    }

    private static func bakeManifest() throws -> BakeManifest {
        let url = OfficeAreaAdapter.propsSourceURL
            .deletingLastPathComponent()
            .appendingPathComponent("PlateBake/office_plate_bake_manifest_v19.json")
        return try JSONDecoder().decode(BakeManifest.self, from: Data(contentsOf: url))
    }

    @Test func theOfficeDescribesItsScenery() throws {
        let props = try Self.officeProps()
        #expect(props.isEmpty, "V03 already embeds every visible office prop")

        var byLayer: [AreaPropLayer: Int] = [:]
        for prop in props { byLayer[prop.layer, default: 0] += 1 }
        #expect(byLayer.isEmpty)

        let split = try Self.bakeManifest()
        #expect(Set(props.map(\.id)) == Set(split.livePropIDs))
        #expect(split.bakedPropIDs.isEmpty)
        let sourceIDs = Set(try Self.officeSourceProps().map(\.id))
        #expect(
            Set(split.retiredPropIDs)
                == sourceIDs.subtracting(split.livePropIDs).subtracting(split.bakedPropIDs)
        )
        #expect(split.logicalDoorID == "office.door")
        #expect(split.doorVisual == "baked into plate")
    }

    @Test func propIDsAreUnique() throws {
        // Identity remains the interaction key if an overlay is added later.
        let ids = try Self.officeProps().map(\.id)
        #expect(Set(ids).count == ids.count, "a prop id is used twice")
    }

    /// The distinction that broke a plate bake: a node's name is not its art.
    /// If these collapse, anything resolving art by id composites the wrong
    /// picture — and the result looks almost right, which is the worst kind of
    /// wrong.
    @Test func aPropsIdentityIsSeparateFromItsArt() throws {
        let props = try Self.officeSourceProps()
        // The rug, the wall stripes, the second visitor armchair, and Voss's
        // stable desk-chair identity (which now uses broad leather chair art).
        let renamed = props.filter { $0.id != $0.textureName }
        #expect(renamed.count == 4, "renamed set changed: \(renamed.map(\.id).sorted())")

        let rug = try #require(props.first { $0.id == "office_worn_rug" })
        #expect(rug.textureName == "office_worn_rug_burgundy")

        let stripes = try #require(props.first { $0.id == "office_light_blind_stripes_wall" })
        #expect(stripes.textureName == "office_light_blind_stripes")

        let vossChair = try #require(props.first { $0.id == "office_desk_chair" })
        #expect(vossChair.textureName == "office_visitor_armchair")
    }

    /// Five of the office's sprites are additive light casts. Losing the blend
    /// mode washes the room out, which reads as an art change rather than a bug.
    @Test func theLightCastsKeepTheirAdditiveBlend() throws {
        let props = try Self.officeSourceProps()
        let additive = props.filter { $0.blend == .add }.map(\.id).sorted()
        #expect(
            additive == [
                "office_light_blind_stripes",
                "office_light_blind_stripes_wall",
                "office_light_hallway",
                "office_light_lamp_pool",
                "office_light_window_spill"
            ],
            "additive set changed: \(additive)"
        )
        for prop in additive.compactMap({ id in props.first { $0.id == id } }) {
            #expect(prop.alpha < 1, "\(prop.id) is additive at full alpha")
        }
    }

    /// The office authors a prop as a *scale* of its art, which is what its
    /// placement code did — and the two are not interchangeable.
    ///
    /// `SKSpriteNode.size` and `xScale` multiply, so a sprite built at an
    /// absolute size has a scale of 1. Anything that later animates its scale
    /// then renders it at that scale outright instead of relative to how it was
    /// placed, and the entrance leaf is driven by `setScale` on every fall and
    /// every restore: rebuilt from a size, it stands back up at an eighth of
    /// itself. Storing the rendered size is not a tidier way to say the same
    /// thing, and the difference is invisible in a still frame.
    @Test func officePropsCarryTheScaleTheyWereBuiltWithRatherThanASize() throws {
        for prop in try Self.officeProps() {
            #expect(prop.worldSize == nil, "\(prop.id) carries an absolute size")
            #expect(prop.scaleX > 0 && prop.scaleY > 0, "\(prop.id) is degenerate")
        }
    }

    /// Static furniture and windows are plate pixels, while the door is an
    /// `AreaDoor` visual. None may survive as a second runtime sprite.
    @Test func bakedSceneryAndRegisteredDoorAreNotGeneralProps() throws {
        let props = try Self.officeProps()
        for bakedID in [
            "office_window", "office_door_leaf", "office_bookshelf",
            "office_filing_cabinet", "office_safe", "office_coat_rack",
            "office_waiting_chair_a", "office_waiting_chair_b", "office_worn_rug"
        ] {
            #expect(!props.contains { $0.id == bakedID }, "\(bakedID) would draw twice")
        }
        #expect(props.allSatisfy { $0.warp == nil })
        #expect(props.allSatisfy { $0.scale != nil })
    }

    /// V03's chair is embedded in the approved plate; a legacy chair node would
    /// draw a second seat over it.
    @Test func theDeskChairIsOwnedByThePlate() throws {
        let props = try Self.officeProps()
        #expect(!props.contains { $0.id == "office_desk_chair" })
    }

    /// Every prop must sit somewhere in the area it belongs to, or it is
    /// scenery nobody will ever see.
    @Test func everyPropStandsInsideItsArea() throws {
        let office = try AreaCatalogLoader.load(HarborpointAreas.office)
        for prop in office.props {
            #expect(
                office.worldBounds.contains(prop.groundPoint.cgPoint),
                "\(prop.id) at \(prop.groundPoint) is outside the office"
            )
        }
    }

    /// A complete Infinity-Engine-style area plate owns its architecture and
    /// street furniture. Keeping the old modular props would draw every
    /// building a second time over the monolithic painting.
    @Test func aMonolithicDistrictDoesNotRedrawModularProps() throws {
        let sableRow = try AreaCatalogLoader.load(HarborpointAreas.sableRow)
        // Sable Row's IE outdoor rebuild ships a day plate (and an authored
        // night plate) rather than the modular block composite.
        #expect(sableRow.plateTextureName == "city_sable_row_day_v01")
        #expect(sableRow.props.isEmpty)
    }
}
