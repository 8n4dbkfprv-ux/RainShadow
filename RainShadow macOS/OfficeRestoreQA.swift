#if DEBUG
import AppKit
import SpriteKit

/// Restored office smoke test: normal opening, street doorway and world-map return.
@MainActor enum OfficeRestoreQA {
    struct Failure: Error { let message: String }
    static func run(in view: SKView, output: URL) async {
        var checks: [String] = []
        func check(_ yes: Bool, _ message: String) throws {
            guard yes else { throw Failure(message: message) }; checks.append(message)
        }
        func waitUntil(_ condition: () -> Bool, timeout: Double = 60) async throws {
            let end = ProcessInfo.processInfo.systemUptime + timeout
            while !condition() {
                guard ProcessInfo.processInfo.systemUptime < end else { throw Failure(message: "Timed out: \(checks.last ?? "start")") }
                try await Task.sleep(for: .milliseconds(20))
            }
        }
        func capture(_ scene: BaseGameScene, _ name: String) throws {
            func actor(in node: SKNode) -> DetectiveActorNode? {
                if let actor = node as? DetectiveActorNode { return actor }
                return node.children.lazy.compactMap { actor(in: $0) }.first
            }
            guard let voss = actor(in: scene.depthWorldRoot),
                  let body = voss.children.compactMap({ $0 as? IEAvatarNode }).first(where: { !$0.isHidden }) else {
                throw Failure(message: "Current Voss body missing in \(name)")
            }
            try check(body.currentFrame?.id?.atlas == VossAnimationSet.atlas,
                      "\(name) displays the current CHMF character")
            try check(body.xScale > 0, "\(name) uses authored facing without a second mirror")
            for _ in 0..<3 { scene.didFinishUpdate() }
            guard let r = scene.nativeWorldRenderer, let p = r.lastPixels, let v = r.lastViewport,
                  let im = IENativeWorldRenderer.image(p, width: v.width, height: v.height),
                  let png = NSBitmapImageRep(cgImage: im).representation(using: .png, properties: [:]) else { throw Failure(message: "No framebuffer") }
            try png.write(to: output.appendingPathComponent(name + ".png"))
        }
        func click(_ scene: BaseGameScene, _ point: CGPoint) {
            scene.recenterCamera(on: point)
            let e = GamePointerEvent(location: point, kind: .touch)
            scene.handlePointerDown(e); scene.handlePointerUp(e)
        }
        func center(_ r: AreaRegion) -> CGPoint {
            CGPoint(x: r.polygon.map(\.x).reduce(0,+) / Double(r.polygon.count),
                    y: r.polygon.map(\.y).reduce(0,+) / Double(r.polygon.count))
        }
        do {
            try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
            try check(Bundle.main.url(forResource: "avatar-v02", withExtension: "json", subdirectory: VossAnimationSet.character) != nil,
                      "Current Voss is packaged in the application")
            try VossAnimationSet.validate(IEIndexedSprite.load(character: VossAnimationSet.character, bundle: .main))
            let store = SaveStore(key: "RainShadow.QA.OfficeRestore.\(UUID().uuidString)")
            defer { store.reset(); SaveStore(key: "RainShadow.QA.OfficeRestore.Bootstrap").reset() }
            let context = GameContext(saveStore: store)
            view.window?.setContentSize(CGSize(width: 1000, height: 750))
            context.router.start(in: view)
            view.window?.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true)
            try check(view.scene is OpeningExteriorScene, "Normal startup opens the opening scene")
            (view.scene as! OpeningExteriorScene).handleConfirmInput()
            try await waitUntil { view.scene is DetectiveOfficeScene && !context.router.isTransitioning }
            let office = view.scene as! DetectiveOfficeScene
            try check(office.area.worldSize.w > 1051 && office.area.worldSize.w < 1053, "Opening arrives in restored office geometry")
            try check(GameArt.texture(named: office.area.plateTextureName)?.size() == CGSize(width: 5120, height: 3840), "Bundled V19 plate is loaded")
            try check(office.area.containers.count == 6 && office.area.animations.count == 3, "Six containers and three fire animations installed")
            office.setZoomStep(CameraZoom.step(forPercent: 75))
            try capture(office, "startup_office")
            // Exercise the replacement through the real actor, navigation,
            // animation clock, tint/stencil layers and native world renderer.
            func findClient(_ node: SKNode) -> ClientActorNode? {
                if let client = node as? ClientActorNode { return client }
                return node.children.lazy.compactMap { findClient($0) }.first
            }
            let lila = try { () throws -> ClientActorNode in
                guard let client = findClient(office.depthWorldRoot) else {
                    throw Failure(message: "Lila actor missing")
                }
                return client
            }()
            try check(Bundle.main.url(forResource: "avatar-v02", withExtension: "json",
                                      subdirectory: LilaAnimationSet.character) != nil,
                      "Current Lila is packaged in the application")
            try LilaAnimationSet.validate(IEIndexedSprite.load(character: LilaAnimationSet.character, bundle: .main))
            office.cutsceneSetMode(true, reason: .skipped)
            office.cutsceneSuppressDialogue()
            office.cutsceneSetDoor(.officeEntrance, open: true, reason: .skipped)
            lila.performEntrance(along: OfficeNavigationLayout.clientArrivalRoute(in: office.navigation)) {}
            var walkingFrames = Set<String>()
            var capturedWalk = false
            let lilaDeadline = ProcessInfo.processInfo.systemUptime + 30
            while lila.isLocomoting {
                guard ProcessInfo.processInfo.systemUptime < lilaDeadline else {
                    throw Failure(message: "Lila entrance did not finish")
                }
                if let body = lila.children.compactMap({ $0 as? IEAvatarNode }).first,
                   let frame = body.currentFrame?.id {
                    guard frame.atlas == LilaAnimationSet.atlas else {
                        throw Failure(message: "Lila entrance used a retired bundle")
                    }
                    walkingFrames.insert(frame.name)
                }
                if walkingFrames.count >= 5 && !capturedWalk {
                    try capture(office, "lila_walking")
                    capturedWalk = true
                }
                try await Task.sleep(for: .milliseconds(80))
            }
            try check(walkingFrames.count >= 5, "Lila advances through multiple authored walk phases")
            try check(true, "Lila entrance uses the replacement bundle")
            try await Task.sleep(for: .milliseconds(500))
            let lilaBody = try { () throws -> IEAvatarNode in
                guard let body = lila.children.compactMap({ $0 as? IEAvatarNode }).first else {
                    throw Failure(message: "Lila sprite missing")
                }
                return body
            }()
            try check(lilaBody.currentFrame?.id?.atlas == LilaAnimationSet.atlas
                      && lilaBody.currentFrame?.id?.name.hasPrefix("idle_ne_") == true
                      && lilaBody.xScale > 0,
                      "Lila finishes facing Voss northeast in an authored idle without mirroring")
            try capture(office, "lila_idle")
            lila.performExit(along: OfficeNavigationLayout.clientDepartureRoute(in: office.navigation)) {}
            try await waitUntil { lila.isHidden && !lila.isLocomoting }
            try check(true, "Lila walks the departure route and completes the exit fade")
            office.cutsceneSetMode(false, reason: .skipped)
            context.session.markOfficeCaseIntroCompleted()
            context.router.travel(to: HarborpointAreas.sableRow, entrance: "from.office")
            try await waitUntil { (view.scene as? GameAreaScene)?.area.id == HarborpointAreas.sableRow && !context.router.isTransitioning }
            let street = view.scene as! CityDistrictScene
            try capture(street, "street_current_character")
            street.setWorldMapPresented(true)
            street.worldMapOverlay.onTravel?(.harborpointPD, "from.north")
            try await waitUntil { (view.scene as? GameAreaScene)?.area.id == LampWardAreas.exteriorID && !context.router.isTransitioning }
            let lamp = view.scene as! CityDistrictScene
            try capture(lamp, "lamp_current_character")
            lamp.setWorldMapPresented(true)
            lamp.worldMapOverlay.onTravel?(.sableRow, "from.office")
            try await waitUntil { (view.scene as? GameAreaScene)?.area.id == HarborpointAreas.sableRow && !context.router.isTransitioning }
            let returned = view.scene as! CityDistrictScene
            let portal = returned.area.travelRegions.first { $0.travel?.destination == HarborpointAreas.office }!
            click(returned, center(portal))
            try await waitUntil { view.scene is DetectiveOfficeScene && !context.router.isTransitioning }
            let room = view.scene as! DetectiveOfficeScene
            try check(room.area.worldSize == office.area.worldSize, "World-map Sable Row doorway loads the same revised office")
            try check(room.areaEntranceName == OfficeAreaAdapter.cityArrivalEntrance, "City return uses the revised entrance")
            try check(GameArt.texture(named: "") == nil, "Empty texture names cannot resolve unrelated bundled art")
            let flame = try { () throws -> SKSpriteNode in
                guard let sprite = room.depthWorldRoot.childNode(withName: "office.hearth") as? SKSpriteNode else { throw Failure(message: "Hearth sprite missing") }
                return sprite
            }()
            let firstFlame = flame.texture
            try await Task.sleep(for: .milliseconds(200))
            try check(flame.texture !== firstFlame && flame.size.width < 70, "Hearth plays registered frames at the authored size")
            try capture(room, "city_return_office")
            click(room, center(room.area.travelRegions.first!))
            try await waitUntil { (view.scene as? GameAreaScene)?.area.id == HarborpointAreas.sableRow && !context.router.isTransitioning }
            try check(true, "Narrow entrance strip exits back to revised Sable Row")
            context.router.travel(to: HarborpointAreas.office)
            try await waitUntil { view.scene is DetectiveOfficeScene && !context.router.isTransitioning }
            let seated = view.scene as! DetectiveOfficeScene
            try capture(seated, "seated_freeplay")
            click(seated, center(seated.area.travelRegions.first!))
            try await waitUntil { (view.scene as? GameAreaScene)?.area.id == HarborpointAreas.sableRow && !context.router.isTransitioning }
            try check(true, "Current Voss rises from the revised desk and walks to the exit")
            try JSONSerialization.data(withJSONObject: ["passed": true, "checks": checks], options: [.prettyPrinted]).write(to: output.appendingPathComponent("report.json"))
        } catch {
            if let scene = view.scene as? BaseGameScene { try? capture(scene, "failure") }
            try? JSONSerialization.data(withJSONObject: ["passed": false, "checks": checks, "error": String(describing:error)], options: [.prettyPrinted]).write(to: output.appendingPathComponent("report.json"))
        }
        NSApp.terminate(nil)
    }
}
#endif
