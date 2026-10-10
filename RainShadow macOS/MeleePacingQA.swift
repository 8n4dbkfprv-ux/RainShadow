#if DEBUG
import AppKit
import SpriteKit
import ImageIO
import UniformTypeIdentifiers

@MainActor enum MeleePacingQA {
    static func run(in view: SKView, output: URL, initial: TacticalCombat) async throws -> [String] {
        var checks: [String] = []
        func check(_ value: Bool, _ message: String) throws {
            guard value else { throw TacticalCombatQA.Failure(message: message) }; checks.append(message)
        }
        func wait(_ condition: () -> Bool) async throws {
            let deadline = ProcessInfo.processInfo.systemUptime + 40
            while !condition() {
                if ProcessInfo.processInfo.systemUptime > deadline { throw TacticalCombatQA.Failure(message: "Melee pacing timeout") }
                try await Task.sleep(for: .milliseconds(10))
            }
        }
        let originalScene = view.scene as! CityDistrictScene
        let player = initial.actors.first(where: \.player)!
        var enemy = initial.actors.first { !$0.player && $0.id.hasSuffix(".0") }!
        let candidates = (0..<32).map { step in
            let angle = Double(step) * .pi / 16
            return CGPoint(x: player.position.x + cos(angle) * 90, y: player.position.y + sin(angle) * 90 * 0.75).rounded
        }
        guard let position = candidates.compactMap({ originalScene.navigation.nearestWalkablePoint(to: $0) }).first(where: {
            (75...100).contains(CombatNavigation.distance(player.position, $0)) && CombatNavigation.clearLine(in: originalScene.navigation,
                from: player.position, to: $0, excluding: initial.actors.map(\.id))
        }) else { throw TacticalCombatQA.Failure(message: "No melee pacing staging point") }
        enemy.position = position; enemy.rangedWeapon = nil
        let store = SaveStore(key: "RainShadow.QA.MeleePacing.\(UUID().uuidString)")
        defer { store.reset() }
        for armored in [false, true] {
            for move in [nil, .powerStrike, .feintingCut, .tripAttack] as [CombatManeuver?] {
                let label = (armored ? "armored-" : "unarmored-") + (move?.rawValue ?? "normal")
                var actors = [player, enemy]
                for index in actors.indices {
                    actors[index].hp = 100; actors[index].maximumHP = 100
                    actors[index].attackBonus = 100; actors[index].defence = 1
                    actors[index].initiativeBonus = actors[index].player ? 100 : -100
                    actors[index].conditions = nil; actors[index].usedManeuvers = nil
                    actors[index].hidden = nil; actors[index].burningTurns = nil
                }
                var seed: UInt64 = 1
                var model: TacticalCombat
                while true {
                    model = TacticalCombat(encounterID: "gate", areaID: initial.areaID, actors: actors, seed: seed)
                    var trial = model
                    if trial.attack(target: enemy.id, clearLine: true, maneuver: move, hasSword: true)?.landed == true { break }
                    seed += 1
                }
                var equipment: [String: PersistedCarriedItemStack] = ["weapon1": .init(id: "lantern-shortsword", quantity: 1)]
                if armored { equipment["coat"] = .init(id: "splint-mail", quantity: 1); equipment["fedora"] = .init(id: "iron-helmet", quantity: 1) }
                store.save(SaveSnapshot(tacticalCombat: try JSONEncoder().encode(model), hasSeenOpening: true,
                    hasCompletedOfficeCaseIntro: true, equippedItems: equipment, hasSeededStarterKit: true,
                    hasReceivedArmorKit: true, hasReceivedElvenCourtBow: true, hasReceivedElvenCourtArrow: true))
                let context = GameContext(saveStore: store); context.router.start(in: view)
                try await wait { (view.scene as? CityDistrictScene)?.context === context && (view.scene as? CityDistrictScene)?.combatDirector?.busy == false }
                let scene = view.scene as! CityDistrictScene, director = scene.combatDirector!
                director.command(move == .tripAttack ? 14 : move == .powerStrike ? 6 : move == .feintingCut ? 7 : 17)
                let target = director.combat.actors.first { !$0.player }!
                director.pointer(at: scene.convert(CGPoint(x: target.position.x, y: target.position.y + 35), from: scene.depthWorldRoot))
                try await wait { director.meleeAttack != nil }
                let attack = director.meleeAttack!
                try check(attack.result.maneuver == move && !attack.isSneakAttack, "\(label): correct authored attack selected")
                try check(attack.actor.definition.appearance.equipment.contains { $0.item == .splintMail } == armored, "\(label): equipment retained")
                try await wait { attack.elapsed >= 0.16 }
                scene.handleTacticalPauseInput()
                let frozen = attack.elapsed, frozenPhase = attack.actor.currentPhase
                try await Task.sleep(for: .milliseconds(120))
                try check(attack.elapsed == frozen && attack.actor.currentPhase == frozenPhase && !attack.impactPresented,
                          "\(label): pause freezes the retimed wind-up without early damage")
                scene.handleTacticalPauseInput()
                var frames: [(Double, CGImage)] = []
                var phase = -1, checkedHit = false, checkedRecovery = false
                while director.meleeAttack != nil {
                    if attack.actor.currentPhase != phase {
                        phase = attack.actor.currentPhase
                        try check(phase == WeaponTechniqueMotion.meleePhase(elapsed: attack.elapsed, move: move), "\(label): pose \(phase) uses shared clock")
                        if !armored, let texture = view.texture(from: scene) {
                            let source = texture.cgImage()
                            let ctx = CGContext(data: nil, width: 550, height: 400, bitsPerComponent: 8, bytesPerRow: 2200,
                                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
                            ctx.draw(source, in: CGRect(x: 0, y: 0, width: 550, height: 400))
                            frames.append((attack.elapsed, ctx.makeImage()!))
                        }
                    }
                    if attack.impactPresented && !checkedHit {
                        try check(attack.elapsed >= attack.impactTime && director.presentedCombat == director.combat && director.busy,
                                  "\(label): damage and reaction occur at contact while recovery locks input")
                        try check(attack.swingTrail?.sprite.isHidden == false, "\(label): trail accompanies contact")
                        if let texture = view.texture(from: scene), let png = NSBitmapImageRep(cgImage: texture.cgImage()).representation(using: .png, properties: [:]) {
                            try png.write(to: output.appendingPathComponent(label + "-impact.png"))
                        }
                        checkedHit = true
                    }
                    let fadeEnd = WeaponTechniqueMotion.meleeTime(atFrame: WeaponTechniqueMotion.trailEnd(move), move: move) + SwordSwingPath.fadeDuration
                    if attack.elapsed >= fadeEnd + 0.01 && !checkedRecovery {
                        try check(attack.swingTrail?.sprite.isHidden == true && !attack.finished, "\(label): trail clears during the longer recovery")
                        checkedRecovery = true
                    }
                    try await Task.sleep(for: .milliseconds(10))
                }
                try check(checkedHit && checkedRecovery && attack.finished && attack.actor.currentAction == .idle,
                          "\(label): complete wind-up, hit and recovery return to idle")
                try check(GameSession(saveStore: store).tacticalCombat == director.combat, "\(label): presentation does not replay the accepted attack")
                if frames.count > 1 {
                    let url = output.appendingPathComponent(label + ".gif")
                    let gif = CGImageDestinationCreateWithURL(url as CFURL, UTType.gif.identifier as CFString, frames.count, nil)!
                    CGImageDestinationSetProperties(gif, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]] as CFDictionary)
                    for index in frames.indices {
                        let duration = index + 1 < frames.count ? frames[index + 1].0 - frames[index].0 : 0.8
                        CGImageDestinationAddImage(gif, frames[index].1, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: duration]] as CFDictionary)
                    }
                    try check(CGImageDestinationFinalize(gif), "\(label): timed visual review exported")
                }
            }
        }
        return checks
    }
}
#endif
