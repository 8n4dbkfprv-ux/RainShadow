#if DEBUG
import AppKit
import SpriteKit

/// Exercises the installed art and actual scene input/router, using a disposable save.
@MainActor enum LampWardTravelQA {
    struct Failure: Error { let message: String }
    static func run(in view: SKView, output: URL) async {
        var checks: [String] = []
        func check(_ value: Bool, _ message: String) throws {
            guard value else { throw Failure(message: message) }
            checks.append(message)
        }
        func waitUntil(_ condition: () -> Bool, timeout: Double = 90) async throws {
            let end = ProcessInfo.processInfo.systemUptime + timeout
            while !condition() {
                guard ProcessInfo.processInfo.systemUptime < end else { throw Failure(message: "Timed out in \(String(describing: (view.scene as? GameAreaScene)?.area.id))") }
                try await Task.sleep(for: .milliseconds(20))
            }
        }
        func click(_ scene: BaseGameScene, _ p: CGPoint, touch: Bool = false) {
            scene.recenterCamera(on: p)
            let event = GamePointerEvent(location: p, kind: touch ? .touch : .mouse)
            scene.handlePointerDown(event); scene.handlePointerUp(event)
        }
        func capture(_ scene: BaseGameScene, _ name: String) throws {
            for _ in 0..<32 { scene.didFinishUpdate() }
            guard let r = scene.nativeWorldRenderer, let pixels = r.lastPixels,
                  let v = r.lastViewport,
                  let image = IENativeWorldRenderer.image(pixels, width: v.width, height: v.height),
                  let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else {
                throw Failure(message: "Missing framebuffer \(name)")
            }
            try png.write(to: output.appendingPathComponent(name + ".png"))
        }
        do {
            try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
            let store = SaveStore(key: "RainShadow.QA.LampWard.\(UUID().uuidString)")
            defer {
                store.reset()
                SaveStore(key: "RainShadow.QA.LampWard.Bootstrap").reset()
            }
            let context = GameContext(saveStore: store)
            view.window?.setContentSize(CGSize(width: 1000, height: 750))
            context.router.start(in: view)
            view.window?.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true)
            try await Task.sleep(for: .seconds(1))
            guard let street = view.scene as? CityDistrictScene, street.area.id == LampWardAreas.exteriorID else {
                throw Failure(message: "Launch with START_SCENE=city START_DISTRICT=lamp_ward START_ENTRANCE=from.portal.lamphouseEntrance")
            }
            street.setZoomStep(CameraZoom.step(forPercent: 100))
            let region = street.area.region(id: "portal.lamphouseEntrance")!
            let door = CGPoint(x: region.boundingBox.midX, y: region.boundingBox.midY)
            street.recenterCamera(on: region.approachPoint!.cgPoint)
            try capture(street, "01_lamp_ward_day")
            try check(street.setExtendedNight(true), "Lamp Ward loads its paged night plate")
            try capture(street, "02_lamp_ward_night")
            street.setExtendedNight(false)
            street.handlePointerMoved(GamePointerEvent(location: door, kind: .mouse))
            try check(street.hoveredHighlightID == region.id, "Painted Lamphouse doorway is identified by mouse hover")
            click(street, door, touch: true)
            try await waitUntil({ (view.scene as? GameAreaScene)?.area.id == LampWardAreas.interiorID })
            try await waitUntil({ !context.router.isTransitioning })
            let room = view.scene as! CityDistrictScene
            try check(room.detective.position == room.area.spawnPoint(entrance: "from.street"), "Travel arrives at the shared interior door strip")
            try check(room.detective.state == .standingIdle, "Voss arrives standing and controllable")
            try capture(room, "03_lamphouse_arrival")
            for (name, point) in [("property_log", CGPoint(x: 513, y: 524)), ("night_books", CGPoint(x: 782, y: 811)), ("cell_corridor", CGPoint(x: 1217, y: 502)), ("property_store", CGPoint(x: 983, y: 344))] {
                try check(room.navigation.isOrderableFloor(point), "\(name) accepts a floor click")
                click(room, point)
                try await waitUntil({ !room.detective.isLocomoting })
                try check(room.navigation.searchMap.cell(for: room.detective.position) == room.navigation.searchMap.cell(for: point), "Voss walks to \(name) through real scene input")
                try capture(room, "04_" + name)
            }
            let exit = room.area.region(id: "portal.return")!
            click(room, CGPoint(x: exit.boundingBox.midX, y: exit.boundingBox.midY), touch: true)
            try await waitUntil({ (view.scene as? GameAreaScene)?.area.id == LampWardAreas.exteriorID })
            try await waitUntil({ !context.router.isTransitioning })
            let returned = view.scene as! CityDistrictScene
            try check(returned.detective.position == region.approachPoint!.cgPoint, "Leaving returns to the Lamphouse forecourt")
            try capture(returned, "05_return_to_ward")
            click(returned, door)
            try await waitUntil({ (view.scene as? GameAreaScene)?.area.id == LampWardAreas.interiorID })
            try check(true, "Immediate re-entry works")
            try await waitUntil({ !context.router.isTransitioning })
            // Use the real world-map travel callback to reach the north arrival,
            // then walk the authored street exit instead of the old bitmap edge.
            context.router.travel(to: LampWardAreas.exteriorID, entrance: "from.north")
            try await waitUntil({ (view.scene as? GameAreaScene)?.area.id == LampWardAreas.exteriorID && !context.router.isTransitioning })
            let north = view.scene as! CityDistrictScene
            click(north, LampWardAreas.exitApproach(for: .north))
            try await waitUntil({ north.worldMapIsPresented })
            try check(north.worldMapIsPresented, "The north street exit opens the world map")
            north.worldMapOverlay.onTravel?(.sableRow, "from.south")
            try await waitUntil({ (view.scene as? GameAreaScene)?.area.id == HarborpointAreas.sableRow && !context.router.isTransitioning })
            let sable = view.scene as! CityDistrictScene
            sable.setWorldMapPresented(true)
            sable.worldMapOverlay.onTravel?(.harborpointPD, "from.north")
            try await waitUntil({ (view.scene as? GameAreaScene)?.area.id == LampWardAreas.exteriorID && !context.router.isTransitioning })
            try check(true, "World-map travel reaches Sable Row and returns to Lamp Ward")
            try JSONSerialization.data(withJSONObject: ["passed": true, "checks": checks], options: [.prettyPrinted, .sortedKeys]).write(to: output.appendingPathComponent("report.json"))
        } catch {
            if let scene = view.scene as? BaseGameScene { try? capture(scene, "failure") }
            try? JSONSerialization.data(withJSONObject: ["passed": false, "checks": checks, "error": String(describing: error)], options: [.prettyPrinted, .sortedKeys]).write(to: output.appendingPathComponent("report.json"))
        }
        NSApp.terminate(nil)
    }
}
#endif
