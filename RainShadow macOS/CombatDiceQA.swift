#if DEBUG
import AppKit
import SpriteKit
import simd

@MainActor enum CombatDiceQA {
    static func run(in view: SKView, output: URL) async {
        var checks: [String] = []
        func check(_ value: Bool, _ text: String) throws {
            guard value else { throw TacticalCombatQA.Failure(message: text) }; checks.append(text)
        }
        do {
            try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
            let scene = SKScene(size: CGSize(width: 1000, height: 600))
            scene.anchorPoint = CGPoint(x: 0.5, y: 0.5); scene.backgroundColor = SKColor(red: 0.035, green: 0.055, blue: 0.05, alpha: 1)
            view.presentScene(scene)
            let tray = CombatDicePresentation(); tray.position.y = -140; tray.muted = true; scene.addChild(tray); scene.addChild(tray.worldNode)
            let title = SKLabelNode(fontNamed: "AmericanTypewriter"); title.text = "HARBORPOINT  /  AREA DICE"; title.position.y = 235; title.fontSize = 22; scene.addChild(title)
            func capture(_ name: String) async throws {
                try await Task.sleep(for: .milliseconds(100))
                guard let image = view.texture(from: scene)?.cgImage(), let data = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else { throw TacticalCombatQA.Failure(message: "Dice render capture") }
                try data.write(to: output.appendingPathComponent(name + ".png"))
            }
            for sides in [3,4,6,20] {
                let mesh = CombatDicePresentation.meshes[String(sides)]!
                try check(mesh.body.uvs?.count == mesh.body.positions.count, "Blender d\(sides) has complete resin texture coordinates")
                try check(Set(mesh.faces.map(\.value)) == Set(1...sides), "Blender d\(sides) contains every result face")
                for face in mesh.faces {
                    let orientation = simd_quatf(from: simd_normalize(face.axis), to: SIMD3<Float>(0,1,0))
                    let upper = TabletopDiceMotion.upperFace(normals: mesh.faces.map(\.axis), orientation: orientation)
                    try check(upper.map { mesh.faces[$0].value } == face.value, "Blender d\(sides) reads face \(face.value) correctly")
                }
            }
            let sample = CombatDiceRoll(kind: .attack, dice: [.init(sides: 20, value: 20), .init(sides: 6, value: 6)], caption: "Voss · d20: 20 + 5 · Critical · d6: 6 + 1 = 7 damage")
            for (name, paint) in [("amber", CombatDicePresentation.Paint.amber), ("green", .green), ("oxblood", .oxblood)] {
                tray.present([sample], speaker: "Voss", paint: paint)
                for _ in 0..<108 { tray.advance(delta: 1.0 / 60, paused: false) }
                try check(tray.pieces.allSatisfy { $0.motion.finished }, "\(name) dice physically settle")
                try await capture("dice-\(name)")
                let positions = tray.pieces.map { $0.motion.position }
                tray.advance(delta: 0.3, paused: true)
                try check(positions == tray.pieces.map { $0.motion.position }, "Pause freezes \(name) dice")
                tray.skip(); try check(!tray.isRolling, "Skip releases \(name) presentation")
            }
            tray.playbackSpeed = .skip; tray.present([sample], speaker: "Voss", paint: .amber)
            try check(!tray.isRolling, "Skip preference never starts a throw")
            tray.playbackSpeed = .fast; tray.present([sample], speaker: "Voss", paint: .amber)
            for _ in 0..<60 { tray.advance(delta: 1.0 / 60, paused: false) }
            try check(!tray.isRolling && tray.completedFaces == [20,6], "Fast mode reads the identical faces and completes sooner")
            tray.playbackSpeed = .normal
            tray.present([.init(kind: .minor, dice: sample.dice, caption: "Silent")], speaker: "Voss", paint: .amber)
            try check(!tray.isRolling, "Minor checks have no visible throw")
            for width: CGFloat in [320, 640] {
                tray.layout(width: width); tray.present([sample], speaker: "Voss", paint: .amber)
                for _ in 0..<108 { tray.advance(delta: 1.0 / 60, paused: false) }
                try await capture("dice-width-\(Int(width))"); tray.stop()
                tray.recentLog = (1...30).map { "Roll · Voss attack \($0): d20 14 + 5 vs 12 · Hit; damage d6 5 + 1 = 6 applied" }
                tray.pointer(at: CGPoint(x: width / 3, y: 0))
                try check(tray.logOpen, "Roll log opens at width \(Int(width))")
                try await capture("log-width-\(Int(width))")
                tray.pointer(at: CGPoint(x: -70, y: 130))
                try await capture("log-older-\(Int(width))"); tray.stop()
            }
            let miniature = try CharacterAppearanceNode(definition: .voss); miniature.position = CGPoint(x: 0, y: 20); miniature.setScale(2); scene.addChild(miniature)
            for (name, action) in [("strike", CharacterVisualAction.attack), ("shove", .shove), ("hit", .hit), ("downed", .die)] {
                try miniature.present(action: action, facing: .southEast, phase: 9)
                miniature.updateMiniatureMotion(at: 1, paused: false)
                try check(miniature.currentPhase == 0, "\(name) keeps the sculpt rigid")
                try await capture("miniature-\(name)")
            }
            try JSONSerialization.data(withJSONObject: ["passed": true, "checks": checks], options: [.prettyPrinted, .sortedKeys]).write(to: output.appendingPathComponent("visual-report.json"))
            tray.stop(); tray.worldNode.removeFromParent(); tray.removeFromParent()
            if ProcessInfo.processInfo.environment["RAINSHADOW_QA_DICE_VISUAL_ONLY"] == "1" { NSApp.terminate(nil); return }
            setenv("RAINSHADOW_QA_DICE_INTEGRATION", "1", 1)
            await TacticalCombatQA.run(in: view, output: output)
        } catch {
            try? JSONSerialization.data(withJSONObject: ["passed": false, "checks": checks, "error": String(describing: error)], options: [.prettyPrinted]).write(to: output.appendingPathComponent("visual-report.json"))
            NSApp.terminate(nil)
        }
    }
}
#endif
