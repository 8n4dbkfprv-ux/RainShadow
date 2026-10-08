#if DEBUG
import AppKit
import SpriteKit

@MainActor enum BladeWardQA {
    static func run(in view: SKView, output: URL, initial: TacticalCombat) async throws -> [String] {
        var checks: [String] = []
        func check(_ value: Bool, _ text: String) throws {
            guard value else { throw TacticalCombatQA.Failure(message: text) }; checks.append(text)
        }
        func wait(_ predicate: () -> Bool) async throws {
            let deadline = ProcessInfo.processInfo.systemUptime + 40
            while !predicate() {
                if ProcessInfo.processInfo.systemUptime > deadline { throw TacticalCombatQA.Failure(message: "Ward timeout after " + (checks.last ?? "start")) }
                try await Task.sleep(for: .milliseconds(20))
            }
        }
        func capture(_ name: String) throws {
            guard let scene = view.scene, let texture = view.texture(from: scene),
                  let data = NSBitmapImageRep(cgImage: texture.cgImage()).representation(using: .png, properties: [:]) else { return }
            try data.write(to: output.appendingPathComponent(name + ".png"))
        }
        let store = SaveStore(key: "RainShadow.QA.Ward.\(UUID().uuidString)")
        defer { store.reset() }
        let equipment: [String: PersistedCarriedItemStack] = ["weapon1": .init(id: "lantern-shortsword", quantity: 1), "coat": .init(id: "splint-mail", quantity: 1)]
        var scene = view.scene as! CityDistrictScene
        var player = initial.actors.first(where: \.player)!
        var enemy = initial.actors.first { !$0.player && $0.rangedWeapon == nil }!
        let available = (0..<16).compactMap { step -> CGPoint? in
            let angle = Double(step) * .pi / 8
            let p = CGPoint(x: player.position.x + cos(angle) * 82, y: player.position.y + sin(angle) * 82 * 0.75)
            guard let point = scene.navigation.nearestWalkablePoint(to: p),
                  (60...100).contains(CombatNavigation.distance(player.position, point)),
                  CombatNavigation.clearLine(in: scene.navigation, from: player.position, to: point,
                    excluding: Array(scene.navigation.occupancy.actors.keys)) else { return nil }
            return point
        }
        guard let point = available.first else { throw TacticalCombatQA.Failure(message: "No ward test position") }
        enemy.position = point
        player.hp = 100; player.maximumHP = 100; player.initiativeBonus = 100
        player.conditions = nil; player.burningTurns = nil; player.hidden = nil
        enemy.hp = 100; enemy.maximumHP = 100; enemy.initiativeBonus = 0
        enemy.attackBonus = 100; enemy.damageMin = 7; enemy.damageMax = 7
        enemy.conditions = nil; enemy.burningTurns = nil; enemy.hidden = nil; enemy.rangedWeapon = nil
        enemy.usedManeuvers = CombatManeuver.allCases; enemy.shoveSpent = true
        var fixture: TacticalCombat?
        for seed in 1...100 {
            let model = TacticalCombat(encounterID: initial.encounterID, areaID: initial.areaID, actors: [player, enemy], seed: UInt64(seed))
            var probe = model; _ = probe.castBladeWard(); _ = probe.endTurn()
            if probe.attack(target: player.id, clearLine: true)?.damage == 3 { fixture = model; break }
        }
        guard let fixture else { throw TacticalCombatQA.Failure(message: "No deterministic ward seed") }
        func open(_ model: TacticalCombat) async throws -> TacticalCombatDirector {
            store.save(SaveSnapshot(tacticalCombat: try JSONEncoder().encode(model), hasSeenOpening: true,
                hasCompletedOfficeCaseIntro: true, equippedItems: equipment, hasSeededStarterKit: true,
                hasReceivedArmorKit: true, hasReceivedElvenCourtBow: true, hasReceivedElvenCourtArrow: true))
            let context = GameContext(saveStore: store); context.router.start(in: view)
            try await wait { (view.scene as? CityDistrictScene)?.context === context && (view.scene as? CityDistrictScene)?.combatDirector != nil }
            scene = view.scene as! CityDistrictScene
            let director = scene.combatDirector!
            try await wait { !director.busy }
            return director
        }
        var director = try await open(fixture)
        try check(director.visibleCombatCommands.contains("combat.bladeWard") && !director.visibleCombatCommands.contains("combat.defend"), "Blade Ward replaces Defend in the action bar")
        director.command(1)
        try await wait { (director.wardCast?.elapsed ?? 0) > 0.2 }
        let accepted = director.combat
        try check(accepted.current.hasBladeWard && !accepted.budget.canAttack && !director.presentedCombat.current.hasBladeWard,
                  "Cast spends one action and hides the ward status until its marker")
        try check(GameSession(saveStore: store).tacticalCombat == accepted, "Mid-cast save stores the accepted result exactly once")
        try check(director.wardCast?.node.currentAction == .ward && scene.detective.isHidden,
                  "Casting uses the new hand gesture and equipped armour")
        try capture("ward-windup")
        scene.handleTacticalPauseInput()
        let frozen = director.wardCast!.elapsed, particles = director.wardEffects[player.id]!.elapsed
        try await Task.sleep(for: .milliseconds(250))
        try check(director.wardCast?.elapsed == frozen && director.wardEffects[player.id]?.elapsed == particles,
                  "Pause freezes casting and protective particles")
        director.command(2)
        try check(director.combat == accepted, "End Turn cannot skip a paused cast")
        scene.handleTacticalPauseInput()
        try await wait { director.wardCast?.impactPresented == true }
        try capture("ward-forms")
        try check(director.presentedCombat.current.hasBladeWard, "Protection is revealed when the gesture completes")
        try await wait { !director.busy }
        try check(!scene.detective.isHidden && director.wardEffects[player.id] != nil,
                  "Recovery restores the equipped human with an active ward")
        try capture("ward-active")
        scene.handleInventoryInput()
        let heldTime = director.wardEffects[player.id]!.elapsed
        try await Task.sleep(for: .milliseconds(250))
        try check(director.wardEffects[player.id]?.elapsed == heldTime, "Inventory pauses persistent ward animation")
        scene.handleInventoryInput()
        director.command(2)
        try await wait { director.meleeAttack?.impactPresented == true }
        try check(director.meleeAttack?.result.damage == 3 && director.meleeAttack?.result.wardAbsorbed == 4,
                  "A seven-point sword hit deals three damage through Blade Ward")
        try capture("ward-hit")
        try await wait { director.combat.isPlayerTurn && !director.busy }
        try check(director.combat.current.bladeWardTurns == 1, "Ward survives into the next player turn")
        director.command(2)
        try await wait { director.combat.isPlayerTurn && !director.busy }
        try check(!director.combat.current.hasBladeWard && director.wardEffects[player.id] == nil,
                  "Expiry removes the ward status and visual")
        director = try await open(accepted)
        try check(director.combat.current.bladeWardTurns == 2 && director.wardCast == nil && director.wardEffects[player.id] != nil,
                  "Reload restores protection without replaying the cast")
        return checks
    }
}
#endif
