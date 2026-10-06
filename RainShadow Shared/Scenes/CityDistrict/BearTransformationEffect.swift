import AVFoundation
import SpriteKit

/// Authored 1.6-second transformation, sampled by the combat clock (including
/// audio pause). Coloured textures are baked once so every mote takes the native
/// compositor's direct sprite path, with no emitter warm-up or custom shader.
@MainActor
final class BearTransformationEffect: SKNode {
    static let duration = 1.6
    static let revealTime = 0.68
    static let impactTime = 1.02
    private(set) var elapsed: TimeInterval = 0
    private let reverting: Bool
    private let mist: [SKSpriteNode]
    private let sparks: [SKSpriteNode]
    private let dust: [SKSpriteNode]
    private let halo: SKSpriteNode
    private let flash: SKSpriteNode
    private let ripple: SKSpriteNode
    private var fragments: [(node: SKSpriteNode, origin: CGPoint)] = []
    private var sound: AVAudioPlayer?
    private var audioPaused = false
    var soundIsPlaying: Bool { sound?.isPlaying == true }

    init(reverting: Bool) {
        self.reverting = reverting
        mist = (0..<20).map { _ in SKSpriteNode(texture: Self.mistTexture) }
        sparks = (0..<28).map { _ in SKSpriteNode(texture: Self.sparkTexture) }
        dust = (0..<14).map { _ in SKSpriteNode(texture: Self.dustTexture) }
        halo = SKSpriteNode(texture: Self.haloTexture)
        flash = SKSpriteNode(texture: Self.flashTexture)
        ripple = SKSpriteNode(texture: Self.rippleTexture)
        super.init()
        name = "combat.bear.transformation"
        zPosition = 20000
        halo.size = CGSize(width: 135, height: 101.25)
        halo.blendMode = .add
        flash.size = CGSize(width: 100, height: 120)
        flash.position.y = 48
        flash.blendMode = .add
        ripple.size = CGSize(width: 110, height: 82.5)
        ripple.blendMode = .add
        addChild(halo)
        mist.forEach { $0.size = CGSize(width: 48, height: 52); addChild($0) }
        sparks.forEach { $0.size = CGSize(width: 4, height: 9); $0.blendMode = .add; addChild($0) }
        addChild(flash)
        addChild(ripple)
        dust.forEach { $0.size = CGSize(width: 27, height: 18); addChild($0) }
        sound = try? AVAudioPlayer(data: Self.soundData(reverting: reverting))
        sound?.volume = reverting ? 0.30 : 0.48
        sound?.prepareToPlay()
        sound?.play()
        advance(to: 0)
    }
    required init?(coder: NSCoder) { fatalError("Created programmatically") }

    /// Capture only visible body/equipment layers, never badges or shadows. The
    /// registered texture strips dissolve upward while the live actor fades;
    /// the approved source frames and their engine shaders remain untouched.
    func captureSilhouette(of actor: SKNode) {
        func visit(_ node: SKNode) {
            guard !node.isHidden, node.alpha > 0 else { return }
            if let layer = node as? IEAvatarNode, let texture = layer.texture {
                let slices = 8
                for i in 0..<slices {
                    let strip = SKSpriteNode(texture: SKTexture(rect: CGRect(x: 0, y: CGFloat(i) / CGFloat(slices),
                        width: 1, height: 1 / CGFloat(slices)), in: texture))
                    let bottom = CGPoint(x: -layer.anchorPoint.x * layer.size.width,
                        y: (CGFloat(i) / CGFloat(slices) - layer.anchorPoint.y) * layer.size.height)
                    let top = CGPoint(x: bottom.x + layer.size.width, y: bottom.y + layer.size.height / CGFloat(slices))
                    let a = convert(bottom, from: layer), b = convert(top, from: layer)
                    strip.size = CGSize(width: abs(b.x - a.x), height: abs(b.y - a.y))
                    strip.position = CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
                    strip.blendMode = .add
                    strip.alpha = 0
                    addChild(strip)
                    fragments.append((strip, strip.position))
                }
            }
            node.children.forEach(visit)
        }
        visit(actor)
    }

