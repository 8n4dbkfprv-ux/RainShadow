import CoreGraphics
import Foundation
import Testing
@testable import RainShadowCore

/// Writes the shipped area files from the Swift geometry that currently defines
/// them.
///
/// This is a content-producing test in the same spirit as `CityLayoutDumpTests`,
/// and for the same reason: the districts, the office and the exterior are
/// thousands of lines of measured Swift, and retyping those numbers into JSON by
/// hand would introduce exactly the rounding errors `AGENTS.md` warns about
/// ("do not round hand-authored nav coordinates" — three city spawns already
/// failed re-validation because tidy numbers were substituted for computed ones).
///
/// The arrow reverses once: run this, commit the output, and from then on the
/// JSON is the source of truth. `AreaParityTests` guards the crossing by
/// asserting the written files still match the Swift they came from, so a drift
/// in either direction is a red test rather than a silent divergence.
///
///     swift test --scratch-path /tmp/RainShadowSwiftPM --filter AreaExport
struct AreaExportTests {

    static var outputDirectory: URL { AreaCatalogLoader.developmentAreasDirectory }

    static func outputURL(for id: AreaID) -> URL {
        outputDirectory.appendingPathComponent(
            "\(id.rawValue)\(AreaCatalogLoader.resourceSuffix).json",
            isDirectory: false
        )
    }

    /// Stable across runs so an area change reads as a reviewable diff.
    static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return encoder
    }

    /// The establishing shot. It has no walkable ground, no regions and no
    /// actors — in Infinity Engine terms it is an area that exists only to be
    /// looked at while a cutscene runs — so it is authored here rather than
    /// projected from geometry that does not exist.
    static var openingExterior: AreaDefinition {
        let artSize = CGSize(width: 3_072, height: 1_728)
        return AreaDefinition(
            id: HarborpointAreas.openingExterior,
            displayName: "HARBOR STREET — RAIN",
            kind: .exterior,
            // A city street, so no shroud beyond its doors — same as the wards.
            areaType: [.outdoor, .city],
            worldSize: AreaSize(artSize),
            plateTextureName: "ext_apartment_base",
            agentProfile: AreaAgentProfile(.point),
            entrances: [
                // The camera focus. Nothing stands here; the entrance exists so
                // every area answers "where does an arrival land" with a point
                // rather than with a special case.
                AreaEntrance(
                    name: AreaEntrance.defaultName,
                    point: AreaPoint(x: 1_536, y: 760)
                )
            ],
            ambients: [
                AreaAmbient(
                    id: "amb.rain",
                    assetName: "amb_rain_exterior",
                    volume: 0.52,
                    isLooping: true
                )
            ]
        )
    }

    /// Every shipped area, in `HarborpointAreas.shippedIDs` order.
    static var shippedAreas: [AreaDefinition] {
        [OfficeAreaAdapter.area(), openingExterior]
            + CityDistrictAreaAdapter.allDistrictAreas
            + CityInteriorAreaAdapter.allAreas
    }

    @Test func writesEveryShippedAreaFile() throws {
        try FileManager.default.createDirectory(
            at: Self.outputDirectory,
            withIntermediateDirectories: true
        )

        let encoder = Self.encoder
        for area in Self.shippedAreas {
            let document = AreaDocument(area: area)
            let data = try encoder.encode(document)
            let output = Self.outputURL(for: area.id)
            // Full-suite tests run concurrently. Avoid replacing an already
            // current area beneath AreaParityTests, and use an atomic rename
            // when an authored change genuinely needs a new document.
            if (try? Data(contentsOf: output)) != data {
                try data.write(to: output, options: .atomic)
            }
        }

        // Every id the shipped facade promises must now exist on disk, or the
        // app would trap at launch loading a catalog that is a file short.
        for id in HarborpointAreas.shippedIDs {
            #expect(
                FileManager.default.fileExists(atPath: Self.outputURL(for: id).path),
                "no area file written for '\(id)'"
            )
        }
    }

    /// The export is only useful if what it wrote loads and validates — including
    /// the cross-area checks, which is where a travel region pointing at a
    /// renamed entrance would surface.
    @Test func theExportedFilesLoadAndValidate() throws {
        let catalog = try AreaCatalogLoader.validate(Self.shippedAreas)
        #expect(catalog.count == HarborpointAreas.shippedIDs.count)
        for id in HarborpointAreas.shippedIDs {
            #expect(catalog.area(for: id) != nil, "catalog is missing '\(id)'")
        }
    }
}
