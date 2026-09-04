import Foundation
import SpriteKit

/// Camera-local residency for a paged area painting.
@MainActor
final class AreaPlatePager: SKNode {
    let manifest: AreaPlatePageManifest
    private var resident: [String: SKSpriteNode] = [:]

    init?(plateTextureName: String, expectedWorldSize: CGSize) {
        guard let manifest = AreaPlatePageManifest.loadIfPresent(named: plateTextureName),
              manifest.version == 1,
              manifest.plateTextureName == plateTextureName,
              abs(manifest.worldSize.w - expectedWorldSize.width) < 0.5,
              abs(manifest.worldSize.h - expectedWorldSize.height) < 0.5 else {
            return nil
        }
        self.manifest = manifest
        super.init()
        name = "\(plateTextureName).pages"
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("AreaPlatePager is created programmatically")
    }

    func update(cameraPosition: CGPoint, viewportSize: CGSize, cameraScale: CGFloat) {
        guard viewportSize.width > 0, viewportSize.height > 0, cameraScale > 0 else { return }
        let visibleSize = CGSize(
            width: viewportSize.width * cameraScale,
            height: viewportSize.height * cameraScale
        )
        let visible = CGRect(
            x: cameraPosition.x - visibleSize.width / 2,
            y: cameraPosition.y - visibleSize.height / 2,
            width: visibleSize.width,
            height: visibleSize.height
        )
        update(visibleWorldRect: visible)
    }

    func update(visibleWorldRect: CGRect) {
        let wanted = manifest.pages(intersecting: visibleWorldRect)
        let wantedIDs = Set(wanted.map(\.id))

        let retiring = resident.keys.filter { !wantedIDs.contains($0) }
        for id in retiring {
            resident.removeValue(forKey: id)?.removeFromParent()
        }

        for page in wanted where resident[page.id] == nil {
            guard let texture = GameArt.texture(
                named: page.textureName,
                preferredExtension: page.fileExtension
            ) else {
                print("Area plate page '\(page.textureName)' failed to load")
                continue
            }
            texture.filteringMode = .linear
            let rect = page.worldRect.cgRect
            let node = SKSpriteNode(texture: texture, size: rect.size)
            node.name = page.id
            node.anchorPoint = .zero
            node.position = rect.origin
            addChild(node)
            resident[page.id] = node
        }
    }

    var residentPageCount: Int { resident.count }
}