    func setPaused(_ paused: Bool) {
        guard paused != audioPaused else { return }
        audioPaused = paused
        if paused { sound?.pause() }
        else if elapsed < Self.duration { sound?.play() }
    }

    func stop() { sound?.stop(); removeFromParent() }

    var cameraOffset: CGPoint {
        #if os(macOS)
        if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion { return .zero }
        #else
        if UIAccessibility.isReduceMotionEnabled { return .zero }
        #endif
        guard !reverting else { return .zero }
        let t = elapsed - Self.impactTime
        guard t >= 0, t < 0.24 else { return .zero }
        let strength = 1.8 * pow(1 - t / 0.24, 2)
        return CGPoint(x: sin(t * 95) * strength, y: cos(t * 73) * strength * 0.6)
    }

    func advance(to time: TimeInterval) {
        elapsed = min(Self.duration, max(0, time))
        // Slow rendering may cap the combat delta. Keep the cue on that clock.
        if let sound, abs(sound.currentTime - elapsed) > 0.10, elapsed < Self.duration {
            sound.currentTime = elapsed
            if !audioPaused && !sound.isPlaying { sound.play() }
        }
        let t = elapsed
        let gather = Self.ramp(t, 0, Self.revealTime)
        let clear = 1 - Self.ramp(t, 0.74, 1.12)
        let bloom = Self.ramp(t, 0.34, 0.64) * (1 - Self.ramp(t, 0.72, 0.96))
        halo.alpha = (0.18 * sin(min(1, t / Self.duration) * .pi) + bloom * 0.4) * (reverting ? 0.6 : 1)
        halo.setScale(1 - gather * 0.3)
        flash.alpha = bloom * (reverting ? 0.65 : 0.95)
        flash.setScale(0.5 + bloom * 0.55)
        for (i, node) in mist.enumerated() {
            let seed = Double(i) * 2.3999632297
            let angle = seed + t * (reverting ? -3.8 : 4.8)
            let radius = 39 * (1 - gather * 0.6) + Self.ramp(t, 0.76, 1.5) * 42
            node.position = CGPoint(x: cos(angle) * radius, y: 14 + Double(i % 5) * 15 + sin(angle) * 12)
            node.alpha = Self.ramp(t, 0.05 + Double(i % 3) * 0.04, 0.5) * clear * 0.45
            node.setScale(0.5 + gather * 0.7 + Self.ramp(t, 0.8, 1.5) * 0.5)
        }
        for (i, node) in sparks.enumerated() {
            let seed = Double(i) * 2.3999632297
            let phase = (t * 0.85 + Double(i) / 28).truncatingRemainder(dividingBy: 1)
            let angle = seed + t * (reverting ? -7 : 7)
            let radius = 52 * (1 - gather * 0.68) + Self.ramp(t, 0.72, 1.4) * 70
            node.position = CGPoint(x: cos(angle) * radius, y: phase * 95 + sin(angle) * radius * 0.32)
            node.alpha = sin(phase * .pi) * Self.ramp(t, 0, 0.18) * (1 - Self.ramp(t, 1.1, 1.6))
            node.yScale = 0.7 + gather * 0.65
        }
        for (i, part) in fragments.enumerated() {
            let amount = Self.ramp(t, 0.28, Self.revealTime)
            part.node.position = CGPoint(x: part.origin.x + sin(Double(i) * 2.4) * amount * 13,
                y: part.origin.y + amount * (12 + Double(i % 8) * 3))
            part.node.alpha = sin(amount * .pi) * 0.5
        }
        let impact = Self.ramp(t, Self.impactTime, Self.duration)
        ripple.alpha = t >= Self.impactTime ? pow(1 - impact, 2) * (reverting ? 0.22 : 0.6) : 0
        ripple.setScale(0.55 + impact * 1.65)
        for (i, node) in dust.enumerated() {
            let angle = Double(i) * 2.3999632297
            let radius = 24 + impact * 66
            node.position = CGPoint(x: cos(angle) * radius, y: sin(angle) * radius * 0.75 + sin(impact * .pi) * 9)
            node.alpha = t >= Self.impactTime ? sin(pow(impact, 0.45) * .pi) * (reverting ? 0.18 : 0.5) : 0
            node.setScale(0.5 + impact)
        }
    }

