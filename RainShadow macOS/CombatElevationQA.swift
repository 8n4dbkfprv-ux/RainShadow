#if DEBUG
import AppKit
import SpriteKit

@MainActor enum CombatElevationQA {
    static func run(in view: SKView, output: URL, initial: TacticalCombat) async throws -> [String] {
        var checks: [String] = []
        func check(_ result: Bool, _ message: String) throws {
            guard result else { throw TacticalCombatQA.Failure(message: message) }; checks.append(message)
        }
        func wait(_ predicate: () -> Bool) async throws {
            let deadline = ProcessInfo.processInfo.systemUptime + 35
            while !predicate() {
                guard ProcessInfo.processInfo.systemUptime < deadline else { throw TacticalCombatQA.Failure(message: "Elevation timeout after " + (checks.last ?? "start")) }
                try await Task.sleep(for: .milliseconds(20))
            }
        }
        func capture(_ scene: SKScene, _ name: String) throws {
            guard let texture = view.texture(from: scene), let data = NSBitmapImageRep(cgImage: texture.cgImage()).representation(using: .png, properties: [:]) else {
                throw TacticalCombatQA.Failure(message: "Elevation capture failed")
            }
            try data.write(to: output.appendingPathComponent(name + ".png"))
        }
        let area = try AreaCatalogLoader.load(WharfLadderStory.exterior)
        let ladder = area.ladders.first!
        let high = ladder.top.cgPoint.rounded
        var player = initial.actors.first(where: \.player)!, enemy = initial.actors.first { !$0.player }!
        player.position = ladder.bottom.cgPoint.rounded
        player.hp = 100; player.maximumHP = 100; player.initiativeBonus = 100
        enemy.id = "wharf-ladder.crew.0"; enemy.position = CGPoint(x: 1933, y: 1896)
        enemy.hp = 100; enemy.maximumHP = 100; enemy.initiativeBonus = -100
        let model = TacticalCombat(encounterID: initial.encounterID, areaID: initial.areaID, actors: [player, enemy], seed: 42)
        let store = SaveStore(key: "RainShadow.QA.Elevation.\(UUID().uuidString)"); defer { store.reset() }
        store.save(SaveSnapshot(tacticalCombat: try JSONEncoder().encode(model), hasReceivedFireArrows: true, hasSeenOpening: true,
            hasCompletedOfficeCaseIntro: true,
            equippedItems: ["weapon1": .init(id: "lantern-shortsword", quantity: 1), "weapon2": .init(id: "elven-court-bow", quantity: 1)], hasSeededStarterKit: true,
            hasReceivedArmorKit: true, hasReceivedElvenCourtBow: true, hasReceivedElvenCourtArrow: true,
            caseFlags: ["combat.a1.gate.trigger"]))
        let context = GameContext(saveStore: store); context.router.start(in: view)
        try await wait { (view.scene as? CityDistrictScene)?.context === context && (view.scene as? CityDistrictScene)?.combatDirector?.busy == false }
        let scene = view.scene as! CityDistrictScene, director = scene.combatDirector!
        scene.setZoomStep(20)
        scene.recenterCamera(on: CGPoint(x: 2050, y: 2100))
        scene.gameCamera.position = CGPoint(x: 2050, y: 2100)
        try await Task.sleep(for: .milliseconds(150))
        try check(scene.floorEffectRoot.childNode(withName: "wharf.loading.platform") == nil, "Detached loading platform has been removed")
        func screen(_ p: CGPoint) -> CGPoint { scene.convert(p, from: scene.depthWorldRoot) }
        director.cancelTargeting()
        director.hover(at: screen(ladder.bottom.cgPoint))
        try capture(scene, "stairs-route")
        let before = director.combat
        director.pointer(at: screen(ladder.bottom.cgPoint))
        try check(director.busy, "Clicking the ladder starts a climb")
        try await Task.sleep(for: .milliseconds(1600))
        try capture(scene, "ladder-climb")
        let climber = scene.depthWorldRoot.childNode(withName: "ladder.climbing.actor")!
        scene.handleTacticalPauseInput()
        let frozen = climber.position
        try await Task.sleep(for: .milliseconds(350))
        try check(climber.position == frozen, "Tactical pause freezes the ladder cycle and movement")
        scene.handleTacticalPauseInput()
        try await wait { !director.busy }
        try check(CombatElevation.feet(at: director.combat.current.position, in: director.combat.areaID) > 18, "Arrival samples the eighteen-foot roof")
        try check(director.combat.budget.canAttack && director.combat.randomState == before.randomState, "Climbing spends movement and preserves the attack")
        try check(scene.detective.visualHeightOffset == 0, "Authored floor is not raised twice by the legacy height map")
        scene.setZoomStep(20)
        scene.recenterCamera(on: CGPoint(x: 2050, y: 2100))
        scene.gameCamera.position = CGPoint(x: 2050, y: 2100)
        try await Task.sleep(for: .milliseconds(150))
        director.command(5)
        let actualTarget = director.combat.actors.first { !$0.player }!
        director.hover(at: screen(CGPoint(x: actualTarget.position.x, y: actualTarget.position.y + 45)))
        try check(director.targetPanel.text.contains("High Ground +2"), "Ranged target tooltip explains the high-ground attack bonus: " + director.targetPanel.text)
        try check(director.targetPanel.text.contains("%"), "Elevated attack previews its hit chance")
        try capture(scene, "high-ground-targeting")
        director.pointer(at: screen(CGPoint(x: actualTarget.position.x, y: actualTarget.position.y + 45)))
        try await wait { director.rangedShot != nil }
        try capture(scene, "high-ground-shot")
        try await wait { !director.busy }
        try check(!director.combat.budget.canAttack && director.combat.randomState != before.randomState, "Elevated ranged attack resolves once and spends the Action")
        try capture(scene, "high-ground-complete")
        try check(director.combat.current.position == high, "Actor and combat save finish at the authored roof endpoint")
        director.command(2)
        try await wait { director.combat.isPlayerTurn && !director.busy }
        director.cancelTargeting()
        scene.recenterCamera(on: CGPoint(x: 2050, y: 2100)); scene.gameCamera.position = CGPoint(x: 2050, y: 2100)
        try await Task.sleep(for: .milliseconds(150))
        director.pointer(at: screen(ladder.top.cgPoint))
        try check(director.busy, "The same ladder can be climbed down")
        try await wait { !director.busy }
        try check(director.combat.current.position == ladder.bottom.cgPoint.rounded, "Descent returns to the landing")
        try capture(scene, "ladder-descent-complete")
        return checks
    }
}
#endif
