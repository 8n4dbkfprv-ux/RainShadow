#if DEBUG
import AppKit
import SpriteKit

@MainActor enum CombatTargetingQA {
    static func run(in view: SKView, output: URL, initial: TacticalCombat) async throws -> [String] {
        var checks: [String] = []
        func check(_ value: Bool, _ message: String) throws {
            guard value else { throw TacticalCombatQA.Failure(message: message) }; checks.append(message)
        }
        func capture(_ node: SKNode, _ name: String) throws {
            guard let texture = view.texture(from: node), let data = NSBitmapImageRep(cgImage: texture.cgImage()).representation(using: .png, properties: [:]) else {
                throw TacticalCombatQA.Failure(message: "Targeting capture failed")
            }
            try data.write(to: output.appendingPathComponent(name + ".png"))
        }
        let store = SaveStore(key: "RainShadow.QA.Targeting.\(UUID().uuidString)")
        defer { store.reset() }
        store.save(SaveSnapshot(tacticalCombat: try JSONEncoder().encode(initial), hasReceivedFireArrows: true, hasSeenOpening: true,
            hasCompletedOfficeCaseIntro: true, carriedItems: [.init(id: CombatAmmunition.fireItemID, quantity: 2)],
            equippedItems: ["weapon1": .init(id: "lantern-shortsword", quantity: 1), "weapon2": .init(id: "elven-court-bow", quantity: 1)], hasSeededStarterKit: true,
            hasReceivedArmorKit: true, hasReceivedElvenCourtBow: true, hasReceivedElvenCourtArrow: true,
            caseFlags: ["combat.a1.gate.trigger"]))
        let context = GameContext(saveStore: store); context.router.start(in: view)
        let deadline = ProcessInfo.processInfo.systemUptime + 35
        while (view.scene as? CityDistrictScene)?.context !== context || (view.scene as? CityDistrictScene)?.combatDirector?.busy != false {
            if ProcessInfo.processInfo.systemUptime > deadline { throw TacticalCombatQA.Failure(message: "Targeting scene timeout") }
            try await Task.sleep(for: .milliseconds(20))
        }
        let scene = view.scene as! CityDistrictScene
        let director = scene.combatDirector!
        let baseline = director.combat
        let target = initial.actors.first { !$0.player && $0.conscious }!
        let location = scene.convert(CGPoint(x: target.position.x, y: target.position.y + 45), from: scene.depthWorldRoot)
        director.hover(at: location)
        try check(!director.targetPanel.isHidden, "Hover opens target forecast")
        try check(director.targetPanel.text.contains("standard action"), "Forecast shows action cost")
        try check(director.targetPanel.text.contains("damage"), "Forecast shows damage band")
        try check(director.combat == baseline, "Hover does not consume actions or random rolls")
        try capture(scene, "targeting-melee")
        let key = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0,
            windowNumber: view.window!.windowNumber, context: nil, characters: "f", charactersIgnoringModifiers: "f", isARepeat: false, keyCode: 3)!
        scene.keyDown(with: key)
        director.hover(at: location)
        try check(director.targetPanel.text.contains("Ranged Attack"), "F switches to ranged targeting")
        try check(director.targetPanel.text.contains("% hit") || director.targetPanel.text.contains("Unavailable"), "Ranged preview reports hit chance or blocking reason")
        try capture(scene, "targeting-ranged")
        let before = director.combat
        let panel = director.targetPanel
        director.pointer(at: scene.convert(CGPoint(x: 24, y: -panel.panelHeight + 20), from: panel))
        try check(panel.examining && panel.text.contains("Defence:"), "Clicking Examine opens target stats")
        director.pointer(at: location)
        _ = director.shortcut(" ")
        try check(director.combat == before, "Examine blocks world attacks and End Turn")
        try capture(scene, "targeting-examine")
        director.cancelTargeting()
        try check(!panel.examining && panel.isHidden, "Escape closes Examine")
        director.hover(at: location)
        _ = director.shortcut("t")
        try check(panel.examining, "T opens Examine on hovered target")
        _ = director.shortcut("t")
        try check(!panel.examining, "T closes Examine")
        director.command(8)
        director.hover(at: location)
        try check(panel.text.contains("Full turn"), "Aimed Shot describes its full-turn cost")
        try capture(panel, "targeting-aimed-detail")
        director.cancelTargeting()
        _ = director.shortcut("g")
        director.command(5)
        director.hover(at: location)
        try check(panel.text.contains("Unavailable"), "Spent action shows blocked attack before click")
        try capture(scene, "targeting-spent-action")
        director.cancelTargeting()
        return checks
    }
}
#endif
