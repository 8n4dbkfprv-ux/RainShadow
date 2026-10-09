#if DEBUG
import AppKit
import SpriteKit

@MainActor enum RangedAmmunitionQA {
    static func run(in view: SKView, output: URL, initial: TacticalCombat) async throws -> [String] {
        var checks: [String] = []
        let armored = ProcessInfo.processInfo.environment["RAINSHADOW_QA_ARMORED_BOW"] == "1"
        func check(_ value: Bool, _ text: String) throws {
            guard value else { throw TacticalCombatQA.Failure(message: text) }; checks.append(text)
        }
        func wait(_ predicate: () -> Bool) async throws {
            let deadline = ProcessInfo.processInfo.systemUptime + 40
            while !predicate() {
                if ProcessInfo.processInfo.systemUptime > deadline { throw TacticalCombatQA.Failure(message: "Ammo timeout after " + (checks.last ?? "start")) }
                try await Task.sleep(for: .milliseconds(20))
            }
        }
        func capture(_ name: String) throws {
            guard let scene = view.scene, let texture = view.texture(from: scene),
                let data = NSBitmapImageRep(cgImage: texture.cgImage()).representation(using: .png, properties: [:]) else { return }
            try data.write(to: output.appendingPathComponent(name + ".png"))
        }
        let store = SaveStore(key: "RainShadow.QA.Ammunition.\(UUID().uuidString)")
        defer { store.reset() }
        var scene = view.scene as! CityDistrictScene
        var player = initial.actors.first(where: \.player)!
        var enemy = initial.actors.first { !$0.player && $0.rangedWeapon == nil }!
        player.hp = 100; player.maximumHP = 100; player.initiativeBonus = 100; player.rangedWeapon = .bow; player.attackBonus = 100; player.conditions = nil; player.burningTurns = nil; player.hidden = nil
        enemy.hp = 100; enemy.maximumHP = 100; enemy.initiativeBonus = -100; enemy.rangedWeapon = nil; enemy.conditions = nil; enemy.burningTurns = nil; enemy.hidden = nil
        let excluded = Array(scene.navigation.occupancy.actors.keys)
        let points = (0..<32).compactMap { step -> CGPoint? in
            let angle = Double(step) * .pi / 16
            let p = CGPoint(x: player.position.x + cos(angle) * 240, y: player.position.y + sin(angle) * 180)
            guard let point = scene.navigation.nearestWalkablePoint(to: p),
                  (170...300).contains(CombatNavigation.distance(player.position, point)),
                  CombatNavigation.clearLine(in: scene.navigation, from: player.position, to: point, excluding: excluded) else { return nil }
            return point
        }
        guard var point = points.first else { throw TacticalCombatQA.Failure(message: "No ranged fixture") }
        enemy.position = point
        func model(_ seed: UInt64 = 42, barrel: Bool = false) -> TacticalCombat {
            var opponent = enemy
            if barrel { opponent.position = initial.actors.first { !$0.player }!.position }
            return TacticalCombat(encounterID: initial.encounterID, areaID: initial.areaID,
                actors: [player, opponent], seed: seed, barrels: barrel ? [.init(id: "qa.barrel", position: point)] : [])
        }
        func open(_ model: TacticalCombat, count: Int = 0, bow: Bool = true, grant: Bool = false) async throws -> TacticalCombatDirector {
            var equipment: [String: PersistedCarriedItemStack] = ["weapon1": .init(id: "lantern-shortsword", quantity: 1)]
            if armored { equipment["coat"] = .init(id: "splint-mail", quantity: 1); equipment["fedora"] = .init(id: "iron-helmet", quantity: 1) }
            if bow { equipment["weapon2"] = .init(id: "elven-court-bow", quantity: 1) }
            store.save(SaveSnapshot(tacticalCombat: try JSONEncoder().encode(model), hasReceivedFireArrows: !grant,
                hasSeenOpening: true, hasCompletedOfficeCaseIntro: true,
                carriedItems: count > 0 ? [.init(id: "fire-arrow", quantity: count)] : [], equippedItems: equipment,
                hasSeededStarterKit: true, hasReceivedArmorKit: true, hasReceivedElvenCourtBow: true, hasReceivedElvenCourtArrow: true))
            let context = GameContext(saveStore: store); context.router.start(in: view)
            try await wait { (view.scene as? CityDistrictScene)?.context === context && (view.scene as? CityDistrictScene)?.combatDirector != nil }
            scene = view.scene as! CityDistrictScene
            let director = scene.combatDirector!
            try await wait { !director.busy }
            return director
        }
        func press(_ name: String, _ director: TacticalCombatDirector) throws {
            guard let button = scene.hudRoot.childNode(withName: "//" + name), let parent = button.parent else {
                throw TacticalCombatQA.Failure(message: "Missing " + name)
            }
            director.pointer(at: scene.convert(button.position, from: parent))
        }
        func target(_ director: TacticalCombatDirector, at point: CGPoint, height: CGFloat = 55) {
            scene.gameCamera.position = scene.clampedCameraPosition(following: point, in: scene.cameraClampBounds)
            director.pointer(at: scene.convert(CGPoint(x: point.x, y: point.y + height), from: scene.depthWorldRoot))
        }
        func verifyArmor(_ actor: CharacterAppearanceNode, key: String) throws {
            for item in [CharacterEquipmentCode.splintMail, .ironHelmet] {
                let layer = actor.childNode(withName: "appearance." + item.rawValue) as? IEAvatarNode
                guard let frame = layer?.currentFrame, !frame.isEmpty,
                      frame.id?.atlas == BowAttackAnimationSet.equipment(item)! + ".atlas",
                      frame.id?.name == key else { throw TacticalCombatQA.Failure(message: "Missing bow armor " + item.rawValue + " at " + key) }
            }
        }
        if armored {
            // Sample every native runtime frame in every facing; check complete,
            // mail-only and helmet-only outfits as well as changing an existing node.
            var definition = CharacterDefinition.voss
            let bow: [CharacterEquipmentAppearance] = [.init(item: .elvenCourtBow), .init(item: .elvenCourtArrow)]
            definition.appearance.equipment = bow
            let actor = try CharacterAppearanceNode(definition: definition)
            for gear in [[CharacterEquipmentCode.splintMail, .ironHelmet], [.splintMail], [.ironHelmet], []] {
                definition.appearance.equipment = bow + gear.map { .init(item: $0) }
                try actor.apply(definition)
                for clip in ["shoot", "pin", "sneakshoot"] {
                    for facing in ActorFacing.allCases { for phase in 0..<18 {
                        if clip == "sneakshoot" { try actor.presentStealth(.sneakshoot, facing: facing, phase: phase) }
                        else { try actor.presentTechnique(clip == "pin" ? .pinningShot : nil, action: .shoot, facing: facing, phase: phase) }
                        let key = String(format: "%@_%@_%02d.png", clip, VossAnimationSet.direction(facing), phase)
                        for item in gear {
                            let layer = actor.childNode(withName: "appearance." + item.rawValue) as? IEAvatarNode
                            guard layer?.currentFrame?.id?.name == key, layer?.currentFrame?.isEmpty == false else {
                                throw TacticalCombatQA.Failure(message: "Missing registered armor at " + key)
                            }
                        }
                    } }
                    try check(true, "All 288 " + clip + " frames load for outfit " + gear.map(\.rawValue).joined(separator: "+"))
                }
            }
        }
        var director = try await open(model(), count: 2, bow: false)
        let noBow = director.combat
        try press("combat.ranged", director)
        try check(!director.aimingRangedAttack && director.combat == noBow && director.targetingFeedback.contains("equipped weapon slot"),
                  "Ranged Attack requires an equipped bow, even in an old bow-enabled checkpoint")
        // Reload uses the saved door state, so certify the fixture in that scene.
        guard let clearPoint = points.first(where: {
            CombatNavigation.clearLine(in: scene.navigation, from: player.position, to: $0,
                excluding: Array(scene.navigation.occupancy.actors.keys))
        }) else { throw TacticalCombatQA.Failure(message: "No restored firing lane") }
        point = clearPoint; enemy.position = point
        director = try await open(model())
        try check(director.visibleCombatCommands.contains("combat.ranged") && director.visibleCombatCommands.contains("combat.ammunition")
                  && !director.visibleCombatCommands.contains("combat.fire"), "Ranged Attack and ammunition selector replace the Fire Arrow action")
        try press("combat.ammunition", director)
        try check(director.selectedAmmunition == .normal && director.targetingFeedback.contains("No Fire Arrows"), "Empty special ammunition cannot be selected")
        try press("combat.ranged", director)
        try check(director.aimingRangedAttack, "Normal ranged attack needs no ordinary arrows in inventory")
        target(director, at: point)
        try check(director.rangedShot != nil && director.rangedShot?.result.fireArrow == false && !director.combat.actors.first(where: { !$0.player })!.isBurning,
                  "Default shot is ordinary and cannot burn the target")
        try await wait { director.rangedShot.map { !$0.arrow.isHidden } == true }
        try check(director.rangedShot?.fire.parent == nil, "Normal projectile has no flame trail")
        if armored, let shot = director.rangedShot {
            try verifyArmor(shot.actor, key: String(format: "shoot_%@_%02d.png", VossAnimationSet.direction(shot.facing), shot.actor.currentPhase))
            try check(true, "Live normal projectile retains both animated armor layers")
        }
        try capture("normal-arrow")
        try await wait { !director.busy }
        var hitSeed: UInt64 = 0, missSeed: UInt64 = 0
        for seed in 1...100 {
            var probe = model(UInt64(seed))
            let shot = probe.attack(target: enemy.id, clearLine: true, ranged: true, ammunition: .fire)!
            if shot.landed { hitSeed = UInt64(seed) } else { missSeed = UInt64(seed) }
            if hitSeed > 0 && missSeed > 0 { break }
        }
        try check(hitSeed > 0 && missSeed > 0, "Deterministic hit and miss fixtures are available")
        director = try await open(model(hitSeed), count: 2)
        try press("combat.ammunition", director)
        try check(director.selectedAmmunition == .fire && director.fireArrowCount == 2, "Selector uses the carried Fire Arrow count")
        try capture("ammunition-selector")
        try press("combat.ranged", director)
        director.cancelTargeting()
        try check(director.fireArrowCount == 2 && director.combat.budget.canAttack, "Cancelling targeting consumes neither arrow nor action")
        try press("combat.ranged", director)
        target(director, at: player.position) // Own position is not an enemy.
        try check(director.fireArrowCount == 2 && director.combat.budget.canAttack, "Invalid target does not consume special ammunition")
        target(director, at: point)
        try check(director.rangedShot?.result.fireArrow == true && director.fireArrowCount == 1, "Accepted fire shot consumes exactly one arrow")
        let accepted = director.combat
        let reloaded = GameSession(saveStore: store)
        try check(reloaded.tacticalCombat == accepted && reloaded.characterInventory.quantity(of: "fire-arrow") == 1,
                  "Accepted damage and ammunition are saved together before playback")
        try await wait { director.rangedShot.map { !$0.arrow.isHidden } == true }
        try check(director.rangedShot?.fire.parent != nil, "Selected fire ammunition uses the existing flame particles")
        try capture("fire-arrow")
        scene.handleInventoryInput()
        let elapsed = director.rangedShot!.elapsed
        try await Task.sleep(for: .milliseconds(220))
        try check(director.rangedShot?.elapsed == elapsed && director.fireArrowCount == 1, "Inventory pauses the shot without consuming another arrow")
        scene.handleInventoryInput()
        try await wait { director.rangedShot?.impactPresented == true }
        try check(director.presentedCombat.actors.first(where: { !$0.player })!.isBurning, "Fire hit retains the burning effect")
        try await wait { !director.busy }
        director = try await open(model(missSeed), count: 1)
        try press("combat.ammunition", director); try press("combat.ranged", director); target(director, at: point)
        try check(director.rangedShot?.result.landed == false && director.fireArrowCount == 0 && director.selectedAmmunition == .normal,
                  "A miss consumes the last fire arrow and returns the selector to Normal")
        let afterMiss = GameSession(saveStore: store)
        try check(afterMiss.characterInventory.quantity(of: "fire-arrow") == 0 && afterMiss.hasReceivedFireArrows,
                  "Reload does not refill consumed ammunition")
        try await wait { !director.busy }
        director = try await open(model(), grant: true)
        try check(director.fireArrowCount == 3 && GameSession(saveStore: store).characterInventory.quantity(of: "fire-arrow") == 3,
                  "Starter fire arrows are granted once and survive reload without duplication")
        director = try await open(model(barrel: true), count: 1)
        try press("combat.ranged", director); target(director, at: point, height: 24)
        try check(director.combat.barrels?.first?.isBroken == true && director.combat.barrels?.first?.exploded == false
                  && director.fireArrowCount == 1, "Normal arrow breaks a barrel without ignition or special-ammo consumption")
        try await wait { !director.busy }
        try capture("normal-barrel-break")
        director = try await open(model(barrel: true), count: 1)
        try press("combat.ammunition", director); try press("combat.ranged", director); target(director, at: point, height: 24)
        try check(director.combat.barrels?.first?.exploded == true && director.fireArrowCount == 0,
                  "Fire arrow consumes one item and ignites the barrel")
        try await wait { !director.busy }
        try capture("fire-barrel")
        if armored {
            for action in ["aimedShot", "pinningShot", "sneak"] {
                var fight = model(hitSeed)
                if action == "sneak" { _ = fight.hide(observed: false) }
                director = try await open(fight, count: 2)
                try press("combat." + action, director); target(director, at: point)
                guard let shot = director.rangedShot else { throw TacticalCombatQA.Failure(message: "Armored " + action + " rejected: " + director.targetingFeedback) }
                try await wait { shot.actor.currentPhase >= 8 }
                let clip = action == "pinningShot" ? "pin" : action == "sneak" ? "sneakshoot" : "shoot"
                try verifyArmor(shot.actor, key: String(format: "%@_%@_%02d.png", clip, VossAnimationSet.direction(shot.facing), shot.actor.currentPhase))
                try check(action == "sneak" ? shot.isSneakAttack : shot.result.maneuver?.rawValue == action,
                          "Armored " + action + " uses its authored combat animation")
                try check(director.fireArrowCount == 2 && !shot.result.fireArrow, "Armored " + action + " preserves special ammunition")
                try capture("armored-" + action)
                try await wait { !director.busy }
                try check(!scene.detective.isHidden, "Armored " + action + " returns to the equipped exploration actor")
            }
        }
        return checks
    }
}
#endif
