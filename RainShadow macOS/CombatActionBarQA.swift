#if DEBUG
import AppKit
import SpriteKit

@MainActor enum CombatActionBarQA {
    static func run(in view: SKView, output: URL, initial: TacticalCombat) async throws -> [String] {
        var checks: [String] = []
        func check(_ value: Bool, _ message: String) throws {
            guard value else { throw TacticalCombatQA.Failure(message: message) }; checks.append(message)
        }
        func wait(_ condition: () -> Bool) async throws {
            let deadline = ProcessInfo.processInfo.systemUptime + 35
            while !condition() {
                if ProcessInfo.processInfo.systemUptime > deadline { throw TacticalCombatQA.Failure(message: "Action bar timeout") }
                try await Task.sleep(for: .milliseconds(20))
            }
        }
        func capture(_ node: SKNode, _ name: String) throws {
            guard let texture = view.texture(from: node), let data = NSBitmapImageRep(cgImage: texture.cgImage()).representation(using: .png, properties: [:]) else {
                throw TacticalCombatQA.Failure(message: "Action bar capture failed")
            }
            try data.write(to: output.appendingPathComponent(name + ".png"))
        }
        let store = SaveStore(key: "RainShadow.QA.ActionBar.\(UUID().uuidString)")
        defer { store.reset() }
        var scene = view.scene as! CityDistrictScene
        var player = initial.actors.first(where: \.player)!
        player.initiativeBonus = 100; player.hp = 12; player.maximumHP = 12
        var enemy = initial.actors.first { !$0.player }!
        enemy.initiativeBonus = -100
        let human = TacticalCombat(encounterID: initial.encounterID, areaID: initial.areaID, actors: [player, enemy], seed: 42)
        func open(_ model: TacticalCombat) async throws -> TacticalCombatDirector {
            store.save(SaveSnapshot(tacticalCombat: try JSONEncoder().encode(model), hasReceivedFireArrows: true, hasSeenOpening: true,
                hasCompletedOfficeCaseIntro: true, carriedItems: [.init(id: CombatAmmunition.fireItemID, quantity: 2)],
                equippedItems: ["weapon1": .init(id: "lantern-shortsword", quantity: 1), "weapon2": .init(id: "elven-court-bow", quantity: 1)], hasSeededStarterKit: true,
                hasReceivedArmorKit: true, hasReceivedElvenCourtBow: true, hasReceivedElvenCourtArrow: true,
                caseFlags: ["combat.a1.gate.trigger"]))
            let context = GameContext(saveStore: store); context.router.start(in: view)
            try await wait { (view.scene as? CityDistrictScene)?.context === context && (view.scene as? CityDistrictScene)?.combatDirector != nil }
            scene = view.scene as! CityDistrictScene
            let director = scene.combatDirector!
            try await wait { !director.busy }
            return director
        }
        func button(_ name: String) throws -> CombatActionButton {
            guard let node = scene.hudRoot.childNode(withName: "//combat." + name) as? CombatActionButton else {
                throw TacticalCombatQA.Failure(message: "Missing action " + name)
            }; return node
        }
        func press(_ name: String, _ director: TacticalCombatDirector) throws {
            let node = try button(name)
            director.pointer(at: scene.convert(.zero, from: node))
        }
        var director = try await open(human)
        for name in ["ui_folio_strip_fantasy_v01", "ui_folio_card_fantasy_v01", "combat_action_inkwash_v02"] {
            try check(GameArt.standaloneTexture(named: name) != nil, "Bundled art: " + name)
        }
        try check(director.actionBar.height == 150, "Desktop combat uses a compact two-row bar")
        let visible = director.actionBar.children.compactMap { $0 as? CombatActionButton }.filter { !$0.isHidden }
        try check(visible.count == 17, "All seventeen human commands remain available")
        for (name, index) in [("melee", 0), ("ranged", 1), ("powerStrike", 4), ("feintingCut", 5), ("aimedShot", 6), ("pinningShot", 7), ("sneak", 9), ("tripAttack", 12)] {
            try check(try button(name).glyphIndex == index, "Correct weapon symbol: " + name)
        }
        let before = director.combat
        let sword = try button("melee")
        director.hover(at: scene.convert(.zero, from: sword))
        try check(director.actionBar.tooltipTitle == "Melee Attack", "Hover explains the sword icon")
        try capture(scene, "action-bar-tooltip")
        try press("melee", director)
        try check(director.selectingMelee && director.combat == before, "Sword icon enters targeting without spending an action")
        try press("melee", director)
        try check(!director.selectingMelee, "Second sword click cancels targeting")
        try press("ranged", director)
        try check(director.aimingRangedAttack, "Arrow icon selects ranged targeting")
        try press("ammunition", director)
        try check(director.selectedAmmunition == .fire && (try button("ammunition")).glyphIndex == 18
            && (try button("ammunition")).badge.text == "×2", "Fire ammo switches symbol and displays inventory count")
        director.actionBar.showTooltip(nil)
        try capture(director.actionBar, "action-bar-fire-ammunition")
        try press("ammunition", director)
        try check(director.selectedAmmunition == .normal && (try button("ammunition")).glyphIndex == 17,
                  "Normal ammo restores the arrow bundle")
        director.actionBar.showTooltip(nil)
        try capture(scene, "action-bar-human")
        // Enlarged capture uses the same live textures and shader as the bar.
        let proof = SKNode()
        let paper = SKSpriteNode(texture: UIPaintedChrome.parchmentSurface())
        paper.size = CGSize(width: 840, height: 150); proof.addChild(paper)
        for (index, name) in ["melee", "ranged", "bladeWard", "bear", "powerStrike", "feintingCut", "aimedShot", "sneak"].enumerated() {
            let glyph = try button(name).glyph.copy() as! SKSpriteNode
            glyph.setScale(2.5); glyph.position = CGPoint(x: CGFloat(index) * 102 - 357, y: 0)
            proof.addChild(glyph)
        }
        try capture(proof, "ink-symbol-detail")
        let slotsProof = SKNode()
        let slotsPaper = SKSpriteNode(texture: UIPaintedChrome.parchmentSurface())
        slotsPaper.size = CGSize(width: 740, height: 160); slotsProof.addChild(slotsPaper)
        let slotNames = ["melee", "ranged", "bladeWard", "bear", "dash", "ammunition"]
        for (index, name) in slotNames.enumerated() {
            let original = try button(name)
            let sample = CombatActionButton(name: original.name!, title: original.titleText,
                glyph: name == "ammunition" ? 18 : original.glyphIndex, shortcut: "", detail: original.detail)
            sample.setScale(2); sample.position.x = CGFloat(index) * 116 - 290
            slotsProof.addChild(sample)
        }
        try capture(slotsProof, "matching-slot-detail")
        let escapeProof = SKNode()
        let escapePaper = SKSpriteNode(texture: UIPaintedChrome.parchmentSurface())
        escapePaper.size = CGSize(width: 300, height: 150); escapeProof.addChild(escapePaper)
        for (index, name) in ["flee", "dash"].enumerated() {
            let glyph = try button(name).glyph.copy() as! SKSpriteNode
            glyph.setScale(2.2); glyph.position = CGPoint(x: index == 0 ? -75 : 75, y: 12)
            escapeProof.addChild(glyph)
            let label = SKLabelNode(fontNamed: UITheme.Font.overlayTitle)
            label.text = index == 0 ? "Flee Combat" : "Dash"
            label.fontSize = 16; label.fontColor = UITheme.Color.ink
            label.position = CGPoint(x: glyph.position.x, y: -56); escapeProof.addChild(label)
        }
        try capture(escapeProof, "flee-and-dash-icons")
        let saved = director.combat
        director.pointer(at: scene.convert(CGPoint(x: 0, y: -65), from: director.actionBar))
        try check(director.combat == saved, "Empty painted chrome cannot issue world movement")
        scene.handleInventoryInput()
        try check(scene.inventoryIsPresented && director.actionBar.parent?.isHidden == true, "Inventory hides the new bar")
        scene.handleCancelInput()
        for width: CGFloat in [820, 560, 320] {
            director.actionBar.layout(width: width, buttons: visible)
            let chrome = director.actionBar.childNode(withName: "combat.actionBar.chrome")!
            try check(abs(chrome.calculateAccumulatedFrame().width - width) < 1,
                      "Painted frame fits \(Int(width)) points")
            let bounds = CGRect(x: -width / 2, y: -director.actionBar.height / 2, width: width, height: director.actionBar.height)
            let rects = visible.map { $0.path!.boundingBoxOfPath.offsetBy(dx: $0.position.x, dy: $0.position.y) }
            try check(rects.allSatisfy { bounds.contains($0) }, "All controls fit at \(Int(width)) points")
            try check(rects.indices.allSatisfy { i in rects.indices.allSatisfy { j in i == j || !rects[i].intersects(rects[j]) } },
                      "Action hit areas do not overlap at \(Int(width)) points")
            try capture(director.actionBar, "action-bar-\(Int(width))")
        }
        director.layout()
        var bear = human
        try check(bear.transformToBear(hasClearance: true), "Bear fixture transforms")
        director = try await open(bear)
        try check(director.visibleCombatCommands == ["combat.claw", "combat.roar", "combat.bear", "combat.dash", "combat.extinguish", "combat.end", "combat.flee"],
                  "Bear form displays only its seven actions")
        try check(try button("bear").glyphIndex == 16 && button("claw").glyphIndex == 13 && button("roar").glyphIndex == 14,
                  "Bear abilities and human-return use their own symbols")
        try capture(scene, "action-bar-bear")
        try press("end", director)
        try check(director.combat != bear, "Separate End Turn control advances combat")
        return checks
    }
}
#endif
