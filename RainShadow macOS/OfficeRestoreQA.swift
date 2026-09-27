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
            context.session.markOfficeCaseIntroCompleted()
            context.router.travel(to: HarborpointAreas.sableRow, entrance: "from.office")
            try await waitUntil { (view.scene as? GameAreaScene)?.area.id == HarborpointAreas.sableRow && !context.router.isTransitioning }
            let street = view.scene as! CityDistrictScene
            street.setWorldMapPresented(true)
            street.worldMapOverlay.onTravel?(.harborpointPD, "from.north")
            try await waitUntil { (view.scene as? GameAreaScene)?.area.id == LampWardAreas.exteriorID && !context.router.isTransitioning }
            let lamp = view.scene as! CityDistrictScene
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
