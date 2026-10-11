#if DEBUG
import AppKit
import SpriteKit

@MainActor enum CombatApproachQA {
    static func run(in view: SKView, output: URL, initial: TacticalCombat) async throws -> [String] {
        if ProcessInfo.processInfo.environment["RAINSHADOW_QA_ELEVATION"] == "1" {
            return try await CombatElevationQA.run(in: view, output: output, initial: initial)
        }
        if ProcessInfo.processInfo.environment["RAINSHADOW_QA_OPPORTUNITY"] == "1" {
            return try await opportunity(in: view, output: output, initial: initial)
        }
        if ProcessInfo.processInfo.environment["RAINSHADOW_QA_DASH_ANIMATION"] == "1" {
            return try await DashAnimationQA.run(in: view, output: output, initial: initial)
        }
        if ProcessInfo.processInfo.environment["RAINSHADOW_QA_MELEE_PACING"] == "1" {
            return try await MeleePacingQA.run(in: view, output: output, initial: initial)
        }
        if ProcessInfo.processInfo.environment["RAINSHADOW_QA_ENEMY_TACTICS"] == "1" {
            return try await EnemyTacticsQA.run(in: view, output: output, initial: initial)
        }
        if let snapshot = ProcessInfo.processInfo.environment["RAINSHADOW_QA_MOVEMENT_REPAIR_SNAPSHOT"] {
            return try await CombatMovementRepairQA.run(in: view, output: output, snapshot: URL(fileURLWithPath: snapshot))
        }
        var checks: [String] = []
        func check(_ value: Bool, _ message: String) throws {
            guard value else { throw TacticalCombatQA.Failure(message: message) }; checks.append(message)
        }
        func wait(_ condition: () -> Bool) async throws {
            let deadline = ProcessInfo.processInfo.systemUptime + 40
            while !condition() {
                if ProcessInfo.processInfo.systemUptime > deadline { throw TacticalCombatQA.Failure(message: "Approach timeout") }
                try await Task.sleep(for: .milliseconds(20))
            }
        }
        func capture(_ node: SKNode, _ name: String) throws {
            guard let texture = view.texture(from: node), let data = NSBitmapImageRep(cgImage: texture.cgImage()).representation(using: .png, properties: [:]) else {
                throw TacticalCombatQA.Failure(message: "Approach capture failed")
            }
            try data.write(to: output.appendingPathComponent(name + ".png"))
        }
        let store = SaveStore(key: "RainShadow.QA.Approach.\(UUID().uuidString)")
        defer { store.reset() }
        func open() async throws -> CityDistrictScene {
            store.save(SaveSnapshot(tacticalCombat: try JSONEncoder().encode(initial), hasReceivedFireArrows: true, hasSeenOpening: true,
                hasCompletedOfficeCaseIntro: true, carriedItems: [.init(id: CombatAmmunition.fireItemID, quantity: 2)],
                equippedItems: ["weapon1": .init(id: "lantern-shortsword", quantity: 1), "weapon2": .init(id: "elven-court-bow", quantity: 1)], hasSeededStarterKit: true,
                hasReceivedArmorKit: true, hasReceivedElvenCourtBow: true, hasReceivedElvenCourtArrow: true,
                caseFlags: ["combat.a1.gate.trigger"]))
            let context = GameContext(saveStore: store); context.router.start(in: view)
            try await wait { (view.scene as? CityDistrictScene)?.context === context && (view.scene as? CityDistrictScene)?.combatDirector?.busy == false }
            return view.scene as! CityDistrictScene
        }
        var scene = try await open()
        var director = scene.combatDirector!
        let target = director.combat.actors.first { !$0.player && CombatNavigation.distance($0.position, director.combat.current.position) > TacticalCombat.meleeReach }!
        func point(_ scene: CityDistrictScene) -> CGPoint {
            scene.convert(CGPoint(x: target.position.x, y: target.position.y + 45), from: scene.depthWorldRoot)
        }
        director.command(17)
        let before = director.combat
        let start = ProcessInfo.processInfo.systemUptime
        director.hover(at: point(scene))
        let elapsed = ProcessInfo.processInfo.systemUptime - start
        try check(director.targetPanel.text.contains("Movement:"), "Melee hover offers an approach")
        try check(director.targetPanel.text.contains("%"), "Approach previews the arrival hit chance")
        try check(!director.movementPreview.isHidden, "Approach route and stopping ring are visible")
        try check(director.combat == before, "Approach hover spends nothing")
        let endpoint = director.movementPreview.geometry.endpoint!
        try capture(scene, "approach-preview")
        director.pointer(at: point(scene))
        try check(director.busy && director.combat.current.position != before.current.position, "One click begins the walk")
        try check(director.combat.budget.canAttack && director.combat.randomState == before.randomState, "Walking preserves the action and attack roll until arrival")
        try await wait { !director.combat.budget.canAttack }
        try check(CombatNavigation.distance(director.combat.current.position, endpoint) < 2, "Attack occurs at the previewed stopping position")
        try await wait { !director.busy }
        try capture(scene, "approach-attack-complete")
        try check(director.combat.randomState != before.randomState, "Arrival resolves the attack")
        checks.append(String(format: "Native approach planning: %.1f ms", elapsed * 1000))
        scene = try await open(); director = scene.combatDirector!
        director.command(6)
        director.hover(at: point(scene))
        try check(director.targetPanel.text.contains("Power Strike") && director.targetPanel.text.contains("Movement:"), "Selected sword technique survives approach planning")
        director.pointer(at: point(scene))
        director.cancelTargeting()
        try await wait { !director.busy }
        try check(director.combat.budget.canAttack && !(director.combat.current.usedManeuvers ?? []).contains(.powerStrike), "Escape during approach cancels the follow-up without spending the attack")
        scene = try await open(); director = scene.combatDirector!
        director.command(6)
        director.pointer(at: point(scene))
        try await wait { !director.combat.budget.canAttack }
        try check((director.combat.current.usedManeuvers ?? []).contains(.powerStrike), "Arrival performs the selected Power Strike rather than a normal attack")
        try await wait { !director.busy }
        try capture(scene, "approach-power-strike-complete")
        return checks
    }
    static func opportunity(in view: SKView, output: URL, initial: TacticalCombat) async throws -> [String] {
        var checks: [String] = []
        func check(_ value: Bool, _ message: String) throws {
            guard value else { throw TacticalCombatQA.Failure(message: message) }; checks.append(message)
        }
        func wait(_ condition: () -> Bool) async throws {
            let deadline = ProcessInfo.processInfo.systemUptime + 45
            while !condition() {
                if ProcessInfo.processInfo.systemUptime > deadline { throw TacticalCombatQA.Failure(message: "Opportunity timeout after " + (checks.last ?? "start")) }
                try await Task.sleep(for: .milliseconds(20))
            }
        }
        func capture(_ scene: SKScene, _ name: String) throws {
            guard let texture = view.texture(from: scene), let data = NSBitmapImageRep(cgImage: texture.cgImage()).representation(using: .png, properties: [:]) else {
                throw TacticalCombatQA.Failure(message: "Opportunity capture failed")
            }
            try data.write(to: output.appendingPathComponent(name + ".png"))
        }
        let store = SaveStore(key: "RainShadow.QA.Opportunity.\(UUID().uuidString)")
        defer { store.reset() }
        let map = (view.scene as! CityDistrictScene).navigation
        let occupants = Array(map.occupancy.actors.values)
        occupants.forEach { map.unregisterActor(id: $0.id) }
        var player = initial.actors.first(where: \.player)!
        var enemy = initial.actors.first { !$0.player }!
        player.hp = 100; player.maximumHP = 100; player.initiativeBonus = 100
        enemy.id = "wharf-ladder.crew.0"; enemy.rangedWeapon = nil; enemy.rangedReadied = false
        enemy.hp = 100; enemy.maximumHP = 100; enemy.initiativeBonus = -100
        enemy.enemyRole = .bruiser; enemy.damageMin = 2; enemy.damageMax = 2; enemy.attackBonus = 100
        var endpoint: CGPoint?
        for i in 0..<32 {
            let angle = Double(i) * .pi / 16
            enemy.position = CGPoint(x: player.position.x + cos(angle) * 96, y: player.position.y + sin(angle) * 72).rounded
            let end = CGPoint(x: player.position.x - cos(angle) * 150, y: player.position.y - sin(angle) * 112.5).rounded
            map.updateActor(id: player.id, position: player.position, isMoving: false)
            map.updateActor(id: enemy.id, position: enemy.position, isMoving: false)
            guard [player, enemy].allSatisfy({ actor in
                map.occupancy.withStampLifted(id: actor.id) {
                    map.searchMap.blockedInRadiusTile(at: actor.position, size: map.circleSize).contains(.passable)
                }
            }), let route = CombatNavigation.route(in: map, actor: player, to: end),
                  CombatNavigation.length(route, from: player.position) < 200 else { continue }
            let sample = TacticalCombat(encounterID: initial.encounterID, areaID: initial.areaID, actors: [player, enemy], seed: 42)
            if !sample.opportunityExits(along: route, clearLine: { a, b in
                CombatNavigation.clearLine(in: map, from: a.position, to: b.position, excluding: [a.id, b.id])
            }).isEmpty { endpoint = route.destination; break }
        }
        Array(map.occupancy.actors.keys).forEach { map.unregisterActor(id: $0) }
        occupants.forEach { map.occupancy.register($0) }; map.occupancy.restampAll()
        guard let endpoint else { throw TacticalCombatQA.Failure(message: "No certified opportunity fixture") }
        let initialModel = TacticalCombat(encounterID: initial.encounterID, areaID: initial.areaID, actors: [player, enemy], seed: 42)
        for safe in [false, true] {
            store.save(SaveSnapshot(tacticalCombat: try JSONEncoder().encode(initialModel), hasReceivedFireArrows: true, hasSeenOpening: true,
                hasCompletedOfficeCaseIntro: true,
                equippedItems: ["weapon1": .init(id: "lantern-shortsword", quantity: 1), "weapon2": .init(id: "elven-court-bow", quantity: 1)], hasSeededStarterKit: true,
                hasReceivedArmorKit: true, hasReceivedElvenCourtBow: true, hasReceivedElvenCourtArrow: true,
                caseFlags: ["combat.a1.gate.trigger"]))
            let context = GameContext(saveStore: store); context.router.start(in: view)
            try await wait { (view.scene as? CityDistrictScene)?.context === context && (view.scene as? CityDistrictScene)?.combatDirector?.busy == false }
            let scene = view.scene as! CityDistrictScene, director = scene.combatDirector!
            try check(director.visibleCombatCommands.contains("combat.disengage"), "Disengage is on the parchment action bar")
            if safe {
                let accepted = director.shortcut("z")
                try check(accepted && director.combat.current.disengaged == true && !director.combat.budget.canAttack,
                          "Disengage shortcut spends one Action and applies the condition")
            }
            scene.followCamera(); scene.gameCamera.position = player.position
            let screen = scene.convert(endpoint, from: scene.depthWorldRoot)
            director.hover(at: screen)
            try check(!director.movementPreview.isHidden, "Certified retreat is previewed in the live scene")
            try check(director.movementPreview.opportunityCount == (safe ? 0 : 1), safe ? "Disengage removes the opportunity warning" : "Retreat preview warns about one Opportunity Attack")
            try capture(scene, safe ? "disengage-preview" : "opportunity-preview")
            let before = director.combat
            director.pointer(at: screen)
            try check(director.busy, "Click starts the accepted retreat")
            if !safe {
                try await wait { director.meleeAttack?.result.opportunityAttack == true }
                let attack = director.meleeAttack!
                try check(attack.attacker.id == enemy.id && attack.target.id == player.id && director.combat.current.player,
                          "Enemy swings out of turn while Voss retains his turn")
                try check(director.presentedCombat == attack.before && director.combat.actors.first { $0.id == enemy.id }?.reactionSpent == true,
                          "Reaction is spent immediately; damage stays hidden until impact")
                try check(CombatNavigation.distance(scene.detective.position, enemy.position) <= TacticalCombat.meleeReach,
                          "Movement pauses inside enemy reach for the swing")
                try check(GameSession(saveStore: store).tacticalCombat == director.combat,
                          "Mid-reaction checkpoint contains the accepted result without a replayable roll")
                scene.handleTacticalPauseInput()
                let elapsed = attack.elapsed, point = scene.detective.position
                try await Task.sleep(for: .milliseconds(220))
                try check(attack.elapsed == elapsed && scene.detective.position == point, "Pause freezes reaction animation and queued movement")
                try capture(scene, "opportunity-swing")
                scene.handleTacticalPauseInput()
            }
            try await wait { !director.busy }
            try check(CombatNavigation.distance(director.combat.current.position, endpoint) < 3,
                      "Retreat resumes to the selected destination after any reaction")
            try check(director.combat.current.player && director.combat.budget.canAttack == !safe,
                      "Retreat preserves the player's turn and expected Action budget")
            if safe { try check(director.combat.current.hp == before.current.hp && director.combat.actors.first { $0.id == enemy.id }!.hasReaction,
                               "Disengage prevents damage and does not consume the enemy's Reaction") }
            try capture(scene, safe ? "disengage-complete" : "opportunity-complete")
        }
        return checks
    }
}
#endif
