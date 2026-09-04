import CoreGraphics
import Foundation
import ImageIO
import Testing
@testable import RainShadowCore

struct AreaPlatePagerTests {
    private static let manifest = AreaPlatePageManifest(
        version: 1,
        plateTextureName: "city_test",
        worldSize: AreaSize(w: 5_120, h: 3_840),
        pageWorldSize: AreaSize(w: 1_024, h: 768),
        pages: [
            .init(
                id: "c00_r00",
                textureName: "city_test_page_c00_r00",
                worldRect: AreaRect(x: 0, y: 0, w: 1_024, h: 768),
                pixelWidth: 2_048,
                pixelHeight: 1_536
            ),
            .init(
                id: "c04_r04",
                textureName: "city_test_page_c04_r04",
                worldRect: AreaRect(x: 4_096, y: 3_072, w: 1_024, h: 768),
                pixelWidth: 2_048,
                pixelHeight: 1_536
            ),
        ]
    )

    @Test func manifestNameDoesNotDuplicatePNGExtension() {
        #expect(AreaPlatePageManifest.resourceStem(for: "city_test") == "city_test.pages")
        #expect(AreaPlatePageManifest.resourceStem(for: "city_test.png") == "city_test.pages")
    }

    @Test func residencySelectsOnlyTheCameraNeighbourhood() {
        let nearOrigin = Self.manifest.pages(
            intersecting: CGRect(x: 100, y: 100, width: 700, height: 500),
            prefetchFraction: 0
        )
        #expect(nearOrigin.map(\.id) == ["c00_r00"])

        let northEast = Self.manifest.pages(
            intersecting: CGRect(x: 4_300, y: 3_200, width: 500, height: 400),
            prefetchFraction: 0
        )
        #expect(northEast.map(\.id) == ["c04_r04"])
    }

    /// The opening's camera marks stay in the old world coordinate system;
    /// replacing its art must not accidentally double the scene or introduce
    /// a missing/swapped quadrant. Check the installed images, not just a
    /// manifest which could claim native resolution for smaller payloads.
    @Test func openingNativePagesCoverTheExistingCinematicWorld() throws {
        let (manifest, directory) = try openingManifest()
        #expect(manifest.version == 1)
        #expect(manifest.plateTextureName == "ext_apartment_base_hd_v02")
        #expect(manifest.worldSize == AreaSize(w: 3_072, h: 1_728))
        #expect(manifest.pageWorldSize == AreaSize(w: 1_536, h: 864))
        #expect(manifest.pages.count == 4)
        #expect(Set(manifest.pages.map(\.id)).count == manifest.pages.count)
        #expect(Set(manifest.pages.map(\.textureName)).count == manifest.pages.count)

        let expectedOrigins = [
            CGPoint(x: 0, y: 0), CGPoint(x: 1_536, y: 0),
            CGPoint(x: 0, y: 864), CGPoint(x: 1_536, y: 864)
        ]
        for origin in expectedOrigins {
            let page = try #require(manifest.pages.first {
                $0.worldRect.cgRect.origin == origin
            })
            #expect(page.worldRect.cgRect.size == CGSize(width: 1_536, height: 864))
            #expect(page.pixelWidth == 3_072)
            #expect(page.pixelHeight == 1_728)

            let url = directory.appendingPathComponent(page.textureName)
                .appendingPathExtension(page.fileExtension ?? "png")
            let source = try #require(CGImageSourceCreateWithURL(url as CFURL, nil))
            let properties = try #require(
                CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
            )
            #expect(properties[kCGImagePropertyPixelWidth] as? Int == page.pixelWidth)
            #expect(properties[kCGImagePropertyPixelHeight] as? Int == page.pixelHeight)
        }
    }

    @Test func openingPageSelectionCoversEveryAuthoredCameraMark() throws {
        let (manifest, _) = try openingManifest()
        let world = CGRect(x: 0, y: 0, width: 3_072, height: 1_728)
        let framing = [
            (CutsceneCatalog.OpeningExteriorFraming.streetLevel,
             CutsceneCatalog.OpeningExteriorFraming.openingScale),
            (CutsceneCatalog.OpeningExteriorFraming.buildingWide,
             CutsceneCatalog.OpeningExteriorFraming.approachScale),
            (CutsceneCatalog.OpeningExteriorFraming.officeWindow,
             CutsceneCatalog.OpeningExteriorFraming.arrivalScale)
        ]
        for aspect: CGFloat in [4.0 / 3.0, 16.0 / 9.0, 21.0 / 9.0] {
            for (position, scale) in framing {
                // The opening deliberately keeps BaseGameScene's 1152-unit
                // base height; it does not use the playable actor zoom target.
                let height = 1_152 * scale
                let visible = CGRect(
                    x: position.x - height * aspect / 2,
                    y: position.y - height / 2,
                    width: height * aspect,
                    height: height
                ).intersection(world)
                let selected = manifest.pages(intersecting: visible)
                let coveredArea = selected.reduce(CGFloat.zero) { result, page in
                    let intersection = page.worldRect.cgRect.intersection(visible)
                    return result + (intersection.isNull ? 0 : intersection.width * intersection.height)
                }
                #expect(abs(coveredArea - visible.width * visible.height) < 0.01)
                #expect(selected.count <= 4)
            }
        }
    }

    private func openingManifest() throws -> (AreaPlatePageManifest, URL) {
        let repo = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let directory = repo.appendingPathComponent(
            "RainShadow Shared/Resources/Art/Areas/OpeningExterior",
            isDirectory: true
        )
        let url = directory.appendingPathComponent("ext_apartment_base_hd_v02.pages.json")
        let manifest = try JSONDecoder().decode(
            AreaPlatePageManifest.self,
            from: Data(contentsOf: url)
        )
        return (manifest, directory)
    }
}
