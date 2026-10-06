#if DEBUG
import AppKit
import SpriteKit

@MainActor enum TacticalCombatQA {
    struct Failure: Error { let message: String }
    static func run(in view: SKView, output: URL) async {
        var checks: [String] = []
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
            let transformation = scene.depthWorldRoot.childNode(withName: "combat.bear.transformation")
            let particlePositions = transformation?.children.map(\.position)
            try await Task.sleep(for: .milliseconds(250))
            try check(particlePositions == transformation?.children.map(\.position), "Pause freezes transformation particles")
            scene.handleTacticalPauseInput()
            try await wait { scene.combatDirector?.busy == false }
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
                    } else { scene.handleConfirmInput() }
                }
                try await Task.sleep(for: .milliseconds(150))
            }
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
                    try capture("bear-reverted")
                    view.window?.setContentSize(CGSize(width: 640, height: 800))
                    try await Task.sleep(for: .milliseconds(300))
                    try capture("combat-compact")
                    view.window?.setContentSize(CGSize(width: 1100, height: 800))
                }
            }
            try JSONSerialization.data(withJSONObject: ["passed": true, "checks": checks], options: [.prettyPrinted, .sortedKeys]).write(to: output.appendingPathComponent("report.json"))
        } catch {
            try? capture("failure")
            try? JSONSerialization.data(withJSONObject: ["passed": false, "checks": checks, "error": String(describing: error)], options: [.prettyPrinted, .sortedKeys]).write(to: output.appendingPathComponent("report.json"))
        }
        NSApp.terminate(nil)
    }
}
#endif
