import SpriteKit

/// A short, tapered sweep of the authored blade. Cached textures retain normal
/// actor depth, lighting and wall stencils through an independent avatar layer.
@MainActor
final class MeleeSwingTrail {
    let sprite = IEAvatarNode(frame: nil)
    private static var textures: [Int: SKTexture] = [:]
    private static let side: CGFloat = 175.78125
    private static let anchor = CGPoint(x: 0.5, y: 0.375)

    init() { sprite.name = "combat.melee.swing"; sprite.isHidden = true }

    func sample(elapsed: TimeInterval, facing: ActorFacing, maneuver: CombatManeuver? = nil) {
        let phase = Int(elapsed * WeaponTechniqueMotion.meleeFPS(maneuver))
        let end = WeaponTechniqueMotion.trailEnd(maneuver) / WeaponTechniqueMotion.meleeFPS(maneuver)
        guard phase > Int(WeaponTechniqueMotion.trailStart(maneuver)), elapsed < end + SwordSwingPath.fadeDuration else {
            sprite.isHidden = true; return
        }
        let head = min(Int(WeaponTechniqueMotion.trailEnd(maneuver)), phase)
        let variant = maneuver == .tripAttack ? 3 : maneuver == .powerStrike ? 1 : maneuver == .feintingCut ? 2 : 0
        let key = variant * 256 + facing.rawValue * 16 + head
        let texture: SKTexture
        if let cached = Self.textures[key] { texture = cached }
        else {
            texture = Self.draw(phase: head, facing: facing, maneuver: maneuver)
            Self.textures[key] = texture
        }
        sprite.apply(.compatibility(texture: texture,
            displaySize: CGSize(width: Self.side, height: Self.side), anchorPoint: Self.anchor))
        sprite.alpha = CGFloat(1 - max(0, elapsed - end) / SwordSwingPath.fadeDuration)
    }

    private static func draw(phase: Int, facing: ActorFacing, maneuver: CombatManeuver?) -> SKTexture {
        let resolution = 512
        let context = CGContext(data: nil, width: resolution, height: resolution, bitsPerComponent: 8,
            bytesPerRow: resolution * 4, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.scaleBy(x: CGFloat(resolution) / side, y: CGFloat(resolution) / side)
        context.translateBy(x: side * anchor.x, y: side * anchor.y)
        let start = max(WeaponTechniqueMotion.trailStart(maneuver), Double(phase) - SwordSwingPath.history)
        func blade(_ fraction: Double, _ width: Double) -> CGPoint {
            let pose = SwordSwingPath.blade(phase: start + (Double(phase) - start) * fraction, facing: facing, maneuver: maneuver)
            // The old end narrows to a point; most light stays near the blade tip.
            let along = 1 - (0.78 * sqrt(fraction)) * (1 - width)
            return CGPoint(x: pose.base.x + (pose.tip.x - pose.base.x) * along,
                           y: pose.base.y + (pose.tip.y - pose.base.y) * along)
        }
        let segments = 36, bands = 8
        for segment in 0..<segments {
            let a = Double(segment) / Double(segments), b = Double(segment + 1) / Double(segments)
            for band in 0..<bands {
                let inner = Double(band) / Double(bands), outer = Double(band + 1) / Double(bands)
                let path = CGMutablePath()
                path.move(to: blade(a, inner)); path.addLine(to: blade(b, inner))
                path.addLine(to: blade(b, outer)); path.addLine(to: blade(a, outer)); path.closeSubpath()
                context.addPath(path)
                context.setFillColor(CGColor(red: 0.77, green: 0.90, blue: 1,
                    alpha: 0.52 * pow(b, 1.4) * (0.15 + 0.85 * outer)))
                context.fillPath()
            }
            context.move(to: blade(a, 1)); context.addLine(to: blade(b, 1))
            context.setLineWidth(0.85)
            context.setStrokeColor(CGColor(red: 0.94, green: 0.98, blue: 1, alpha: 0.7 * b))
            context.strokePath()
        }
        let texture = SKTexture(cgImage: context.makeImage()!)
        texture.filteringMode = .linear
        return texture
    }
}
