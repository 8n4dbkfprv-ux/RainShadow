#if DEBUG
import AppKit
import SpriteKit

/// Live scene, dialogue, cinematic, router and save integration; isolated from player saves.
@MainActor enum WharfLadderQA {
    struct Failure: Error { let message: String }
    static func run(in view: SKView, output: URL) async {
        var checks: [String] = []
        func check(_ value: Bool, _ message: String) throws {
            guard value else { throw Failure(message: message) }
            if !checks.contains(message) { checks.append(message) }
        }
        func wait(_ predicate: () -> Bool) async throws {
            let deadline = ProcessInfo.processInfo.systemUptime + 45
            while !predicate() {
                guard ProcessInfo.processInfo.systemUptime < deadline else { throw Failure(message: "Timed out; " + checks.suffix(1).joined()) }
                try await Task.sleep(for: .milliseconds(30))
            }
        }
        func capture(_ name: String) throws {
            guard let scene = view.scene as? BaseGameScene else { return }
            scene.didFinishUpdate()
            guard let texture = view.texture(from: scene),
                  let png = NSBitmapImageRep(cgImage: texture.cgImage()).representation(using: .png, properties: [:]) else {
                throw Failure(message: "No capture for " + name)
            }
            try png.write(to: output.appendingPathComponent(name + ".png"))
        }
        let store = SaveStore(key: "RainShadow.QA.Wharf.\(UUID().uuidString)")
        defer { store.reset() }
        do {
            try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
            let report = output.appendingPathComponent("report.json")
            if FileManager.default.fileExists(atPath: report.path) { try FileManager.default.removeItem(at: report) }
            store.save(SaveSnapshot(hasSeenOpening: true, hasCompletedOfficeCaseIntro: true))
            let context = GameContext(saveStore: store)
            view.window?.setContentSize(CGSize(width: 1100, height: 800))
            view.window?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            context.router.start(in: view)
            try await Task.sleep(for: .seconds(1.5))
            context.router.travel(to: WharfLadderStory.exterior, entrance: "from.portal.shippingOffice")
            try await wait { (view.scene as? GameAreaScene)?.area.id == WharfLadderStory.exterior && !context.router.isTransitioning }
            let street = view.scene as! CityDistrictScene
            let portal = street.area.travelRegions.first!
            if let door = street.door(matching: portal.id) { street.openDoor(door) }
            // Pick a painted aperture pixel that does not hit the open leaf.
            var target = CGPoint(x: portal.boundingBox.midX, y: portal.boundingBox.midY)
            outer: for y in stride(from: portal.boundingBox.minY, to: portal.boundingBox.maxY, by: 2) {
                for x in stride(from: portal.boundingBox.minX, to: portal.boundingBox.maxX, by: 2) {
                    let p = CGPoint(x: x, y: y)
                    if portal.contains(p), !street.area.doors.contains(where: { HighlightGeometry.contains(p, polygon: $0.openOutline.map(\.cgPoint)) }) {
                        target = p; break outer
                    }
                }
            }
            let event = GamePointerEvent(location: target, kind: .mouse)
            street.handlePointerDown(event); street.handlePointerUp(event)
            try await wait { street.dialoguePresenter.isPresenting }
            try check(street.dialoguePresenter.runtimeContext.dialogueState.graphID == "case.wharf-ladder.gate", "Door starts A1 gate before travel")
            try await Task.sleep(for: .seconds(0.5))
            try capture("gate")
            var visited: Set<String> = []
            var lastKey: String?
            var capturedClock = false
            var seenCinematics: Set<String> = []
            let deadline = ProcessInfo.processInfo.systemUptime + 140
            while !context.session.caseState.hasFlag("wharf-ladder.case.e1-aftermath-seen")
                || (view.scene as? BaseGameScene)?.dialogueIsActive == true {
                guard ProcessInfo.processInfo.systemUptime < deadline else { throw Failure(message: "Story did not complete: \(visited.sorted())") }
                guard let scene = view.scene as? CityDistrictScene else { try await Task.sleep(for: .milliseconds(50)); continue }
                if scene.cutsceneDirector.isPlaying {
                    let id = scene.cutsceneDirector.activeCutsceneID ?? ""
                    if id.hasPrefix("wharf-ladder.resolve.") { seenCinematics.insert(id) }
                    scene.handleInventoryInput()
                    scene.handleMapInput()
                    scene.handleJournalInput()
                    try check(!scene.anyOverlayIsPresented, "Cinematic input excludes inventory, map and journal")
                    if id.contains("lane") || id.contains("e1") { scene.handleCancelInput() }
                } else if scene.dialoguePresenter.isPresenting {
                    let ctx = scene.dialoguePresenter.runtimeContext
                    let id = ctx.dialogueState.currentNodeID ?? ""
                    let key = ctx.dialogueState.graphID + ":" + id
                    if key != lastKey {
                        lastKey = key
                        visited.insert(key)
                        if id == "clock.bark", !capturedClock {
                            try await Task.sleep(for: .seconds(0.5))
                            try check(scene.navigation.occupancy.actors.count == 4, "Clock room stages Hobb and two hands (\(scene.navigation.occupancy.actors.count) actors)")
                            try capture("clock-room"); capturedClock = true
                        }
                        let graphName = String(ctx.dialogueState.graphID.dropFirst("case.".count))
                        let graph = WharfLadderDialogue.graph(graphName)
                        let node = graph.node(id: id)!
                        let choices = CaseDialogueGraph.visibleChoices(node.choices, in: ctx)
                        if choices.isEmpty { scene.handleConfirmInput() }
                        else {
                            // Sharp office path triggers E1; alternate opening tones in A1.
                            let index = id == "merrick.price" ? 2 : 0
                            scene.handleDialogueChoiceDigit(index + 1)
                        }
                    }
                }
                try await Task.sleep(for: .milliseconds(120))
            }
            try check(seenCinematics.count == 4, "All three A1 fights and E1 resolve through the cinematic director")
            try check(context.session.caseState.hasEvidence("evidence.a1.lane.chit"), "Lane chit granted")
            try check(context.session.caseState.hasEvidence("evidence.a1.clockroom.chalk"), "Clock chalk granted")
            try check(!context.session.caseState.hasKnowledge("knowledge.nightClock.interval"), "Interval stays in side case 04")
            try check(context.session.caseState.hasEvidence("evidence.payTally.crateMark"), "E1 grants Bram's tally")
            try check(context.session.caseState.counter("watch.attention") == 1, "E1 attention applied once")
            try check(WharfLadderStory.pendingAftermath(in: context.session.caseState) == nil, "No pending aftermath after acknowledgement")
            let reload = GameSession(saveStore: store)
            try check(reload.caseState == context.session.caseState, "Case state survives real SaveStore reload")
            try check(reload.walletPence == context.session.walletPence, "Reload cannot duplicate retainer")
            let room = view.scene as! CityDistrictScene
            try check(room.navigation.occupancy.actors.count == 1, "Cinematic crew leaves no occupancy behind")
            try check(!room.cutsceneDirector.isPlaying && !room.dialogueIsActive, "Natural and skipped cinematics restore exploration")
            try capture("aftermath")
            try JSONSerialization.data(withJSONObject: ["passed": true, "checks": checks], options: [.prettyPrinted, .sortedKeys]).write(to: output.appendingPathComponent("report.json"))
        } catch {
            try? capture("failure")
            try? JSONSerialization.data(withJSONObject: ["passed": false, "checks": checks, "error": String(describing: error)], options: [.prettyPrinted, .sortedKeys]).write(to: output.appendingPathComponent("report.json"))
        }
        NSApp.terminate(nil)
    }
}
#endif
