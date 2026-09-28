import SpriteKit

/// Shared UI artwork loader and resolution-independent folio chrome.
enum UIPaintedChrome {
    @MainActor
    static func texture(named name: String, filtering: SKTextureFilteringMode = .linear) -> SKTexture? {
        guard let texture = assetTexture(named: name) else {
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
        configure(node, for: name)
        return node
    }
}


extension UIPaintedChrome {
    @MainActor private static var folioTextures: [String: SKTexture] = [:]

    /// Only structural UI plates are replaced. Maps, portraits, items and the
    /// frame overlays with authored cutouts keep their original texture geometry.
    @MainActor
    static func assetTexture(named name: String) -> SKTexture? {
        if let folio = folioAssetName(for: name) {
            return GameArt.texture(named: folio)
        }
        let leather = name == "hud_right_rail_plate_v03"
            || name == "hud_loot_container_panel_v02"
        guard leather else { return GameArt.texture(named: name) }
        let plateName = name
        if let cached = folioTextures[plateName] { return cached }
        guard let original = GameArt.texture(named: plateName) else { return nil }
        let originalSize = original.size()
        let scale = min(1, 1960 / max(originalSize.width, originalSize.height))
        let width = max(16, Int(originalSize.width * scale))
        let height = max(16, Int(originalSize.height * scale))
        guard let context = CGContext(data: nil, width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return original }
        let bounds = CGRect(x: 0, y: 0, width: width, height: height)
        let colors = [CGColor(red: 0.24, green: 0.16, blue: 0.11, alpha: 1),
                      CGColor(red: 0.10, green: 0.065, blue: 0.045, alpha: 1)]
        if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                     colors: colors as CFArray, locations: [0, 1]) {
            context.drawLinearGradient(gradient, start: CGPoint(x: 0, y: height),
                end: CGPoint(x: width, y: 0), options: [])
        }
        // Deterministic, low-contrast leather grain; cached once per plate, never
        // regenerated during layout or interaction.
        var seed: UInt64 = 0xF0110
        for _ in 0..<(width * height / 85) {
            seed = seed &* 6364136223846793005 &+ 1
            let x = CGFloat((seed >> 24) % UInt64(width))
            seed = seed &* 6364136223846793005 &+ 1
            let y = CGFloat((seed >> 24) % UInt64(height))
            context.setStrokeColor(CGColor(red: 0.32, green: 0.20, blue: 0.09, alpha: 0.07))
            context.setLineWidth(0.5)
            context.move(to: CGPoint(x: x, y: y))
            context.addLine(to: CGPoint(x: x + 2 + CGFloat(seed % 5), y: y + 0.6))
            context.strokePath()
        }
        let edge = CGFloat(min(width, height))
        let inset = min(18, edge * 0.045)
        context.setStrokeColor(CGColor(red: 0.34, green: 0.22, blue: 0.10, alpha: 1))
        context.setLineWidth(max(2, inset / 3))
        context.stroke(bounds.insetBy(dx: 2, dy: 2))
        context.setStrokeColor(CGColor(red: 0.64, green: 0.46, blue: 0.23, alpha: 1))
        context.setLineWidth(1)
        context.stroke(bounds.insetBy(dx: inset, dy: inset))
        context.stroke(bounds.insetBy(dx: inset + 4, dy: inset + 4))
        // Engraved diamond corners evoke a book cover without intruding into text.
        let radius = min(8, inset * 0.65)
        for x in [inset + 2, CGFloat(width) - inset - 2] {
            for y in [inset + 2, CGFloat(height) - inset - 2] {
                context.setFillColor(CGColor(red: 0.48, green: 0.28, blue: 0.12, alpha: 1))
                context.move(to: CGPoint(x: x, y: y + radius))
                context.addLine(to: CGPoint(x: x + radius, y: y))
                context.addLine(to: CGPoint(x: x, y: y - radius))
                context.addLine(to: CGPoint(x: x - radius, y: y))
                context.closePath()
                context.fillPath()
            }
        }
        guard let image = context.makeImage() else { return original }
        let texture = SKTexture(cgImage: image)
        texture.filteringMode = .linear
        folioTextures[plateName] = texture
        return texture
    }
}


extension UIPaintedChrome {
    /// Parchment comes from the same Image Generator material family as the slots.
    /// The three main inventory cards deliberately share one painted master.
    private static func folioAssetName(for name: String) -> String? {
        if name.hasPrefix("inventory_outer_frame_") || name.hasPrefix("journal_casebook_plate_") {
            return "ui_folio_outer_fantasy_v01"
        }
        if name.hasPrefix("inventory_section_mid_") || name.hasPrefix("inventory_section_bag_") {
            return "ui_folio_strip_fantasy_v01"
        }
        if name.hasPrefix("inventory_section_") { return "ui_folio_card_fantasy_v01" }
        return nil
    }

    /// Nine-slicing preserves the painted corner fittings and border thickness.
    @MainActor
    static func configure(_ sprite: SKSpriteNode, for name: String) {
        switch folioAssetName(for: name) {
        case "ui_folio_outer_fantasy_v01":
            sprite.centerRect = CGRect(x: 0.08, y: 0.12, width: 0.84, height: 0.76)
        case "ui_folio_card_fantasy_v01":
            sprite.centerRect = CGRect(x: 0.10, y: 0.10, width: 0.80, height: 0.80)
        case "ui_folio_strip_fantasy_v01":
            sprite.centerRect = CGRect(x: 0.06, y: 0.24, width: 0.88, height: 0.52)
        default: break
        }
    }

    @MainActor
    static func parchmentSurface() -> SKTexture? {
        guard let paper = GameArt.texture(named: "ui_folio_card_fantasy_v01") else { return nil }
        // SKShapeNode.fillTexture does not honor a subtexture's UV rectangle.
        // Give it a physical crop so the card border cannot leak into dialogue.
        let image = paper.cgImage()
        let width = CGFloat(image.width)
        let height = CGFloat(image.height)
        guard let center = image.cropping(to: CGRect(x: width * 0.2, y: height * 0.2,
                                                     width: width * 0.6, height: height * 0.6)) else { return nil }
        return SKTexture(cgImage: center)
    }
}
