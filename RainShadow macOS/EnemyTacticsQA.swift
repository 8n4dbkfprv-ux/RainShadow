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
        for archer in [false, true] {
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
        return checks
    }
}
#endif
