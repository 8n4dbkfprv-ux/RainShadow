#if DEBUG
import AppKit
import SpriteKit

@MainActor enum CombatMovementRepairQA {
    static func run(in view: SKView, output: URL, snapshot: URL) async throws -> [String] {
        var checks: [String] = []
        func check(_ value: Bool, _ message: String) throws {
            guard value else { throw TacticalCombatQA.Failure(message: message) }; checks.append(message)
        }
        func wait(_ condition: () -> Bool) async throws {
            let deadline = ProcessInfo.processInfo.systemUptime + 40
            while !condition() {
                if ProcessInfo.processInfo.systemUptime > deadline { throw TacticalCombatQA.Failure(message: "Movement repair timeout") }
                try await Task.sleep(for: .milliseconds(20))
            }
        }
        func capture(_ scene: SKScene, _ name: String) throws {
            guard let texture = view.texture(from: scene), let data = NSBitmapImageRep(cgImage: texture.cgImage()).representation(using: .png, properties: [:]) else {
                throw TacticalCombatQA.Failure(message: "Movement repair capture failed")
            }
            try data.write(to: output.appendingPathComponent(name + ".png"))
        }
        let stored = try JSONDecoder().decode(SaveSnapshot.self, from: Data(contentsOf: snapshot))
        let before = try JSONDecoder().decode(TacticalCombat.self, from: stored.tacticalCombat!)
        let store = SaveStore(key: "RainShadow.QA.MovementRepair.\(UUID().uuidString)")
        defer { store.reset() }
        store.save(stored)
        let context = GameContext(saveStore: store); context.router.start(in: view)
        try await wait { (view.scene as? CityDistrictScene)?.context === context && (view.scene as? CityDistrictScene)?.combatDirector?.busy == false }
        let scene = view.scene as! CityDistrictScene, director = scene.combatDirector!
        try check(director.combat.current.position == before.current.position, "Saved Voss position remains unchanged")
        try check(director.combat.randomState == before.randomState && director.combat.budget == before.budget,
            "Repair preserves dice and remaining actions")
        try check(director.combat.round == before.round && director.combat.actors.map(\.hp) == before.actors.map(\.hp),
            "Saved round and health remain unchanged")
        try check(director.combat.actors.contains { actor in before.actors.first { $0.id == actor.id }!.position != actor.position },
            "Crowded enemy is reseated on load")
        let goal = CGPoint(x: before.current.position.x - 160, y: before.current.position.y)
        let point = scene.convert(goal, from: scene.depthWorldRoot)
        director.hover(at: point)
        try check(!director.movementPreview.isHidden && director.movementPreview.canMove, "Previously blocked open street now previews a valid route")
        let endpoint = director.movementPreview.geometry.endpoint!
        try capture(scene, "repaired-route")
        director.pointer(at: point)
        try await wait { !director.busy }
        try check(CombatNavigation.distance(director.combat.current.position, endpoint) < 2, "Voss walks to the formerly unreachable street")
        try check(director.combat.budget.canAttack, "Moving away preserves the attack action")
        try capture(scene, "repaired-movement-complete")
        return checks
    }
}
#endif
