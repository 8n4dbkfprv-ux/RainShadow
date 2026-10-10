#if DEBUG
import AppKit
import SpriteKit

@MainActor enum DashAnimationQA {
    static func run(in view: SKView, output: URL, initial: TacticalCombat) async throws -> [String] {
        var checks: [String] = []
        func check(_ value: Bool, _ message: String) throws {
            guard value else { throw TacticalCombatQA.Failure(message: message) }; checks.append(message)
        }
        func wait(_ stage: String = "player activation", _ condition: () -> Bool) async throws {
            let deadline = ProcessInfo.processInfo.systemUptime + 40
            while !condition() {
                guard ProcessInfo.processInfo.systemUptime < deadline else { throw TacticalCombatQA.Failure(message: "Dash animation timeout: \(stage)") }
                try await Task.sleep(for: .milliseconds(10))
            }
        }
        let store = SaveStore(key: "RainShadow.QA.Dash.\(UUID().uuidString)")
        defer { store.reset() }
        let kits = ProcessInfo.processInfo.environment["RAINSHADOW_QA_DASH_ENEMY_ONLY"] == "1" ? [] : ["unarmed", "sword", "armored", "bow", "armored-bow", "hidden", "bear"]
        for kit in kits {
            var model = initial
            if kit == "hidden" { _ = model.hide(observed: false) }
            if kit == "bear" {
                _ = model.transformToBear(hasClearance: true)
                while !model.isPlayerTurn || !model.canDash { _ = model.endTurn() }
            }
            var equipment: [String: PersistedCarriedItemStack] = [:]
            if kit != "unarmed" && kit != "bear" {
                equipment["weapon1"] = .init(id: kit.contains("bow") ? "elven-court-bow" : "lantern-shortsword", quantity: 1)
            }
            if kit.contains("armored") {
                equipment["coat"] = .init(id: "splint-mail", quantity: 1)
                equipment["fedora"] = .init(id: "iron-helmet", quantity: 1)
            }
            store.save(SaveSnapshot(tacticalCombat: try JSONEncoder().encode(model), hasSeenOpening: true,
                hasCompletedOfficeCaseIntro: true, equippedItems: equipment, hasSeededStarterKit: true,
                hasReceivedArmorKit: true, hasReceivedElvenCourtBow: true, hasReceivedElvenCourtArrow: true))
            let context = GameContext(saveStore: store); context.router.start(in: view)
            try await wait { (view.scene as? CityDistrictScene)?.context === context && (view.scene as? CityDistrictScene)?.combatDirector?.busy == false }
            let scene = view.scene as! CityDistrictScene, director = scene.combatDirector!
            let before = director.combat, speed = before.movementSpeed(for: before.current)
            let allowance = before.budget.availableMovement(speed: speed)
            director.command(19)
            try check(director.dashPresentation != nil && director.busy, "\(kit): Dash starts its activation and locks input")
            let accepted = director.combat
            try check(!accepted.canDash && accepted.budget.availableMovement(speed: speed) == allowance + speed,
                      "\(kit): exactly one action grants exactly one speed")
            director.command(19); director.command(2)
            try check(director.combat == accepted, "\(kit): repeat Dash and end-turn cannot interrupt activation")
            try check(accepted.current.position == before.current.position, "\(kit): activation does not displace the actor")
            try await wait { (director.dashPresentation?.elapsed ?? 0) >= 0.43 }
            scene.handleTacticalPauseInput()
            let dash = director.dashPresentation!
            try check(!dash.wind.isHidden, "\(kit): wind burst accompanies activation")
            if kit == "bear" { try check(dash.node == nil && director.combat.isBear, "Bear keeps its own body during Dash") }
            else {
                try check(dash.node?.currentAction == .dash, "\(kit): dedicated body animation is visible")
                try check(dash.node?.definition.appearance.equipment.contains { $0.item == .elvenCourtBow } == kit.contains("bow"),
                          "\(kit): readied bow is preserved")
                try check(dash.node?.definition.appearance.equipment.contains { $0.item == .splintMail } == kit.contains("armored"),
                          "\(kit): armor is preserved")
            }
            let phase = dash.node?.currentPhase
            try await Task.sleep(for: .milliseconds(150))
            try check(director.dashPresentation?.elapsed == dash.elapsed && dash.wind.elapsed == dash.elapsed && dash.node?.currentPhase == phase,
                      "\(kit): pause freezes body and wind together")
            if let image = view.texture(from: scene)?.cgImage(), let data = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) {
                try data.write(to: output.appendingPathComponent("dash-" + kit + ".png"))
            }
            try check(GameSession(saveStore: store).tacticalCombat == accepted, "\(kit): accepted allowance is saved during activation")
            scene.handleTacticalPauseInput()
            scene.handleInventoryInput()
            try await Task.sleep(for: .milliseconds(150))
            try check(scene.inventoryIsPresented && director.dashPresentation?.elapsed == dash.elapsed && dash.wind.elapsed == dash.elapsed,
                      "\(kit): inventory freezes the activation independently of tactical pause")
            scene.handleInventoryInput()
            try await wait { director.dashPresentation == nil && !director.busy }
            try check(dash.wind.parent == nil && dash.node?.parent == nil, "\(kit): transient animation and particles are removed")
            try check(director.combat == accepted, "\(kit): recovery does not change rules or position")
            if kit == "hidden" { try check(director.combat.current.hidden == true, "Dash preserves concealment until movement is observed") }
            // Reload the accepted state: no animation replay and no second grant.
            let restored = GameContext(saveStore: store); restored.router.start(in: view)
            try await wait { (view.scene as? CityDistrictScene)?.context === restored && (view.scene as? CityDistrictScene)?.combatDirector?.busy == false }
            let loaded = (view.scene as! CityDistrictScene).combatDirector!
            try check(loaded.dashPresentation == nil && !loaded.combat.canDash && loaded.combat.budget == accepted.budget,
                      "\(kit): reload retains spent Dash without replaying it")
            let runScene = view.scene as! CityDistrictScene
            let origin = loaded.combat.current.position
            runScene.followCamera(); runScene.gameCamera.position = origin
            var runPath: Path?
            search: for distance in [190.0, 130, 85] {
                for step in 0..<32 {
                    let a = Double(step) * .pi / 16
                    let point = CGPoint(x: origin.x + cos(a) * distance, y: origin.y + sin(a) * distance * 0.75)
                    guard let path = CombatNavigation.route(in: runScene.navigation, actor: loaded.combat.current, to: point, bear: loaded.combat.isBear),
                          let end = path.destination, CombatNavigation.length(path, from: origin) > 70 else { continue }
                    loaded.hover(at: runScene.convert(end, from: runScene.depthWorldRoot))
                    if !loaded.movementPreview.isHidden && loaded.movementPreview.canMove { runPath = path; break search }
                }
            }
            guard let runPath, let endpoint = runPath.destination else { throw TacticalCombatQA.Failure(message: "No Dash run route for \(kit)") }
            let beforeRun = loaded.combat
            loaded.pointer(at: runScene.convert(endpoint, from: runScene.depthWorldRoot))
            try check(loaded.runPresentation != nil && loaded.isWalking(TacticalCombat.playerID), "\(kit): a ground click after Dash starts the running gait")
            try await wait("\(kit) running progress") { (loaded.runPresentation?.travelled ?? 0) > 35 }
            runScene.handleTacticalPauseInput()
            let running = loaded.runPresentation!
            try check(running.node.currentAction == .run && running.bear == (kit == "bear"), "\(kit): correct human or bear run body is visible")
            try check(running.node.currentPhase == CombatRunMotion.phase(distance: running.travelled, bear: running.bear), "\(kit): gait phase follows actual ground travel")
            let position = running.node.position, runPhase = running.node.currentPhase
            try await Task.sleep(for: .milliseconds(150))
            try check(loaded.runPresentation?.travelled == running.travelled && running.node.position == position && running.node.currentPhase == runPhase,
                      "\(kit): pause freezes travel and running feet together")
            if let image = view.texture(from: runScene)?.cgImage(), let data = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) {
                try data.write(to: output.appendingPathComponent("run-" + kit + ".png"))
            }
            try check(GameSession(saveStore: store).tacticalCombat?.budget.usesRunningGait == true, "\(kit): in-flight save retains the Dash gait for subsequent moves")
            runScene.handleTacticalPauseInput()
            runScene.handleInventoryInput()
            try await Task.sleep(for: .milliseconds(150))
            try check(loaded.runPresentation?.travelled == running.travelled, "\(kit): inventory also freezes running movement")
            runScene.handleInventoryInput()
            try await wait("\(kit) run recovery") { !loaded.busy }
            try check(loaded.runPresentation == nil && running.node.parent == nil, "\(kit): run proxy is removed after stopping")
            try check(loaded.combat.current.position == endpoint, "\(kit): running reaches the certified endpoint")
            let cost = CombatNavigation.length(runPath, from: origin)
            let remaining = loaded.combat.budget.availableMovement(speed: speed)
            try check(abs(remaining - (beforeRun.budget.availableMovement(speed: speed) - cost)) < 0.001,
                      "\(kit): faster playback spends the same route distance")
            try check(loaded.combat.budget.usesRunningGait, "\(kit): later moves in this turn retain the running gait")
        }
        // A distant melee opponent must spend its ordinary move, activate Dash,
        // then play the queued second route. Exercise the actual AI entry point.
        let currentScene = view.scene as! CityDistrictScene
        var player = initial.actors.first(where: \.player)!
        var enemy = initial.actors.first { !$0.player }!
        player.hp = 100; player.maximumHP = 100; player.initiativeBonus = 100
        enemy.hp = 100; enemy.maximumHP = 100; enemy.initiativeBonus = -100
        enemy.rangedWeapon = nil; enemy.enemyRole = .bruiser
        let bystanders = initial.actors.filter { !$0.player && $0.id != enemy.id }.map { actor in
            var defeated = actor; defeated.hp = 0; return defeated
        }
        func dashFixture() -> CGPoint? {
            let map = currentScene.navigation
            let originalStamps = Array(map.occupancy.actors.values)
            defer {
                for stamp in originalStamps { map.occupancy.register(stamp) }
                map.occupancy.restampAll()
            }
            // Keep every crew ID in the save. Omitting one leaves its scene
            // actor alive and stamped, making the loaded fixture a different map.
            for actor in bystanders { map.unregisterActor(id: actor.id) }
            map.registerActor(id: player.id, kind: .player, at: player.position)
            // A certified approach alone is insufficient: the enemy policy must
            // actually choose Dash after spending its ordinary movement.
            for step in 0..<32 {
                let a = Double(step) * .pi / 16
                guard let p = map.nearestWalkablePoint(to: CGPoint(x: player.position.x + cos(a) * 720,
                                                                   y: player.position.y + sin(a) * 540)),
                      CombatNavigation.distance(player.position, p) > 600 else { continue }
                var candidate = enemy; candidate.position = p
                map.registerActor(id: enemy.id, kind: .npc, at: p)
                var probe = TacticalCombat(encounterID: initial.encounterID, areaID: initial.areaID,
                                           actors: [player, candidate] + bystanders, seed: 42)
                _ = probe.endTurn()
                planning: for _ in 0..<4 {
                    switch EnemyTactics.choose(combat: probe, map: map).action {
                    case .dash: return p
                    case .move(let path):
                        guard probe.move(along: path) else { break planning }
                        map.updateActor(id: enemy.id, position: probe.current.position, isMoving: false)
                    default: break planning
                    }
                }
            }
            return nil
        }
        guard let distant = dashFixture() else { throw TacticalCombatQA.Failure(message: "No distant Dash AI fixture") }
        enemy.position = distant
        let enemyModel = TacticalCombat(encounterID: initial.encounterID, areaID: initial.areaID, actors: [player, enemy] + bystanders, seed: 42)
        store.save(SaveSnapshot(tacticalCombat: try JSONEncoder().encode(enemyModel), hasSeenOpening: true,
            hasCompletedOfficeCaseIntro: true, hasSeededStarterKit: true, hasReceivedArmorKit: true,
            hasReceivedElvenCourtBow: true, hasReceivedElvenCourtArrow: true))
        let enemyContext = GameContext(saveStore: store); enemyContext.router.start(in: view)
        try await wait { (view.scene as? CityDistrictScene)?.context === enemyContext && (view.scene as? CityDistrictScene)?.combatDirector?.busy == false }
        let enemyScene = view.scene as! CityDistrictScene, enemyDirector = enemyScene.combatDirector!
        enemyDirector.command(2)
        var trace: [String] = []
        try await wait("enemy AI selects Dash") {
            let model = enemyDirector.combat
            let line = "\(model.current.id) \(model.current.position) \(model.budget) busy=\(enemyDirector.busy) feedback=\(enemyDirector.targetingFeedback)"
            if trace.last != line { trace.append(line) }
            return enemyDirector.dashPresentation != nil || model.round > 1
        }
        try JSONEncoder().encode(trace).write(to: output.appendingPathComponent("enemy-playback.json"))
        try check(enemyDirector.dashPresentation != nil, "Enemy selects Dash before ending its turn (details in enemy-playback.json)")
        let enemyDash = enemyDirector.dashPresentation!
        let start = enemyDirector.combat.current.position
        try check(enemyDash.actorID == enemy.id && enemyDash.path?.isPresent == true, "Enemy AI plays Dash with its planned route queued")
        try check(!enemyDirector.isWalking(enemy.id), "Enemy holds position during Dash preparation")
        try await wait("enemy wind burst") { (enemyDirector.dashPresentation?.elapsed ?? 0) >= 0.4 }
        try check(enemyDirector.combat.current.position == start && !enemyDirector.isWalking(enemy.id), "Enemy wind burst precedes navigation movement")
        try await wait("enemy recovery") { enemyDirector.dashPresentation == nil }
        try check(enemyDirector.isWalking(enemy.id) && !enemyDirector.combat.canDash, "Enemy starts the queued move only after recovery")
        try check(enemyDirector.runPresentation?.actorID == enemy.id, "Enemy queued Dash movement uses the running gait")
        try await wait("enemy turn completes") { enemyDirector.combat.isPlayerTurn && !enemyDirector.busy }
        try check(enemyDirector.combat.round == 2, "Enemy Dash completes its turn without an action loop")
        return checks
    }
}
#endif
