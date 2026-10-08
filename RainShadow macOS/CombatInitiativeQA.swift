#if DEBUG
import AppKit
import SpriteKit

@MainActor enum CombatInitiativeQA {
    static func run(in view: SKView, output: URL) throws -> [String] {
        var checks: [String] = []
        func check(_ condition: Bool, _ message: String) throws {
            guard condition else { throw TacticalCombatQA.Failure(message: message) }
            checks.append(message)
        }
        let scene = view.scene as! CityDistrictScene
        let director = scene.combatDirector!
        let presented = director.presentedCombat
        try check(director.initiativeBar.entries.map(\.id) == presented.actors.filter(\.conscious).map(\.id),
                  "Live initiative portraits follow the core's conscious actor order")
        try check(director.initiativeBar.activeID == presented.current.id,
                  "Live active portrait matches the presented turn")
        let before = director.combat
        director.pointer(at: scene.convert(.zero, from: director.initiativeBar))
        try check(director.combat == before && !director.busy,
                  "Clicking the initiative strip cannot issue movement or attacks")

        let bar = CombatInitiativeBar()
        var player = presented.actors.first(where: \.player)!
        player.hp = 12; player.maximumHP = 12; player.initiativeBonus = 100
        var actors = [player]
        for index in 0..<8 {
            actors.append(Combatant(id: "initiative.enemy.\(index)", name: "Hand \(index + 1)", player: false,
                position: CGPoint(x: 400 + index * 50, y: 400), hp: 10, maximumHP: 10,
                defence: 10, attackBonus: 0, damageMin: 1, damageMax: 1, initiativeBonus: index))
        }
        var model = TacticalCombat(encounterID: "gate", areaID: presented.areaID, actors: actors, seed: 42)
        bar.update(combat: model, paused: false)
        try check(bar.entries.count == 9 && bar.entries.first?.allied == true
                  && bar.entries.dropFirst().allSatisfy { !$0.allied }, "Team colours distinguish the player and enemies")
        try check(bar.entries.map(\.initiative) == model.actors.map(\.initiative),
                  "Portrait initiative badges use the actual rolled values")
        _ = model.endTurn(); bar.update(combat: model, paused: false)
        try check(bar.entries.first?.acted == true && bar.entries.filter(\.active).map(\.id) == [model.current.id],
                  "Turn advance dims completed turns and moves exactly one active marker")
        for _ in 0..<8 { _ = model.endTurn() }
        bar.update(combat: model, paused: true)
        try check(model.round == 2 && !bar.entries.contains(where: \.acted),
                  "The next round restores all portrait brightness")
        let caption = bar.childNode(withName: "combat.initiative.caption") as! SKLabelNode
        try check(caption.text?.contains("PAUSED") == true && caption.text?.contains("ROUND 2") == true,
                  "Round and pause information remain visible")
        _ = model.transformToBear(hasClearance: true); bar.update(combat: model, paused: false)
        try check(bar.entries.first?.portrait == "bear_portrait_guardian" && bar.entries.first?.health == 8
                  && bar.entries.first?.maximumHealth == 8, "Bear transformation changes the initiative portrait and health pool")
        let restored = try JSONDecoder().decode(TacticalCombat.self, from: JSONEncoder().encode(model))
        let originalEntries = bar.entries
        bar.update(combat: restored, paused: false)
        try check(bar.entries == originalEntries, "Save reload preserves initiative presentation")
        for width: CGFloat in [820, 320] {
            bar.layout(width: width)
            try check(bar.calculateAccumulatedFrame().width <= width + 1,
                      "Nine portraits fit within a \(Int(width))-point strip")
            if let texture = view.texture(from: bar),
               let data = NSBitmapImageRep(cgImage: texture.cgImage()).representation(using: .png, properties: [:]) {
                try data.write(to: output.appendingPathComponent("initiative-\(Int(width)).png"))
            }
        }
        for _ in 0..<9 { _ = model.endTurn() }
        _ = model.revertBear(); bar.update(combat: model, paused: false)
        try check(bar.entries.first?.portrait == "dialogue_portrait_harlan_voss_v01" && bar.entries.first?.health == 12,
                  "Reverting restores the human initiative portrait and health")
        actors[1].hp = 0; actors[2].burningTurns = 2
        let defeated = TacticalCombat(encounterID: "gate", areaID: presented.areaID, actors: actors, seed: 42)
        bar.update(combat: defeated, paused: false)
        try check(!bar.entries.contains { $0.id == actors[1].id } && bar.entries.count == 8,
                  "Defeated combatants leave the initiative strip")
        try check(bar.entries.first { $0.id == actors[2].id }?.status == "Burning",
                  "Portrait conditions come from current combat state")
        return checks
    }
}
#endif
