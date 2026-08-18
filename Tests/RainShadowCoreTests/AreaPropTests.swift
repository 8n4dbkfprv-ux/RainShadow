import CoreGraphics
import Foundation
import Testing
@testable import RainShadowCore

/// The office's scenery as authored data.
///
/// `props` was empty from the day the record existed, because the office places
/// its scenery imperatively — texture names as string literals at roughly sixty
/// call sites. It is now described by `office_props_v01.json`, converted from
/// what the renderer actually placed.
struct AreaPropTests {

    static func officeProps() throws -> [AreaProp] {
        try AreaCatalogLoader.load(HarborpointAreas.office).props
    }

    @Test func theOfficeDescribesItsScenery() throws {
        let props = try Self.officeProps()
        #expect(props.count == 55, "the office describes \(props.count) props")

        var byLayer: [AreaPropLayer: Int] = [:]
        for prop in props { byLayer[prop.layer, default: 0] += 1 }
        #expect(byLayer[.depthWorld] == 36)
        #expect(byLayer[.rearFixtures] == 9)
        #expect(byLayer[.floorEffects] == 10)
    }

    @Test func propIDsAreUnique() throws {
        // Two visitor armchairs share a texture, so identity has to come from
        // the id rather than the art.
        let ids = try Self.officeProps().map(\.id)
        #expect(Set(ids).count == ids.count, "a prop id is used twice")
    }

    /// The distinction that broke a plate bake: a node's name is not its art.
    /// If these collapse, anything resolving art by id composites the wrong
    /// picture — and the result looks almost right, which is the worst kind of
    /// wrong.
    @Test func aPropsIdentityIsSeparateFromItsArt() throws {
        let props = try Self.officeProps()
        // The rug, the wall stripes, and the second visitor armchair — which
        // shares a node name with the first and is numbered so the record can
        // tell them apart.
        let renamed = props.filter { $0.id != $0.textureName }
        #expect(renamed.count == 3, "renamed set changed: \(renamed.map(\.id).sorted())")

        let rug = try #require(props.first { $0.id == "office_worn_rug" })
        #expect(rug.textureName == "office_worn_rug_burgundy")

        let stripes = try #require(props.first { $0.id == "office_light_blind_stripes_wall" })
        #expect(stripes.textureName == "office_light_blind_stripes")
    }

    /// Five of the office's sprites are additive light casts. Losing the blend
    /// mode washes the room out, which reads as an art change rather than a bug.
    @Test func theLightCastsKeepTheirAdditiveBlend() throws {
        let props = try Self.officeProps()
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

    /// `SKSpriteNode.size` already includes the node's scale, so a prop's world
    /// size is stored directly. Re-applying `scale` on top is the error that
    /// made a bookshelf nine world units wide.
    @Test func propsCarryTheirRenderedWorldSizeRatherThanAScaleFactor() throws {
        for prop in try Self.officeProps() {
            let size = try #require(prop.worldSize, "\(prop.id) has no world size")
            #expect(size.w > 0 && size.h > 0, "\(prop.id) is degenerate")
            #expect(prop.scale == 1, "\(prop.id) carries both a size and a scale")
        }
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

    /// Districts keep the scale-based form, so both authoring styles decode.
    @Test func aDistrictStillUsesScaleRatherThanWorldSize() throws {
        let sableRow = try AreaCatalogLoader.load(HarborpointAreas.sableRow)
        #expect(!sableRow.props.isEmpty)
        #expect(
            sableRow.props.contains { $0.worldSize == nil && $0.scale != 1 },
            "no district prop uses the scale form any more"
        )
        #expect(sableRow.props.allSatisfy { $0.layer == .depthWorld })
    }
}
