import CoreGraphics
import Foundation
import Testing
@testable import RainShadowCore

/// The office's plate/live split as authored data.
///
/// `props` was empty from the day the record existed, because the office places
/// its scenery imperatively — texture names as string literals at roughly sixty
/// call sites. `office_props_v01.json` remains the placement authority, but the
/// shipped area retains only the desk cluster that must sort around a seated
/// actor; the rest is now pixels in `office_suite_plate`.
struct AreaPropTests {

    static func officeProps() throws -> [AreaProp] {
        try AreaCatalogLoader.load(HarborpointAreas.office).props
    }

    private struct PropsDocument: Decodable { let props: [AreaProp] }

    private struct BakeManifest: Decodable {
        let bakedPropIDs: [String]
        let livePropIDs: [String]
        let retiredPropIDs: [String]
        let registeredDoorID: String
        let registeredDoorStates: [String]
    }

    static func officeSourceProps() throws -> [AreaProp] {
        let data = try Data(contentsOf: OfficeAreaAdapter.propsSourceURL)
        return try JSONDecoder().decode(PropsDocument.self, from: data).props
    }

    private static func bakeManifest() throws -> BakeManifest {
        let url = OfficeAreaAdapter.propsSourceURL
            .deletingLastPathComponent()
            .appendingPathComponent("PlateBake/office_plate_bake_manifest_v15.json")
        return try JSONDecoder().decode(BakeManifest.self, from: Data(contentsOf: url))
    }

    @Test func theOfficeDescribesItsScenery() throws {
        let props = try Self.officeProps()
        #expect(props.count == 5, "the office describes \(props.count) live overlays")

        var byLayer: [AreaPropLayer: Int] = [:]
        for prop in props { byLayer[prop.layer, default: 0] += 1 }
        #expect(byLayer == [.depthWorld: 5])
        #expect(Set(props.map(\.id)) == [
            "office_desk_bare",
            "office_desk_chair",
            "office_desk_actor_occluder",
            "office_desk_front_occluder_v04",
            "office_desk_top_occluder"
        ])

        let split = try Self.bakeManifest()
        #expect(Set(props.map(\.id)) == Set(split.livePropIDs))
        #expect(split.bakedPropIDs.isEmpty)
        #expect(split.retiredPropIDs.count == 46)
        #expect(split.registeredDoorID == "office.door")
        #expect(split.registeredDoorStates == ["closed", "mid", "open"])
    }

    @Test func propIDsAreUnique() throws {
        // Identity remains the interaction key even when art names happen to
        // match throughout today's live desk cluster.
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

    /// The desk chair is a world prop, standing where the empty seat is.
    ///
    /// Inherited from `ActorLocomotionPacingTests`, which asserted it as source
    /// text while the chair was placed in code. It is load-bearing: Voss's
    /// seated and transition atlases are chairless, so this prop is the only
    /// chair in the room and has to be drawn in every actor state. A record that
    /// dropped it would empty the desk the moment he stood up.
    @Test func theDeskChairIsAWorldPropStandingWhereTheSeatIs() throws {
        let props = try Self.officeProps()
        let chair = try #require(props.first { $0.id == "office_desk_chair" })
        #expect(chair.layer == .depthWorld, "the chair must sort against actors")

        let seat = OfficeNavigationLayout.emptyDeskChairWorldPosition
        #expect(
            abs(chair.groundPoint.x - seat.x) < 0.01
                && abs(chair.groundPoint.y - seat.y) < 0.01,
            "chair at \(chair.groundPoint), seat at \(seat)"
        )
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
            sableRow.props.contains { prop in
                guard prop.worldSize == nil, let scale = prop.scale else { return false }
                return scale != 1
            },
            "no district prop uses the scale form any more"
        )
        #expect(sableRow.props.allSatisfy { $0.layer == .depthWorld })
    }
}
