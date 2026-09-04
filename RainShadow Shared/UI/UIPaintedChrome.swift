import SpriteKit

/// Loads required painted UI textures. Missing art must not invent procedural chrome.
enum UIPaintedChrome {
    @MainActor
    static func texture(named name: String, filtering: SKTextureFilteringMode = .linear) -> SKTexture? {
        guard let texture = GameArt.texture(named: name) else {
            assertionFailure("Missing painted UI chrome: \(name).png")
            return nil
        }
        texture.filteringMode = filtering
        return texture
    }

    @MainActor
    static func requireTexture(named name: String, filtering: SKTextureFilteringMode = .linear) -> SKTexture {
        if let texture = texture(named: name, filtering: filtering) {
            return texture
        }
        // Invisible 1×1 so layout can still run in debug without inventing decorative shapes.
        let fallback = SKTexture()
        fallback.filteringMode = filtering
        return fallback
    }

    @MainActor
    static func sprite(named name: String, size: CGSize, filtering: SKTextureFilteringMode = .linear) -> SKSpriteNode? {
        guard let texture = texture(named: name, filtering: filtering) else { return nil }
        let node = SKSpriteNode(texture: texture, size: size)
        node.name = name
        return node
    }
}
