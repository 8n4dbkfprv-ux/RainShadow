import SpriteKit

/// A bounded, deterministic particle burst. Sprite particles use the existing
/// native compositor directly, so no weather-emitter warm-up consumes the burst.
/// The combat director advances its clock; pause freezes every particle.
@MainActor
final class BearTransformationEffect: SKNode {
    private let particles: [SKSpriteNode]
    private let ring = SKShapeNode(ellipseOf: CGSize(width: 90, height: 67.5))
    private let reverting: Bool

    init(reverting: Bool) {
        self.reverting = reverting
        particles = (0..<40).map { i in
            let particle = SKSpriteNode(texture: Self.softDisc)
            particle.size = CGSize(width: i < 12 ? 48 : 7, height: i < 12 ? 42 : 7)
            particle.color = i < 12 ? SKColor(red: 0.28, green: 0.40, blue: 0.34, alpha: 1)
                : SKColor(red: 0.82, green: 0.95, blue: 0.62, alpha: 1)
            particle.colorBlendFactor = 1
            particle.blendMode = i < 12 ? .alpha : .add
            return particle
        }
        super.init()
        name = "combat.bear.transformation"
        zPosition = 20000
        ring.strokeColor = SKColor(red: 0.64, green: 0.82, blue: 0.52, alpha: 1)
        ring.lineWidth = 2
        addChild(ring)
        particles.forEach(addChild)
        advance(to: 0)
    }
    required init?(coder: NSCoder) { fatalError("Created programmatically") }

    func advance(to elapsed: TimeInterval) {
        let t = min(1, max(0, elapsed / 1.2))
        let envelope = sin(t * .pi)
        ring.alpha = envelope * 0.8
        ring.setScale(0.65 + t * 0.8)
        for (i, particle) in particles.enumerated() {
            let seed = Double(i) * 2.399963229728653
            let swirl = seed + t * (reverting ? -5 : 5)
            let radius = (i < 12 ? 26.0 : 43.0) * (0.3 + abs(t - 0.5) * 1.4)
            particle.position = CGPoint(x: cos(swirl) * radius,
                y: 18 + Double(i % 7) * 7 + t * 25 + sin(swirl) * radius * 0.4)
            particle.alpha = envelope * (i < 12 ? 0.8 : 1)
            particle.setScale(i < 12 ? 0.65 + envelope * 0.7 : 0.5 + envelope)
        }
    }

    private static let softDisc: SKTexture = {
        let space = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(data: nil, width: 32, height: 32, bitsPerComponent: 8,
            bytesPerRow: 128, space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        let gradient = CGGradient(colorsSpace: space,
            colors: [CGColor(gray: 1, alpha: 1), CGColor(gray: 1, alpha: 0)] as CFArray,
            locations: [0, 1])!
        context.drawRadialGradient(gradient, startCenter: CGPoint(x: 16, y: 16), startRadius: 0,
            endCenter: CGPoint(x: 16, y: 16), endRadius: 16, options: [])
        return SKTexture(cgImage: context.makeImage()!)
    }()
}
