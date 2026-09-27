#if DEBUG
import AppKit
import SpriteKit

/// Exercises the installed art and actual scene input/router, using a disposable save.
@MainActor enum RebuiltCityTravelQA {
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
            let store = SaveStore(key: "RainShadow.QA.CityRestore.\(UUID().uuidString)")
            store.save(SaveSnapshot(hasSeenOpening: true, hasSeenOfficeHint: true,
                                    hasCompletedOfficeCaseIntro: true))
            defer { store.reset(); SaveStore(key: "RainShadow.QA.CityRestore.Bootstrap").reset() }
            let context = GameContext(saveStore: store)
            view.window?.setContentSize(CGSize(width: 1000, height: 750))
            context.router.start(in: view)
            view.window?.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true)
            try await Task.sleep(for: .seconds(1))
            func arrive(_ id: AreaID, _ entrance: String) async throws -> GameAreaScene {
                context.router.travel(to: id, entrance: entrance)
                try await waitUntil({ (view.scene as? GameAreaScene)?.area.id == id && !context.router.isTransitioning })
                return view.scene as! GameAreaScene
            }
            func center(_ points: [AreaPoint]) -> CGPoint {
                CGPoint(x: points.map(\.x).reduce(0, +) / Double(points.count),
                        y: points.map(\.y).reduce(0, +) / Double(points.count))
            }
            for district in [CityDistrictID.sableRow, .wharfLadder, .riverside] {
                let id = CityDistrictAreaAdapter.areaID(for: district)
                let definition = RebuiltCityAreas.area(id)
                let region = definition.travelRegions.first!
                let entrance = definition.entrances.first { $0.point == region.approachPoint }!.name
                let street = try await arrive(id, entrance) as! CityDistrictScene
                street.setZoomStep(CameraZoom.step(forPercent: 100))
                street.recenterCamera(on: region.approachPoint!.cgPoint)
                try capture(street, district.slug + "_day")
                try check(street.setExtendedNight(true), "\(district.slug): night pages load")
                try capture(street, district.slug + "_night")
                street.setExtendedNight(false)
                if let door = street.door(matching: region.id) {
                    let leaf = center(door.closedOutline)
                    street.handlePointerMoved(GamePointerEvent(location: leaf, kind: .mouse))
                    try check(street.hoveredHighlightID == region.id, "\(district.slug): painted door has correct hover")
                    click(street, leaf, touch: true)
                    try await waitUntil({ street.areaRuntime?.openDoorIDs.contains(door.id) == true })
                    try check(view.scene === street, "\(district.slug): first click opens without entering")
                    try capture(street, district.slug + "_open_door")
                }
                // Choose an aperture pixel outside the open leaf's hit polygon.
                let box = region.boundingBox
                var aperture = center(region.polygon)
                if let door = street.door(matching: region.id) {
                    outer: for y in stride(from: box.minY + 1, to: box.maxY, by: 2) {
                        for x in stride(from: box.minX + 1, to: box.maxX, by: 2) {
                            let p = CGPoint(x: x, y: y)
                            if region.contains(p) && !HighlightGeometry.contains(p, polygon: door.openOutline.map(\.cgPoint)) {
                                aperture = p; break outer
                            }
                        }
                    }
                }
                click(street, aperture, touch: true)
                let destination = region.travel!.destination
                try await waitUntil({ (view.scene as? GameAreaScene)?.area.id == destination && !context.router.isTransitioning })
                let room = view.scene as! GameAreaScene
                try check(room.area.id == destination, "\(district.slug): aperture enters \(destination)")
                try capture(room, district.slug + "_interior")
                let exit = room.area.travelRegions.first { $0.travel?.destination == id }!
                click(room, center(exit.polygon), touch: true)
                try await waitUntil({ (view.scene as? GameAreaScene)?.area.id == id && !context.router.isTransitioning })
                try check(true, "\(district.slug): interior return connects to restored street")
                let edge = CityWorldMap.travelableExitEdges(from: district).first!
                let north = try await arrive(id, edge.arrivalKey) as! CityDistrictScene
                click(north, RebuiltCityAreas.exitApproach(district, edge))
                try await waitUntil({ north.worldMapIsPresented })
                try check(true, "\(district.slug): authored street exit opens world map")
                north.worldMapOverlay.onTravel?(.harborpointPD, "from.north")
                try await waitUntil({ (view.scene as? GameAreaScene)?.area.id == LampWardAreas.exteriorID && !context.router.isTransitioning })
                let lamp = view.scene as! CityDistrictScene
                lamp.setWorldMapPresented(true)
                lamp.worldMapOverlay.onTravel?(district, "from.south")
                try await waitUntil({ (view.scene as? GameAreaScene)?.area.id == id && !context.router.isTransitioning })
                try check(true, "\(district.slug): world map travels to retained Lamp Ward and back")
            }
            try JSONSerialization.data(withJSONObject: ["passed": true, "checks": checks], options: [.prettyPrinted, .sortedKeys]).write(to: output.appendingPathComponent("report.json"))
        } catch {
            if let scene = view.scene as? BaseGameScene { try? capture(scene, "failure") }
            try? JSONSerialization.data(withJSONObject: ["passed": false, "checks": checks, "error": String(describing: error)], options: [.prettyPrinted, .sortedKeys]).write(to: output.appendingPathComponent("report.json"))
        }
        NSApp.terminate(nil)
    }
}
#endif
