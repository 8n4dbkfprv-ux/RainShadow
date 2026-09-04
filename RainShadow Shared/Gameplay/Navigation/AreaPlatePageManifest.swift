import CoreGraphics
import Foundation

/// Runtime description of one paged area painting.
///
/// The Infinity Engine stores an area as 64x64 TIS tiles. RainShadow keeps its
/// authored painting continuous, but packages it in larger 1024x768-world-unit
/// pages so only the camera neighbourhood is decoded and resident on the GPU.
struct AreaPlatePageManifest: Decodable, Equatable {
    struct Page: Decodable, Equatable {
        let id: String
        let textureName: String
        var fileExtension: String? = nil
        let worldRect: AreaRect
        let pixelWidth: Int
        let pixelHeight: Int
    }

    let version: Int
    let plateTextureName: String
    let worldSize: AreaSize
    let pageWorldSize: AreaSize
    let pages: [Page]

    static func resourceStem(for plateTextureName: String) -> String {
        (plateTextureName as NSString).deletingPathExtension + ".pages"
    }

    static var resourceBundle: Bundle {
        #if SWIFT_PACKAGE
        .module
        #else
        .main
        #endif
    }

    static func loadIfPresent(named plateTextureName: String) -> Self? {
        let stem = resourceStem(for: plateTextureName)
        guard let url = resourceBundle.url(forResource: stem, withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(Self.self, from: data)
    }

    func pages(intersecting rect: CGRect, prefetchFraction: CGFloat = 0.25) -> [Page] {
        let expanded = rect.insetBy(
            dx: -pageWorldSize.w * prefetchFraction,
            dy: -pageWorldSize.h * prefetchFraction
        )
        return pages.filter { $0.worldRect.cgRect.intersects(expanded) }
    }
}
