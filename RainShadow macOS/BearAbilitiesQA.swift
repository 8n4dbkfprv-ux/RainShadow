#if DEBUG
import AppKit
import SpriteKit

@MainActor enum BearAbilitiesQA {
    static func run(in view: SKView, output: URL, initial: TacticalCombat) async throws -> [String] {
        var checks: [String] = []
        func check(_ value: Bool, _ text: String) throws {
            guard value else { throw TacticalCombatQA.Failure(message: text) }
            checks.append(text)
        }
        func wait(_ predicate: () -> Bool) async throws {
            let deadline = ProcessInfo.processInfo.systemUptime + 40
            while !predicate() {
                if ProcessInfo.processInfo.systemUptime > deadline { throw TacticalCombatQA.Failure(message: "Bear abilities timeout after " + (checks.last ?? "start")) }
                try await Task.sleep(for: .milliseconds(20))
            }
        }
        func capture(_ name: String) throws {
            guard let scene = view.scene, let texture = view.texture(from: scene),
                  let data = NSBitmapImageRep(cgImage: texture.cgImage()).representation(using: .png, properties: [:]) else { return }
            try data.write(to: output.appendingPathComponent(name + ".png"))
        }
        func checkBearInterface(_ scene: CityDistrictScene, _ director: TacticalCombatDirector, captureName: String? = nil) async throws {
            scene.handleInventoryInput()
            try await Task.sleep(for: .milliseconds(240))
            let form = BearFormReadout(director.presentedCombat)
            try check(scene.inventoryIsPresented && scene.inventoryOverlay.bearForm == form && form != nil,
                      "Bear inventory projects the active form on open and reload")
            try check(scene.inventoryOverlay.childNode(withName: "//inventory.paperdoll.bear")?.isHidden == false
                && scene.inventoryOverlay.childNode(withName: "//inventory.paperdoll")?.parent?.isHidden == true,
                      "Inventory shows the bear and hides the equipped human figure")
            try check(scene.portraitBar.isBearForm && scene.portraitBar.displayedHealth == form?.endurance
                && scene.portraitBar.displayedMaximumHealth == BearFormRules.maximumEndurance,
                      "Party portrait and health use the bear form and endurance pool")
            let portraitDepth = scene.portraitBar.childNode(withName: "hud.detective-portrait")!.zPosition
            let backgroundDepth = scene.portraitBar.childNode(withName: "hud.party-rail-background")!.zPosition
            try check(portraitDepth > backgroundDepth, "Portrait draws above the opaque leather rail")
            let vitality = scene.inventoryOverlay.childNode(withName: "//inventory.stat.vitality.value") as? SKLabelNode
            let defence = scene.inventoryOverlay.childNode(withName: "//inventory.stat.defence.value") as? SKLabelNode
            let damage = scene.inventoryOverlay.childNode(withName: "//inventory.stat.damage.value") as? SKLabelNode
            try check(vitality?.text == "\(form!.endurance)/8" && defence?.text == "\(form!.defence)" && damage?.text == "5–8",
                      "Inventory displays bear endurance, defence and claw damage")
            let before = scene.context.session.characterInventory
            let refusal = scene.inventoryOverlay.onUnequipItem?(.weapon1)
            try check(refusal == .equipmentMergedInBearForm && scene.context.session.characterInventory == before,
                      "Merged equipment cannot be removed in Bear Form")
            if let captureName { try capture(captureName) }
            scene.handleInventoryInput()
        }
        func checkHumanInterface(_ scene: CityDistrictScene, captureName: String) async throws {
            scene.handleInventoryInput()
            try await Task.sleep(for: .milliseconds(240))
            try check(scene.inventoryOverlay.bearForm == nil && !scene.portraitBar.isBearForm,
                      "Reversion restores human portrait, inventory and stats")
            try check(scene.inventoryOverlay.childNode(withName: "//inventory.paperdoll.bear")?.isHidden == true
                && scene.inventoryOverlay.childNode(withName: "//inventory.paperdoll")?.parent?.isHidden == false
                && scene.inventoryOverlay.childNode(withName: "//inventory.paperdoll.weapon")?.isHidden == false,
                      "Reversion restores the equipped human preview")
            try capture(captureName)
            scene.handleCancelInput()
        }
        let store = SaveStore(key: "RainShadow.QA.BearAbilities.\(UUID().uuidString)")
        defer { store.reset() }
        let equipment: [String: PersistedCarriedItemStack] = ["weapon1": .init(id: "lantern-shortsword", quantity: 1), "coat": .init(id: "splint-mail", quantity: 1)]
        var scene = view.scene as! CityDistrictScene
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
        var player = initial.actors.first(where: \.player)!
        var enemy = initial.actors.first { !$0.player && $0.id.hasSuffix(".0") }!
        let original = player.position
        var site: (CGPoint, CGPoint)?
        search: for ring in 1...8 { for step in 0..<16 {
            let angle = Double(step) * .pi / 8
            let point = CGPoint(x: original.x + cos(angle)*Double(ring*48), y: original.y + sin(angle)*Double(ring*48)*0.75)
            guard let point = scene.navigation.nearestWalkablePoint(to: point) else { continue }
            var probe = player; probe.position = point
            guard BearFormRules.canStand(in: scene.navigation, actor: probe) else { continue }
            for heading in 0..<16 {
                let a = Double(heading) * .pi / 8
                let target = CGPoint(x: point.x + cos(a)*85, y: point.y + sin(a)*85*0.75)
                guard let target = scene.navigation.nearestWalkablePoint(to: target),
                      (78...100).contains(CombatNavigation.distance(point, target)),
                      CombatNavigation.clearLine(in: scene.navigation, from: point, to: target, excluding: Array(scene.navigation.occupancy.actors.keys)) else { continue }
                site = (point, target); break search
            }
        } }
        guard let site else { throw TacticalCombatQA.Failure(message: "No open bear fixture") }
        player.position = site.0; enemy.position = site.1
        player.hp = 100; player.maximumHP = 100; player.initiativeBonus = 100
        player.conditions = nil; player.burningTurns = nil; player.hidden = nil; player.rangedWeapon = .bow
        enemy.hp = 100; enemy.maximumHP = 100; enemy.initiativeBonus = 0
        enemy.defence = 1; enemy.attackBonus = -100; enemy.damageMin = 1; enemy.damageMax = 1
        enemy.conditions = nil; enemy.burningTurns = nil; enemy.hidden = nil; enemy.rangedWeapon = nil
        enemy.usedManeuvers = CombatManeuver.allCases; enemy.shoveSpent = true
        func fixture(_ mode: String) throws -> TacticalCombat {
            for seed in 1...100 {
                var opponent = enemy
                if mode == "transform" {
                    // Transformation needs an empty large-body footprint. The
                    // close melee fixture deliberately places a rival inside it.
                    opponent.position = scene.navigation.nearestWalkablePoint(to:
                        CGPoint(x: site.0.x - 260, y: site.0.y - 180)) ?? enemy.position
                }
                if mode == "deplete" { opponent.attackBonus = 100; opponent.damageMin = 10; opponent.damageMax = 10 }
                var model = TacticalCombat(encounterID: "gate", areaID: initial.areaID, actors: [player, opponent], seed: UInt64(seed))
                if mode != "transform" {
                    _ = model.transformToBear(hasClearance: true); _ = model.endTurn(); _ = model.endTurn()
                }
                if mode == "claw" || mode == "miss" {
                    var probe = model
                    guard let strike = probe.attack(target: enemy.id, clearLine: true), (strike.damage == 0) == (mode == "miss") else { continue }
                }
                if mode == "expiry" { for _ in 0..<2 { _ = model.endTurn(); _ = model.endTurn() } }
                return model
            }
            throw TacticalCombatQA.Failure(message: "No deterministic bear fixture")
        }
        for mode in ["transform", "roar", "claw", "miss", "revert", "deplete", "expiry"] {
            let model = try fixture(mode)
            let director = try await open(model)
            let inventory = scene.context.session.characterInventory
            if mode == "transform" {
                try check(director.visibleCombatCommands.contains("combat.tripAttack") && !director.visibleCombatCommands.contains("combat.roar"), "Human form has weapon actions before transforming")
                director.command(4)
                try await wait { director.combat.isBear && director.busy }
                try capture("bear-transform")
                try await wait { !director.busy }
                try check(director.bearNode?.isHidden == false && scene.detective.isHidden, "Transformation displays the bear")
                try check(director.visibleCombatCommands == ["combat.claw", "combat.roar", "combat.bear", "combat.extinguish", "combat.end", "combat.flee"], "Bear form replaces weapon techniques with its own action bar")
                try capture("bear-actions")
                try await checkBearInterface(scene, director, captureName: "bear-inventory")
                continue
            }
            try check(director.visibleCombatCommands.contains("combat.roar") && !director.visibleCombatCommands.contains("combat.tripAttack"), "\(mode): loading Bear Form restores bear controls")
            try await checkBearInterface(scene, director)
            let beforeIllegal = director.combat
            for command in [7, 8, 9, 10, 11, 13, 14] { director.command(command) }
            try check(director.combat == beforeIllegal && director.selectedManeuver == nil && !director.selectingShove, "\(mode): human shortcuts cannot spend bear actions")
            if mode == "roar" {
                director.command(6)
                try check(director.bearAbility?.action == .roar && director.busy && director.combat.bearForm?.roarSpent == true, "Roar consumes its action and single transformation use")
                let accepted = director.combat
                try check(director.presentedCombat == model && GameSession(saveStore: store).tacticalCombat == accepted, "Roar saves its result but holds condition feedback until the roar marker")
                try await wait { (director.bearAbility?.elapsed ?? 0) > 0.15 }
                scene.handleTacticalPauseInput()
                let elapsed = director.bearAbility!.elapsed, phase = director.bearNode!.currentPhase
                try await Task.sleep(for: .milliseconds(200))
                try check(director.bearAbility?.elapsed == elapsed && director.bearNode?.currentPhase == phase && !director.roarSoundIsPlaying, "Pause freezes the roar animation and audio")
                director.command(2)
                try check(director.combat == accepted, "End Turn cannot skip the roar")
                scene.handleTacticalPauseInput()
                try await wait { director.bearAbility?.impactPresented == true }
                try check(director.bearNode?.currentAction == .roar && director.hitReactions[enemy.id]?.kind == .hit, "Roar impact plays the raised-head pose and enemy flinch")
                try check(director.presentedCombat == accepted && accepted.actors.map(\.hp) == model.actors.map(\.hp), "Roar applies Goaded without damage")
                try capture("bear-roar-impact")
                try await wait { !director.busy }
                try check(!director.roarSoundIsPlaying && director.bearAbility == nil, "Roar finishes and cleans up audio")
                let restored = try await open(accepted)
                try check(restored.bearAbility == nil && restored.combat == accepted, "Reload preserves Goaded and spent use without replaying the roar")
                restored.command(2)
                try await wait { restored.meleeAttack != nil || restored.rangedShot != nil }
                let attackTarget = restored.meleeAttack?.result.target ?? restored.rangedShot?.result.target
                try check(attackTarget == TacticalCombat.playerID && restored.combat.current.conditions?.goadedBy == TacticalCombat.playerID, "Goaded enemy attacks the bear on its turn")
                try await wait { restored.combat.isPlayerTurn && !restored.busy }
                try check(restored.combat.actors.first { $0.id == enemy.id }?.conditions?.goadedBy == nil, "Goaded expires at the end of the enemy's turn")
                let spent = restored.combat; restored.command(6)
                try check(restored.combat == spent && restored.bearAbility == nil, "Roar cannot be reused next turn")
            } else if mode == "claw" || mode == "miss" {
                director.command(5)
                try check(director.selectingClaw && director.combat == model, "\(mode): Claw targeting spends nothing")
                director.command(5)
                try check(!director.selectingClaw && director.combat == model, "\(mode): Claw targeting cancels cleanly")
                director.command(5)
                director.pointer(at: scene.convert(enemy.position, from: scene.depthWorldRoot))
                try check(director.bearAbility?.action == .attack && director.presentedCombat == model, "\(mode): claw begins before visible damage")
                let accepted = director.combat
                try check(GameSession(saveStore: store).tacticalCombat == accepted, "\(mode): claw result is saved once before playback")
                try await wait { director.bearNode?.currentAction == .attack && (director.bearNode?.currentPhase ?? 0) >= 8 }
                scene.handleTacticalPauseInput(); let phase = director.bearNode!.currentPhase
                try await Task.sleep(for: .milliseconds(150))
                try check(director.bearNode?.currentPhase == phase && director.presentedCombat == model, "\(mode): pause freezes claw wind-up without revealing damage")
                try capture("bear-" + mode + "-windup"); scene.handleTacticalPauseInput()
                try await wait { director.bearAbility?.impactPresented == true }
                try check(director.presentedCombat == accepted && director.hitReactions[enemy.id]?.kind == (mode == "miss" ? .dodge : .hit), "\(mode): contact reveals damage or a dodge")
                try capture("bear-" + mode + "-contact")
                try check((director.bearNode?.currentPhase ?? 0) >= 12, "\(mode): contact uses the new diagonal strike marker")
                try await wait { (director.bearNode?.currentPhase ?? 0) >= 17 }
                try check(director.busy && director.bearAbility != nil, "\(mode): landing keeps input locked through recovery")
                try capture("bear-" + mode + "-landing")
                try await wait { !director.busy }
                try check(director.bearAbility == nil && !director.combat.budget.canAttack, "\(mode): recovery unlocks input without another attack")
            } else {
                if mode == "revert" { director.command(4) }
                else { director.command(2) }
                try await wait { !director.combat.isBear && !director.busy && scene.depthWorldRoot.childNode(withName: "combat.bear.transformation") == nil }
                try check(!scene.detective.isHidden && director.bearNode?.isHidden == true, "\(mode): human appearance returns")
                try check(director.visibleCombatCommands.contains("combat.tripAttack") && !director.visibleCombatCommands.contains("combat.roar"), "\(mode): human actions return automatically")
                try check(scene.context.session.characterInventory == inventory && !director.combat.canTransform, "\(mode): equipment and spent transformation persist")
                try capture("bear-" + mode + "-human")
                try await checkHumanInterface(scene, captureName: "inventory-" + mode + "-human")
            }
        }
        return checks
    }
}
#endif
