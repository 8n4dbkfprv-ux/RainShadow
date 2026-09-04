import CoreGraphics
import Foundation
import Testing
@testable import RainShadowCore

/// Writes the live district catalog to JSON for the offline previewer.
///
/// `ArtSource/Processing/compose_city_district_preview.py` used to re-declare
/// every sprite in Python "transcribed from CityDistrictCatalog; keep in step
/// when it moves". It did not stay in step — it drifted two refactors and a
/// world-size change behind, so the one tool that could review a district
/// layout without opening Xcode was reviewing a layout nobody shipped.
///
/// There is no way to run SpriteKit on the art pipeline's machine, so the fix
/// is not to delete the previewer but to stop it guessing: dump what the
/// catalog actually holds, and render from that.
///
///     swift test --scratch-path /tmp/RainShadowSwiftPM --filter CityLayoutDump
///     python3 ArtSource/Processing/compose_city_district_preview.py --all
struct CityLayoutDumpTests {

    /// Beside `sable_iso_lots.json`, the other survey the layout rests on.
    /// In the tree rather than a temp dir so a layout change shows up as a
    /// reviewable diff, and so the previewer has one path to look in.
    static var outputURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("ArtSource/Generated/CityDistrict/V2/city_layout.json")
    }

    private static func point(_ p: CGPoint) -> [String: CGFloat] { ["x": p.x, "y": p.y] }

    private static func rect(_ r: CGRect) -> [String: CGFloat] {
        ["x": r.minX, "y": r.minY, "w": r.width, "h": r.height]
    }

    private static func sprite(_ s: CityDistrictDefinition.VisualSprite) -> [String: Any] {
        var out: [String: Any] = [
            "textureName": s.textureName,
            "groundPoint": point(s.groundPoint),
            "scale": s.scale,
            "anchorY": s.anchorY,
            "depthBias": s.depthBias
        ]
        if let worldSize = s.worldSize {
            out["worldSize"] = ["w": worldSize.width, "h": worldSize.height]
        }
        if let slice = s.depthSliceWidth { out["depthSliceWidth"] = slice }
        if let lot = s.depthSortLot { out["depthSortLot"] = lot }
        return out
    }

    static func payload() -> [String: Any] {
        let blocks = CityBlockGrid.all.map { block -> [String: Any] in
            [
                "i": block.i,
                "j": block.j,
                "centre": point(block.centre),
                "vertices": block.vertices.map(point)
            ]
        }
        let districts = CityDistrictID.allCases.map { id -> [String: Any] in
            let district = CityDistrictCatalog.definition(for: id)
            return [
                "id": id.rawValue,
                "slug": id.slug,
                "locationName": district.locationName,
                "groundTextureName": district.groundTextureName,
                "actorStart": point(district.actorStart),
                "spawns": district.spawnByArrivalKey.mapValues(point),
                "sprites": district.runtimeVisualSprites.map(sprite),
                "obstacles": district.obstacles.map(rect),
                "portals": district.portals.map { portal in
                    [
                        "id": portal.id,
                        "label": portal.label,
                        "approachPoint": point(portal.approachPoint),
                        "hitArea": rect(portal.hitArea)
                    ] as [String: Any]
                },
                "pointsOfInterest": district.pointsOfInterest.map {
                    ["label": $0.label, "worldPoint": point($0.worldPoint)] as [String: Any]
                }
            ]
        }
        return [
            "worldSize": [
                "w": CityDistrictDefinition.worldArtSize.width,
                "h": CityDistrictDefinition.worldArtSize.height
            ],
            "standingAdultBodyHeight": CityDistrictDefinition.standingAdultBodyHeight,
            "agentRadius": NavigationAgentProfile.detective.radius,
            "blockGrid": [
                "halfWidth": CityBlockGrid.halfWidth,
                "halfHeight": CityBlockGrid.halfHeight,
                "blocks": blocks,
                "crossings": CityBlockGrid.crossings.map(point)
            ],
            "districts": districts
        ]
    }

    @Test func dumpsTheLiveCatalogForTheOfflinePreviewer() throws {
        let data = try JSONSerialization.data(
            withJSONObject: Self.payload(),
            options: [.prettyPrinted, .sortedKeys]
        )
        try data.write(to: Self.outputURL)
        #expect(data.count > 4_000)
    }
}
