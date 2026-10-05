#if DEBUG
import AppKit
import SpriteKit

/// Production SpriteKit/native-renderer coverage, beyond SwiftPM's pure models.
/// RAINSHADOW_QA_APPEARANCE=<directory> runs without opening the player's save.
@MainActor enum CharacterAppearanceQA {
    struct Failure: Error { let message: String }

    static func run(in view: SKView, output: URL) {
        var checks: [String] = []
        func check(_ condition: Bool, _ message: String) throws {
            guard condition else { throw Failure(message: message) }
            checks.append(message)
        }
        func body(_ actor: CharacterAppearanceNode) throws -> IEAvatarNode {
            guard let body = actor.childNode(withName: "appearance.body") as? IEAvatarNode else {
                throw Failure(message: "Missing body")
            }
            return body
        }
        do {
            try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
            for original in [CharacterDefinition.voss, .lila] {
                let base = try IEAvatarFrameLibrary.shared(character: original.appearance.body.character)
                let named = try IEAvatarFrameLibrary.shared(appearance: original.appearance)
                try check(base === named, "\(original.id): named preset preserves the original library")
                var variant = original
                variant.appearance.palette = .guardUniform
                let changed = try IEAvatarFrameLibrary.shared(appearance: variant.appearance)
                let same = try IEAvatarFrameLibrary.shared(appearance: variant.appearance)
                try check(changed === same && changed !== base, "\(original.id): cache shares equal palettes and isolates different palettes")
                let frameName = try original.appearance.body.frameName(action: .idle, facing: .south, phase: 0)
                guard let old = base.frame(atlas: original.appearance.body.atlas, name: frameName),
                      let new = changed.frame(atlas: original.appearance.body.atlas, name: frameName),
                      let indexed = changed.sprite.frame(atlas: original.appearance.body.atlas, name: frameName) else {
                    throw Failure(message: "Missing palette comparison frame")
                }
                try check(old.native?.rgba != new.native?.rgba && old.texture !== new.texture,
                          "\(original.id): SpriteKit texture and native payload both change")
                try check(new.native?.rgba == Data(changed.sprite.rgba(for: indexed, colors: changed.colors)),
                          "\(original.id): native renderer receives the selected palette exactly")
                try check(old.displaySize == new.displaySize && old.anchorPoint == new.anchorPoint,
                          "\(original.id): recolouring retains crop and pivot")
            }

            let guardActor = try CharacterAppearanceNode(definition: .cityGuard)
            let secondGuard = try CharacterAppearanceNode(definition: .cityGuard)
            for facing in ActorFacing.allCases {
                for phase in 0..<10 {
                    try guardActor.present(action: .walk, facing: facing, phase: phase)
                    let body = try body(guardActor)
                    for item in CharacterEquipmentCode.allCases {
                        guard let layer = guardActor.childNode(withName: "appearance." + item.rawValue) as? IEAvatarNode else {
                            throw Failure(message: "Missing equipment")
                        }
                        guard layer.currentFrame?.id?.name == body.currentFrame?.id?.name,
                              layer.blitShader !== body.blitShader, layer.currentFrame?.native != nil else {
                            throw Failure(message: "Unsynchronized or shared equipment shader")
                        }
                    }
                }
            }
            try check(true, "All 160 walk poses synchronize all three equipment layers with independent shaders")
            let otherBody = try body(secondGuard)
            let firstBody = try body(guardActor)
            try check(firstBody.blitShader !== otherBody.blitShader, "Different actors own separate stencil/shading state")
            let previous = guardActor.definition
            var invalid = previous
            invalid.appearance.body = .humanFemale01
            do {
                try guardActor.apply(invalid)
                throw Failure(message: "Accepted Voss armor on Lila")
            } catch is CharacterAppearanceError { }
            try check(guardActor.definition == previous, "Failed equipment changes leave the displayed actor intact")
            var helmetOnly = previous
            helmetOnly.appearance.equipment.removeAll { $0.item == .splintMail }
            try guardActor.apply(helmetOnly)
            for facing in ActorFacing.allCases {
                for phase in 0..<10 {
                    try guardActor.present(action: .walk, facing: facing, phase: phase)
                    let frame = try body(guardActor).currentFrame?.id?.name
                    let helmet = guardActor.childNode(withName: "appearance.iron-helmet") as? IEAvatarNode
                    try check(helmet?.currentFrame?.id?.name == frame.map { "unarmored_" + $0 },
                              "Standalone NPC helmet follows \(facing.rawValue)/\(phase)")
                }
            }
            try guardActor.apply(previous)
            var recoloredEquipment = previous
            recoloredEquipment.appearance.equipment[0].colors = .init(metal: 1)
            let helmetName = "appearance.iron-helmet"
            let oldHelmet = (guardActor.childNode(withName: helmetName) as? IEAvatarNode)?.currentFrame?.native?.rgba
            try guardActor.apply(recoloredEquipment)
            let newHelmet = (guardActor.childNode(withName: helmetName) as? IEAvatarNode)?.currentFrame?.native?.rgba
            try check(oldHelmet != nil && newHelmet != nil && oldHelmet != newHelmet,
                      "Equipment supports an independent material palette")
            var undressed = previous
            undressed.appearance.equipment = []
            try guardActor.apply(undressed)
            try check(guardActor.children.compactMap { $0 as? IEAvatarNode }.count == 1
                && secondGuard.children.compactMap { $0 as? IEAvatarNode }.count == 4,
                "Unequipping affects only the intended actor")

            let clockActor = try CharacterAppearanceNode(definition: .civilian)
            try clockActor.advance(action: .walk, facing: .south, at: 1, paused: false)
            try clockActor.advance(action: .walk, facing: .south, at: 1.132, paused: false)
            let phase = clockActor.currentPhase
            try clockActor.advance(action: .walk, facing: .south, at: 9, paused: true)
            try clockActor.advance(action: .walk, facing: .south, at: 10, paused: false)
            try check(phase == 2 && clockActor.currentPhase == phase, "Animation advances at engine cadence and resumes without pause catch-up")

            let store = SaveStore(key: "RainShadow.QA.Appearance.\(UUID().uuidString)")
            defer { store.reset() }
            let context = GameContext(saveStore: store)
            let unit = OfficeInteriorScale.cameraScaleAt100Percent
            let scene = BaseGameScene(context: context, artSize: CGSize(width: 600, height: 180))
            scene.size = CGSize(width: 600, height: 180)
            scene.gameCamera.position = CGPoint(x: 300 * unit, y: 90 * unit)
            scene.gameCamera.setScale(unit)
            for root in scene.nativeWorldRoots { scene.addChild(root) }
            let background = SKSpriteNode(color: SKColor(white: 0.16, alpha: 1),
                                          size: CGSize(width: 600 * unit, height: 180 * unit))
            background.position = scene.gameCamera.position
            scene.backgroundRoot.addChild(background)
            scene.backgroundRoot.zPosition = -100
            let definitions: [CharacterDefinition] = [.voss, .cityGuard, .bandit, .lila, .civilian]
            var actors: [CharacterAppearanceNode] = []
            for (i, definition) in definitions.enumerated() {
                let actor = try CharacterAppearanceNode(definition: definition)
                actor.position = CGPoint(x: CGFloat(60 + i * 120) * unit, y: 55 * unit)
                try actor.present(action: .idle, facing: .south, phase: 0)
                scene.depthWorldRoot.addChild(actor)
                actors.append(actor)
                let label = SKLabelNode(text: definition.id)
                label.fontName = "Helvetica"
                label.fontSize = 11 * unit
                label.position = CGPoint(x: actor.position.x, y: 20 * unit)
                scene.depthWorldRoot.addChild(label)
            }
            guard let renderer = IENativeWorldRenderer() else { throw Failure(message: "No native renderer") }
            func render(_ filename: String) throws -> Data {
                guard renderer.render(scene: scene) != nil, let pixels = renderer.lastPixels,
                      let image = IENativeWorldRenderer.image(pixels, width: 600, height: 180),
                      let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else {
                    throw Failure(message: "Could not render appearance gallery")
                }
                try png.write(to: output.appendingPathComponent(filename))
                return pixels
            }
            let idle = try render("idle.png")
            for actor in actors { try actor.present(action: .walk, facing: .northWest, phase: 4) }
            let walk = try render("walk.png")
            try check(idle != walk, "Production native renderer draws five simultaneous body/palette/equipment variants")
            try JSONSerialization.data(withJSONObject: ["passed": true, "checks": checks], options: [.prettyPrinted])
                .write(to: output.appendingPathComponent("report.json"))
        } catch {
            try? JSONSerialization.data(withJSONObject: ["passed": false, "checks": checks,
                "error": String(describing: error)], options: [.prettyPrinted])
                .write(to: output.appendingPathComponent("report.json"))
        }
        NSApp.terminate(nil)
    }
}
#endif
