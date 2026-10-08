#if DEBUG
import AppKit
import SpriteKit

@MainActor enum CombatEscapeQA {
    static func run(in view: SKView, output: URL, initial: TacticalCombat) async throws -> [String] {
        var checks: [String] = []
        func check(_ value: Bool, _ text: String) throws {
            guard value else { throw TacticalCombatQA.Failure(message: text) }; checks.append(text)
        }
        func wait(_ predicate: () -> Bool) async throws {
            let deadline = ProcessInfo.processInfo.systemUptime + 40
            while !predicate() {
                if ProcessInfo.processInfo.systemUptime > deadline { throw TacticalCombatQA.Failure(message: "Escape timeout after " + (checks.last ?? "start")) }
                try await Task.sleep(for: .milliseconds(20))
            }
        }
        func capture(_ name: String) throws {
            guard let scene = view.scene, let texture = view.texture(from: scene),
                let data = NSBitmapImageRep(cgImage: texture.cgImage()).representation(using: .png, properties: [:]) else { return }
            try data.write(to: output.appendingPathComponent(name + ".png"))
        }
        let store = SaveStore(key: "RainShadow.QA.Escape.\(UUID().uuidString)")
        defer { store.reset() }
        var scene = view.scene as! CityDistrictScene
        var player = initial.actors.first(where: \.player)!
        var enemy = initial.actors.first { !$0.player && $0.rangedWeapon == nil }!
        player.hp = 6; player.initiativeBonus = 100; player.conditions = nil
        enemy.hp = 100; enemy.maximumHP = 100; enemy.initiativeBonus = -100; enemy.rangedWeapon = nil
        let excluded = Array(scene.navigation.occupancy.actors.keys)
        let near = (0..<32).compactMap { step -> CGPoint? in
            let angle = Double(step) * .pi / 16
            let p = CGPoint(x: player.position.x + cos(angle) * 82, y: player.position.y + sin(angle) * 82 * 0.75)
            guard let point = scene.navigation.nearestWalkablePoint(to: p),
                  (60...100).contains(CombatNavigation.distance(player.position, point)),
                  CombatNavigation.clearLine(in: scene.navigation, from: player.position, to: point, excluding: excluded) else { return nil }
            return point
        }
        guard let close = near.first else { throw TacticalCombatQA.Failure(message: "No melee fixture") }
        enemy.position = close
        let fixture = TacticalCombat(encounterID: initial.encounterID, areaID: initial.areaID, actors: [player, enemy], seed: 42)
        func open(_ model: TacticalCombat) async throws -> TacticalCombatDirector {
            store.save(SaveSnapshot(tacticalCombat: try JSONEncoder().encode(model), hasSeenOpening: true,
                hasCompletedOfficeCaseIntro: true, equippedItems: ["weapon1": .init(id: "lantern-shortsword", quantity: 1)],
                hasSeededStarterKit: true, hasReceivedArmorKit: true, hasReceivedElvenCourtBow: true, hasReceivedElvenCourtArrow: true,
                caseFlags: ["combat.a1.gate.trigger"]))
            let context = GameContext(saveStore: store); context.router.start(in: view)
            try await wait { (view.scene as? CityDistrictScene)?.context === context && (view.scene as? CityDistrictScene)?.combatDirector != nil }
            scene = view.scene as! CityDistrictScene
            let director = scene.combatDirector!
            try await wait { !director.busy }
            return director
        }
        func press(_ name: String, director: TacticalCombatDirector) throws {
            guard let button = scene.hudRoot.childNode(withName: "//" + name), let parent = button.parent else {
                throw TacticalCombatQA.Failure(message: "Missing " + name)
            }
            director.pointer(at: scene.convert(button.position, from: parent))
        }
        var director = try await open(fixture)
        try check(director.visibleCombatCommands.first == "combat.melee" && director.visibleCombatCommands.contains("combat.flee")
                  && !director.visibleCombatCommands.contains("combat.yield"), "Action bar exposes Melee Attack and replaces Yield with Flee Combat")
        let before = director.combat
        try press("combat.flee", director: director)
        try check(director.combat == before && director.targetingFeedback.contains("60 ft"), "Nearby enemies block escape without changing health, actions or random state")
        try press("combat.melee", director: director)
        try check(director.selectingMelee, "Pointer selects the explicit Melee Attack button")
        director.hover(at: scene.convert(CGPoint(x: close.x, y: close.y + 60), from: scene.depthWorldRoot))
        try check(director.targetingFeedback.contains("click to strike"), "Melee hover reports an available target")
        try capture("melee-targeting")
        scene.handleInventoryInput()
        try check(!director.selectingMelee, "Opening inventory clears melee targeting")
        scene.handleInventoryInput()
        try press("combat.melee", director: director)
        director.pointer(at: scene.convert(CGPoint(x: close.x, y: close.y + 60), from: scene.depthWorldRoot))
        try check(director.meleeAttack != nil && !director.combat.budget.canAttack && !director.selectingMelee,
                  "Melee button uses the existing sword animation and spends one action")
        try await wait { director.meleeAttack?.impactPresented == true }
        try capture("melee-impact")
        try await wait { !director.busy }
        director = try await open(fixture)
        // Find a real retreat route, checking the same raster and action allowance as play.
        var retreat: Path?
        for radius in [460.0, 440, 420] {
            for step in 0..<64 {
                let angle = Double(step) * .pi / 32
                let p = CGPoint(x: player.position.x + cos(angle) * radius, y: player.position.y + sin(angle) * radius * 0.75)
                guard let path = CombatNavigation.route(in: scene.navigation, actor: director.combat.current, to: p),
                      let end = path.destination,
                      CombatNavigation.length(path, from: player.position) <= 480,
                      CombatNavigation.distance(end, close) >= TacticalCombat.fleeDistance else { continue }
                retreat = path; break
            }
            if retreat != nil { break }
        }
        guard let retreat, let end = retreat.destination else { throw TacticalCombatQA.Failure(message: "No escape route on shipped map") }
        // Place the rival at the retreat endpoint to verify rejected melee targeting.
        var farEnemy = enemy; farEnemy.position = end
        director = try await open(TacticalCombat(encounterID: initial.encounterID, areaID: initial.areaID, actors: [player, farEnemy], seed: 42))
        try press("combat.melee", director: director)
        let unchanged = director.combat
        scene.gameCamera.position = scene.clampedCameraPosition(following: end, in: scene.cameraClampBounds)
        director.pointer(at: scene.convert(CGPoint(x: end.x, y: end.y + 60), from: scene.depthWorldRoot))
        try check(director.combat == unchanged && director.targetingFeedback.contains("Out of melee reach"), "Out-of-reach melee target spends nothing and explains how to approach")
        director.cancelTargeting()
        try check(!director.selectingMelee, "Cancel restores movement mode")
        director = try await open(fixture)
        scene.gameCamera.position = scene.clampedCameraPosition(following: end, in: scene.cameraClampBounds)
        director.pointer(at: scene.convert(end, from: scene.depthWorldRoot))
        try await wait { !director.busy }
        try check(director.combat.fleeUnavailableReason == nil && director.combat.current.position == end,
                  "Walking a certified retreat route enables escape")
        try capture("flee-ready")
        scene.handleTacticalPauseInput()
        try press("combat.flee", director: director)
        try check(director.combat.outcome == nil, "Pause blocks Flee Combat")
        scene.handleTacticalPauseInput()
        try press("combat.flee", director: director)
        try check(director.combat.outcome == .fled && director.combat.current.hp == 6, "Escape keeps remaining human health")
        try await wait { scene.combatDirector == nil }
        try check(!scene.dialoguePresenter.isPresenting && !scene.dialogueIsActive && !scene.detective.isHidden,
                  "Escape returns directly to exploration without defeat dialogue")
        let session = scene.context.session
        try check(session.tacticalCombat == nil && session.currentHealth == 6 && !session.caseState.hasFlag("combat.a1.gate.done"),
                  "Escape clears combat while leaving story unresolved")
        let restored = GameSession(saveStore: store)
        try check(restored.currentHealth == 6 && restored.tacticalCombat == nil && !WharfLadderStory.requested(.gate, in: restored.caseState),
                  "Reload preserves escape health without replaying combat")
        try check(scene.navigation.occupancy.actors.count == 1, "Escape removes crew occupancy")
        try capture("escaped")
        return checks
    }
}
#endif