    static func ramp(_ t: Double, _ start: Double, _ end: Double) -> Double {
        let x = min(1, max(0, (t - start) / (end - start)))
        return x * x * (3 - 2 * x)
    }

    private static func texture(_ color: (Double, Double, Double), ring: Bool = false, cloud: Bool = false) -> SKTexture {
        let n = 64
        var bytes = [UInt8](repeating: 0, count: n * n * 4)
        for y in 0..<n { for x in 0..<n {
            let dx = (Double(x) + 0.5 - 32) / 32, dy = (Double(y) + 0.5 - 32) / 32
            let r = hypot(dx, dy)
            let edge = max(0, 1 - r)
            var a = ring ? max(0, 1 - abs(r - 0.82) / 0.08) * 0.7 : edge * edge
            if cloud { a *= 0.65 + 0.35 * sin(dx * 11 + sin(dy * 9)) * sin(dy * 12 - dx * 4) }
            let index = (y * n + x) * 4
            bytes[index] = UInt8(255 * color.0 * a)
            bytes[index + 1] = UInt8(255 * color.1 * a)
            bytes[index + 2] = UInt8(255 * color.2 * a)
            bytes[index + 3] = UInt8(255 * a)
        }}
        let provider = CGDataProvider(data: Data(bytes) as CFData)!
        let image = CGImage(width: n, height: n, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: n * 4,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent)!
        return SKTexture(cgImage: image)
    }
    private static let mistTexture = texture((0.32, 0.47, 0.34), cloud: true)
    private static let sparkTexture = texture((0.91, 0.91, 0.55))
    private static let dustTexture = texture((0.48, 0.42, 0.29), cloud: true)
    private static let haloTexture = texture((0.34, 0.63, 0.34))
    private static let flashTexture = texture((0.88, 1, 0.67))
    private static let rippleTexture = texture((0.70, 0.83, 0.44), ring: true)

    /// Original synthesized breath, low impact and creature-like rumble. No
    /// borrowed game audio. One player owns the complete cue so pause resumes
    /// exactly where it stopped rather than retriggering the landing.
    private static func soundData(reverting: Bool) -> Data {
        let rate = 44100, count = Int(duration * 44100)
        var pcm = Data(capacity: count * 2)
        var seed: UInt32 = 7319
        var low = 0.0, phase = 0.0
        for i in 0..<count {
            let t = Double(i) / Double(rate)
            seed = 1664525 &* seed &+ 1013904223
            let noise = Double(seed) / Double(UInt32.max) * 2 - 1
            low += (noise - low) * 0.065
            let gather = ramp(t, 0, 0.3) * (1 - ramp(t, 0.60, 0.85))
            let impact = max(0, t - impactTime)
            let tail = t >= impactTime ? exp(-impact * 7) * ramp(t, impactTime, impactTime + 0.015) : 0
            phase += 2 * .pi * (57 + 25 * exp(-impact * 8)) / Double(rate)
            let rumble = (sin(phase) + 0.35 * sin(phase * 1.98) + 0.18 * sin(phase * 3.02)) * (0.7 + 0.3 * sin(t * 51))
            let cue = low * gather * 0.8 + tail * (low * 0.7 + rumble * (reverting ? 0.08 : 0.35))
            var sample = Int16(max(-1, min(1, cue)) * 28000).littleEndian
            withUnsafeBytes(of: &sample) { pcm.append(contentsOf: $0) }
        }
        var wav = Data()
        func ascii(_ s: String) { wav.append(contentsOf: s.utf8) }
        func u32(_ v: UInt32) { var n = v.littleEndian; withUnsafeBytes(of: &n) { wav.append(contentsOf: $0) } }
        func u16(_ v: UInt16) { var n = v.littleEndian; withUnsafeBytes(of: &n) { wav.append(contentsOf: $0) } }
        ascii("RIFF"); u32(UInt32(36 + pcm.count)); ascii("WAVEfmt "); u32(16)
        u16(1); u16(1); u32(UInt32(rate)); u32(UInt32(rate * 2)); u16(2); u16(16)
        ascii("data"); u32(UInt32(pcm.count)); wav.append(pcm)
        return wav
    }
}
