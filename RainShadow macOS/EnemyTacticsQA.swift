#if DEBUG
import AppKit
import SpriteKit

@MainActor enum EnemyTacticsQA {
    static func run(in view: SKView, output: URL, initial: TacticalCombat) async throws -> [String] {
        var checks: [String] = []
        func check(_ value: Bool, _ message: String) throws {
            guard value else { throw TacticalCombatQA.Failure(message: message) }; checks.append(message)
        }
        func wait(_ condition: () -> Bool) async throws {
            let deadline = ProcessInfo.processInfo.systemUptime + 60
            while !condition() {
                if ProcessInfo.processInfo.systemUptime > deadline { throw TacticalCombatQA.Failure(message: "Enemy tactics turn timeout") }
                try await Task.sleep(for: .milliseconds(20))
            }
        }
        let store = SaveStore(key: "RainShadow.QA.EnemyTactics.\(UUID().uuidString)")
        defer { store.reset() }
        for archer in ProcessInfo.processInfo.environment["RAINSHADOW_QA_ENEMY_SHOVE_ONLY"] == "1" ? [] : [false, true] {
            var actors = initial.actors
            for index in actors.indices {
                actors[index].hp = 60; actors[index].maximumHP = 60
                actors[index].usedManeuvers = nil; actors[index].conditions = nil
                if actors[index].player { actors[index].initiativeBonus = 100 }
                else {
                    actors[index].enemyRole = archer && actors[index].rangedWeapon == .bow ? .archer : index % 2 == 0 ? .opportunist : .bruiser
                    actors[index].name = actors[index].enemyRole!.title
                    if !archer { actors[index].rangedWeapon = nil; actors[index].fireArrows = nil }
                }
            }
            let model = TacticalCombat(encounterID: initial.encounterID, areaID: initial.areaID, actors: actors, seed: 42)
            store.save(SaveSnapshot(tacticalCombat: try JSONEncoder().encode(model), hasReceivedFireArrows: true, hasSeenOpening: true,
                hasCompletedOfficeCaseIntro: true,
                equippedItems: ["weapon1": .init(id: "lantern-shortsword", quantity: 1), "weapon2": .init(id: "elven-court-bow", quantity: 1)], hasSeededStarterKit: true,
                hasReceivedArmorKit: true, hasReceivedElvenCourtBow: true, hasReceivedElvenCourtArrow: true,
                caseFlags: ["combat.a1.gate.trigger"]))
            let context = GameContext(saveStore: store); context.router.start(in: view)
            try await wait { (view.scene as? CityDistrictScene)?.context === context && (view.scene as? CityDistrictScene)?.combatDirector?.busy == false }
            let scene = view.scene as! CityDistrictScene, director = scene.combatDirector!
            try check(director.combat.actors.filter { !$0.player }.allSatisfy { $0.enemyRole != nil }, "\(archer ? "Ranged" : "Melee") encounter loads enemy roles")
            var sawMelee = false, sawBow = false, sawMovement = false
            for _ in 0..<2 {
                director.command(2)
                let deadline = ProcessInfo.processInfo.systemUptime + 60
                while !director.combat.isPlayerTurn || director.busy {
                    guard ProcessInfo.processInfo.systemUptime < deadline else { throw TacticalCombatQA.Failure(message: "Enemy tactics failed to finish its turn") }
                    sawMelee = sawMelee || director.meleeAttack != nil
                    sawBow = sawBow || director.rangedShot != nil
                    sawMovement = sawMovement || director.combat.actors.contains { !$0.player && director.isWalking($0.id) }
                    try await Task.sleep(for: .milliseconds(20))
                }
            }
            if !archer { try check(sawMovement, "Melee enemies animate their planned movement") }
            try check(sawMelee, "\(archer ? "Ranged" : "Melee") encounter executes melee attacks")
            if archer { try check(sawBow, "Archer executes a scored bow attack with animation") }
            try check(director.combat.round >= 3 && director.combat.isPlayerTurn, "\(archer ? "Ranged" : "Melee") enemies finish two rounds without loops")
            try check(GameSession(saveStore: store).tacticalCombat == director.combat, "\(archer ? "Ranged" : "Melee") decisions and spent resources persist")
            try await Task.sleep(for: .milliseconds(80))
            if let texture = view.texture(from: scene), let png = NSBitmapImageRep(cgImage: texture.cgImage()).representation(using: .png, properties: [:]) {
                try png.write(to: output.appendingPathComponent(archer ? "archer-turns.png" : "melee-roles.png"))
            }
        }
        // Tight level-ground encounters isolate AI-selected shoves from walking.
        // Use the real area's raster and the real director/animation/save path.
        for archer in [false, true] {
            let label = archer ? "archer-shove" : "melee-shove"
            let map = (view.scene as! CityDistrictScene).navigation
            var player = initial.actors.first { $0.player }!
            var enemy = initial.actors.first { !$0.player && ($0.rangedWeapon == .bow) == archer }!
            // A one-opponent restored encounter stages crew index zero. Preserve
            // that identity when using the lookout's loadout in this fixture.
            enemy.id = "wharf-ladder.crew.0"
            player.hp = 100; player.maximumHP = 100; player.initiativeBonus = 100
            enemy.hp = 100; enemy.maximumHP = 100; enemy.initiativeBonus = -100
            enemy.enemyRole = archer ? .archer : .bruiser
            enemy.usedManeuvers = CombatManeuver.allCases; enemy.fireArrows = 0
            enemy.speed = 1
            enemy.shoveProfile = .init(strength: 14, athletics: 30, acrobatics: 2, weight: 80)
            var found = false
            let previousOccupants = Array(map.occupancy.actors.values)
            map.updateActor(id: player.id, position: player.position, isMoving: false)
            for step in 0..<16 {
                let angle = Double(step) * .pi / 8
                enemy.position = CGPoint(x: player.position.x + cos(angle) * 96,
                                         y: player.position.y + sin(angle) * 96 * 0.75).rounded
                map.updateActor(id: enemy.id, position: enemy.position, isMoving: false)
                guard [player, enemy].allSatisfy({ actor in
                    map.occupancy.withStampLifted(id: actor.id) {
                        map.searchMap.blockedInRadiusTile(at: actor.position, size: map.circleSize).contains(.passable)
                    }
                }),
                      CombatNavigation.clearLine(in: map, from: enemy.position, to: player.position,
                        excluding: [enemy.id, player.id]) else { continue }
                let end = CombatNavigation.knockbackDestination(in: map, actor: player, awayFrom: enemy.position,
                    actors: [player, enemy], destroyedBarrels: [], maximumDistance: 80)
                if CombatNavigation.distance(enemy.position, end) > TacticalCombat.meleeReach + 8 {
                    found = true; break
                }
            }
            Array(map.occupancy.actors.keys).forEach { map.unregisterActor(id: $0) }
            previousOccupants.forEach { map.occupancy.register($0) }
            map.occupancy.restampAll()
            try check(found, "\(label): certified standing and landing positions on the shipped raster")
            let model = TacticalCombat(encounterID: initial.encounterID, areaID: initial.areaID, actors: [player, enemy], seed: 42)
            store.save(SaveSnapshot(tacticalCombat: try JSONEncoder().encode(model), hasReceivedFireArrows: true, hasSeenOpening: true,
                hasCompletedOfficeCaseIntro: true,
                equippedItems: ["weapon1": .init(id: "lantern-shortsword", quantity: 1)], hasSeededStarterKit: true,
                hasReceivedArmorKit: true, hasReceivedElvenCourtBow: true, hasReceivedElvenCourtArrow: true,
                caseFlags: ["combat.a1.gate.trigger"]))
            let context = GameContext(saveStore: store); context.router.start(in: view)
            try await wait { (view.scene as? CityDistrictScene)?.context === context && (view.scene as? CityDistrictScene)?.combatDirector?.busy == false }
            let scene = view.scene as! CityDistrictScene, director = scene.combatDirector!
            try check(director.combat.actors.first { !$0.player }!.position == enemy.position,
                "\(label): actor staging preserves the certified melee start")
            let loaded = director.combat
            director.command(2)
            var sawShove = false, sawAttack = false, captured = false
            let deadline = ProcessInfo.processInfo.systemUptime + 60
            while !director.combat.isPlayerTurn || director.busy {
                guard ProcessInfo.processInfo.systemUptime < deadline else { throw TacticalCombatQA.Failure(message: "\(label): enemy turn timeout") }
                sawAttack = sawAttack || director.meleeAttack != nil || director.rangedShot != nil
                if let shove = director.shovePresentation {
                    if !sawShove && !archer { try check(sawAttack, "Melee enemy attacks before pushing its target out of reach") }
                    sawShove = true
                    if !captured && shove.elapsed >= ShoveAnimationSet.impactTime {
                        if let texture = view.texture(from: scene), let png = NSBitmapImageRep(cgImage: texture.cgImage()).representation(using: .png, properties: [:]) {
                            try png.write(to: output.appendingPathComponent(label + ".png")); captured = true
                        }
                    }
                }
                try await Task.sleep(for: .milliseconds(20))
            }
            guard sawShove && captured else {
                let diagnostics = ["loaded": try JSONEncoder().encode(loaded), "finished": try JSONEncoder().encode(director.combat)]
                for (name, data) in diagnostics { try data.write(to: output.appendingPathComponent(label + "-" + name + ".json")) }
                throw TacticalCombatQA.Failure(message: "\(label): enemy-selected shove contact missing (shove=\(sawShove), captured=\(captured), attack=\(sawAttack))")
            }
            try check(true, "\(label): enemy-selected shove plays through contact")
            try check(sawAttack, "\(label): bonus shove preserves the normal attack")
            try check(director.combat.actors.first { $0.player }!.position != player.position, "\(label): successful shove displaces the target")
            try check(director.combat.actors.first { !$0.player }!.shoveSpent == true,
                "\(label): shove is spent once and the enemy turn finishes")
            try check(GameSession(saveStore: store).tacticalCombat == director.combat, "\(label): outcome and resources survive reload")
        }
        return checks
    }
}
#endif
