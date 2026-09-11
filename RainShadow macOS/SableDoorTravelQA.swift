#if DEBUG
import AppKit
import SpriteKit

/// Opt-in real-scene regression, including input dispatch, movement callbacks,
/// router transitions and native-renderer captures. SwiftPM cannot run scenes.
@MainActor
enum SableDoorTravelQA {
    struct Failure: Error { let message: String }

    static func run(in view: SKView, output: URL) async {
        var checks: [String] = []
        var manualClock: TimeInterval?
        func check(_ condition: Bool, _ message: String) throws {
            guard condition else { throw Failure(message: message) }
            checks.append(message)
        }
        func click(_ scene: BaseGameScene, at point: CGPoint, kind: GamePointerKind = .mouse) {
            scene.recenterCamera(on: point)
            scene.gameCamera.position = point
            let event = GamePointerEvent(location: point, kind: kind)
            scene.handlePointerDown(event)
            scene.handlePointerUp(event)
        }
        // After checking the live touch flash, pause automatic frames and drive
        // the same scene updates deterministically. Do not mix two tick clocks.
        func waitUntil(_ condition: () -> Bool, timeout: Double = 15) async throws {
            let end = ProcessInfo.processInfo.systemUptime + timeout
            while !condition() {
                guard ProcessInfo.processInfo.systemUptime < end else {
                    let game = view.scene as? GameAreaScene
                    throw Failure(message: "Timed out: area=\(String(describing: game?.area.id)) pos=\(String(describing: game?.detective.position)) destination=\(String(describing: game?.detective.movementDestination))")
                }
                if let time = manualClock {
                    manualClock = time + 1.0 / 30.0
                    (view.scene as? BaseGameScene)?.update(manualClock!)
                }
                // SKView advances a crossfade only on its own rendering loop.
                // Hand the clock back before waiting for the new scene.
                if (view.scene as? BaseGameScene)?.context.router.isTransitioning == true {
                    manualClock = nil
                    (view.scene as? BaseGameScene)?.detective.resetLocomotionClock()
                    view.isPaused = false
                }
                try await Task.sleep(for: .milliseconds(20))
            }
        }
        func settle(_ seconds: Double) async throws {
            let end = ProcessInfo.processInfo.systemUptime + seconds
            try await waitUntil({ ProcessInfo.processInfo.systemUptime >= end }, timeout: seconds + 2)
        }
        func capture(_ scene: BaseGameScene, _ name: String) throws {
            // The paged exterior spreads cold texture conversions over frames.
            for _ in 0..<32 {
                scene.didFinishUpdate()
                if scene.nativeWorldRenderer?.lastPixels != nil { break }
            }
            guard let renderer = scene.nativeWorldRenderer,
                  let pixels = renderer.lastPixels, let viewport = renderer.lastViewport,
                  let image = IENativeWorldRenderer.image(pixels, width: viewport.width, height: viewport.height),
                  let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else {
                throw Failure(message: "No native framebuffer for \(name)")
            }
            try png.write(to: output.appendingPathComponent(name + ".png"))
        }

        do {
            try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
            // No writes to the player's playtest save while exercising cancels.
            let store = SaveStore(key: "RainShadow.QA.DoorTravel.\(UUID().uuidString)")
            defer { store.reset() }
            let context = GameContext(saveStore: store)
            view.window?.setContentSize(CGSize(width: 1000, height: 750))
            context.router.start(in: view)
            view.window?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            try await settle(0.3)
            guard let street = view.scene as? CityDistrictScene,
                  street.area.id == SableBlenderPlaytest.exteriorID else {
                throw Failure(message: "Launch with RAINSHADOW_START_SCENE=sable_blender")
            }
            var glass = CGPoint(x: 519, y: 1899)
            let openLeaf = CGPoint(x: 520, y: 1916)
            street.setZoomStep(CameraZoom.step(forPercent: 100))
            let start = street.detective.position
            let approach = street.area.region(at: glass)!.approachPoint!.cgPoint
            func state(_ label: String) {
                let current = (view.scene as? GameAreaScene)?.area.id.rawValue ?? "none"
                FileHandle.standardError.write(Data("QA \(label): scene=\(current) pos=\(street.detective.position) moving=\(street.detective.isLocomoting) destination=\(String(describing: street.detective.movementDestination)) overlays=\(street.anyOverlayIsPresented)\n".utf8))
            }
            street.recenterCamera(on: glass)
            street.gameCamera.position = glass
            state("initial hover")
            street.handlePointerMoved(GamePointerEvent(location: glass, kind: .mouse))
            try check(street.hoveredHighlightID == SableBlenderPlaytest.apartmentRegionID,
                      "Mouse hover identifies the painted apartment doorway")
            try check(NSCursor.current == NSCursor.pointingHand, "Closed door hover offers the interaction cursor")
            try capture(street, "01_door_highlight")
            click(street, at: glass, kind: .touch)
            state("first click")
            try check(view.scene === street && street.detective.isLocomoting,
                      "A touch starts walking without immediately changing area")
            try await settle(0.8)
            try check(view.scene === street, "The street remains active while Voss approaches")
            try check(street.hoveredHighlightID == nil, "The touch doorway highlight clears after its brief feedback")
            view.isPaused = true
            manualClock = 0
            street.detective.resetLocomotionClock()
            // A refused replacement order must not fire the old door callback
            // when its discarded path stops on the next locomotion tick.
            let blocked = CGPoint(x: 590, y: 1980)
            try check(!street.navigation.isOrderableFloor(blocked) && street.area.region(at: blocked) == nil,
                      "Cancellation witness is solid facade outside the entrance")
            click(street, at: blocked)
            state("blocked click")
            try await settle(0.4)
            try check(view.scene === street && !context.router.isTransitioning,
                      "A refused replacement click cannot trigger stale door travel")
            try check(!street.detective.isLocomoting, "The refused floor order stops the discarded route")
            click(street, at: start)
            state("return order")
            try await waitUntil({ !street.detective.isLocomoting })
            state("back to start")
            try await settle(0.2)
            click(street, at: glass)
            state("before stop")
            street.handleCancelInput()
            state("after stop")
            try await settle(0.4)
            try check(view.scene === street && !context.router.isTransitioning && !street.detective.isLocomoting,
                      "Stop cancels pending entrance travel")
            click(street, at: start)
            try await waitUntil({ !street.detective.isLocomoting })
            try await settle(0.2)
            click(street, at: glass)
            click(street, at: start)
            try await waitUntil({ !street.detective.isLocomoting })
            try check(view.scene === street, "A new floor destination replaces entrance travel")
            try await settle(0.2)
            let door = street.area.doors.first { $0.id == SableBlenderPlaytest.apartmentRegionID }!
            let entry = door.entryPoint!.cgPoint
            let closedWalls = street.areaRuntime!.currentWallPolygons
            click(street, at: glass)
            try await waitUntil({ street.areaRuntime!.openDoorIDs.contains(door.id) })
            try await settle(1.0)
            try check(view.scene === street && !context.router.isTransitioning && !street.detective.isLocomoting,
                      "The first click opens the door and leaves Voss outside without pending travel")
            glass = CGPoint(x: 537, y: 1864) // Clear opening, measured from V25's projected leaf.
            street.handlePointerMoved(GamePointerEvent(location: glass, kind: .mouse))
            try check(street.hoveredHighlightID == nil, "The empty entrance has no door-leaf highlight")
            try check(NSCursor.current == NSCursor.dragLink, "Open doorway hover offers the travel cursor")
            street.handlePointerMoved(GamePointerEvent(location: openLeaf, kind: .mouse))
            try check(street.hoveredHighlightID == door.id && NSCursor.current == NSCursor.pointingHand,
                      "The moved open leaf has its own highlight and close cursor")
            try capture(street, "01_open_leaf_highlight")
            street.handlePointerMoved(GamePointerEvent(location: glass, kind: .mouse))
            let patch = street.backgroundRoot.childNode(withName: "\(door.id).backgroundTiles") as! SKSpriteNode
            let expectedSize = door.backgroundTiles!.worldRect.cgRect.size
            // SKSpriteNode stores geometry as Float internally.
            try check(!patch.isHidden && Float(patch.size.width) == Float(expectedSize.width)
                        && Float(patch.size.height) == Float(expectedSize.height),
                      "Open secondary tiles are registered in the background below actors")
            try check(street.areaRuntime!.currentWallPolygons != closedWalls,
                      "Opening selects the open door cover polygons")
            try capture(street, "01_open_day_before_entry")
            click(street, at: glass, kind: .touch)
            try check(street.detective.isLocomoting, "A second click starts the threshold walk")
            street.handleCancelInput()
            try await settle(0.4)
            try check(view.scene === street && !street.detective.isLocomoting && !context.router.isTransitioning,
                      "Stop cancels the second-click threshold walk without stale travel")
            let dayTexture = patch.texture
            try check(street.setExtendedNight(true), "The open doorway supports Extended Night")
            try check(patch.texture !== dayTexture && !patch.isHidden,
                      "Night swaps the open tiles while preserving the open state")
            try capture(street, "01_open_night")
            street.setExtendedNight(false)
            click(street, at: openLeaf, kind: .touch)
            try await waitUntil({ !street.areaRuntime!.openDoorIDs.contains(door.id) })
            try check(view.scene === street && !context.router.isTransitioning,
                      "Clicking the open leaf closes it without entering")
            try check(patch.isHidden && street.areaRuntime!.currentWallPolygons == closedWalls,
                      "Closing restores baked tiles and closed cover together")
            try check(door.closedImpededCells.allSatisfy { street.navigation.searchMap.doorBlocksMovement(at: $0.searchMapCell) },
                      "Closing restores the threshold's blocked search cells")
            click(street, at: glass)
            try await waitUntil({ street.areaRuntime!.openDoorIDs.contains(door.id) })
            try await settle(0.4)
            try check(view.scene === street && !street.detective.isLocomoting,
                      "Reopening a closed door still requires a separate entry click")
            click(street, at: glass)
            try await waitUntil({ view.scene is DetectiveOfficeScene })
            try check(street.navigation.searchMap.cell(for: street.detective.position) == street.navigation.searchMap.cell(for: entry),
                      "Transition happens only after Voss reaches the open threshold")
            try await waitUntil({ !context.router.isTransitioning })
            guard let office = view.scene as? DetectiveOfficeScene else {
                throw Failure(message: "Missing office scene")
            }
            let arrival = office.area.spawnPoint(entrance: "from.city")!
            try check(hypot(office.detective.position.x - arrival.x, office.detective.position.y - arrival.y) < 2,
                      "Office arrival uses from.city rather than the desk start")
            try check(!office.dialogueIsActive, "Playtest arrival permits immediate free play")
            try check(office.detective.state == .standingIdle,
                      "Entering from the street leaves Voss standing at the entrance")
            try capture(office, "02_inside_office")
            // Real floor clicks below both sills: these were blocked by the
            // inscribed navigation diamond despite being visibly clear floor.
            for (name, pixel) in [
                ("near_window", CGPoint(x: 1300, y: 1205)),
                ("far_window", CGPoint(x: 1600, y: 1010)),
            ] {
                let target = OfficeInteriorScale.mapPoint(
                    CGPoint(x: pixel.x, y: 2304 - pixel.y)
                )
                try check(office.navigation.isOrderableFloor(target), "\(name) floor accepts walking")
                click(office, at: target)
                try await waitUntil({ !office.detective.isLocomoting })
                // FindPath lands in the requested 16×12 search cell; arbitrary
                // pixel clicks are not exact sub-cell destinations.
                try check(office.navigation.searchMap.cell(for: office.detective.position)
                            == office.navigation.searchMap.cell(for: target),
                          "Voss reaches \(name) through the real floor-click handler")
                guard let fog = office.weatherRoot.children.compactMap({ $0 as? FogOfWarNode }).first else {
                    throw Failure(message: "Missing office fog layer")
                }
                let aperture = name == "near_window"
                    ? OfficeNavigationLayout.Architecture.nearWindowAperture
                    : OfficeNavigationLayout.Architecture.farWindowAperture
                try check(aperture.allSatisfy { fog.isVisible(OfficeInteriorScale.mapPoint($0)) },
                          "\(name) aperture is revealed by the actual scene fog")
                try capture(office, "02_" + name)
            }
            let exit = office.area.region(id: "office.door")!
            let box = exit.boundingBox
            click(office, at: CGPoint(x: box.midX, y: box.midY), kind: .touch)
            try await waitUntil({ (view.scene as? CityDistrictScene)?.area.id == SableBlenderPlaytest.exteriorID })
            try await waitUntil({ !context.router.isTransitioning })
            let returned = view.scene as! CityDistrictScene
            try check(returned.detective.position == approach,
                      "The office exit returns to the new district's apartment pavement")
            returned.handlePointerMoved(GamePointerEvent(location: openLeaf, kind: .mouse))
            try check(returned.hoveredHighlightID == SableBlenderPlaytest.apartmentRegionID,
                      "Returning outside starts with the open leaf's highlight geometry")
            returned.handlePointerMoved(GamePointerEvent(location: glass, kind: .mouse))
            try check(returned.hoveredHighlightID == nil, "The returned entrance stays separate from the leaf")
            try capture(returned, "03_back_outside")
            try check(returned.areaRuntime!.openDoorIDs.contains(SableBlenderPlaytest.apartmentRegionID),
                      "The apartment door remains open when returning outside")
            // A player can cancel on the final threshold cell. A new tap must
            // enter instead of receiving MoveTo's same-cell head-turn result.
            returned.detective.position = entry
            click(returned, at: glass, kind: .touch)
            try await waitUntil({ view.scene is DetectiveOfficeScene })
            try check(view.scene is DetectiveOfficeScene, "Re-entry works when already standing in the threshold cell")
            let report: [String: Any] = ["passed": true, "checks": checks]
            try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
                .write(to: output.appendingPathComponent("report.json"))
            FileHandle.standardError.write(Data("DOOR TRAVEL QA PASS: \(checks.count) checks\n".utf8))
            NSApp.terminate(nil)
        } catch {
            if let game = view.scene as? BaseGameScene { try? capture(game, "failure") }
            let report: [String: Any] = ["passed": false, "checks": checks, "error": String(describing: error)]
            try? JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
                .write(to: output.appendingPathComponent("report.json"))
            FileHandle.standardError.write(Data("DOOR TRAVEL QA FAIL: \(error)\n".utf8))
            NSApp.terminate(nil)
        }
    }
}
#endif
