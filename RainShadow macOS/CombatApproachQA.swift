#if DEBUG
import AppKit
import SpriteKit

@MainActor enum CombatApproachQA {
    static func run(in view: SKView, output: URL, initial: TacticalCombat) async throws -> [String] {
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
        try check(director.targetPanel.text.contains("Approach:"), "Melee hover offers an approach")
        try check(director.targetPanel.text.contains("% hit"), "Approach previews the arrival hit chance")
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
        try check(director.targetPanel.text.contains("Power strike") && director.targetPanel.text.contains("Approach:"), "Selected sword technique survives approach planning")
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
}
#endif
