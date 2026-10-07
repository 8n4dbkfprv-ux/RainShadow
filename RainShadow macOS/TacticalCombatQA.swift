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
                        try check(shot.fire.parent != nil && !shot.fire.isHidden
                            && shot.fire.children.filter { !$0.isHidden && $0.alpha > 0 }.count > 2,
                            "Flying arrow carries a burning head and visible flame particles")
                        try check(director.presentedCombat == shot.before,
                            "Arrow damage stays hidden until impact")
                        try check(GameSession(saveStore: store).tacticalCombat == director.combat,
                            "In-flight save stores the accepted outcome without a replayable action")
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
            scene.handleInventoryInput(); scene.handleMapInput(); scene.handleJournalInput()
            try check(!scene.anyOverlayIsPresented, "Combat blocks inventory, map and journal input")
            try await wait { scene.combatDirector?.combat.isPlayerTurn == true && scene.combatDirector?.busy == false }
            try capture("combat-start")
            let beforeChromeClick = scene.combatDirector!.combat
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
                    try await Task.sleep(for: .milliseconds(180))
                    try check(attack.elapsed == elapsed && attack.actor.currentPhase == phase,
                              "\(mode): pause freezes the attack pose and hit marker")
                    try capture("melee-\(mode)-windup")
                    scene.handleTacticalPauseInput()
                    try await wait { attack.impactPresented }
                    try check(director.presentedCombat == director.combat && director.busy,
                              "\(mode): damage appears at impact while recovery still locks input")
                    try check((attack.result.damage == 0) == (mode == "miss"), "\(mode): hit or miss follows the accepted roll")
                    try capture("melee-\(mode)-impact")
                    try await wait { director.meleeAttack == nil }
                    try check(attack.actor.currentAction == .idle, "\(mode): recovery returns to idle")
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
            let pushTime = barrelDirector.knockbackElapsed
            let pushPositions = shot.displacements.map { scene.navigation.occupancy.actors[$0.id]?.position }
            try check(!barrelDirector.knockbacks.isEmpty, "Knockback is animated during the blast")
            try await Task.sleep(for: .milliseconds(180))
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
            try await wait { !barrelDirector.busy }
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
            let fireCandidates = (0..<24).map { i in
                let angle = CGFloat(i) * .pi / 12
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
