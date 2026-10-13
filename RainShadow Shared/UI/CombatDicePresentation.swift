import SpriteKit
import SceneKit
import AVFoundation
import simd
import ImageIO
import Metal

/// Blender-authored meshes; local rendering and physics have no access to rules.
@MainActor
final class CombatDicePresentation: SKNode {
    struct Part: Decodable {
        let positions: [[Float]]
        let normals: [[Float]]
        let uvs: [[Float]]?
        func geometry() -> SCNGeometry {
            let vertices = positions.map { SCNVector3($0[0], $0[2], -$0[1]) }
            let ns = normals.map { SCNVector3($0[0], $0[2], -$0[1]) }
            var sources: [SCNGeometrySource] = [.init(vertices: vertices), .init(normals: ns)]
            if let uvs {
                precondition(uvs.count == positions.count, "Dice UVs must match the exported triangles")
                sources.append(.init(textureCoordinates: uvs.map { CGPoint(x: CGFloat($0[0]), y: CGFloat($0[1])) }))
            }
            return SCNGeometry(sources: sources,
                elements: [.init(indices: Array(Int32(0)..<Int32(vertices.count)), primitiveType: .triangles)])
        }
    }
    struct Face: Decodable {
        let value: Int
        let normal: [Float]
        let center: [Float]
        let up: [Float]
        var heading: SIMD3<Float> { SIMD3(up[0], up[2], -up[1]) }
        var axis: SIMD3<Float> { SIMD3(normal[0], normal[2], -normal[1]) }
    }
    struct Mesh: Decodable {
        let faces: [Face]
        let body: Part
        let numerals: [Part]
    }
    enum Paint { case amber, green, oxblood }
    struct Piece {
        let die: CombatDie
        let mesh: Mesh
        let node: SCNNode
        var motion: TabletopDiceMotion
    }
    static let resourceRoot = Bundle.main.resourceURL!.appendingPathComponent("Tabletop/Dice")
    private static let resinAlbedo: CGImage = {
        let url = resourceRoot.appendingPathComponent("resin-marble-v1.png")
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            preconditionFailure("Missing generated resin texture")
        }
        return image
    }()
    static let meshes: [String: Mesh] = {
        do { return try JSONDecoder().decode([String: Mesh].self, from: Data(contentsOf: resourceRoot.appendingPathComponent("meshes.json"))) }
        catch { assertionFailure("Missing Blender dice: \(error)"); return [:] }
    }()
    static func tokenTexture() -> SKTexture? { brassToken }
    private static let brassToken: SKTexture? = {
        guard let source = CGImageSourceCreateWithURL(resourceRoot.appendingPathComponent("table-props.png") as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return nil }
        let rect = CGRect(x: 576, y: 590, width: 384, height: 384)
        guard let crop = image.cropping(to: rect) else { return nil }
        var imported = crop
        if let context = CGContext(data: nil, width: 384, height: 384, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) {
            context.addEllipse(in: CGRect(x: 6, y: 6, width: 372, height: 372))
            context.addEllipse(in: CGRect(x: 57, y: 57, width: 270, height: 270))
            context.clip(using: .evenOdd); context.draw(crop, in: CGRect(x: 0, y: 0, width: 384, height: 384))
            imported = context.makeImage() ?? crop
        }
        let texture = SKTexture(cgImage: imported); texture.filteringMode = .linear
        return texture
    }()

    /// Attached to the area, independently of the HUD controls.
    let worldNode = SKNode()
    // October 12 reference: a d20 spans roughly 85% of a human base.
    static let areaScale: CGFloat = 2.5
    private let shadows = SKNode()
    private var renderPending = false
    private var renderElapsed = 0.0
    // Render offscreen: SK3DNode leaks a flipped projection into subsequent
    // SpriteKit labels on the current macOS renderer. A texture isolates it.
    private let renderer = SCNRenderer(device: MTLCreateSystemDefaultDevice(), options: nil)
    private let diceImage = SKSpriteNode()
    private let viewportSize = CGSize(width: 864, height: 504)
    private let world = SCNScene()
    private let diceRoot = SCNNode()
    private let caption = SKLabelNode(fontNamed: "AmericanTypewriter")
    private let speedLabel = SKLabelNode(fontNamed: "AmericanTypewriter")
    private let soundLabel = SKLabelNode(fontNamed: "AmericanTypewriter")
    private let skipLabel = SKLabelNode(fontNamed: "AmericanTypewriter")
    private let logLabel = SKLabelNode(fontNamed: "AmericanTypewriter")
    private let logPaper = SKSpriteNode(texture: UIPaintedChrome.parchmentSurface())
    private let logText = SKLabelNode(fontNamed: "AmericanTypewriter")
    private let logFooter = SKLabelNode(fontNamed: "AmericanTypewriter")
    private var queue: [CombatDiceRoll] = []
    private var current: CombatDiceRoll?
    private(set) var pieces: [Piece] = []
    private var readTime = 0.0
    private var paint: Paint = .amber
    private var speaker = ""
    private var width: CGFloat = 640
    private var reducedMotion: Bool {
        #if os(macOS)
        NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        #else
        UIAccessibility.isReduceMotionEnabled
        #endif
    }
    private let sound = DiceContactAudio()
    private let lamp = SCNNode()
    var playbackSpeed: CombatDiceSpeed = .normal { didSet { refreshControls(); if playbackSpeed == .skip { skip() } } }
    var muted = false { didSet { if muted { sound.stop() }; refreshControls() } }
    var onPreferencesChanged: (() -> Void)?
    private(set) var isRolling = false
    private(set) var completedFaces: [Int] = []
    var logOpen: Bool { !logPaper.isHidden }
    private var logPage = 0
    private var logEntriesPerPage: Int { width < 480 ? 3 : 5 }
    var recentLog: [String] = [] { didSet { refreshLog() } }
    private func refreshLog() {
        let count = logEntriesPerPage
        let pages = max(1, (recentLog.count + count - 1) / count)
        logPage = min(logPage, pages - 1)
        let end = max(0, recentLog.count - logPage * count)
        logText.text = "ROLL LOG · \(logPage + 1)/\(pages)\n\n" + recentLog[max(0, end - count)..<end].joined(separator: "\n")
    }

    override init() {
        super.init()
        name = "combat.dice"; zPosition = 25
        worldNode.name = "combat.dice.world"
        worldNode.setScale(Self.areaScale)
        worldNode.addChild(shadows)
        world.background.contents = SKColor.clear
        world.rootNode.addChildNode(diceRoot)
        let camera = SCNNode(); camera.camera = SCNCamera(); camera.camera!.usesOrthographicProjection = true
        camera.camera!.orthographicScale = 7
        // Match the existing 0.75 ground projection without changing the area camera.
        camera.position = SCNVector3(0, 17, 13.22876)
        camera.look(at: SCNVector3(0, 2, 0)); world.rootNode.addChildNode(camera)
        lamp.light = SCNLight(); lamp.light!.type = .omni
        lamp.light!.intensity = 700; lamp.position = SCNVector3(-3, 8, 6); world.rootNode.addChildNode(lamp)
        let fill = SCNNode(); fill.light = SCNLight(); fill.light!.type = .ambient; fill.light!.intensity = 350
        world.rootNode.addChildNode(fill)
        renderer.scene = world; renderer.pointOfView = camera; renderer.isPlaying = false
        diceImage.size = CGSize(width: 288, height: 168)
        diceImage.position.y = 15.8745; diceImage.zPosition = 1; worldNode.addChild(diceImage)
        for label in [caption, speedLabel, soundLabel, skipLabel, logLabel] {
            label.fontSize = 12; label.fontColor = SKColor(red: 0.90, green: 0.86, blue: 0.77, alpha: 1)
            label.verticalAlignmentMode = .center; addChild(label)
        }
        caption.position.y = 76; caption.numberOfLines = 2
        skipLabel.text = "Skip throw"; skipLabel.position.y = 34
        speedLabel.position.y = 0; soundLabel.position.y = 0; logLabel.position.y = 0
        logLabel.text = "Roll log"
        logPaper.position.y = 225; logPaper.zPosition = 3; logPaper.isHidden = true; addChild(logPaper)
        logText.fontSize = 12; logText.fontColor = UITheme.Color.ink; logText.numberOfLines = 0
        logText.verticalAlignmentMode = .center; logText.position.y = 15; logPaper.addChild(logText)
        logFooter.text = "‹ Older                 Newer ›"; logFooter.fontSize = 12
        logFooter.fontColor = UITheme.Color.ink; logFooter.verticalAlignmentMode = .center
        logFooter.position.y = -98; logPaper.addChild(logFooter)
        layout(width: 640); refreshControls(); showThrow(false)
    }
    required init?(coder: NSCoder) { fatalError("Created in code") }

    func layout(width: CGFloat) {
        self.width = min(720, max(240, width))
        caption.preferredMaxLayoutWidth = self.width - 40
        speedLabel.position.x = -self.width / 3; soundLabel.position.x = 0; logLabel.position.x = self.width / 3
        logPaper.size = CGSize(width: self.width, height: 240)
        logText.preferredMaxLayoutWidth = self.width - 48
        refreshLog()
    }
    private func refreshControls() {
        speedLabel.text = "Dice: \(playbackSpeed.title)"
        soundLabel.text = muted ? "Dice sound: Off" : "Dice sound: On"
    }
    private func showThrow(_ visible: Bool) {
        worldNode.isHidden = !visible; caption.isHidden = !visible; skipLabel.isHidden = !visible
    }
    func present(_ rolls: [CombatDiceRoll], speaker: String, paint: Paint) {
        guard playbackSpeed != .skip else { return }
        self.paint = paint; self.speaker = speaker
        queue = rolls.filter(\.shouldPresent).flatMap { roll in
            stride(from: 0, to: roll.dice.count, by: 5).map { start in
                CombatDiceRoll(kind: roll.kind, dice: Array(roll.dice[start..<min(start + 5, roll.dice.count)]), caption: roll.caption, critical: roll.critical)
            }
        }
        completedFaces = []; nextRoll()
    }
    private func nextRoll() {
        lamp.light?.intensity = 700
        shadows.removeAllChildren()
        pieces.removeAll(); diceRoot.childNodes.forEach { $0.removeFromParentNode() }; readTime = 0
        guard !queue.isEmpty else { current = nil; isRolling = false; showThrow(false); sound.stop(); return }
        current = queue.removeFirst(); isRolling = true; showThrow(true)
        caption.text = "\(speaker) · \(current!.kind == .attack ? "Attack" : current!.kind == .damage ? "Damage" : "Story roll")"
        for (index, die) in current!.dice.enumerated() {
            guard let mesh = Self.meshes[String(die.sides)], let face = mesh.faces.first(where: { $0.value == die.value }) else { continue }
            let node = SCNNode(geometry: mesh.body.geometry())
            let resin = SCNMaterial(); resin.lightingModel = .blinn; resin.shininess = 0.65; resin.specular.contents = SKColor(white: 0.4, alpha: 1)
            resin.diffuse.contents = Self.resinAlbedo
            resin.diffuse.wrapS = .repeat; resin.diffuse.wrapT = .repeat
            resin.diffuse.minificationFilter = .linear; resin.diffuse.magnificationFilter = .linear; resin.diffuse.mipFilter = .linear
            // Compensate for the pearl map's average brightness while retaining
            // the existing three pigments. Numerals use their own untextured ink.
            switch paint {
            case .amber: resin.multiply.contents = SKColor(red: 0.66, green: 0.34, blue: 0.094, alpha: 1)
            case .green: resin.multiply.contents = SKColor(red: 0.075, green: 0.315, blue: 0.20, alpha: 1)
            case .oxblood: resin.multiply.contents = SKColor(red: 0.59, green: 0.10, blue: 0.107, alpha: 1)
            }
            node.geometry!.materials = [resin]
            let ink = SCNMaterial(); ink.lightingModel = .constant
            // Light ivory stays readable on every resin colour, including oxblood.
            ink.diffuse.contents = SKColor(red: 0.96, green: 0.9, blue: 0.74, alpha: 1)
            for part in mesh.numerals { let number = SCNNode(geometry: part.geometry()); number.geometry!.materials = [ink]; node.addChildNode(number) }
            let orientation = TabletopDiceMotion.readableOrientation(normal: face.axis, up: face.heading)
            let height = -(mesh.body.positions.map { orientation.act(SIMD3($0[0], $0[2], -$0[1])).y }.min() ?? -1)
            var motion = TabletopDiceMotion(faceNormal: face.axis, faceUp: face.heading, restingHeight: height, index: index, count: current!.dice.count, collisionVertices: Array(Set(mesh.body.positions.map { SIMD3<Float>($0[0], $0[2], -$0[1]) })))
            if reducedMotion { motion.settle() }
            node.simdPosition = motion.position; node.simdOrientation = motion.orientation; diceRoot.addChildNode(node)
            pieces.append(Piece(die: die, mesh: mesh, node: node, motion: motion))
            let shadow = SKShapeNode(ellipseOf: CGSize(width: 25, height: 18.75))
            shadow.fillColor = .black; shadow.strokeColor = .clear
            shadows.addChild(shadow)
        }
        layout(width: width); updateShadows(); requestRender()
    }
    private func updateShadows() {
        for (index, piece) in pieces.enumerated() {
            let p = piece.motion.position
            shadows.children[index].position = CGPoint(x: CGFloat(p.x) * 12, y: -CGFloat(p.z) * 9)
            shadows.children[index].alpha = CGFloat(max(0.12, 0.32 - p.y * 0.025))
        }
    }
    private func requestRender() {
        guard !renderPending else { return }; renderPending = true
        // A synchronous Metal snapshot inside SpriteKit.update can deadlock its
        // render queue. Defer until the frame callback has returned.
        Task { @MainActor [weak self] in
            guard let self else { return }; self.renderPending = false
            guard self.isRolling else { return }
            let rendered = self.renderer.snapshot(atTime: 0, with: self.viewportSize, antialiasingMode: .multisampling4X)
            self.diceImage.texture = SKTexture(image: rendered)
        }
    }
    func advance(delta: Double, paused: Bool) {
        if paused { sound.stop(); return }
        guard isRolling else { return }
        var contact = false
        for i in pieces.indices {
            let before = pieces[i].motion.contacts
            pieces[i].motion.advance(delta: delta * playbackSpeed.multiplier)
            if pieces[i].motion.contacts > before { contact = true }
            if pieces[i].motion.finished {
                let face = TabletopDiceMotion.upperFace(normals: pieces[i].mesh.faces.map(\.axis), orientation: pieces[i].motion.orientation)
                if face.map({ pieces[i].mesh.faces[$0].value }) != pieces[i].die.value { pieces[i].motion.retryCocked() }
            }
            pieces[i].node.simdPosition = pieces[i].motion.position
            pieces[i].node.simdOrientation = pieces[i].motion.orientation
        }
        if contact && !muted { sound.play() }
        updateShadows()
        renderElapsed += delta
        if renderElapsed >= 1.0 / 30 && (readTime == 0 || (current?.critical == true && !reducedMotion)) {
            renderElapsed = 0; requestRender()
        }
        if pieces.allSatisfy({ $0.motion.finished }) {
            caption.text = current?.caption
            if !reducedMotion && current?.critical == true {
                lamp.light?.intensity = 700 + 180 * exp(-readTime * 8)
            }
            readTime += delta * playbackSpeed.multiplier
            if readTime >= 1.1 {
                completedFaces += pieces.map(\.die.value)
                nextRoll()
            }
        }
    }
    func skip() { queue.removeAll(); current = nil; pieces.removeAll(); diceRoot.childNodes.forEach { $0.removeFromParentNode() }; isRolling = false; showThrow(false); sound.stop() }
    func stop() { skip(); logPaper.isHidden = true }
    @discardableResult func pointer(at point: CGPoint) -> Bool {
        if abs(point.y) <= 22 && abs(point.x) <= width / 2 {
            if point.x < -width / 6 { playbackSpeed = playbackSpeed.next; onPreferencesChanged?() }
            else if point.x < width / 6 { muted.toggle(); onPreferencesChanged?() }
            else { logPaper.isHidden.toggle() }
            return true
        }
        if logOpen && logPaper.frame.contains(point) {
            if point.y < logPaper.position.y - 70 {
                logPage = max(0, logPage + (point.x < 0 ? 1 : -1)); refreshLog()
            }
            return true
        }
        if isRolling && abs(point.x) <= width / 2 && (12...98).contains(point.y) {
            if abs(point.y - 34) <= 22 { skip() }
            return true
        }
        return false
    }
}

