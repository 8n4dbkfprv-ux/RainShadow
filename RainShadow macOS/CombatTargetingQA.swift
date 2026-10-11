#if DEBUG
import AppKit
import SpriteKit

@MainActor enum CombatTargetingQA {
    static func run(in view: SKView, output: URL, initial: TacticalCombat) async throws -> [String] {
        if ProcessInfo.processInfo.environment["RAINSHADOW_QA_SHIPPING_BARREL"] == "1" {
            return try await shippingBarrelPreview(in: view, output: output)
        }
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
        try check(GameArt.standaloneTexture(named: "ui_combat_tooltip_parchment_v01") != nil,
                  "Generated tooltip artwork is packaged in the app")
        let baseline = director.combat
        let target = initial.actors.first { !$0.player && $0.conscious }!
        let location = scene.convert(CGPoint(x: target.position.x, y: target.position.y + 45), from: scene.depthWorldRoot)
        director.hover(at: location)
        try check(!director.targetPanel.isHidden, "Hover opens target forecast")
        try check(director.targetPanel.text.contains("1 Action"), "Forecast shows action cost")
        try check(director.targetPanel.text.contains("Damage"), "Forecast shows damage band")
        try check(director.combat == baseline, "Hover does not consume actions or random rolls")
        try capture(scene, "targeting-melee")
        let key = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0,
            windowNumber: view.window!.windowNumber, context: nil, characters: "f", charactersIgnoringModifiers: "f", isARepeat: false, keyCode: 3)!
        scene.keyDown(with: key)
        director.hover(at: location)
        try check(director.targetPanel.text.contains("Ranged Attack"), "F switches to ranged targeting")
        try check(director.targetPanel.text.contains("%") || director.targetPanel.text.contains("Target is too far") || director.targetPanel.text.contains("Can't use") || director.targetPanel.text.contains("Target is blocked!"), "Ranged preview reports hit chance or blocking reason")
        try capture(scene, "targeting-ranged")
        let before = director.combat
        let panel = director.targetPanel
        try check((view.texture(from: panel)?.size().width ?? .infinity) <= panel.panelWidth + 2,
                  "Painted forecast frame stays within its intended width")
        director.pointer(at: scene.convert(CGPoint(x: 24, y: -panel.panelHeight + 20), from: panel))
        try check(panel.examining && panel.text.contains("Armour Class:"), "Clicking Examine opens target stats")
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
        try check(panel.text.contains("1 Action"), "Aimed Shot describes its Action cost")
        try capture(panel, "targeting-aimed-detail")
        director.cancelTargeting()
        _ = director.shortcut("g")
        // Dash has a wind-up animation; input is intentionally locked until it
        // finishes. Check the spent-action forecast once targeting is available.
        let dashDeadline = ProcessInfo.processInfo.systemUptime + 10
        while director.busy {
            if ProcessInfo.processInfo.systemUptime > dashDeadline {
                throw TacticalCombatQA.Failure(message: "Dash animation timeout")
            }
            try await Task.sleep(for: .milliseconds(20))
        }
        director.command(5)
        director.hover(at: location)
        try check(panel.text.contains("Not enough resources: Action."), "Spent action shows blocked attack before click")
        try capture(scene, "targeting-spent-action")
        director.cancelTargeting()
        let resourceLabel = director.actionBar.childNode(withName: "combat.resources") as! SKLabelNode
        try check(resourceLabel.text?.contains("Action 0/1") == true
            && resourceLabel.text?.contains("Bonus Action 1/1") == true,
            "Dash spends the displayed Action while preserving the Bonus Action")
        director.command(4)
        try check(director.combat.isBear && !director.combat.canUseBonusAction,
                  "Wild Shape remains usable after Dash and spends the Bonus Action")
        func waitForPresentation() async throws {
            let limit = ProcessInfo.processInfo.systemUptime + 15
            while director.busy {
                if ProcessInfo.processInfo.systemUptime > limit { throw TacticalCombatQA.Failure(message: "Form presentation timeout") }
                try await Task.sleep(for: .milliseconds(20))
            }
        }
        try await waitForPresentation()
        try capture(scene, "resources-bear")
        let spent = director.combat.budget
        director.command(4)
        try check(!director.combat.isBear && director.combat.budget == spent,
                  "Dismiss Wild Shape is usable with both resources spent and refunds neither")
        try await waitForPresentation()
        let shove = director.actionBar.children.compactMap { $0 as? CombatActionButton }.first { $0.name == "combat.shove" }!
        director.actionBar.showTooltip(shove)
        try check(shove.unavailableReason == "Not enough resources: Bonus Action.",
                  "Shove explains the shared Bonus Action shortage after transformation")
        try capture(scene, "resources-spent-tooltip")
        director.actionBar.showTooltip(nil)
        let buttons = director.actionBar.children.compactMap { $0 as? CombatActionButton }.filter { !$0.isHidden }
        for width: CGFloat in [360, 920] {
            director.actionBar.layout(width: width, buttons: buttons)
            try check(resourceLabel.frame.width <= resourceLabel.preferredMaxLayoutWidth + 1,
                      "Resource readout fits the \(Int(width))-point action bar")
            try capture(director.actionBar, "resources-bar-\(Int(width))")
            director.actionBar.showTooltip(shove)
            try check((view.texture(from: director.actionBar)?.size().width ?? .infinity) <= width + 2,
                      "Painted tooltip fits the \(Int(width))-point action bar")
            try capture(director.actionBar, "tooltip-bar-\(Int(width))")
            director.actionBar.showTooltip(nil)
        }
        return checks
    }

    private static func shippingBarrelPreview(in view: SKView, output: URL) async throws -> [String] {
        let map = try AreaCatalogLoader.load(WharfLadderStory.interior).makeNavigationMap()
        let origin = CGPoint(x: 487, y: 364)
        map.registerActor(id: TacticalCombat.playerID, kind: .player, at: origin)
        let positions = [origin] + WharfLadderStaging.positions(near: origin, count: 3,
            navigation: map, ignoringActorID: TacticalCombat.playerID)
        let actors = positions.enumerated().map { index, point in
            Combatant(id: index == 0 ? TacticalCombat.playerID : "qa.shipping.\(index)",
                name: index == 0 ? "Voss" : "Hand \(index)", player: index == 0, position: point,
                hp: 12, maximumHP: 12, defence: 11, attackBonus: 2, damageMin: 1, damageMax: 3,
                initiativeBonus: index == 0 ? 100 : -100)
        }
        let legacy = TacticalCombat(encounterID: "clockroom", areaID: WharfLadderStory.interior.rawValue,
            actors: actors, seed: 42, barrels: [.init(id: "combat.oil.0", position: CGPoint(x: 600, y: 285))])
        let store = SaveStore(key: "RainShadow.QA.ShippingBarrel.\(UUID().uuidString)")
        defer { store.reset() }
        store.save(SaveSnapshot(tacticalCombat: try JSONEncoder().encode(legacy), hasSeenOpening: true,
            hasCompletedOfficeCaseIntro: true, hasSeededStarterKit: true, hasReceivedArmorKit: true))
        let context = GameContext(saveStore: store); context.router.start(in: view)
        let deadline = ProcessInfo.processInfo.systemUptime + 40
        while (view.scene as? CityDistrictScene)?.context !== context || (view.scene as? CityDistrictScene)?.combatDirector?.busy != false {
            if ProcessInfo.processInfo.systemUptime > deadline { throw TacticalCombatQA.Failure(message: "Shipping barrel scene timeout") }
            try await Task.sleep(for: .milliseconds(20))
        }
        let scene = view.scene as! CityDistrictScene
        let director = scene.combatDirector!
        guard let barrel = director.combat.barrels?.first,
              barrel.position == CGPoint(x: 430, y: 410),
              GameSession(saveStore: store).tacticalCombat?.barrels?.first?.position == barrel.position else {
            throw TacticalCombatQA.Failure(message: "Shipping barrel migration was not presented and persisted")
        }
        director.hover(at: scene.convert(CGPoint(x: barrel.position.x, y: barrel.position.y + 30), from: scene.depthWorldRoot))
        guard let texture = view.texture(from: scene),
              let data = NSBitmapImageRep(cgImage: texture.cgImage()).representation(using: .png, properties: [:]) else {
            throw TacticalCombatQA.Failure(message: "Shipping barrel capture failed")
        }
        try data.write(to: output.appendingPathComponent("shipping-barrel-floor.png"))
        return ["Legacy indoor barrel moves to the authored floor position", "Corrected position is checkpointed", "Shipping-room barrel and blast preview render"]
    }
}
#endif
