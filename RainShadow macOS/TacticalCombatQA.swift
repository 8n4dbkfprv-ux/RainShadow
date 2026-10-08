#if DEBUG
import AppKit
import SpriteKit

@MainActor enum TacticalCombatQA {
    struct Failure: Error { let message: String }
    static func run(in view: SKView, output: URL) async {
        var checks: [String] = []
        var sawBowDraw = false, sawArrowFlight = false, sawArrowImpact = false
        let store = SaveStore(key: "RainShadow.QA.Combat.\(UUID().uuidString)")
        defer { store.reset() }
        func check(_ value: Bool, _ message: String) throws {
            guard value else { throw Failure(message: message) }
            if !checks.contains(message) { checks.append(message) }
        }
        func require<T>(_ value: T?, _ message: String) throws -> T {
            guard let value else { throw Failure(message: message) }; return value
        }
        func wait(_ predicate: () -> Bool) async throws {
            let deadline = ProcessInfo.processInfo.systemUptime + 50
            while !predicate() {
                if ProcessInfo.processInfo.systemUptime > deadline { throw Failure(message: "Timed out after " + (checks.last ?? "start")) }
                if let scene = view.scene as? CityDistrictScene, let director = scene.combatDirector, let shot = director.rangedShot {
                    if !sawBowDraw && shot.elapsed > 0.2 && shot.elapsed < BowAttackRules.releaseTime {
                        try check(shot.actor.currentAction == .shoot && shot.arrow.isHidden,
                            "Lookout draws before the arrow release marker")
                        try capture("bow-draw"); sawBowDraw = true
                    }
                    if !sawArrowFlight && !shot.arrow.isHidden {
                        try capture("arrow-flight")
                        if shot.result.maneuver == nil {
                            try check(shot.fire.parent != nil && !shot.fire.isHidden
                                && shot.fire.children.filter { !$0.isHidden && $0.alpha > 0 }.count > 2,
                                "Flying arrow carries a burning head and visible flame particles")
                        } else {
                            try check(shot.fire.parent == nil, "Weapon techniques use ordinary arrows")
                        }
                        try check(director.presentedCombat == shot.before,
                            "Arrow damage stays hidden until impact")
                        try check(GameSession(saveStore: store).tacticalCombat == director.combat,
                            "In-flight save stores the accepted outcome without a replayable action")
                        if ProcessInfo.processInfo.environment["RAINSHADOW_QA_COMBAT_INVENTORY_ONLY"] == "1" {
                            scene.handleInventoryInput()
                            let frozenTime = shot.elapsed, frozenArrow = shot.arrow.position, frozenCombat = director.combat
                            try await Task.sleep(for: .milliseconds(250))
                            try check(scene.inventoryIsPresented && shot.elapsed == frozenTime && shot.arrow.position == frozenArrow
                                && director.combat == frozenCombat, "Inventory freezes an enemy attack and projectile in flight")
                            scene.handleInventoryInput()
                            try check(!scene.inventoryIsPresented && !scene.pause.isPausedByPlayer,
                                      "Closing inventory releases only its own pause")
                        }
                        scene.handleTacticalPauseInput()
                        let elapsed = shot.elapsed, position = shot.arrow.position
                        let flamePositions = shot.fire.children.map(\.position)
                        let flameAlphas = shot.fire.children.map(\.alpha)
                        try await Task.sleep(for: .milliseconds(180))
                        try check(shot.elapsed == elapsed && shot.arrow.position == position,
                            "Pause freezes both bow animation and arrow flight")
                        try check(shot.fire.children.map(\.position) == flamePositions
                            && shot.fire.children.map(\.alpha) == flameAlphas,
                            "Pause freezes the flame trail and embers")
                        scene.handleTacticalPauseInput()
                        sawArrowFlight = true
                    }
                    if !sawArrowImpact && shot.impactPresented {
                        try check(shot.arrow.isHidden && director.presentedCombat == director.combat,
                            "Arrow arrival reveals damage exactly at impact")
                        try capture("arrow-impact"); sawArrowImpact = true
                    }
                }
                try await Task.sleep(for: .milliseconds(30))
            }
        }
        func capture(_ name: String) throws {
            guard let scene = view.scene as? BaseGameScene else { return }
            scene.didFinishUpdate()
            guard let texture = view.texture(from: scene),
                  let data = NSBitmapImageRep(cgImage: texture.cgImage()).representation(using: .png, properties: [:]) else { throw Failure(message: "Capture failed") }
            try data.write(to: output.appendingPathComponent(name + ".png"))
        }
        func click(_ scene: CityDistrictScene, world: CGPoint) {
            let location = scene.convert(world, from: scene.depthWorldRoot)
            let event = GamePointerEvent(location: location, kind: .mouse)
            scene.handlePointerDown(event); scene.handlePointerUp(event)
        }
        func driveDialogue(_ scene: CityDistrictScene) {
            guard scene.dialoguePresenter.isPresenting else { return }
            let ctx = scene.dialoguePresenter.runtimeContext
            let graph = WharfLadderDialogue.graph(String(ctx.dialogueState.graphID.dropFirst("case.".count)))
            guard let id = ctx.dialogueState.currentNodeID, let node = graph.node(id: id) else { return }
            if CaseDialogueGraph.visibleChoices(node.choices, in: ctx).isEmpty { scene.handleConfirmInput() }
            else { scene.handleDialogueChoiceDigit(id == "merrick.price" ? 3 : 1) }
        }
        do {
            try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
            store.save(SaveSnapshot(hasSeenOpening: true, hasCompletedOfficeCaseIntro: true))
            var context = GameContext(saveStore: store)
            view.window?.setContentSize(CGSize(width: 1100, height: 800))
            view.window?.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true)
            context.router.start(in: view)
            context.router.travel(to: WharfLadderStory.exterior, entrance: "from.portal.shippingOffice")
            try await wait { (view.scene as? GameAreaScene)?.area.id == WharfLadderStory.exterior && !context.router.isTransitioning }
            var scene = view.scene as! CityDistrictScene
            let portal = scene.area.travelRegions.first!
            if let door = scene.door(matching: portal.id) { scene.openDoor(door) }
            var target = CGPoint(x: portal.boundingBox.midX, y: portal.boundingBox.midY)
            outer: for y in stride(from: portal.boundingBox.minY, to: portal.boundingBox.maxY, by: 2) {
                for x in stride(from: portal.boundingBox.minX, to: portal.boundingBox.maxX, by: 2) {
                    let point = CGPoint(x: x, y: y)
                    if portal.contains(point), !scene.area.doors.contains(where: { HighlightGeometry.contains(point, polygon: $0.openOutline.map(\.cgPoint)) }) {
                        target = point; break outer
                    }
                }
            }
            click(scene, world: target)
            try await wait { scene.dialoguePresenter.isPresenting }
            let dialogueDeadline = ProcessInfo.processInfo.systemUptime + 30
            while scene.combatDirector == nil {
                if ProcessInfo.processInfo.systemUptime > dialogueDeadline { throw Failure(message: "Dialogue did not dispatch combat") }
                driveDialogue(scene); try await Task.sleep(for: .milliseconds(300))
            }
            try check(!scene.cutsceneDirector.isPlaying, "Dialogue starts playable combat without auto-resolution")
            scene.handleMapInput(); scene.handleJournalInput()
            try check(!scene.anyOverlayIsPresented, "Combat still blocks map and journal input")
            try await wait { scene.combatDirector?.combat.isPlayerTurn == true && scene.combatDirector?.busy == false }
            try capture("combat-start")
            let beforeChromeClick = scene.combatDirector!.combat
            if ProcessInfo.processInfo.environment["RAINSHADOW_QA_COMBAT_INVENTORY_ONLY"] == "1" {
                let director = scene.combatDirector!
                scene.handleInventoryInput()
                try check(scene.inventoryIsPresented, "I opens inventory during combat")
                try check(scene.inventoryCurrentHealth == director.presentedCombat.actors.first(where: \.player)?.hp,
                          "Inventory uses the health currently shown in combat")
                try await Task.sleep(for: .milliseconds(250))
                try check(scene.hudRoot.childNode(withName: "combat.hud")?.isHidden == true,
                          "Inventory appears above the combat controls")
                try capture("combat-inventory")
                scene.handleDialogueChoiceDigit(1); director.command(2)
                director.pointer(at: scene.detective.position)
                try check(director.combat == beforeChromeClick, "Inventory blocks combat hotkeys and world orders")
                scene.handleCancelInput()
                try check(!scene.inventoryIsPresented && director.combat == beforeChromeClick,
                          "Escape returns to the same turn and action budget")
                for name in ["hud.action.inventory", "hud.action.character", "hud.detective-portrait"] {
                    let node = try require(scene.hudRoot.childNode(withName: "//" + name), "Missing inventory entry point")
                    let portraitRect = HUDChromeLayout.rightRailLayout(for: scene.size).portraitWindowRect
                    let point = name == "hud.detective-portrait"
                        ? scene.convert(CGPoint(x: portraitRect.midX, y: portraitRect.midY), from: scene.portraitBar)
                        : scene.convert(.zero, from: node)
                    let event = GamePointerEvent(location: point, kind: .mouse)
                    scene.handlePointerDown(event); scene.handlePointerUp(event)
                    try check(scene.inventoryIsPresented, "\(name) opens inventory with a click")
                    let close = try require(scene.inventoryOverlay.childNode(withName: "//inventory.close"), "Missing close button")
                    let closeEvent = GamePointerEvent(location: scene.convert(.zero, from: close), kind: .mouse)
                    scene.handlePointerDown(closeEvent); scene.handlePointerUp(closeEvent)
                    try check(!scene.inventoryIsPresented, "Inventory close button receives combat-time pointer input")
                }
                scene.handleTacticalPauseInput(); scene.handleInventoryInput(); scene.handleInventoryInput()
                try check(scene.pause.isPausedByPlayer && !scene.inventoryIsPresented,
                          "Closing inventory preserves a pre-existing tactical pause")
                scene.handleTacticalPauseInput()
                scene.handleInventoryInput(); scene.handleConfirmInput()
                try check(!scene.inventoryIsPresented && director.combat == beforeChromeClick,
                          "Enter dismisses inventory without ending the turn")
                try JSONSerialization.data(withJSONObject: ["passed": true, "checks": checks], options: [.prettyPrinted, .sortedKeys]).write(to: output.appendingPathComponent("report.json"))
                NSApp.terminate(nil); return
            }
            if ProcessInfo.processInfo.environment["RAINSHADOW_QA_BEAR_ABILITIES_ONLY"] == "1" {
                checks += try await BearAbilitiesQA.run(in: view, output: output, initial: beforeChromeClick)
                try JSONSerialization.data(withJSONObject: ["passed": true, "checks": checks], options: [.prettyPrinted, .sortedKeys]).write(to: output.appendingPathComponent("report.json"))
                NSApp.terminate(nil); return
            }
            if ProcessInfo.processInfo.environment["RAINSHADOW_QA_TRIP_ONLY"] == "1" {
                sawBowDraw = true; sawArrowFlight = true; sawArrowImpact = true
                let tripStore = SaveStore(key: "RainShadow.QA.Trip.\(UUID().uuidString)")
                defer { tripStore.reset() }
                var equipment: [String: PersistedCarriedItemStack] = [:]
                func openTripFight(_ model: TacticalCombat) async throws {
                    tripStore.save(SaveSnapshot(tacticalCombat: try JSONEncoder().encode(model), hasSeenOpening: true,
                        hasCompletedOfficeCaseIntro: true, equippedItems: equipment, hasSeededStarterKit: true,
                        hasReceivedArmorKit: true, hasReceivedElvenCourtBow: true, hasReceivedElvenCourtArrow: true))
                    context = GameContext(saveStore: tripStore); context.router.start(in: view)
                    try await wait { (view.scene as? CityDistrictScene)?.context === context && (view.scene as? CityDistrictScene)?.combatDirector != nil }
                    scene = view.scene as! CityDistrictScene
                }
                for mode in ["sword", "armored", "bow", "miss", "hidden", "enemy"] {
                    let enemyActs = mode == "enemy"
                    // Restored crew are staged with contiguous IDs starting at 0.
                    // Equip the single fixture opponent with a bow below rather
                    // than retaining a lone .1 ID from the full story encounter.
                    var actors = [beforeChromeClick.actors.first(where: \.player)!, beforeChromeClick.actors.first(where: { !$0.player && $0.id.hasSuffix(".0") })!]
                    let origin = actors[0].position
                    var site: CGPoint?
                    for step in 0..<64 {
                        let a = Double(step) * .pi / 32
                        let candidate = CGPoint(x: origin.x + cos(a)*85, y: origin.y + sin(a)*85*0.75)
                        if let point = scene.navigation.nearestWalkablePoint(to: candidate),
                           abs(CombatNavigation.distance(origin, point)-85) < 8,
                           CombatNavigation.clearLine(in: scene.navigation, from: origin, to: point, excluding: Array(scene.navigation.occupancy.actors.keys)) { site = point; break }
                    }
                    guard let site else { throw Failure(message: "No clear Trip Attack fixture") }
                    actors[1].position = site
                    for i in actors.indices {
                        actors[i].hp = 100; actors[i].maximumHP = 100; actors[i].conditions = nil; actors[i].burningTurns = nil
                        actors[i].hidden = nil; actors[i].sneakDice = 0; actors[i].shoveSpent = true
                        actors[i].usedManeuvers = [.powerStrike, .feintingCut, .aimedShot, .pinningShot]
                        actors[i].attackBonus = 30; actors[i].damageMin = 4; actors[i].damageMax = 4; actors[i].rangedWeapon = mode == "bow" && !actors[i].player ? .bow : nil
                        actors[i].initiativeBonus = actors[i].player != enemyActs ? 100 : 0
                    }
                    if enemyActs {
                        var ally = beforeChromeClick.actors.first { !$0.player && $0.id != actors[1].id }!
                        ally.position = scene.navigation.nearestWalkablePoint(to: CGPoint(x: origin.x - (site.x-origin.x)*0.7, y: origin.y - (site.y-origin.y)*0.7)) ?? origin
                        ally.hp = 100; ally.maximumHP = 100; ally.initiativeBonus = 50
                        ally.attackBonus = 30; ally.damageMin = 1; ally.damageMax = 1
                        ally.usedManeuvers = CombatManeuver.allCases; ally.rangedWeapon = nil
                        actors.append(ally)
                    }
                    let target = actors[enemyActs ? 0 : 1]
                    var model: TacticalCombat?
                    for seed in 1...100 {
                        var candidate = TacticalCombat(encounterID: "gate", areaID: WharfLadderStory.exterior.rawValue, actors: actors, seed: UInt64(seed))
                        if mode == "hidden" { _ = candidate.hide(observed: false) }
                        var probe = candidate
                        if let result = probe.attack(target: target.id, clearLine: true, maneuver: .tripAttack, hasSword: true),
                           (result.damage == 0) == (mode == "miss") { model = candidate; break }
                    }
                    guard let model else { throw Failure(message: "No deterministic trip fixture") }
                    equipment = ["weapon1": .init(id: "lantern-shortsword", quantity: 1)]
                    if mode == "armored" || enemyActs { equipment["coat"] = .init(id: "splint-mail", quantity: 1); equipment["fedora"] = .init(id: "iron-helmet", quantity: 1) }
                    try await openTripFight(model)
                    let director = scene.combatDirector!
                    if !enemyActs {
                        try await wait { !director.busy }
                        director.command(14)
                        try check(director.selectedManeuver == .tripAttack, "\(mode): Trip Attack control selects the technique")
                        director.command(14)
                        try check(director.selectedManeuver == nil && director.combat == model, "\(mode): cancelling targeting spends nothing")
                        director.command(14); click(scene, world: site)
                    }
                    try await wait { director.meleeAttack != nil }
                    let attack = director.meleeAttack!
                    let accepted = director.combat
                    try check(attack.result.maneuver == .tripAttack && !attack.isSneakAttack, "\(mode): dedicated low sword cut plays")
                    try check(accepted.current.usedManeuvers?.contains(.tripAttack) == true && !accepted.budget.canAttack, "\(mode): standard action and encounter use are spent")
                    try check(GameSession(saveStore: tripStore).tacticalCombat == accepted && director.presentedCombat == attack.before, "\(mode): accepted result saves before the visual contact")
                    scene.handleTacticalPauseInput()
                    let elapsed = attack.elapsed
                    try await Task.sleep(for: .milliseconds(180))
                    try check(attack.elapsed == elapsed, "\(mode): pause freezes the attacking character")
                    try capture("trip-" + mode + "-windup"); scene.handleTacticalPauseInput()
                    try await wait { attack.impactPresented }
                    try check(director.hitReactions[target.id]?.kind == (mode == "miss" ? .dodge : .tripFall), "\(mode): impact selects dodge or dedicated trip reaction correctly")
                    if mode == "bow" {
                        try check(director.reactionNodes[target.id]?.definition.appearance.equipment.contains(where: { $0.item == .elvenCourtBow }) == true,
                                  "bow: fallen lookout keeps their bow in the reaction")
                    }
                    try capture("trip-" + mode + "-impact")
                    if mode == "miss" {
                        try await wait { !director.busy }
                        try check(!director.combat.actors.first { $0.id == target.id }!.isProne && director.hitReactions[target.id] == nil, "miss: target stays standing and reaction clears")
                        continue
                    }
                    if !enemyActs {
                        try await wait { !director.busy }
                        try check(director.combat.actors.first { $0.id == target.id }!.isProne && director.reactionNodes[target.id]?.currentPhase == ProneMotion.holdPhase && director.reactionNodes[target.id]?.currentReaction == .tripFall,
                                  "\(mode): target stays on the ground while attacker's turn continues")
                        let held = director.reactionNodes[target.id]!.currentPhase
                        try await Task.sleep(for: .milliseconds(250))
                        try check(director.reactionNodes[target.id]?.currentPhase == held && !director.busy, "\(mode): holding Prone does not lock combat or advance the get-up clip")
                        try capture("trip-" + mode + "-prone")
                        try await openTripFight(accepted)
                        let restored = scene.combatDirector!
                        try await wait { !restored.busy }
                        try check(restored.combat == accepted && restored.meleeAttack == nil && restored.reactionNodes[target.id]?.currentPhase == ProneMotion.holdPhase && restored.reactionNodes[target.id]?.currentReaction == .tripFall,
                                  "\(mode): loading preserves the grounded pose without replaying damage")
                        restored.command(2)
                        try check(restored.combat.current.id == target.id && !restored.combat.current.isProne && restored.busy,
                                  "\(mode): victim's turn starts with a locked get-up animation")
                        try check(restored.combat.budget.canAttack && restored.combat.budget.movementRemaining == target.speed/2,
                                  "\(mode): standing spends half movement and preserves the attack")
                        try await wait { (restored.reactionNodes[target.id]?.currentPhase ?? 0) >= 18 }
                        scene.handleTacticalPauseInput()
                        let phase = restored.reactionNodes[target.id]!.currentPhase
                        try await Task.sleep(for: .milliseconds(180))
                        try check(restored.reactionNodes[target.id]?.currentPhase == phase && restored.busy, "\(mode): pause freezes recovery before the victim can act")
                        try capture("trip-" + mode + "-getup"); scene.handleTacticalPauseInput()
                        try await wait { restored.hitReactions[target.id] == nil }
                        try check(restored.reactionNodes[target.id]?.isHidden == true, "\(mode): standing body is restored after recovery")
                    } else {
                        let allyID = actors[2].id
                        try await wait { director.meleeAttack?.before.current.id == allyID }
                        let followup = director.meleeAttack!
                        try await wait { followup.impactPresented }
                        try check(director.combat.actors.first(where: { $0.id == target.id })?.isProne == true
                            && director.hitReactions[target.id]?.kind == .tripFall
                            && director.reactionNodes[target.id]?.currentPhase == ProneMotion.holdPhase,
                                  "enemy: a follow-up strike keeps the victim in the braced ground pose")
                        try capture("trip-enemy-followup")
                        try await wait { director.combat.isPlayerTurn }
                        try check(director.hitReactions[target.id] != nil && director.busy, "enemy: player recovers on their own turn before accepting input")
                        let before = director.combat; director.command(1)
                        try check(director.combat == before, "enemy: commands cannot skip the player's get-up animation")
                        try await wait { !director.busy }
                        try check(director.hitReactions[target.id] == nil && !director.combat.current.isProne && director.combat.budget.canAttack,
                                  "enemy: recovered player can take their standard action")
                        try capture("trip-enemy-recovered")
                    }
                }
                try JSONSerialization.data(withJSONObject: ["passed": true, "checks": checks], options: [.prettyPrinted, .sortedKeys]).write(to: output.appendingPathComponent("report.json"))
                NSApp.terminate(nil); return
            }
            if ProcessInfo.processInfo.environment["RAINSHADOW_QA_SHOVE_ONLY"] == "1" {
                sawBowDraw = true; sawArrowFlight = true; sawArrowImpact = true
                let shoveStore = SaveStore(key: "RainShadow.QA.Shove.\(UUID().uuidString)")
                defer { shoveStore.reset() }
                var equipment: [String: PersistedCarriedItemStack] = [:]
                func openShoveFight(_ model: TacticalCombat) async throws {
                    shoveStore.save(SaveSnapshot(tacticalCombat: try JSONEncoder().encode(model), hasSeenOpening: true,
                        hasCompletedOfficeCaseIntro: true, equippedItems: equipment, hasSeededStarterKit: true,
                        hasReceivedArmorKit: true, hasReceivedElvenCourtBow: true, hasReceivedElvenCourtArrow: true))
                    context = GameContext(saveStore: shoveStore); context.router.start(in: view)
                    try await wait { (view.scene as? CityDistrictScene)?.context === context && (view.scene as? CityDistrictScene)?.combatDirector != nil }
                    scene = view.scene as! CityDistrictScene
                }
                for mode in ["sword", "armored", "bow", "resisted", "hidden", "enemy", "far"] {
                    let enemyActs = mode == "enemy", shouldPush = mode != "resisted"
                    var actors = [beforeChromeClick.actors.first(where: \.player)!, beforeChromeClick.actors.first(where: { !$0.player && $0.id.hasSuffix(".0") })!]
                    let origin = actors[0].position
                    for i in actors.indices {
                        actors[i].hp = 100; actors[i].maximumHP = 100; actors[i].conditions = nil; actors[i].burningTurns = nil
                        actors[i].hidden = nil; actors[i].usedManeuvers = CombatManeuver.allCases
                        actors[i].attackBonus = 5; actors[i].damageMin = 1; actors[i].damageMax = 1
                        actors[i].initiativeBonus = actors[i].player != enemyActs ? 100 : -100
                        actors[i].rangedWeapon = mode == "bow" || enemyActs ? .bow : nil
                        actors[i].shoveProfile = .init(strength: 14, athletics: actors[i].player != enemyActs ? (shouldPush ? 30 : -5) : (shouldPush ? 0 : 30), acrobatics: 0, weight: 80)
                    }
                    let sourceIndex = enemyActs ? 1 : 0, targetIndex = enemyActs ? 0 : 1
                    actors[sourceIndex].position = origin
                    var site: CGPoint?
                    let distance = mode == "far" ? 220.0 : 85.0
                    for step in 0..<64 {
                        let angle = Double(step) * .pi / 32
                        let proposed = CGPoint(x: origin.x + cos(angle) * distance, y: origin.y + sin(angle) * distance * 0.75)
                        guard let point = scene.navigation.nearestWalkablePoint(to: proposed),
                              abs(CombatNavigation.distance(origin, point) - distance) < 8,
                              CombatNavigation.clearLine(in: scene.navigation, from: origin, to: point, excluding: Array(scene.navigation.occupancy.actors.keys)) else { continue }
                        actors[targetIndex].position = point
                        let end = CombatNavigation.knockbackDestination(in: scene.navigation, actor: actors[targetIndex], awayFrom: origin, actors: actors, destroyedBarrels: [])
                        if CombatNavigation.distance(point, end) >= 48 { site = point; break }
                    }
                    guard let site else { throw Failure(message: "No clear shove QA landing") }
                    actors[targetIndex].position = site
                    actors[1].combatFacing = ActorFacing.orient(from: origin, to: site).rawValue
                    var model = TacticalCombat(encounterID: "gate", areaID: WharfLadderStory.exterior.rawValue, actors: actors, seed: 42)
                    if mode == "hidden" { _ = model.hide(observed: false) }
                    equipment = ["weapon1": .init(id: mode == "bow" ? "elven-court-bow" : "lantern-shortsword", quantity: 1)]
                    if mode == "bow" { equipment["quiver1"] = .init(id: "elven-court-arrow", quantity: 1) }
                    if mode == "armored" || enemyActs { equipment["coat"] = .init(id: "splint-mail", quantity: 1); equipment["fedora"] = .init(id: "iron-helmet", quantity: 1) }
                    try await openShoveFight(model)
                    let director = scene.combatDirector!, target = actors[targetIndex]
                    if !enemyActs {
                        try await wait { !director.busy }
                        director.command(13)
                        director.hover(at: scene.convert(site, from: scene.depthWorldRoot))
                        let previewNode = scene.childNode(withName: "//combat.routePreview") as? SKShapeNode
                        let path = previewNode?.path
                        try check(director.selectingShove && path != nil, "\(mode): Shove button enables the landing preview")
                        try check((previewNode?.zPosition ?? .infinity) + scene.depthWorldRoot.zPosition < scene.hudRoot.zPosition, "\(mode): landing preview draws beneath combat controls")
                        try capture("shove-" + mode + "-preview")
                        if mode == "far" {
                            let before = director.combat
                            click(scene, world: site)
                            try check(director.combat == before && director.shovePresentation == nil, "far: out-of-range targeting spends nothing")
                            director.command(13)
                            try check(!director.selectingShove && previewNode?.path == nil, "far: selecting Shove again cancels targeting")
                            continue
                        }
                        click(scene, world: site)
                    }
                    try await wait { director.shovePresentation != nil }
                    guard let shove = director.shovePresentation else { throw Failure(message: "No shove presentation") }
                    let accepted = director.combat
                    try check(shove.node.currentAction == .shove && director.busy, "\(mode): push animation locks combat input")
                    try check(accepted.budget == shove.before.budget && accepted.current.shoveSpent == true, "\(mode): shove spends only its bonus action")
                    try check(accepted.actors.map(\.hp) == shove.before.actors.map(\.hp), "\(mode): shove deals no direct damage")
                    try check(GameSession(saveStore: shoveStore).tacticalCombat == accepted, "\(mode): accepted endpoint and bonus cost are saved before contact")
                    scene.handleTacticalPauseInput()
                    let elapsed = shove.elapsed, phase = shove.node.currentPhase
                    try await Task.sleep(for: .milliseconds(180))
                    try check(director.shovePresentation?.elapsed == elapsed && shove.node.currentPhase == phase, "\(mode): pause freezes the pushing character")
                    try capture("shove-" + mode + "-windup")
                    scene.handleTacticalPauseInput()
                    try await wait { director.shovePresentation?.impactPresented == true }
                    try check(director.hitReactions[target.id]?.kind == (shouldPush ? .fall : .hit), "\(mode): contact starts the correct target reaction")
                    scene.handleTacticalPauseInput()
                    let pushElapsed = director.knockbackElapsed, reactionElapsed = director.hitReactions[target.id]?.elapsed
                    try await Task.sleep(for: .milliseconds(180))
                    try check(director.knockbackElapsed == pushElapsed && director.hitReactions[target.id]?.elapsed == reactionElapsed, "\(mode): pause freezes target impulse and reaction")
                    try capture("shove-" + mode + "-contact")
                    scene.handleTacticalPauseInput()
                    if shouldPush {
                        try await wait { (director.hitReactions[target.id]?.elapsed ?? 0) >= 0.60 }
                        scene.handleTacticalPauseInput()
                        let groundedPhase = director.reactionNodes[target.id]?.currentPhase ?? -1
                        try check(director.shovePresentation == nil && director.knockbacks.isEmpty && director.busy,
                                  "\(mode): turn stays locked after the push while the fallen target recovers")
                        try check(director.reactionNodes[target.id]?.currentReaction == .fall
                            && director.reactionNodes[target.id]?.isHidden == false && groundedPhase >= 12,
                                  "\(mode): target visibly reaches the ground phase of the fall")
                        let pausedState = director.combat
                        director.command(2)
                        try await Task.sleep(for: .milliseconds(180))
                        try check(director.combat == pausedState && director.reactionNodes[target.id]?.currentPhase == groundedPhase,
                                  "\(mode): ground pose pauses without advancing the turn")
                        try capture("shove-" + mode + "-grounded")
                        scene.handleTacticalPauseInput()
                        try await wait { (director.hitReactions[target.id]?.elapsed ?? 0) >= 0.95 }
                        try check((director.reactionNodes[target.id]?.currentPhase ?? -1) > groundedPhase && director.busy,
                                  "\(mode): get-up animation completes before combat input resumes")
                        try capture("shove-" + mode + "-getting-up")
                        try check(director.combat.budget == accepted.budget
                            && director.combat.actors.first(where: { $0.id == target.id })?.conditions == target.conditions,
                                  "\(mode): falling and standing add no condition or movement cost")
                    }
                    if enemyActs {
                        try await wait { director.rangedShot != nil }
                        try check(director.rangedShot?.before.current.id == actors[1].id, "enemy: lookout creates space then uses its normal bow attack")
                    } else { try await wait { !director.busy } }
                    let position = director.combat.actors.first { $0.id == target.id }!.position
                    try check(position == (shove.result.displacement?.to ?? site), "\(mode): presentation settles on the accepted landing")
                    try check(shove.result.succeeded == shouldPush && shove.node.parent == nil, "\(mode): resolved outcome returns the pusher to its normal pose")
                    if shouldPush {
                        try check(director.hitReactions[target.id] == nil && director.reactionNodes[target.id]?.isHidden == true,
                                  "\(mode): recovered target returns to its standing presentation")
                    }
                    try capture("shove-" + mode + "-settled")
                    try await openShoveFight(accepted)
                    let restored = scene.combatDirector!
                    try check(restored.shovePresentation == nil && restored.combat.current.shoveSpent == true
                        && restored.combat.actors.first(where: { $0.id == target.id })?.position == position,
                        "\(mode): loading restores the endpoint without replaying or refunding the shove")
                }
                try JSONSerialization.data(withJSONObject: ["passed": true, "checks": checks], options: [.prettyPrinted, .sortedKeys]).write(to: output.appendingPathComponent("report.json"))
                NSApp.terminate(nil); return
            }
            if ProcessInfo.processInfo.environment["RAINSHADOW_QA_DEFEAT_ONLY"] == "1" {
                sawBowDraw = true; sawArrowFlight = true; sawArrowImpact = true
                let defeatStore = SaveStore(key: "RainShadow.QA.Defeat.\(UUID().uuidString)")
                defer { defeatStore.reset() }
                var equipment: [String: PersistedCarriedItemStack] = [:]
                func openDefeatFight(_ model: TacticalCombat) async throws {
                    defeatStore.save(SaveSnapshot(tacticalCombat: try JSONEncoder().encode(model),
                        hasSeenOpening: true, hasCompletedOfficeCaseIntro: true, equippedItems: equipment,
                        hasSeededStarterKit: true, hasReceivedArmorKit: true,
                        hasReceivedElvenCourtBow: true, hasReceivedElvenCourtArrow: true))
                    context = GameContext(saveStore: defeatStore); context.router.start(in: view)
                    try await wait { (view.scene as? CityDistrictScene)?.context === context && (view.scene as? CityDistrictScene)?.combatDirector != nil }
                    scene = view.scene as! CityDistrictScene
                }
                let source = try beforeChromeClick.liveBarrels.first(where: {
                    CombatNavigation.distance(beforeChromeClick.actors.first(where: \.player)!.position, $0.position) > TacticalCombat.meleeReach
                    && CombatNavigation.clearLine(in: scene.navigation, from: beforeChromeClick.actors.first(where: \.player)!.position, to: $0.position, excluding: Array(scene.navigation.occupancy.actors.keys))
                }).map { $0 } ?? { throw Failure(message: "No defeat barrel fixture") }()
                for mode in ["sword", "arrow", "player", "burning", "blast", "bear"] {
                    let playerFalls = mode == "player" || mode == "burning" || mode == "bear"
                    let ranged = mode == "arrow" || mode == "blast"
                    var actors = [beforeChromeClick.actors.first(where: \.player)!, beforeChromeClick.actors.first(where: { !$0.player && $0.id.hasSuffix(".0") })!]
                    let player = actors[0]
                    var site: CGPoint?
                    if mode == "blast" {
                        // Put the victim behind the barrel, inside the blast, leaving the firing lane open.
                        let away = atan2((source.position.y - player.position.y) / 0.75, source.position.x - player.position.x)
                        for step in 0..<64 {
                            let angle = away + Double(step) * .pi / 32
                            let proposed = CGPoint(x: source.position.x + cos(angle) * 70, y: source.position.y + sin(angle) * 52.5)
                            if let point = scene.navigation.nearestWalkablePoint(to: proposed),
                               abs(CombatNavigation.distance(point, source.position) - 70) < 8,
                               CombatNavigation.distance(player.position, point) > CombatNavigation.distance(player.position, source.position) + 25,
                               CombatNavigation.clearLine(in: scene.navigation, from: source.position, to: point, excluding: Array(scene.navigation.occupancy.actors.keys)) { site = point; break }
                        }
                    }
                    else {
                        let distance = ranged ? 220.0 : 85.0
                        for i in 0..<32 {
                            let a = Double(i) * .pi / 16
                            let proposed = CGPoint(x: player.position.x + cos(a) * distance, y: player.position.y + sin(a) * distance * 0.75)
                            if let point = scene.navigation.nearestWalkablePoint(to: proposed),
                               abs(CombatNavigation.distance(player.position, point) - distance) < 12,
                               CombatNavigation.clearLine(in: scene.navigation, from: player.position, to: point, excluding: actors.map(\.id)) { site = point; break }
                        }
                    }
                    guard let site else { throw Failure(message: "No defeat fixture site") }
                    actors[1].position = site
                    for i in actors.indices {
                        let victim = actors[i].player == playerFalls
                        actors[i].hp = victim ? 1 : 100; actors[i].maximumHP = 100
                        actors[i].attackBonus = 100; actors[i].defence = 1
                        actors[i].damageMin = 10; actors[i].damageMax = 10
                        actors[i].conditions = nil; actors[i].burningTurns = nil
                        actors[i].usedManeuvers = CombatManeuver.allCases
                        actors[i].initiativeBonus = (actors[i].player != (mode == "player")) ? 100 : -100
                        actors[i].rangedWeapon = ranged ? .bow : nil
                    }
                    if mode == "burning" { actors[0].burningTurns = 1 }
                    let victim = actors[playerFalls ? 0 : 1]
                    var model = TacticalCombat(encounterID: "gate", areaID: WharfLadderStory.exterior.rawValue, actors: actors, seed: 42, barrels: mode == "blast" ? [source] : [])
                    if mode != "blast" && mode != "burning" {
                        for seed in 1...100 {
                            var candidate = TacticalCombat(encounterID: "gate", areaID: WharfLadderStory.exterior.rawValue, actors: actors, seed: UInt64(seed))
                            if mode == "bear" {
                                guard candidate.transformToBear(hasClearance: true) else { throw Failure(message: "Bear defeat setup failed") }
                                candidate.endTurn()
                            }
                            var trial = candidate
                            if trial.attack(target: victim.id, clearLine: true, ranged: ranged, hasSword: !ranged)?.knockedOut == true { model = candidate; break }
                        }
                    }
                    equipment = ["weapon1": .init(id: ranged ? "elven-court-bow" : "lantern-shortsword", quantity: 1)]
                    if ranged { equipment["quiver1"] = .init(id: "elven-court-arrow", quantity: 1) }
                    if playerFalls { equipment["coat"] = .init(id: "splint-mail", quantity: 1); equipment["fedora"] = .init(id: "iron-helmet", quantity: 1) }
                    try await openDefeatFight(model)
                    let director = scene.combatDirector!
                    if mode != "player" && mode != "bear" {
                        try await wait { !director.busy }
                        if mode == "burning" { director.command(2) }
                        else {
                            if ranged { director.command(5) }
                            click(scene, world: mode == "blast" ? CGPoint(x: source.position.x, y: source.position.y + 30) : site)
                        }
                    }
                    try await wait { (director.defeats[victim.id]?.elapsed ?? 0) > 0.15 }
                    guard let body = director.defeatNodes[victim.id] else { throw Failure(message: "Missing defeat body") }
                    let accepted = director.combat
                    if mode == "blast" { try check(accepted.barrels?.first?.isBroken == true, "blast: ignited barrel caused the fatal impact") }
                    if mode == "bear" { try check(!accepted.isBear, "bear: fatal overflow reverts before the human collapse") }
                    try check(body.currentAction == .die && !body.isHidden && director.busy, "\(mode): fatal impact starts a visible collapse and locks the turn")
                    try check(director.hitReactions[victim.id] == nil && director.stealthNodes[victim.id]?.isHidden != false, "\(mode): collapse replaces transient reactions and stealth")
                    try check(scene.navigation.occupancy.actors[victim.id] == nil, "\(mode): fallen actor no longer blocks navigation")
                    try check(GameSession(saveStore: defeatStore).tacticalCombat == accepted, "\(mode): accepted knockout is saved before the fall ends")
                    scene.handleTacticalPauseInput()
                    let phase = body.currentPhase, elapsed = director.defeats[victim.id]!.elapsed
                    try await Task.sleep(for: .milliseconds(180))
                    try check(body.currentPhase == phase && director.defeats[victim.id]?.elapsed == elapsed && scene.combatDirector === director, "\(mode): pause freezes collapse and aftermath")
                    try capture("defeat-" + mode + "-falling")
                    scene.handleTacticalPauseInput()
                    try await wait { scene.combatDirector == nil }
                    try check(body.currentPhase == DefeatAnimationSet.frames - 1 && body.parent != nil && !body.isHidden,
                              "\(mode): settled body survives combat cleanup and remains visible in the aftermath")
                    try check(!playerFalls || scene.detective.isHidden, "\(mode): defeated Voss does not duplicate his fallen body")
                    try capture("defeat-" + mode + "-settled")
                    if let texture = view.texture(from: body), let data = NSBitmapImageRep(cgImage: texture.cgImage()).representation(using: .png, properties: [:]) {
                        try data.write(to: output.appendingPathComponent("defeat-" + mode + "-body.png"))
                    }
                    try await openDefeatFight(accepted)
                    let restored = scene.combatDirector!
                    let restoredBody = restored.defeatNodes[victim.id]
                    try check(restoredBody?.currentPhase == DefeatAnimationSet.frames - 1 && restored.defeats[victim.id]?.finished == true,
                              "\(mode): loading a knockout restores the resting pose without replaying the fall")
                    try await wait { scene.combatDirector == nil }
                    let deadline = ProcessInfo.processInfo.systemUptime + 15
                    while scene.dialoguePresenter.isPresenting && ProcessInfo.processInfo.systemUptime < deadline {
                        scene.handleConfirmInput(); scene.handleDialogueChoiceDigit(1)
                        try await Task.sleep(for: .milliseconds(60))
                    }
                    if playerFalls {
                        // Dialogue becomes noninteractive before its closing fade calls the aftermath completion.
                        try await wait { !scene.detective.isHidden && restoredBody?.parent == nil }
                        try check(true, "\(mode): Voss recovers only after the nonlethal aftermath")
                    }
                    else { try check(restoredBody?.parent != nil && restoredBody?.isHidden == false, "\(mode): defeated enemy remains in the area after dialogue") }
                }
                try JSONSerialization.data(withJSONObject: ["passed": true, "checks": checks], options: [.prettyPrinted, .sortedKeys]).write(to: output.appendingPathComponent("report.json"))
                NSApp.terminate(nil); return
            }
            if ProcessInfo.processInfo.environment["RAINSHADOW_QA_SNEAK_ONLY"] == "1" {
                let sneakStore = SaveStore(key: "RainShadow.QA.Sneak.\(UUID().uuidString)")
                defer { sneakStore.reset() }
                var sneakArmor = true
                func openFight(_ model: TacticalCombat) async throws {
                    var equipment: [String: PersistedCarriedItemStack] = ["weapon1": .init(id: "lantern-shortsword", quantity: 1)]
                    if sneakArmor { equipment["coat"] = .init(id: "splint-mail", quantity: 1); equipment["fedora"] = .init(id: "iron-helmet", quantity: 1) }
                    else { equipment["weapon1"] = .init(id: "elven-court-bow", quantity: 1); equipment["quiver1"] = .init(id: "elven-court-arrow", quantity: 1) }
                    sneakStore.save(SaveSnapshot(tacticalCombat: try JSONEncoder().encode(model),
                        hasSeenOpening: true, hasCompletedOfficeCaseIntro: true,
                        equippedItems: equipment,
                        hasSeededStarterKit: true, hasReceivedArmorKit: true,
                        hasReceivedElvenCourtBow: true, hasReceivedElvenCourtArrow: true))
                    context = GameContext(saveStore: sneakStore); context.router.start(in: view)
                    try await wait { (view.scene as? CityDistrictScene)?.context === context && (view.scene as? CityDistrictScene)?.combatDirector != nil }
                    scene = view.scene as! CityDistrictScene
                    try await wait { scene.combatDirector?.busy == false }
                }
                func clickAction(_ name: String) throws {
                    guard let button = scene.childNode(withName: "//combat." + name) else { throw Failure(message: "Missing " + name) }
                    let event = GamePointerEvent(location: scene.convert(.zero, from: button), kind: .mouse)
                    scene.handlePointerDown(event); scene.handlePointerUp(event)
                }
                let jumpOnly = ProcessInfo.processInfo.environment["RAINSHADOW_QA_SNEAK_JUMP_ONLY"] == "1"
                for ranged in (jumpOnly ? [false] : [false, true]) {
                    sneakArmor = !ranged
                    let label = ranged ? "bow-sneak" : "melee-sneak"
                    var actors = [beforeChromeClick.actors.first { $0.player }!, beforeChromeClick.actors.first { !$0.player && $0.id.hasSuffix(".0") }!]
                    var site: CGPoint?
                    for i in 0..<32 {
                        let a = Double(i) * .pi / 16, distance = ranged ? 220.0 : 85.0
                        let proposed = CGPoint(x: actors[0].position.x + cos(a) * distance,
                            y: actors[0].position.y + sin(a) * distance * 0.75).rounded
                        if let point = scene.navigation.nearestWalkablePoint(to: proposed),
                           abs(CombatNavigation.distance(actors[0].position, point) - distance) < 16,
                           CombatNavigation.clearLine(in: scene.navigation, from: actors[0].position, to: point,
                            excluding: actors.map(\.id)) { site = point; break }
                    }
                    guard let site else { throw Failure(message: "No sneak test site") }
                    actors[1].position = site
                    for i in actors.indices {
                        actors[i].hp = 100; actors[i].maximumHP = 100; actors[i].attackBonus = 100
                        actors[i].defence = 1; actors[i].damageMin = 4; actors[i].damageMax = 4
                        actors[i].initiativeBonus = actors[i].player ? 100 : -100
                        actors[i].rangedWeapon = actors[i].player ? .bow : nil
                        actors[i].conditions = nil; actors[i].usedManeuvers = nil
                    }
                    actors[1].combatFacing = ActorFacing.orient(from: site, to: actors[0].position).reflected.rawValue
                    var seed: UInt64 = 1
                    var model: TacticalCombat
                    while true {
                        model = TacticalCombat(encounterID: "gate", areaID: WharfLadderStory.exterior.rawValue, actors: actors, seed: seed)
                        var trial = model; _ = trial.hide(observed: false)
                        if (trial.attack(target: actors[1].id, clearLine: true, ranged: ranged, hasSword: true, requireSneakAttack: true)?.sneakDamage ?? 0) > 0 { break }
                        seed += 1
                    }
                    try await openFight(model)
                    var director = scene.combatDirector!
                    let before = director.combat
                    try clickAction("sneak"); click(scene, world: site)
                    try check(director.combat == before && director.meleeAttack == nil && director.rangedShot == nil,
                              "\(label): ineligible click spends nothing")
                    try clickAction("hide")
                    try check(director.combat.current.hidden == true && director.combat.budget == before.budget,
                              "\(label): Hide outside sight preserves the standard action")
                    try check(GameSession(saveStore: sneakStore).tacticalCombat == director.combat,
                              "\(label): hiding is checkpointed")
                    guard let crouch = director.stealthNodes[director.combat.current.id] else { throw Failure(message: "Missing stealth body") }
                    try check(crouch.currentStealth == .hide && director.busy, "\(label): Hide plays its crouching transition")
                    scene.handleTacticalPauseInput()
                    let hidePhase = crouch.currentPhase
                    try await Task.sleep(for: .milliseconds(180))
                    try check(crouch.currentPhase == hidePhase, "\(label): pause freezes the crouching transition")
                    scene.handleTacticalPauseInput()
                    try await wait { !director.busy && crouch.currentStealth == .sneakidle }
                    try check(Set(crouch.definition.appearance.equipment.map(\.item)).isSuperset(of: sneakArmor ? [.lanternShortsword, .splintMail, .ironHelmet] : [.elvenCourtBow, .elvenCourtArrow]), "\(label): crouch retains equipped gear")
                    try check(scene.detective.isHidden && !crouch.isHidden, "\(label): crouched body replaces the standing body")
                    try capture(label + "-hidden")
                    let hidden = director.combat
                    try await openFight(hidden); director = scene.combatDirector!
                    try check(director.combat == hidden, "\(label): reload retains hidden state and enemy facing")
                    try check(director.stealthNodes[hidden.current.id]?.currentStealth == .sneakidle, "\(label): reload restores crouched idle without replaying Hide")
                    if !ranged {
                        var destination: CGPoint?
                        let mover = hidden.current
                        for i in 0..<32 {
                            let angle = Double(i) * .pi / 16
                            let point = CGPoint(x: mover.position.x + cos(angle) * 90, y: mover.position.y + sin(angle) * 90 * 0.75)
                            guard let route = CombatNavigation.route(in: scene.navigation, actor: mover, to: point),
                                  CombatNavigation.length(route, from: mover.position) > 50,
                                  CombatNavigation.length(route, from: mover.position) < 130,
                                  let endpoint = route.destination,
                                  !director.isObserved(mover, at: endpoint) else { continue }
                            destination = point; break
                        }
                        guard let destination else { throw Failure(message: "No hidden movement site") }
                        click(scene, world: destination)
                        try await wait { director.stealthNodes[mover.id]?.currentStealth == .sneakwalk }
                        let walker = director.stealthNodes[mover.id]!
                        let phase = walker.currentPhase
                        try await wait { walker.currentPhase != phase }
                        scene.handleTacticalPauseInput()
                        let position = walker.position, pausedPhase = walker.currentPhase
                        try await Task.sleep(for: .milliseconds(180))
                        try check(walker.position == position && walker.currentPhase == pausedPhase, "Hidden walk pauses its feet and travel together")
                        try capture("stealth-walk")
                        scene.handleTacticalPauseInput()
                        try await wait { !director.busy }
                        try check(walker.currentStealth == .sneakidle && director.combat.current.hidden == true, "Hidden walk returns to crouched idle")
                        try await openFight(hidden); director = scene.combatDirector!
                    }
                    try clickAction("sneak")
                    try check(director.selectingSneakAttack, "\(label): pointer selects Sneak Attack")
                    click(scene, world: site)
                    let strike = director.meleeAttack?.result ?? director.rangedShot?.result
                    try check(strike?.requestedSneakAttack == true && (strike?.sneakDamage ?? 0) > 0,
                              "\(label): accepted attack includes bonus damage")
                    try check(strike?.attackRolls.count == 2 && director.combat.current.hidden != true,
                              "\(label): hidden attack rolls advantage then reveals Voss")
                    let accepted = director.combat
                    try check(GameSession(saveStore: sneakStore).tacticalCombat == accepted && accepted.current.sneakSpent == true,
                              "\(label): accepted bonus use is saved before impact")
                    try check(director.presentedCombat == hidden, "\(label): bonus damage waits for the hit marker")
                    guard let stealthAttack = director.meleeAttack?.actor ?? director.rangedShot?.actor else { throw Failure(message: "Missing stealth attack body") }
                    try check(stealthAttack.currentStealth == (ranged ? .sneakshoot : .sneakstab), "\(label): attack uses its distinct authored clip")
                    try await wait { (director.meleeAttack?.elapsed ?? director.rangedShot?.elapsed ?? 0) > 0.2 }
                    scene.handleTacticalPauseInput()
                    let attackPhase = stealthAttack.currentPhase
                    try await Task.sleep(for: .milliseconds(180))
                    try check(stealthAttack.currentPhase == attackPhase && director.presentedCombat == hidden, "\(label): pause freezes stealth wind-up before damage")
                    try capture(label + "-windup")
                    scene.handleTacticalPauseInput()
                    if let attack = director.meleeAttack {
                        try check(attack.swingTrail == nil, "\(label): downward stab has no sweeping slash trail")
                        try await wait { attack.elapsed >= 6.0 / StealthAnimationSet.fps }
                        scene.handleTacticalPauseInput()
                        let airbornePhase = attack.actor.currentPhase
                        try check((6...8).contains(airbornePhase) && !attack.impactPresented,
                                  "Melee sneak jump reaches its airborne apex before impact")
                        try capture("melee-sneak-airborne")
                        try await Task.sleep(for: .milliseconds(180))
                        try check(attack.actor.currentPhase == airbornePhase, "Pause freezes the airborne jump pose")
                        scene.handleTacticalPauseInput()
                    }
                    if let shot = director.rangedShot {
                        try check(shot.fire.parent == nil, "\(label): explicit Sneak Shot uses an unlit arrow")
                        try await wait { shot.elapsed > 0.3 }; try capture(label + "-draw")
                    }
                    try await wait { director.meleeAttack?.impactPresented == true || director.rangedShot?.impactPresented == true }
                    try check(director.presentedCombat == accepted, "\(label): impact reveals the whole accepted result")
                    try capture(label + "-impact")
                    try await wait { !director.busy }
                    try await openFight(accepted)
                    try check(scene.combatDirector!.combat.current.sneakSpent == true,
                              "\(label): reload cannot grant another Sneak Attack")
                    // An enemy looking at Voss blocks Hide without spending its use.
                    actors[1].combatFacing = ActorFacing.orient(from: site, to: actors[0].position).rawValue
                    let watched = TacticalCombat(encounterID: "gate", areaID: WharfLadderStory.exterior.rawValue, actors: actors, seed: seed)
                    try await openFight(watched); director = scene.combatDirector!
                    let watchedBefore = director.combat
                    try clickAction("hide")
                    try check(director.combat == watchedBefore, "\(label): enemy sight blocks Hide without a cost")
                    try capture(label + "-watched")
                    if ranged {
                        try await openFight(hidden); director = scene.combatDirector!
                        var traversal: (Int, CGPoint)?
                        let player = hidden.actors.first { $0.player }!
                        let enemy = hidden.actors.first { !$0.player }!
                        searchSight: for facing in 0..<16 {
                            var observer = enemy; observer.combatFacing = facing
                            if TacticalCombat.insideSightCone(observer: observer, point: player.position) { continue }
                            for distance in [120.0, 180.0, 240.0] {
                                let angle = Double(facing) * .pi / 8
                                let proposed = CGPoint(x: enemy.position.x - sin(angle) * distance,
                                    y: enemy.position.y - cos(angle) * distance * 0.75)
                                guard let point = scene.navigation.nearestWalkablePoint(to: proposed),
                                    TacticalCombat.insideSightCone(observer: observer, point: point),
                                    !CGRect(x: enemy.position.x - 48, y: enemy.position.y - 20, width: 96, height: 110).contains(point),
                                    CombatNavigation.clearLine(in: scene.navigation, from: enemy.position, to: point,
                                        excluding: hidden.actors.map(\.id)),
                                    let path = CombatNavigation.route(in: scene.navigation, actor: player, to: point),
                                    CombatNavigation.length(path, from: player.position) <= hidden.budget.availableMovement(speed: player.speed) else { continue }
                                traversal = (facing, point); break searchSight
                            }
                        }
                        guard let traversal else { throw Failure(message: "No reachable sight-cone crossing") }
                        var walkingActors = hidden.actors
                        for i in walkingActors.indices where !walkingActors[i].player { walkingActors[i].combatFacing = traversal.0 }
                        let walking = TacticalCombat(encounterID: "gate", areaID: WharfLadderStory.exterior.rawValue,
                            actors: walkingActors, seed: seed)
                        try await openFight(walking); director = scene.combatDirector!
                        try check(director.combat.current.hidden == true && !director.isObserved(director.combat.current, at: director.combat.current.position),
                                  "Hidden walk starts outside enemy sight")
                        // The port certifies a goal cell, whose integral endpoint may differ from the click.
                        guard let endpoint = CombatNavigation.route(in: scene.navigation, actor: director.combat.current, to: traversal.1)?.destination else {
                            throw Failure(message: "Sight-cone crossing lost its certified route")
                        }
                        click(scene, world: traversal.1)
                        try check(director.combat.current.hidden != true, "Crossing enemy sight reveals the hidden mover")
                        try await wait { !director.busy }
                        try check(director.combat.current.position == endpoint,
                                  "Movement reaches its certified endpoint (expected \(endpoint), actual \(director.combat.current.position))")
                        try check(GameSession(saveStore: sneakStore).tacticalCombat?.current.hidden != true,
                                  "Movement exposure is saved")
                        try capture("sight-cone-crossing")
                    }
                    // Staying at the last known position lets the enemy turn and find Voss.
                    try await openFight(hidden); director = scene.combatDirector!
                    director.command(2)
                    try await wait { director.combat.actors.first(where: { $0.player })?.hidden != true }
                    try check(director.combat.log.contains { $0.contains("revealed") }, "\(label): enemy searches last known position and reveals Voss")
                }
                let data = try JSONSerialization.data(withJSONObject: ["passed": true, "checks": checks], options: [.prettyPrinted, .sortedKeys])
                try data.write(to: output.appendingPathComponent("report.json")); NSApp.terminate(nil); return
            }
            if ProcessInfo.processInfo.environment["RAINSHADOW_QA_BURNING_ONLY"] == "1" {
                sawBowDraw = true; sawArrowFlight = true; sawArrowImpact = true
                let fireStore = SaveStore(key: "RainShadow.QA.Burning.\(UUID().uuidString)")
                defer { fireStore.reset() }
                let player = beforeChromeClick.actors.first { $0.player }!
                let enemy = beforeChromeClick.actors.first { !$0.player && $0.id.hasSuffix(".0") }!
                let ignored = Array(scene.navigation.occupancy.actors.keys)
                let site = try beforeChromeClick.liveBarrels.first(where: {
                    CombatNavigation.distance(player.position, $0.position) > TacticalCombat.meleeReach &&
                    CombatNavigation.clearLine(in: scene.navigation, from: player.position, to: $0.position, excluding: ignored)
                }).map { $0.position } ?? { throw Failure(message: "No fire-arrow QA firing lane") }()
                func openFireFight(_ model: TacticalCombat) async throws {
                    fireStore.save(SaveSnapshot(tacticalCombat: try JSONEncoder().encode(model),
                        hasSeenOpening: true, hasCompletedOfficeCaseIntro: true,
                        equippedItems: ["weapon1": .init(id: "elven-court-bow", quantity: 1), "quiver1": .init(id: "elven-court-arrow", quantity: 1)],
                        hasSeededStarterKit: true, hasReceivedArmorKit: true,
                        hasReceivedElvenCourtBow: true, hasReceivedElvenCourtArrow: true))
                    context = GameContext(saveStore: fireStore); context.router.start(in: view)
                    try await wait { (view.scene as? CityDistrictScene)?.context === context && (view.scene as? CityDistrictScene)?.combatDirector != nil }
                    scene = view.scene as! CityDistrictScene
                }
                for playerTarget in [false, true] {
                    let label = playerTarget ? "player" : "enemy"
                    var actors = [player, enemy]
                    actors[0].position = player.position; actors[1].position = site
                    for i in actors.indices {
                        actors[i].hp = 50; actors[i].maximumHP = 50; actors[i].conditions = nil; actors[i].burningTurns = nil
                        actors[i].hidden = nil; actors[i].sneakSpent = nil
                        actors[i].damageMin = 2; actors[i].damageMax = 2; actors[i].attackBonus = 100
                        actors[i].rangedWeapon = .bow; actors[i].usedManeuvers = CombatManeuver.allCases
                        actors[i].initiativeBonus = actors[i].player != playerTarget ? 100 : -100
                    }
                    let victim = actors[playerTarget ? 0 : 1]
                    var fixture: TacticalCombat?
                    for seed in 1...40 {
                        let trial = TacticalCombat(encounterID: "gate", areaID: WharfLadderStory.exterior.rawValue,
                            actors: actors, seed: UInt64(seed))
                        var probe = trial
                        if probe.attack(target: victim.id, clearLine: true, ranged: true)?.damage == 2 { fixture = trial; break }
                    }
                    guard let fixture else { throw Failure(message: "No deterministic hit fixture") }
                    try await openFireFight(fixture)
                    var director = scene.combatDirector!
                    if !playerTarget {
                        try await wait { !director.busy }; director.command(5)
                        click(scene, world: CGPoint(x: victim.position.x, y: victim.position.y + 40))
                    }
                    try await wait { director.rangedShot != nil }
                    let shot = director.rangedShot!, accepted = director.combat
                    try check(accepted.actors.first { $0.id == victim.id }?.burningTurns == 2,
                        "\(label): a hit accepts two burn turns atomically")
                    try check(director.burningNodes[victim.id] == nil && director.presentedCombat == shot.before,
                        "\(label): persistent flames remain hidden before impact")
                    try check(GameSession(saveStore: fireStore).tacticalCombat == accepted,
                        "\(label): in-flight checkpoint already contains the burn")
                    try await wait { shot.impactPresented && (director.hitReactions[victim.id]?.elapsed ?? 0) > 0.1 }
                    let effect = director.burningNodes[victim.id]!
                    try check(effect.parent === director.reactionNodes[victim.id] && !effect.isHidden,
                        "\(label): burning follows the visible hit-reaction body")
                    try check(shot.fire.children.filter { !$0.isHidden && $0.alpha > 0 }.count > 10,
                        "\(label): fire impact presents a short flame burst")
                    scene.handleTacticalPauseInput()
                    let positions = effect.children.map(\.position), alphas = effect.children.map(\.alpha)
                    let saved = director.combat
                    try await Task.sleep(for: .milliseconds(250))
                    try check(effect.children.map(\.position) == positions && effect.children.map(\.alpha) == alphas && director.combat == saved,
                        "\(label): pause freezes flames, smoke and burn state")
                    try capture("burning-" + label + "-impact")
                    if let body = effect.parent, let texture = view.texture(from: body),
                       let data = NSBitmapImageRep(cgImage: texture.cgImage()).representation(using: .png, properties: [:]) {
                        try data.write(to: output.appendingPathComponent("burning-" + label + "-closeup.png"))
                    }
                    scene.handleTacticalPauseInput()
                    try await Task.sleep(for: .milliseconds(35))
                    try capture("burning-" + label + "-colour")
                    try await wait { director.rangedShot == nil && director.hitReactions.isEmpty }
                    try check(effect.parent === (playerTarget ? scene.detective : scene.childNode(withName: "//" + victim.id)),
                        "\(label): flames return to the resting character after recoil")
                    // Reopen the accepted hit while its shooter still owns the turn.
                    // No attack or damage tick is replayed on load.
                    try await openFireFight(accepted); director = scene.combatDirector!
                    try check(director.combat == accepted && director.rangedShot == nil && director.burningNodes[victim.id] != nil,
                        "\(label): reload restores burning without replaying impact or damage")
                    if playerTarget {
                        try await wait { director.combat.isPlayerTurn && !director.busy }
                        try capture("burning-player-idle")
                        if let body = director.burningNodes[victim.id]?.parent,
                           let texture = view.texture(from: body),
                           let data = NSBitmapImageRep(cgImage: texture.cgImage()).representation(using: .png, properties: [:]) {
                            try data.write(to: output.appendingPathComponent("burning-player-idle-closeup.png"))
                        }
                        let hp = director.combat.current.hp
                        director.command(12)
                        try check(!director.combat.current.isBurning && director.burningNodes[victim.id] == nil && !director.combat.budget.canAttack,
                            "Player can extinguish flames for a standard action")
                        try check(director.combat.current.hp == hp && GameSession(saveStore: fireStore).tacticalCombat == director.combat,
                            "Extinguishing deals no damage and checkpoints immediately")
                    }
                }
                // Persistent flames follow walking and expire without real-time HP drain.
                var walkers = [player, enemy]
                walkers[0].position = player.position; walkers[1].position = site
                for i in walkers.indices {
                    walkers[i].hp = 100; walkers[i].maximumHP = 100; walkers[i].burningTurns = i == 0 ? 2 : nil
                    walkers[i].initiativeBonus = i == 0 ? 100 : -100; walkers[i].rangedWeapon = nil
                    walkers[i].usedManeuvers = CombatManeuver.allCases; walkers[i].attackBonus = -100
                }
                try await openFireFight(TacticalCombat(encounterID: "gate", areaID: WharfLadderStory.exterior.rawValue, actors: walkers, seed: 1))
                let walking = scene.combatDirector!
                try await wait { !walking.busy }
                var destination: CGPoint?
                for step in 0..<16 {
                    let angle = Double(step) * .pi / 8
                    let point = CGPoint(x: player.position.x + cos(angle) * 65, y: player.position.y + sin(angle) * 65 * 0.75).rounded
                    if let path = CombatNavigation.route(in: scene.navigation, actor: walking.combat.current, to: point),
                       CombatNavigation.length(path, from: player.position) < 90,
                       CombatNavigation.distance(point, site) > 120 { destination = point; break }
                }
                guard let destination else { throw Failure(message: "No certified burning walk") }
                click(scene, world: destination)
                try await wait { walking.isWalking(player.id) }
                let flame = walking.burningNodes[player.id]!
                try await Task.sleep(for: .milliseconds(160))
                try check(flame.parent === scene.detective && flame.parent!.position != player.position && walking.combat.current.burningTurns == 2,
                    "Burning particles move with the walking player without consuming a turn")
                try await wait { !walking.busy }
                try check(walking.combat.current.hp == 100, "Real-time animation and movement do not tick burn damage")
                for remaining in [1, 0] {
                    walking.command(2)
                    try check((walking.combat.actors.first { $0.player }!.burningTurns ?? 0) == remaining,
                        "Ending an affected turn leaves \(remaining) burn ticks")
                    if remaining == 0 {
                        try check(walking.burningNodes[player.id] == nil && flame.parent == nil,
                            "Natural expiration removes flame and smoke nodes immediately")
                    }
                    try await wait { walking.combat.isPlayerTurn && !walking.busy }
                }
                // At-risk enemies spend an action to extinguish instead of taking avoidable burn damage.
                var actors = [player, enemy]
                actors[0].position = player.position; actors[1].position = site
                actors[0].hp = 50; actors[0].maximumHP = 50; actors[0].initiativeBonus = -100
                actors[1].hp = 4; actors[1].burningTurns = 2; actors[1].initiativeBonus = 100
                actors[1].usedManeuvers = CombatManeuver.allCases; actors[1].rangedWeapon = .bow
                try await openFireFight(TacticalCombat(encounterID: "gate", areaID: WharfLadderStory.exterior.rawValue, actors: actors, seed: 1))
                let director = scene.combatDirector!
                try await wait { !director.combat.current.isBurning }
                try check(!director.combat.budget.canAttack && director.burningNodes[enemy.id] == nil && director.combat.current.hp == 4,
                    "A badly hurt enemy extinguishes instead of spending its action on an attack")
                try JSONSerialization.data(withJSONObject: ["passed": true, "checks": checks], options: [.prettyPrinted, .sortedKeys]).write(to: output.appendingPathComponent("report.json"))
                NSApp.terminate(nil); return
            }
            if ProcessInfo.processInfo.environment["RAINSHADOW_QA_KNOCKBACK_ONLY"] == "1" {
                let motionStore = SaveStore(key: "RainShadow.QA.Knockback.\(UUID().uuidString)")
                defer { motionStore.reset() }
                let player = beforeChromeClick.actors.first { $0.player }!
                let enemy = beforeChromeClick.actors.first { !$0.player && $0.id.hasSuffix(".0") }!
                guard let source = beforeChromeClick.liveBarrels.first(where: {
                    CombatNavigation.clearLine(in: scene.navigation, from: player.position, to: $0.position,
                        excluding: Array(scene.navigation.occupancy.actors.keys))
                }) else { throw Failure(message: "No certified knockback firing lane") }
                let ignored = Array(scene.navigation.occupancy.actors.keys)
                var sites: [CombatReactionKind: CGPoint] = [:]
                for kind in [CombatReactionKind.stumble, .fall] {
                    let distance: Double = kind == .fall ? 70 : 100
                    let awayFromShooter = atan2((source.position.y - player.position.y) / 0.75, source.position.x - player.position.x)
                    for step in 0..<64 {
                        let angle = awayFromShooter + Double(step) * .pi / 32
                        let proposed = CGPoint(x: source.position.x + cos(angle) * distance,
                            y: source.position.y + sin(angle) * distance * 0.75).rounded
                        guard let point = scene.navigation.nearestWalkablePoint(to: proposed),
                              abs(CombatNavigation.distance(point, source.position) - distance) < 8,
                              CombatNavigation.clearLine(in: scene.navigation, from: source.position, to: point, excluding: ignored) else { continue }
                        var victim = enemy; victim.position = point
                        let end = CombatNavigation.knockbackDestination(in: scene.navigation, actor: victim,
                            awayFrom: source.position, actors: [player, victim], destroyedBarrels: beforeChromeClick.liveBarrels.map(\.id))
                        guard CombatNavigation.distance(point, end) >= 60 else { continue }
                        sites[kind] = point; break
                    }
                    try check(sites[kind] != nil, "Certified space exists for \(kind.rawValue) QA")
                }
                for playerTarget in [false, true] { for kind in [CombatReactionKind.stumble, .fall] {
                    let label = "\(playerTarget ? "player" : "enemy")-\(kind.rawValue)"
                    var actors = [player, enemy]
                    actors[0].position = playerTarget ? sites[kind]! : player.position
                    actors[1].position = playerTarget ? player.position : sites[kind]!
                    for i in actors.indices {
                        actors[i].hp = 100; actors[i].maximumHP = 100; actors[i].conditions = nil
                        actors[i].rangedWeapon = .bow; actors[i].usedManeuvers = CombatManeuver.allCases
                        actors[i].initiativeBonus = actors[i].player != playerTarget ? 100 : -100
                    }
                    let victim = actors[playerTarget ? 0 : 1]
                    let fight = TacticalCombat(encounterID: "gate", areaID: WharfLadderStory.exterior.rawValue,
                        actors: actors, seed: 42, barrels: [source])
                    var equipment: [String: PersistedCarriedItemStack] = ["weapon1": .init(id: playerTarget ? "lantern-shortsword" : "elven-court-bow", quantity: 1)]
                    if playerTarget { equipment["coat"] = .init(id: "splint-mail", quantity: 1); equipment["fedora"] = .init(id: "iron-helmet", quantity: 1) }
                    else { equipment["quiver1"] = .init(id: "elven-court-arrow", quantity: 1) }
                    motionStore.save(SaveSnapshot(tacticalCombat: try JSONEncoder().encode(fight), hasSeenOpening: true,
                        hasCompletedOfficeCaseIntro: true, equippedItems: equipment, hasSeededStarterKit: true,
                        hasReceivedArmorKit: true, hasReceivedElvenCourtBow: true, hasReceivedElvenCourtArrow: true))
                    context = GameContext(saveStore: motionStore); context.router.start(in: view)
                    try await wait { (view.scene as? CityDistrictScene)?.context === context && (view.scene as? CityDistrictScene)?.combatDirector != nil }
                    scene = view.scene as! CityDistrictScene
                    let director = scene.combatDirector!
                    if !playerTarget {
                        try await wait { !director.busy }
                        scene.handleDialogueChoiceDigit(5)
                        click(scene, world: CGPoint(x: source.position.x, y: source.position.y + 30))
                    }
                    try await wait { director.rangedShot != nil }
                    let shot = director.rangedShot!, accepted = director.combat
                    try await wait { (director.hitReactions[victim.id]?.elapsed ?? 0) >= 0.18 }
                    let reaction = director.hitReactions[victim.id]!, node = director.reactionNodes[victim.id]!
                    try check(reaction.kind == kind && node.currentReaction == kind && node.currentPhase > 0,
                              "\(label): blast selects and plays its authored recovery")
                    let move = shot.displacements.first { $0.id == victim.id }!
                    try check(abs(reaction.elapsed - director.knockbackElapsed) < 0.000001,
                              "\(label): physical shove and pose share the impact clock")
                    try check(node.position == ExplosionKnockbackMotion.position(from: move.from, to: move.to, elapsed: director.knockbackElapsed),
                              "\(label): animated body follows physical displacement")
                    if playerTarget { try check(Set(node.definition.appearance.equipment.map(\.item)) == [.lanternShortsword, .splintMail, .ironHelmet], "\(label): armor and sword follow the fall") }
                    scene.handleTacticalPauseInput()
                    let elapsed = reaction.elapsed, phase = node.currentPhase, point = node.position
                    scene.handleConfirmInput()
                    try await Task.sleep(for: .milliseconds(200))
                    try check(director.hitReactions[victim.id]?.elapsed == elapsed && node.currentPhase == phase && node.position == point && director.combat == accepted,
                              "\(label): pause freezes body, movement and turn state")
                    try capture("knockback-" + label + "-impact")
                    scene.handleTacticalPauseInput()
                    try await wait { director.knockbacks.isEmpty }
                    try check(director.hitReactions[victim.id] != nil && director.busy && node.position == move.to,
                              "\(label): character regains balance after movement stops")
                    try capture("knockback-" + label + "-recovery")
                    if let texture = view.texture(from: node), let data = NSBitmapImageRep(cgImage: texture.cgImage()).representation(using: .png, properties: [:]) {
                        try data.write(to: output.appendingPathComponent("closeup-" + label + ".png"))
                    }
                    // Inspect the accepted event before the enemy's normal
                    // post-animation turn progression can advance initiative.
                    try await wait { director.hitReactions.isEmpty && director.knockbacks.isEmpty && director.rangedShot == nil }
                    let original: SKNode = playerTarget ? scene.detective : scene.childNode(withName: "//" + victim.id)!
                    try check(node.isHidden && !original.isHidden && original.position == move.to,
                              "\(label): recovery restores the original actor at the saved endpoint")
                    try check(director.combat == accepted && GameSession(saveStore: motionStore).tacticalCombat == accepted,
                              "\(label): motion adds no damage, conditions or action cost")
                    context = GameContext(saveStore: motionStore); context.router.start(in: view)
                    try await wait { (view.scene as? CityDistrictScene)?.context === context && (view.scene as? CityDistrictScene)?.combatDirector != nil }
                    scene = view.scene as! CityDistrictScene
                    try check(scene.combatDirector!.combat == accepted && scene.combatDirector!.hitReactions.isEmpty && scene.combatDirector!.knockbacks.isEmpty,
                              "\(label): reload does not replay the shove or fall")
                } }
                try JSONSerialization.data(withJSONObject: ["passed": true, "checks": checks], options: [.prettyPrinted, .sortedKeys]).write(to: output.appendingPathComponent("report.json"))
                NSApp.terminate(nil); return
            }
            if ProcessInfo.processInfo.environment["RAINSHADOW_QA_REACTIONS_ONLY"] == "1" {
                let reactionStore = SaveStore(key: "RainShadow.QA.Reactions.\(UUID().uuidString)")
                defer { reactionStore.reset() }
                let player = beforeChromeClick.actors.first { $0.player }!
                let enemy = beforeChromeClick.actors.first { !$0.player && $0.id.hasSuffix(".0") }!
                for enemyAttacks in [false, true] { for ranged in [false, true] { for miss in [false, true] {
                    let label = "\(enemyAttacks ? "enemy" : "player")-\(ranged ? "bow" : "sword")-\(miss ? "miss" : "hit")"
                    var actors = [player, enemy]
                    let distance: Double = ranged ? 210 : 85
                    var site: CGPoint?
                    for i in 0..<32 {
                        let a = Double(i) * .pi / 16
                        let proposed = CGPoint(x: player.position.x + cos(a) * distance, y: player.position.y + sin(a) * distance * 0.75).rounded
                        guard let point = scene.navigation.nearestWalkablePoint(to: proposed),
                              abs(CombatNavigation.distance(player.position, point) - distance) < 16,
                              CombatNavigation.clearLine(in: scene.navigation, from: player.position, to: point,
                                excluding: Array(scene.navigation.occupancy.actors.keys)) else { continue }
                        site = point; break
                    }
                    guard let site else { throw Failure(message: "No reaction QA position") }
                    actors[1].position = site
                    for i in actors.indices {
                        actors[i].hp = 100; actors[i].maximumHP = 100
                        actors[i].attackBonus = miss ? -100 : 100; actors[i].defence = miss ? 1000 : 1
                        actors[i].damageMin = 4; actors[i].damageMax = 4
                        actors[i].rangedWeapon = ranged ? .bow : nil
                        actors[i].usedManeuvers = CombatManeuver.allCases
                        actors[i].initiativeBonus = actors[i].player != enemyAttacks ? 100 : -100
                    }
                    let victim = actors[enemyAttacks ? 0 : 1]
                    var seed: UInt64 = 1
                    var model: TacticalCombat
                    while true {
                        model = TacticalCombat(encounterID: "gate", areaID: WharfLadderStory.exterior.rawValue, actors: actors, seed: seed)
                        var trial = model
                        if let result = trial.attack(target: victim.id, clearLine: true, ranged: ranged), (result.damage == 0) == miss { break }
                        seed += 1
                    }
                    var equipment: [String: PersistedCarriedItemStack] = ["weapon1": .init(id: ranged ? "elven-court-bow" : "lantern-shortsword", quantity: 1)]
                    if ranged { equipment["quiver1"] = .init(id: "elven-court-arrow", quantity: 1) }
                    if !ranged { equipment["fedora"] = .init(id: "iron-helmet", quantity: 1); equipment["coat"] = .init(id: "splint-mail", quantity: 1) }
                    reactionStore.save(SaveSnapshot(tacticalCombat: try JSONEncoder().encode(model), hasSeenOpening: true,
                        hasCompletedOfficeCaseIntro: true, equippedItems: equipment, hasSeededStarterKit: true,
                        hasReceivedArmorKit: true, hasReceivedElvenCourtBow: true, hasReceivedElvenCourtArrow: true))
                    context = GameContext(saveStore: reactionStore); context.router.start(in: view)
                    try await wait { (view.scene as? CityDistrictScene)?.context === context && (view.scene as? CityDistrictScene)?.combatDirector != nil }
                    scene = view.scene as! CityDistrictScene
                    let director = scene.combatDirector!
                    if !enemyAttacks {
                        try await wait { !director.busy }
                        if ranged { scene.handleDialogueChoiceDigit(5) }
                        click(scene, world: victim.position)
                    }
                    try await wait { director.meleeAttack != nil || director.rangedShot != nil }
                    let accepted = director.combat
                    try await wait { director.hitReactions[victim.id] != nil }
                    let reaction = director.hitReactions[victim.id]!
                    let node = director.reactionNodes[victim.id]!
                    try check(reaction.kind == (miss ? .dodge : .hit) && node.currentReaction == reaction.kind && !node.isHidden,
                              "\(label): correct authored reaction is visible")
                    if miss {
                        try check(!(director.meleeAttack?.impactPresented ?? director.rangedShot?.impactPresented ?? true), "\(label): dodge starts before impact")
                        try check(accepted.actors.first { $0.id == victim.id }!.hp == victim.hp, "\(label): evasion does not apply damage")
                    }
                    try await wait { (director.hitReactions[victim.id]?.phase ?? 0) >= 2 }
                    let clock = director.hitReactions[victim.id]!.elapsed, phase = node.currentPhase
                    try check(Set(node.definition.appearance.equipment.map(\.item)) == (enemyAttacks
                        ? (ranged ? Set([.elvenCourtBow, .elvenCourtArrow]) : Set([.lanternShortsword, .ironHelmet, .splintMail]))
                        : Set((scene.childNode(withName: "//" + victim.id) as! CharacterAppearanceNode).definition.appearance.equipment.map(\.item))),
                              "\(label): reaction retains equipped layers")
                    scene.handleTacticalPauseInput()
                    try await Task.sleep(for: .milliseconds(200))
                    try check(director.hitReactions[victim.id]?.elapsed == clock && node.currentPhase == phase, "\(label): pause freezes reaction")
                    try capture("reaction-" + label)
                    if let texture = view.texture(from: node), let data = NSBitmapImageRep(cgImage: texture.cgImage()).representation(using: .png, properties: [:]) {
                        try data.write(to: output.appendingPathComponent("closeup-" + label + ".png"))
                    }
                    scene.handleTacticalPauseInput()
                    try await wait { director.hitReactions.isEmpty && director.meleeAttack == nil && director.rangedShot == nil }
                    try check(node.isHidden && node.childNode(withName: "appearance.body")!.zRotation == 0, "\(label): reaction resets and hides after recovery")
                    let original: SKNode = victim.player ? scene.detective : scene.childNode(withName: "//" + victim.id)!
                    try check(!original.isHidden && original.position == victim.position, "\(label): original actor is restored without movement")
                    try check(director.combat == accepted && GameSession(saveStore: reactionStore).tacticalCombat == accepted,
                              "\(label): presentation preserves accepted and saved outcome")
                } } }
                try JSONSerialization.data(withJSONObject: ["passed": true, "checks": checks], options: [.prettyPrinted, .sortedKeys]).write(to: output.appendingPathComponent("report.json"))
                NSApp.terminate(nil); return
            }
            if ProcessInfo.processInfo.environment["RAINSHADOW_QA_MANEUVERS_ONLY"] == "1" {
                let techniqueStore = SaveStore(key: "RainShadow.QA.Techniques.\(UUID().uuidString)")
                defer { techniqueStore.reset() }
                let originalPlayer = beforeChromeClick.actors.first { $0.player }!
                let originalEnemy = beforeChromeClick.actors.first { !$0.player && $0.id.hasSuffix(".0") }!
                for enemyUsesMove in [false, true] {
                    for (index, technique) in CombatManeuver.allCases.filter({ $0 != .tripAttack }).enumerated() {
                        let label = "\(enemyUsesMove ? "enemy" : "player")-\(technique.rawValue)"
                        var actors = [originalPlayer, originalEnemy]
                        var site: CGPoint?
                        let distance: Double = technique.ranged ? 210 : 85
                        for i in 0..<32 {
                            let angle = Double(i) * .pi / 16
                            let proposed = CGPoint(x: originalPlayer.position.x + cos(angle) * distance,
                                y: originalPlayer.position.y + sin(angle) * distance * 0.75).rounded
                            guard let point = scene.navigation.nearestWalkablePoint(to: proposed),
                                abs(CombatNavigation.distance(originalPlayer.position, point) - distance) < 16,
                                CombatNavigation.clearLine(in: scene.navigation, from: originalPlayer.position, to: point,
                                    excluding: Array(scene.navigation.occupancy.actors.keys)) else { continue }
                            site = point; break
                        }
                        guard let site else { throw Failure(message: "No technique test position") }
                        actors[1].position = site
                        for i in actors.indices {
                            actors[i].hp = 100; actors[i].maximumHP = 100
                            actors[i].attackBonus = technique == .feintingCut || technique == .aimedShot ? 8 : 100
                            actors[i].defence = technique == .feintingCut || technique == .aimedShot ? 17 : 1
                            actors[i].damageMin = 8; actors[i].damageMax = 8
                            actors[i].rangedWeapon = technique.ranged || actors[i].player ? .bow : nil
                            actors[i].conditions = nil; actors[i].usedManeuvers = nil
                            actors[i].initiativeBonus = actors[i].player != enemyUsesMove ? 100 : -100
                        }
                        let victim = actors[enemyUsesMove ? 0 : 1]
                        var seed: UInt64 = 1
                        var model: TacticalCombat
                        while true {
                            model = TacticalCombat(encounterID: "gate", areaID: WharfLadderStory.exterior.rawValue, actors: actors, seed: seed)
                            var trial = model
                            if trial.attack(target: victim.id, clearLine: true, ranged: technique.ranged, maneuver: technique, hasSword: true)?.damage ?? 0 > 0 { break }
                            seed += 1
                        }
                        if enemyUsesMove {
                            try check(model.preferredManeuver(target: victim, ranged: technique.ranged, hasSword: true) == technique,
                                      "\(label): tactical situation selects the expected technique")
                        }
                        techniqueStore.save(SaveSnapshot(tacticalCombat: try JSONEncoder().encode(model),
                            hasSeenOpening: true, hasCompletedOfficeCaseIntro: true,
                            equippedItems: ["weapon1": .init(id: "lantern-shortsword", quantity: 1)],
                            hasSeededStarterKit: true, hasReceivedArmorKit: true,
                            hasReceivedElvenCourtBow: true, hasReceivedElvenCourtArrow: true))
                        context = GameContext(saveStore: techniqueStore); context.router.start(in: view)
                        try await wait { (view.scene as? CityDistrictScene)?.context === context && (view.scene as? CityDistrictScene)?.combatDirector != nil }
                        scene = view.scene as! CityDistrictScene
                        let director = scene.combatDirector!
                        // The scene migrates legacy checkpoints with persisted facing.
                        model = director.combat
                        if !enemyUsesMove {
                            try await wait { !director.busy }
                            let before = director.combat
                            scene.handleDialogueChoiceDigit(index + 6)
                            try check(director.selectedManeuver == technique && director.combat == before, "\(label): selecting spends nothing")
                            scene.handleCancelInput()
                            try check(director.selectedManeuver == nil && director.combat == before, "\(label): Escape cancels targeting without spending")
                            guard let button = scene.childNode(withName: "//combat." + technique.rawValue) else { throw Failure(message: "Missing technique button") }
                            let position = scene.convert(.zero, from: button)
                            let event = GamePointerEvent(location: position, kind: .mouse)
                            scene.handlePointerDown(event); scene.handlePointerUp(event)
                            try check(director.selectedManeuver == technique, "\(label): action bar accepts pointer input")
                            try capture(label + "-targeting")
                            if technique == .feintingCut {
                                view.window?.setContentSize(CGSize(width: 720, height: 900))
                                try await Task.sleep(for: .milliseconds(250))
                                try capture("compact-techniques")
                                let controls = CombatManeuver.allCases.compactMap { scene.childNode(withName: "//combat." + $0.rawValue) }
                                try check(controls.count == 4 && controls.allSatisfy {
                                    let point = view.convert(scene.convert(.zero, from: $0), from: scene)
                                    return view.bounds.contains(point)
                                }, "Compact action bar keeps all four techniques on screen")
                                view.window?.setContentSize(CGSize(width: 1100, height: 800))
                                try await Task.sleep(for: .milliseconds(250))
                            }
                            click(scene, world: victim.position)
                        }
                        try await wait { director.meleeAttack != nil || director.rangedShot != nil }
                        let strike = director.meleeAttack?.result ?? director.rangedShot!.result
                        try check(strike.maneuver == technique && strike.damage > 0, "\(label): presentation carries the accepted technique")
                        let accepted = director.combat
                        try check(accepted.current.usedManeuvers == [technique], "\(label): exactly one use is spent")
                        try check(GameSession(saveStore: techniqueStore).tacticalCombat == accepted, "\(label): outcome and use are saved before impact")
                        try check(director.presentedCombat == model, "\(label): damage and conditions wait for impact")
                        scene.handleTacticalPauseInput()
                        let elapsed = director.meleeAttack?.elapsed ?? director.rangedShot!.elapsed
                        try await Task.sleep(for: .milliseconds(180))
                        try check((director.meleeAttack?.elapsed ?? director.rangedShot!.elapsed) == elapsed, "\(label): pause freezes the technique")
                        scene.handleTacticalPauseInput()
                        try await wait { (director.meleeAttack?.elapsed ?? director.rangedShot?.elapsed ?? 0) >= 0.1 }
                        let motionActor = director.meleeAttack?.actor ?? director.rangedShot!.actor
                        try check(motionActor.currentTechnique == technique, "\(label): plays its distinct technique motion")
                        if let shot = director.rangedShot {
                            if technique == .aimedShot {
                                try await wait { shot.elapsed >= 0.8 }
                                try check(shot.actor.currentPhase == 9 && shot.arrow.isHidden && !shot.impactPresented,
                                          "\(label): holds full draw before the later release")
                                try capture(label + "-steady-aim")
                            } else {
                                try await wait { shot.elapsed >= 0.45 }
                                try capture(label + "-lowered-aim")
                                try check(shot.origin.y < shot.actor.position.y + BowAttackAnimationSet.muzzleOffset(facing: shot.facing).y + shot.actor.visualHeightOffset,
                                          "\(label): arrow starts at the lowered bow")
                            }
                        } else if let attack = director.meleeAttack {
                            try await wait { attack.elapsed >= (technique == .powerStrike ? 0.34 : 0.2) }
                            try capture(label + "-windup")
                            try check(attack.impactTime == WeaponTechniqueMotion.meleeImpact(technique),
                                      "\(label): damage follows the authored hit marker")
                        }
                        try await wait { director.meleeAttack?.impactPresented == true || director.rangedShot?.impactPresented == true }
                        try check(director.presentedCombat == accepted, "\(label): impact reveals accepted damage and conditions")
                        let condition = accepted.actors.first { $0.id == victim.id }?.conditions
                        try check((condition?.weakened == true) == (technique == .feintingCut)
                            && (condition?.slowed == true) == (technique == .pinningShot), "\(label): correct condition is applied")
                        if technique.ranged { try check(director.rangedShot?.fire.parent == nil, "\(label): technique uses an ordinary arrow") }
                        if technique == .aimedShot { try check(accepted.budget.availableMovement(speed: 240) == 0, "\(label): aimed shot uses the full turn") }
                        try capture(label + "-impact")
                        try await wait { (director.hitReactions[victim.id]?.elapsed ?? 0) >= 0.08 }
                        let recoil = director.hitReactions[victim.id]!
                        let reactionNode = director.reactionNodes[victim.id]!
                        let hitBody = reactionNode.childNode(withName: "appearance.body")!
                        try check(!reactionNode.isHidden && reactionNode.currentReaction == .hit && reactionNode.currentPhase > 0,
                                  "\(label): authored flinch reaches the visible body")
                        try check(abs(Double(hitBody.zRotation) - recoil.angle) < 0.00001,
                                  "\(label): recoil reaches the visible body")
                        if victim.player {
                            try check(scene.detective.childNode(withName: "//detective.equippedWeapon")!.zRotation == 0,
                                      "\(label): equipped weapon inherits the body lean once")
                        }
                        try check(abs(recoil.angle) > 0 && (recoil.strength > 1) == (technique == .powerStrike),
                                  "\(label): impact recoils, with a stronger power stagger")
                        try check(director.combat.actors.first { $0.id == victim.id }?.position == victim.position,
                                  "\(label): recoil preserves the navigation position")
                        scene.handleTacticalPauseInput()
                        try await Task.sleep(for: .milliseconds(180))
                        try check(director.hitReactions[victim.id]?.elapsed == recoil.elapsed,
                                  "\(label): pause freezes the impact reaction")
                        try capture(label + "-recoil")
                        scene.handleTacticalPauseInput()
                        try await wait { director.meleeAttack == nil && director.rangedShot == nil && director.hitReactions.isEmpty }
                        try check(hitBody.zRotation == 0, "\(label): visible body returns exactly to neutral")
                        try check(director.selectedManeuver == nil, "\(label): targeting clears after the strike")
                        if !enemyUsesMove {
                            context = GameContext(saveStore: techniqueStore); context.router.start(in: view)
                            try await wait { (view.scene as? CityDistrictScene)?.context === context && (view.scene as? CityDistrictScene)?.combatDirector != nil }
                            scene = view.scene as! CityDistrictScene
                            try check(scene.combatDirector!.combat == accepted, "\(label): reload preserves the spent technique and condition")
                        }
                    }
                }
                let data = try JSONSerialization.data(withJSONObject: ["passed": true, "checks": checks], options: [.prettyPrinted, .sortedKeys])
                try data.write(to: output.appendingPathComponent("report.json")); NSApp.terminate(nil); return
            }
            if ProcessInfo.processInfo.environment["RAINSHADOW_QA_MELEE_ONLY"] == "1" {
                let meleeStore = SaveStore(key: "RainShadow.QA.Melee.\(UUID().uuidString)")
                defer { meleeStore.reset() }
                let player = beforeChromeClick.actors.first { $0.player }!
                var opponent = beforeChromeClick.actors.first { !$0.player && $0.id.hasSuffix(".0") }!
                let ignored = beforeChromeClick.actors.map(\.id)
                var site: CGPoint?
                for i in 0..<32 {
                    let angle = Double(i) * .pi / 16
                    let proposed = CGPoint(x: player.position.x + cos(angle) * 85,
                                           y: player.position.y + sin(angle) * 85 * 0.75).rounded
                    guard let point = scene.navigation.nearestWalkablePoint(to: proposed),
                        (65...100).contains(CombatNavigation.distance(player.position, point)),
                        CombatNavigation.clearLine(in: scene.navigation, from: player.position, to: point, excluding: ignored) else { continue }
                    site = point; break
                }
                guard let site else { throw Failure(message: "No melee QA position") }
                opponent.position = site; opponent.rangedWeapon = nil
                for mode in ["sword", "armored", "unarmed", "miss", "knockout", "enemy"] {
                    var actors = [player, opponent]
                    for i in actors.indices {
                        actors[i].hp = 100; actors[i].maximumHP = 100
                        actors[i].attackBonus = 100; actors[i].defence = 1
                        actors[i].damageMin = 4; actors[i].damageMax = 4
                        actors[i].initiativeBonus = actors[i].player == (mode != "enemy") ? 100 : -100
                    }
                    if mode == "miss" { actors[1].defence = 1000; actors[0].attackBonus = -100 }
                    if mode == "knockout" { actors[1].hp = 1 }
                    var seed: UInt64 = 1
                    var model: TacticalCombat
                    while true {
                        model = TacticalCombat(encounterID: "gate", areaID: WharfLadderStory.exterior.rawValue, actors: actors, seed: seed)
                        var trial = model
                        let targetID = mode == "enemy" ? player.id : opponent.id
                        let result = trial.attack(target: targetID, clearLine: true)!
                        if (result.damage == 0) == (mode == "miss") { break }
                        seed += 1
                    }
                    var equipment: [String: PersistedCarriedItemStack] = [:]
                    if mode != "unarmed" { equipment["weapon1"] = .init(id: "lantern-shortsword", quantity: 1) }
                    if mode == "armored" {
                        equipment["fedora"] = .init(id: "iron-helmet", quantity: 1)
                        equipment["coat"] = .init(id: "splint-mail", quantity: 1)
                    }
                    meleeStore.save(SaveSnapshot(tacticalCombat: try JSONEncoder().encode(model),
                        hasSeenOpening: true, hasCompletedOfficeCaseIntro: true, equippedItems: equipment,
                        hasSeededStarterKit: true, hasReceivedArmorKit: true,
                        hasReceivedElvenCourtBow: true, hasReceivedElvenCourtArrow: true))
                    context = GameContext(saveStore: meleeStore); context.router.start(in: view)
                    try await wait { (view.scene as? CityDistrictScene)?.context === context && (view.scene as? CityDistrictScene)?.combatDirector != nil }
                    scene = view.scene as! CityDistrictScene
                    guard let director = scene.combatDirector else { throw Failure(message: "No melee director") }
                    if mode != "enemy" {
                        try await wait { !director.busy }
                        click(scene, world: opponent.position)
                    }
                    try await wait { director.meleeAttack != nil }
                    guard let attack = director.meleeAttack else { throw Failure(message: "No melee presentation") }
                    try check(attack.actor.currentAction == .attack && director.busy, "\(mode): strike plays and locks the turn")
                    let items = Set(attack.actor.definition.appearance.equipment.map(\.item))
                    try check(items.contains(.lanternShortsword) == (mode != "unarmed"), "\(mode): readied weapon matches the animated layer")
                    if mode == "armored" { try check(items.contains(.ironHelmet) && items.contains(.splintMail), "Armor remains equipped throughout the swing") }
                    try await wait { attack.elapsed >= 0.15 }
                    try check(!attack.impactPresented && director.presentedCombat == attack.before,
                              "\(mode): wind-up hides accepted damage")
                    try check(GameSession(saveStore: meleeStore).tacticalCombat == director.combat,
                              "\(mode): save already contains the accepted outcome")
                    let accepted = director.combat
                    scene.handleConfirmInput(); click(scene, world: opponent.position)
                    try check(director.combat == accepted, "\(mode): input cannot interrupt or repeat the strike")
                    scene.handleTacticalPauseInput()
                    let elapsed = attack.elapsed, phase = attack.actor.currentPhase
                    try check(attack.swingTrail?.sprite.isHidden != false,
                              "\(mode): the trail stays off during wind-up")
                    try await Task.sleep(for: .milliseconds(180))
                    try check(attack.elapsed == elapsed && attack.actor.currentPhase == phase,
                              "\(mode): pause freezes the attack pose and hit marker")
                    try capture("melee-\(mode)-windup")
                    scene.handleTacticalPauseInput()
                    try await wait { attack.impactPresented }
                    try check(director.presentedCombat == director.combat && director.busy,
                              "\(mode): damage appears at impact while recovery still locks input")
                    try check((attack.result.damage == 0) == (mode == "miss"), "\(mode): hit or miss follows the accepted roll")
                    let trail = attack.swingTrail?.sprite
                    try check((trail != nil) == (mode != "unarmed"),
                              "\(mode): only a held sword gets a blade trail")
                    if let trail {
                        try check(!trail.isHidden && trail.texture != nil && trail.parent === attack.actor,
                                  "\(mode): the blade trail is visible at impact")
                        try check(trail.shader === trail.blitShader && trail.zPosition < 0,
                                  "\(mode): the trail keeps actor lighting and passes behind the body")
                        let trailTexture = trail.texture, trailAlpha = trail.alpha
                        let time = attack.elapsed
                        scene.handleTacticalPauseInput()
                        try await Task.sleep(for: .milliseconds(180))
                        try check(attack.elapsed == time && trail.texture === trailTexture && trail.alpha == trailAlpha,
                                  "\(mode): pause freezes the visible trail and its fade")
                        scene.handleTacticalPauseInput()
                    }
                    try capture("melee-\(mode)-impact")
                    if mode == "armored", let texture = view.texture(from: attack.actor),
                       let data = NSBitmapImageRep(cgImage: texture.cgImage()).representation(using: .png, properties: [:]) {
                        try data.write(to: output.appendingPathComponent("swing-closeup.png"))
                    }
                    try await wait { attack.elapsed >= WeaponTechniqueMotion.trailEnd(attack.result.maneuver) / WeaponTechniqueMotion.meleeFPS(attack.result.maneuver) + SwordSwingPath.fadeDuration + 0.02 }
                    try check(trail?.isHidden != false, "\(mode): the trail fades before recovery ends")
                    try await wait { director.meleeAttack == nil }
                    try check(attack.actor.currentAction == .idle && trail?.parent == nil,
                              "\(mode): recovery returns to idle and removes the trail")
                    if mode != "enemy" { try check(!scene.detective.isHidden, "\(mode): player body is restored") }
                    if mode == "sword" {
                        let saved = GameSession(saveStore: meleeStore).tacticalCombat!
                        context = GameContext(saveStore: meleeStore); context.router.start(in: view)
                        try await wait { (view.scene as? CityDistrictScene)?.context === context && (view.scene as? CityDistrictScene)?.combatDirector != nil }
                        scene = view.scene as! CityDistrictScene
                        try check(scene.combatDirector?.combat == saved && scene.combatDirector?.meleeAttack == nil,
                                  "Reload does not repeat an accepted sword strike")
                    }
                }
                try JSONSerialization.data(withJSONObject: ["passed": true, "checks": checks], options: [.prettyPrinted, .sortedKeys]).write(to: output.appendingPathComponent("report.json"))
                NSApp.terminate(nil)
                return
            }
            if ProcessInfo.processInfo.environment["RAINSHADOW_QA_BARRELS_ONLY"] != "1" {
            for point in [HUDChromeLayout.leftRailLayout(for: scene.size).plateCenter,
                          HUDChromeLayout.rightRailLayout(for: scene.size).plateCenter] {
                let location = scene.convert(point, from: scene.hudRoot)
                scene.handlePointerUp(GamePointerEvent(location: location, kind: .mouse))
            }
            try check(scene.combatDirector!.combat == beforeChromeClick && !scene.combatDirector!.busy,
                      "Sidebar clicks cannot issue ground movement")
            scene.handleDialogueChoiceDigit(1)
            try check(scene.combatDirector!.combat.current.defending, "Defend spends a standard action and raises guard")
            let savedGuard = scene.combatDirector!.combat
            let reloadSession = GameSession(saveStore: store)
            try check(reloadSession.tacticalCombat == savedGuard, "SaveStore persists complete tactical state")
            scene.handleConfirmInput()
            scene.handleTacticalPauseInput()
            let paused = scene.combatDirector!.combat
            try await Task.sleep(for: .seconds(1))
            try check(scene.combatDirector!.combat == paused, "Pause freezes enemy turns")
            scene.handleTacticalPauseInput()
            try await wait { scene.combatDirector?.combat.isPlayerTurn == true && scene.combatDirector?.busy == false }
            // Move away on the real raster so enemy approach and walk animation are exercised.
            let model = scene.combatDirector!.combat
            var moved = false
            for i in 0..<16 {
                let angle = CGFloat(i) * .pi / 8
                let point = CGPoint(x: model.current.position.x + cos(angle) * 150,
                                    y: model.current.position.y + sin(angle) * 150 * 0.75)
                var candidate = model.current
                candidate.position = point
                guard BearFormRules.canStand(in: scene.navigation, actor: candidate),
                    !model.actors.filter({ !$0.player }).contains(where: {
                    CGRect(x: $0.position.x - 48, y: $0.position.y - 20, width: 96, height: 110).contains(point)
                }), let path = CombatNavigation.route(in: scene.navigation, actor: model.current, to: point),
                    CombatNavigation.length(path, from: model.current.position) <= 240 else { continue }
                click(scene, world: point)
                if scene.combatDirector!.busy { moved = true; break }
            }
            try check(moved, "Ground click starts a budgeted move")
            try await wait { scene.combatDirector?.busy == false }
            try check(scene.combatDirector!.combat.budget.state == 2, "Walking preserves the standard attack action")
            let humanEquipment = context.session.characterInventory
            scene.handleDialogueChoiceDigit(4)
            try check(scene.combatDirector!.combat.isBear && scene.combatDirector!.combat.budget.state == 0,
                      "Bear Form input consumes the standard action after walking")
            try await Task.sleep(for: .milliseconds(420))
            try capture("bear-transforming")
            scene.handleTacticalPauseInput()
            let transformation = scene.depthWorldRoot.childNode(withName: "combat.bear.transformation") as? BearTransformationEffect
            let particlePositions = transformation?.children.map(\.position)
            try await Task.sleep(for: .milliseconds(250))
            try check(particlePositions == transformation?.children.map(\.position), "Pause freezes transformation particles")
            try check(transformation?.soundIsPlaying == false, "Pause freezes transformation audio")
            scene.handleTacticalPauseInput()
            for (stage, threshold) in [("reveal", 0.76), ("impact", 1.04), ("settle", 1.32)] {
                try await wait { (transformation?.elapsed ?? 0) >= threshold }
                try capture("bear-" + stage)
                if stage == "reveal" {
                    try check(scene.combatDirector?.bearNode?.currentAction == .revert,
                        "Emergence reverses the authored bear crouch")
                }
            }
            try await wait { scene.combatDirector?.busy == false }
            try check(scene.detective.alpha == 1 && scene.combatDirector?.bearNode?.alpha == 1
                && scene.combatDirector?.bearNode?.visualHeightOffset == scene.detective.visualHeightOffset,
                "Transformation restores opacity and ground registration")
            try check(transformation?.parent == nil && transformation?.soundIsPlaying == false,
                "Transformation removes particles and stops its audio")
            try check(scene.detective.isHidden && scene.combatDirector?.bearNode?.isHidden == false,
                      "Transformation displays the bear and hides human equipment layers")
            try check(scene.navigation.occupancy.actors[TacticalCombat.playerID]?.personalSpaceCells == BearFormRules.circleSize,
                      "Bear registers its larger occupancy footprint")
            try capture("bear-ready")
            let bearBeforeMove = scene.combatDirector!.combat
            var bearMoved = false
            for i in 0..<16 {
                let angle = CGFloat(i) * .pi / 8
                let point = CGPoint(x: bearBeforeMove.current.position.x + cos(angle) * 44,
                                    y: bearBeforeMove.current.position.y + sin(angle) * 44 * 0.75)
                guard let path = CombatNavigation.route(in: scene.navigation, actor: bearBeforeMove.current, to: point, bear: true),
                      CombatNavigation.length(path, from: bearBeforeMove.current.position) <= bearBeforeMove.budget.movementRemaining else { continue }
                click(scene, world: point)
                if scene.combatDirector!.busy { bearMoved = true; break }
            }
            try check(bearMoved, "Bear can spend leftover movement after transforming")
            try await wait { scene.combatDirector?.bearNode?.currentAction == .walk && (scene.combatDirector?.bearNode?.currentPhase ?? 0) > 0 }
            try capture("bear-walking")
            try await wait { scene.combatDirector?.busy == false }
            try check(scene.detective.position == scene.combatDirector?.bearNode?.position,
                      "Bear movement keeps the player controller at its visible position")
            let checkpoint = scene.combatDirector!.combat
            context = GameContext(saveStore: store)
            context.router.start(in: view)
            try await wait { (view.scene as? CityDistrictScene)?.combatDirector != nil }
            scene = view.scene as! CityDistrictScene
            try check(scene.combatDirector!.combat == checkpoint, "Router resumes combat in the saved area with identical positions, turn and RNG")
            try check(scene.detective.isHidden && scene.combatDirector?.bearNode?.isHidden == false,
                      "Reload restores the bear appearance")
            try capture("combat-resumed")
            // Play through the actual scene input. Let enemies approach after the
            // retreat, then attack the closest reachable opponent each turn.
            let deadline = ProcessInfo.processInfo.systemUptime + 150
            var attacks = 0
            var sawEnemyWalkFrame = false
            var sawClawFrame = false
            while scene.combatDirector != nil {
                if scene.depthWorldRoot.children.compactMap({ $0 as? CharacterAppearanceNode }).contains(where: {
                    $0.currentAction == .walk && $0.currentPhase > 0
                }) { sawEnemyWalkFrame = true }
                if let bear = scene.combatDirector?.bearNode, bear.currentAction == .attack && bear.currentPhase > 0 {
                    if !sawClawFrame { try capture("bear-claw") }
                    sawClawFrame = true
                }
                guard ProcessInfo.processInfo.systemUptime < deadline else { throw Failure(message: "Fight stalled") }
                if let director = scene.combatDirector, director.combat.isPlayerTurn, !director.busy {
                    let model = director.combat
                    let enemies = model.actors.filter { !$0.player && $0.conscious }
                    if model.budget.canAttack, let target = enemies.min(by: {
                        CombatNavigation.distance(model.current.position, $0.position) < CombatNavigation.distance(model.current.position, $1.position)
                    }), CombatNavigation.distance(model.current.position, target.position) <= TacticalCombat.meleeReach,
                       CombatNavigation.clearLine(in: scene.navigation, from: model.current.position, to: target.position, excluding: [model.current.id, target.id]) {
                        click(scene, world: CGPoint(x: target.position.x, y: target.position.y + 60))
                        if !director.combat.budget.canAttack { attacks += 1 }
                    } else if let target = enemies.min(by: {
                        CombatNavigation.distance(model.current.position, $0.position) < CombatNavigation.distance(model.current.position, $1.position)
                    }), CombatNavigation.distance(model.current.position, target.position) > TacticalCombat.meleeReach,
                        model.budget.availableMovement(speed: model.movementSpeed(for: model.current)) > 0 {
                        var moved = false
                        for i in 0..<16 {
                            let angle = CGFloat(i) * .pi / 8
                            let goal = CGPoint(x: target.position.x + cos(angle) * 100,
                                               y: target.position.y + sin(angle) * 75).rounded
                            guard let route = CombatNavigation.route(in: scene.navigation, actor: model.current, to: goal, bear: model.isBear) else { continue }
                            let path = CombatNavigation.prefix(route, from: model.current.position,
                                within: model.budget.availableMovement(speed: model.movementSpeed(for: model.current)))
                            guard let destination = path.destination, !path.isEmpty else { continue }
                            click(scene, world: destination)
                            if director.busy { moved = true; break }
                        }
                        if !moved { scene.handleConfirmInput() }
                    } else { scene.handleConfirmInput() }
                }
                try await Task.sleep(for: .milliseconds(150))
            }
            try check(sawBowDraw && sawArrowFlight && sawArrowImpact, "Lookout plays draw, release, arrow flight and impact in the live encounter")
            try check(scene.depthWorldRoot.childNode(withName: "combat.bow.arrow") == nil,
                "Combat cleanup removes the arrow projectile")
            try check(scene.depthWorldRoot.childNode(withName: "combat.bow.fire") == nil,
                "Combat cleanup removes the arrow fire and embers")
            try check(attacks > 0, "Pointer attacks resolve through real scene input")
            try check(sawEnemyWalkFrame, "Enemy approach plays advancing walk frames")
            try check(sawClawFrame, "Bear strikes play the authored claw animation")
            try check(context.session.caseState.hasFlag("combat.a1.gate.outcome.won"), "Played gate victory enters authored aftermath")
            try check(!context.session.caseState.hasFlag("combat.a1.gate.auto-resolved"), "Played victory is never marked auto-resolved")
            try check(context.session.tacticalCombat == nil, "Outcome clears the checkpoint in the story transaction")
            try check(!scene.detective.isHidden && scene.depthWorldRoot.childNode(withName: "combat.bear.visual") == nil,
                      "Encounter completion restores the human actor")
            try check(context.session.characterInventory == humanEquipment, "Bear Form preserves the complete equipment inventory")
            try capture("combat-aftermath")
            let nextDeadline = ProcessInfo.processInfo.systemUptime + 30
            while scene.combatDirector == nil {
                if ProcessInfo.processInfo.systemUptime > nextDeadline { throw Failure(message: "Lane did not start") }
                driveDialogue(scene); try await Task.sleep(for: .milliseconds(300))
            }
            try await wait { scene.combatDirector?.combat.isPlayerTurn == true && scene.combatDirector?.busy == false }
            scene.handleDialogueChoiceDigit(3)
            try await wait { scene.combatDirector == nil }
            try check(context.session.caseState.hasFlag("combat.a1.lane.outcome.lost"), "Yield produces a nonlethal loss and authored aftermath")
            try check(context.session.caseState.hasEvidence("evidence.a1.lane.chit"), "Lane reward follows the existing first-fight contract")
            try check(scene.navigation.occupancy.actors.count == 1, "Combat cleanup removes crew occupancy")
            try check(GameSession(saveStore: store).tacticalCombat == nil, "Completed encounter stays complete after reload")
            // Finish the resumed exterior visit, then exercise both indoor casts.
            driveDialogue(scene)
            context.router.travel(to: WharfLadderStory.interior)
            try await wait { (view.scene as? CityDistrictScene)?.area.id == WharfLadderStory.interior && !context.router.isTransitioning }
            scene = view.scene as! CityDistrictScene
            let indoorDeadline = ProcessInfo.processInfo.systemUptime + 100
            while scene.combatDirector == nil {
                if ProcessInfo.processInfo.systemUptime > indoorDeadline { throw Failure(message: "Clock room did not dispatch") }
                driveDialogue(scene); try await Task.sleep(for: .milliseconds(300))
            }
            try check(scene.combatDirector!.combat.actors.count == 4, "Clock room stages Voss and all three opponents")
            try await wait { scene.combatDirector?.combat.isPlayerTurn == true && scene.combatDirector?.busy == false }
            try capture("clock-combat")
            scene.handleDialogueChoiceDigit(3)
            try await wait { scene.combatDirector == nil }
            try check(context.session.caseState.hasFlag("combat.a1.clockroom.outcome.lost"), "Clock-room defeat still allows story progress")
            let e1Deadline = ProcessInfo.processInfo.systemUptime + 60
            while scene.combatDirector == nil {
                if ProcessInfo.processInfo.systemUptime > e1Deadline { throw Failure(message: "Merrick did not dispatch E1") }
                driveDialogue(scene); try await Task.sleep(for: .milliseconds(300))
            }
            try check(scene.combatDirector!.combat.encounterID == "e1", "Merrick dialogue dispatches played E1")
            try await wait { scene.combatDirector?.combat.isPlayerTurn == true && scene.combatDirector?.busy == false }
            scene.handleDialogueChoiceDigit(3)
            try await wait { scene.combatDirector == nil }
            try check(context.session.caseState.hasFlag("combat.e1.outcome.lost") && context.session.caseState.counter("watch.attention") == 1,
                      "E1 defeat applies Watch attention exactly once")
            try check(!context.session.caseState.hasFlag("combat.e1.auto-resolved"), "E1 uses the played outcome contract")
            try check(GameSession(saveStore: store).caseState == context.session.caseState, "Final case state survives reload")
            // Reuse a real, certified checkpoint to exercise every live reversion
            // path without depending on random combat damage or story replay.
            let formStore = SaveStore(key: "RainShadow.QA.BearReversion.\(UUID().uuidString)")
            defer { formStore.reset() }
            for mode in ["voluntary", "expiry", "yield"] {
                var form = checkpoint
                repeat { _ = form.endTurn() } while !form.isPlayerTurn
                if mode == "expiry" {
                    for _ in 0..<2 { repeat { _ = form.endTurn() } while !form.isPlayerTurn }
                }
                formStore.save(SaveSnapshot(tacticalCombat: try JSONEncoder().encode(form),
                    hasSeenOpening: true, hasCompletedOfficeCaseIntro: true))
                context = GameContext(saveStore: formStore)
                context.router.start(in: view)
                try await wait { (view.scene as? CityDistrictScene)?.context === context && (view.scene as? CityDistrictScene)?.combatDirector != nil }
                scene = view.scene as! CityDistrictScene
                try await wait { scene.combatDirector?.busy == false }
                if mode == "voluntary" { scene.handleDialogueChoiceDigit(4) }
                else if mode == "expiry" { scene.handleConfirmInput() }
                else { scene.handleDialogueChoiceDigit(3) }
                try await wait { !scene.detective.isHidden && scene.depthWorldRoot.childNode(withName: "combat.bear.transformation") == nil }
                try check(scene.combatDirector?.combat.isBear != true, "\(mode) reversion restores the human presentation")
                try check(scene.navigation.occupancy.actors[TacticalCombat.playerID]?.personalSpaceCells == ActorLocomotionPacing.personalSpaceCells,
                          "\(mode) reversion restores human clearance")
                if mode == "voluntary" {
                    try check(scene.combatDirector?.combat.canTransform == false, "Voluntary reversion cannot grant another use")
                    try check(scene.detective.alpha == 1 && scene.combatDirector?.transformationCameraOffset == .zero,
                        "Reversion leaves no opacity or camera offset behind")
                    try capture("bear-reverted")
                    view.window?.setContentSize(CGSize(width: 640, height: 800))
                    try await Task.sleep(for: .milliseconds(300))
                    try capture("combat-compact")
                    view.window?.setContentSize(CGSize(width: 1100, height: 800))
                }
            }
            }
            // A fresh copy of the actual staged gate tests player environmental
            // targeting independently of the existing brawl/autoplay strategy.
            let barrelStore = SaveStore(key: "RainShadow.QA.Barrels.\(UUID().uuidString)")
            defer { barrelStore.reset() }
            var barrelActors = beforeChromeClick.actors
            for i in barrelActors.indices {
                barrelActors[i].maximumHP = 20
                barrelActors[i].hp = barrelActors[i].maximumHP
                barrelActors[i].initiativeBonus = barrelActors[i].player ? 100 : -100
            }
            let barrelFight = TacticalCombat(encounterID: "gate", areaID: WharfLadderStory.exterior.rawValue,
                actors: barrelActors, seed: 42, barrels: beforeChromeClick.barrels ?? [])
            try check(!barrelFight.liveBarrels.isEmpty, "Gate stages targetable oil barrels on clear ground")
            barrelStore.save(SaveSnapshot(tacticalCombat: try JSONEncoder().encode(barrelFight),
                hasSeenOpening: true, hasCompletedOfficeCaseIntro: true))
            context = GameContext(saveStore: barrelStore); context.router.start(in: view)
            try await wait { (view.scene as? CityDistrictScene)?.context === context && (view.scene as? CityDistrictScene)?.combatDirector?.busy == false }
            scene = view.scene as! CityDistrictScene
            guard let barrelDirector = scene.combatDirector,
                  let barrel = barrelDirector.combat.liveBarrels.first(where: {
                      CombatNavigation.clearLine(in: scene.navigation, from: barrelDirector.combat.current.position,
                          to: $0.position, excluding: [TacticalCombat.playerID, $0.id])
                  }) else { throw Failure(message: "No player barrel firing lane") }
            scene.handleDialogueChoiceDigit(5)
            try check(barrelDirector.aimingFireArrow, "Player can select Fire arrow through scene input")
            let barrelPoint = CGPoint(x: barrel.position.x, y: barrel.position.y + 30)
            barrelDirector.hover(at: scene.convert(barrelPoint, from: scene.depthWorldRoot))
            try capture("barrel-preview")
            click(scene, world: barrelPoint)
            guard let shot = barrelDirector.rangedShot else { throw Failure(message: "Player barrel shot was rejected") }
            try check(!shot.explosions.isEmpty && scene.detective.isHidden,
                "Player barrel shot plays the authored bow clip")
            try check(GameSession(saveStore: barrelStore).tacticalCombat == barrelDirector.combat,
                "Accepted chain explosion is saved before presentation")
            try check(!shot.displacements.isEmpty, "Surviving blast targets receive accepted knockback endpoints")
            try check(shot.destructions.count == shot.explosions.count
                && shot.explosions.allSatisfy { event in
                    barrelDirector.combat.barrels?.first { $0.id == event.barrel.id }?.debris?.count == 14
                }, "Accepted explosion saves every fragment endpoint before impact")
            try check(!barrelDirector.debrisMoving, "Intact barrels do not emit fragments before arrow impact")
            let acceptedBarrelFight = barrelDirector.combat
            try check(shot.before.liveBarrels.count > barrelDirector.combat.liveBarrels.count
                && scene.depthWorldRoot.childNode(withName: barrel.id) != nil,
                "Barrel stays visible until arrow impact")
            try await wait { shot.elapsed > BowAttackRules.releaseTime + 0.04 }
            try capture("player-fire-arrow")
            try await wait { barrelDirector.blasts.first.map { $0.elapsed > 0.12 } == true }
            try capture("barrel-explosion")
            try check(barrelDirector.debrisMoving
                && barrelDirector.barrelNodes.values.contains { $0.fragmentBodies.contains { $0.height > 15 } },
                "Impact launches separate fragments above their ground shadows")
            scene.handleTacticalPauseInput()
            let blastTimes = barrelDirector.blasts.map(\.elapsed)
            let fragmentTimes = barrelDirector.barrelNodes.mapValues(\.elapsed)
            let fragmentBodies = barrelDirector.barrelNodes.mapValues(\.fragmentBodies)
            let fragmentPositions = barrelDirector.barrelNodes.mapValues { $0.children.map(\.position) }
            for (id, reaction) in barrelDirector.hitReactions {
                let node = barrelDirector.reactionNodes[id]!
                let original: SKNode = id == TacticalCombat.playerID ? scene.detective : scene.childNode(withName: "//" + id)!
                try check(node.currentPhase > 0 && node.currentReaction == reaction.kind,
                          "Blast plays the authored \(reaction.kind.rawValue) animation")
                try check(reaction.kind != .dodge && node.currentReaction == reaction.kind && node.position == original.position && !node.isHidden && original.isHidden,
                          "Explosion reaction follows its displaced actor without a duplicate body")
            }
            let reactionClocks = barrelDirector.hitReactions.mapValues(\.elapsed)
            let reactionPhases = barrelDirector.reactionNodes.mapValues(\.currentPhase)
            for move in shot.displacements {
                let node: SKNode = move.id == TacticalCombat.playerID ? scene.detective : scene.childNode(withName: "//" + move.id)!
                try check(node.position == ExplosionKnockbackMotion.position(from: move.from, to: move.to, elapsed: barrelDirector.knockbackElapsed),
                          "Explosion displacement follows the impulse and friction trajectory")
            }
            let pushTime = barrelDirector.knockbackElapsed
            let pushPositions = shot.displacements.map { scene.navigation.occupancy.actors[$0.id]?.position }
            try check(!barrelDirector.knockbacks.isEmpty, "Knockback is animated during the blast")
            try await Task.sleep(for: .milliseconds(180))
            try check(barrelDirector.hitReactions.mapValues(\.elapsed) == reactionClocks
                && barrelDirector.reactionNodes.mapValues(\.currentPhase) == reactionPhases,
                "Pause freezes the stumble or fall pose with the physical shove")
            try check(barrelDirector.blasts.map(\.elapsed) == blastTimes, "Pause freezes barrel explosion particles")
            try check(barrelDirector.knockbackElapsed == pushTime
                && shot.displacements.map { scene.navigation.occupancy.actors[$0.id]?.position } == pushPositions,
                "Pause freezes knockback without advancing combat")
            try check(barrelDirector.barrelNodes.mapValues(\.elapsed) == fragmentTimes
                && barrelDirector.barrelNodes.mapValues(\.fragmentBodies) == fragmentBodies
                && barrelDirector.barrelNodes.mapValues { $0.children.map(\.position) } == fragmentPositions,
                "Pause freezes fragment physics and visible debris positions")
            scene.handleTacticalPauseInput()
            try await wait { barrelDirector.barrelNodes[barrel.id]!.elapsed > 0.5 }
            try capture("barrel-fragments-airborne")
            try check(barrelDirector.knockbacks.isEmpty && barrelDirector.hitReactions.values.contains { $0.kind.isKnockback },
                      "Feet recover after the physical shove has stopped")
            for (id, node) in barrelDirector.reactionNodes where !node.isHidden {
                if let texture = view.texture(from: node), let data = NSBitmapImageRep(cgImage: texture.cgImage()).representation(using: .png, properties: [:]) {
                    try data.write(to: output.appendingPathComponent("knockback-recovery-" + id + ".png"))
                }
            }
            try await wait { !barrelDirector.busy }
            try check(barrelDirector.hitReactions.isEmpty && barrelDirector.reactionNodes.values.allSatisfy(\.isHidden),
                      "All knockback recoveries finish before input is unlocked")
            try check(!scene.detective.isHidden && barrelDirector.blasts.isEmpty,
                "Player bow recovery restores Voss and removes the blast")
            try check(shot.explosions.allSatisfy { scene.navigation.occupancy.actors[$0.barrel.id] == nil
                && scene.depthWorldRoot.childNode(withName: $0.barrel.id) == nil },
                "Exploded barrels remove intact visuals and raster occupancy")
            try check(shot.explosions.allSatisfy { scene.depthWorldRoot.childNode(withName: $0.barrel.id + ".remains") != nil },
                "Explosions leave charred wooden debris on the ground")
            try check(shot.displacements.allSatisfy { scene.navigation.occupancy.actors[$0.id]?.position == $0.to },
                "Surviving actors finish at their saved knockback positions")
            try check(barrelDirector.barrelNodes.values.allSatisfy { !$0.isSimulating
                && $0.fragmentBodies.allSatisfy { $0.sleeping && $0.height == 0 } },
                "All pieces bounce and settle before the next action")
            try check(shot.explosions.allSatisfy { event in
                barrelDirector.barrelNodes[event.barrel.id]?.fragmentBodies.map(\.pose)
                    == barrelDirector.combat.barrels?.first { $0.id == event.barrel.id }?.debris
            }, "Presented debris settles at the accepted saved positions")
            try capture("barrel-aftermath")
            // Resume exactly the saved in-flight endpoint, with no animation replay.
            barrelStore.save(SaveSnapshot(tacticalCombat: try JSONEncoder().encode(acceptedBarrelFight),
                hasSeenOpening: true, hasCompletedOfficeCaseIntro: true))
            context = GameContext(saveStore: barrelStore); context.router.start(in: view)
            try await wait { (view.scene as? CityDistrictScene)?.context === context && (view.scene as? CityDistrictScene)?.combatDirector != nil }
            scene = view.scene as! CityDistrictScene
            try check(scene.combatDirector!.combat == acceptedBarrelFight
                && scene.combatDirector!.rangedShot == nil
                && shot.explosions.allSatisfy { scene.depthWorldRoot.childNode(withName: $0.barrel.id) == nil },
                "Reload cannot rearm a barrel or replay its explosion")
            try check(shot.explosions.allSatisfy { scene.depthWorldRoot.childNode(withName: $0.barrel.id + ".remains") != nil },
                "Reload preserves broken barrel remains")
            try check(!scene.combatDirector!.debrisMoving && shot.explosions.allSatisfy { event in
                scene.combatDirector!.barrelNodes[event.barrel.id]?.fragmentBodies.map(\.pose)
                    == acceptedBarrelFight.barrels?.first { $0.id == event.barrel.id }?.debris
            }, "In-flight reload restores settled fragments without replaying their launch")
            // Exercise a physical strike and its persistent, still-flammable spill.
            let smashPlayer = barrelActors.first { $0.player }!
            let smashCandidates = (0..<24).map { i in
                let angle = CGFloat(i) * .pi / 12
                return CGPoint(x: smashPlayer.position.x + cos(angle) * 85,
                               y: smashPlayer.position.y + sin(angle) * 85 * 0.75).rounded
            }
            guard let smashPoint = smashCandidates.first(where: {
                scene.navigation.searchMap.blockedInRadiusTile(at: $0, size: 3).contains(.passable)
                    && CombatNavigation.clearLine(in: scene.navigation, from: smashPlayer.position, to: $0,
                                                   excluding: [TacticalCombat.playerID])
            }) else { throw Failure(message: "No close barrel site for physical strike") }
            let smashFight = TacticalCombat(encounterID: "gate", areaID: WharfLadderStory.exterior.rawValue,
                actors: barrelActors, seed: 42, barrels: [.init(id: "combat.oil.smash", position: smashPoint)])
            barrelStore.save(SaveSnapshot(tacticalCombat: try JSONEncoder().encode(smashFight),
                hasSeenOpening: true, hasCompletedOfficeCaseIntro: true))
            context = GameContext(saveStore: barrelStore); context.router.start(in: view)
            try await wait { (view.scene as? CityDistrictScene)?.context === context && (view.scene as? CityDistrictScene)?.combatDirector?.busy == false }
            scene = view.scene as! CityDistrictScene
            click(scene, world: CGPoint(x: smashPoint.x, y: smashPoint.y + 30))
            let smashDirector = scene.combatDirector!
            try check(smashDirector.combat.actors == smashFight.actors && !smashDirector.combat.budget.canAttack,
                "Breaking a barrel costs a standard action without blast damage")
            try check(smashDirector.meleeAttack != nil && !smashDirector.debrisMoving
                && scene.navigation.occupancy.actors["combat.oil.smash"] != nil,
                "Barrel fragments and occupancy wait for the melee hit pose")
            try await wait { smashDirector.meleeAttack?.impactPresented == true }
            try check(smashDirector.combat.liveBarrels.first?.isBroken == true
                && smashDirector.combat.liveBarrels.first?.exploded == false
                && scene.navigation.occupancy.actors["combat.oil.smash"] == nil,
                "Physical strike leaves flammable oil and debris and opens its raster cell")
            try check(smashDirector.debrisMoving, "A physical strike also launches barrel fragments")
            try await wait { smashDirector.barrelNodes["combat.oil.smash"]!.elapsed > 0.25 }
            try capture("barrel-smash-fragments")
            try await wait { !smashDirector.busy }
            try capture("barrel-spill")
            let savedSpill = smashDirector.combat
            context = GameContext(saveStore: barrelStore); context.router.start(in: view)
            try await wait { (view.scene as? CityDistrictScene)?.context === context && (view.scene as? CityDistrictScene)?.combatDirector?.busy == false }
            scene = view.scene as! CityDistrictScene
            try check(scene.combatDirector!.combat == savedSpill
                && scene.depthWorldRoot.childNode(withName: "combat.oil.smash") != nil
                && scene.navigation.occupancy.actors["combat.oil.smash"] == nil,
                "Reload restores the oil spill without restoring a solid barrel")
            // Start a fresh turn at a certified firing position to test spill ignition.
            // Approach from the camera-near side so the spill stays above the
            // expanded technique action bar; HUD clicks intentionally do nothing.
            let fireCandidates = (0..<24).map { i in
                let angle = CGFloat(i) * .pi / 12 + .pi
                return CGPoint(x: smashPoint.x + cos(angle) * 200,
                               y: smashPoint.y + sin(angle) * 200 * 0.75).rounded
            }
            guard let firePoint = fireCandidates.first(where: {
                CombatNavigation.route(in: scene.navigation, actor: smashPlayer, to: $0) != nil
                    && CombatNavigation.clearLine(in: scene.navigation, from: $0, to: smashPoint,
                                                   excluding: [TacticalCombat.playerID])
            }) else { throw Failure(message: "No firing lane to spilled oil") }
            var spillActors = barrelActors
            spillActors[spillActors.firstIndex { $0.player }!].position = firePoint
            let spillFight = TacticalCombat(encounterID: "gate", areaID: WharfLadderStory.exterior.rawValue,
                actors: spillActors, seed: 42, barrels: savedSpill.barrels ?? [])
            barrelStore.save(SaveSnapshot(tacticalCombat: try JSONEncoder().encode(spillFight),
                hasSeenOpening: true, hasCompletedOfficeCaseIntro: true))
            context = GameContext(saveStore: barrelStore); context.router.start(in: view)
            try await wait { (view.scene as? CityDistrictScene)?.context === context && (view.scene as? CityDistrictScene)?.combatDirector?.busy == false }
            scene = view.scene as! CityDistrictScene
            scene.handleDialogueChoiceDigit(5)
            click(scene, world: CGPoint(x: smashPoint.x, y: smashPoint.y + 10))
            let spillDirector = scene.combatDirector!
            try check(spillDirector.rangedShot?.explosions.count == 1, "Player can ignite spilled oil with a fire arrow")
            try check(spillDirector.rangedShot?.destructions["combat.oil.smash"]?.samples.first?.map(\.pose)
                == savedSpill.barrels?.first?.debris,
                "Igniting a spill throws its existing pieces from their resting places")
            try await wait { !spillDirector.busy }
            try check(scene.depthWorldRoot.childNode(withName: "combat.oil.smash.remains") != nil,
                "Ignited spill becomes charred remains")
            // Swap the lookout and player in the same certified layout: the
            // barrel that was unsafe for the AI now threatens only its opponent.
            var aiActors = barrelActors
            guard let playerIndex = aiActors.firstIndex(where: \.player),
                  let lookoutIndex = aiActors.firstIndex(where: { !$0.player && $0.rangedWeapon == .bow })
                else { throw Failure(message: "Missing lookout for barrel AI test") }
            let oldPlayerPoint = aiActors[playerIndex].position
            aiActors[playerIndex].position = aiActors[lookoutIndex].position
            aiActors[lookoutIndex].position = oldPlayerPoint
            for i in aiActors.indices { aiActors[i].initiativeBonus = i == lookoutIndex ? 200 : -100 }
            let aiFight = TacticalCombat(encounterID: "gate", areaID: WharfLadderStory.exterior.rawValue,
                actors: aiActors, seed: 42, barrels: barrelFight.barrels ?? [])
            barrelStore.save(SaveSnapshot(tacticalCombat: try JSONEncoder().encode(aiFight),
                hasSeenOpening: true, hasCompletedOfficeCaseIntro: true))
            context = GameContext(saveStore: barrelStore); context.router.start(in: view)
            try await wait { (view.scene as? CityDistrictScene)?.context === context && (view.scene as? CityDistrictScene)?.combatDirector?.rangedShot != nil }
            scene = view.scene as! CityDistrictScene
            guard let aiShot = scene.combatDirector?.rangedShot else { throw Failure(message: "Lookout did not shoot") }
            try check(!aiShot.explosions.isEmpty && aiShot.explosions.flatMap(\.hits).allSatisfy { $0.target == TacticalCombat.playerID },
                "Lookout chooses a useful barrel shot without hitting its own crew")
            try await wait { aiShot.elapsed > BowAttackRules.releaseTime + 0.04 }
            try capture("lookout-barrel-shot")
            try await wait { aiShot.impactPresented }
            let playerPush = aiShot.displacements.first { $0.id == TacticalCombat.playerID }
            try check(playerPush != nil, "Enemy barrel shot also pushes the surviving player")
            try await wait { scene.combatDirector?.knockbacks.isEmpty == true }
            try check(scene.detective.position == playerPush?.to
                && scene.detective.movable.position == playerPush?.to
                && scene.navigation.occupancy.actors[TacticalCombat.playerID]?.position == playerPush?.to,
                "Player sprite, movement origin, and raster occupancy agree after knockback")
            try capture("player-knockback-aftermath")
            try JSONSerialization.data(withJSONObject: ["passed": true, "checks": checks], options: [.prettyPrinted, .sortedKeys]).write(to: output.appendingPathComponent("report.json"))
        } catch {
            try? capture("failure")
            try? JSONSerialization.data(withJSONObject: ["passed": false, "checks": checks, "error": String(describing: error)], options: [.prettyPrinted, .sortedKeys]).write(to: output.appendingPathComponent("report.json"))
        }
        NSApp.terminate(nil)
    }
}
#endif