/// Short resin-on-board contact, synthesized once and pooled. Independent from
/// movement/voice volume and from the gameplay RNG. No sound for silent checks.
@MainActor private final class DiceContactAudio {
    private var players: [AVAudioPlayer] = []
    init() {
        let rate = 22050, count = 2646
        var pcm = Data(); var noise: UInt32 = 773
        for i in 0..<count {
            let t = Double(i) / Double(rate)
            noise = noise &* 1664525 &+ 1013904223
            let n = Double(noise & 65535) / 32768 - 1
            let sample = exp(-t * 52) * (0.3 * sin(2 * .pi * 540 * t) + 0.18 * sin(2 * .pi * 1290 * t) + 0.22 * n)
            var value = Int16(max(-1, min(1, sample)) * 20000).littleEndian
            withUnsafeBytes(of: &value) { pcm.append(contentsOf: $0) }
        }
        var wav = Data()
        func word<T: FixedWidthInteger>(_ value: T) { var le = value.littleEndian; withUnsafeBytes(of: &le) { wav.append(contentsOf: $0) } }
        wav.append(Data("RIFF".utf8)); word(UInt32(36 + pcm.count)); wav.append(Data("WAVEfmt ".utf8))
        word(UInt32(16)); word(UInt16(1)); word(UInt16(1)); word(UInt32(rate)); word(UInt32(rate * 2)); word(UInt16(2)); word(UInt16(16))
        wav.append(Data("data".utf8)); word(UInt32(pcm.count)); wav.append(pcm)
        for _ in 0..<3 { if let player = try? AVAudioPlayer(data: wav) { player.volume = 0.5; player.prepareToPlay(); players.append(player) } }
    }
    func play() { guard let player = players.first(where: { !$0.isPlaying }) ?? players.first else { return }; player.currentTime = 0; player.play() }
    func stop() { players.forEach { $0.stop() } }
}
