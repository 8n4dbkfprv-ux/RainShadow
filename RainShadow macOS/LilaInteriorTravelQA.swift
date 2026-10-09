#if DEBUG
import AppKit
import SpriteKit

/// Checks actual pointer dispatch, arrival, rendering and both lodging exits.
@MainActor enum LilaInteriorTravelQA {
    struct Failure: Error { let message: String }
    static func run(in view: SKView, output: URL) async {
        var checks: [String] = []
        func require(_ value: Bool, _ message: String) throws {
            guard value else { throw Failure(message: message) }
            checks.append(message)
        }
        func waitUntil(_ condition: () -> Bool) async throws {
            let end = ProcessInfo.processInfo.systemUptime + 45
            while !condition() {
                guard ProcessInfo.processInfo.systemUptime < end else {
                    throw Failure(message: "Timed out in \(String(describing: (view.scene as? GameAreaScene)?.area.id))")
                }
                try await Task.sleep(for: .milliseconds(30))
            }
        }
        func capture(_ name: String) throws {
            guard let scene = view.scene as? BaseGameScene else { throw Failure(message: "Missing scene") }
            for _ in 0..<32 { scene.didFinishUpdate() }
            guard let r = scene.nativeWorldRenderer, let pixels = r.lastPixels, let v = r.lastViewport,
                  let image = IENativeWorldRenderer.image(pixels, width: v.width, height: v.height),
                  let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])
            else { throw Failure(message: "Missing framebuffer") }
            try png.write(to: output.appendingPathComponent(name + ".png"))
        }
        do {
            try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
            let store = SaveStore(key: "RainShadow.QA.Lila.\(UUID().uuidString)")
            store.save(SaveSnapshot(hasSeenOpening: true, hasSeenOfficeHint: true,
                                    hasCompletedOfficeCaseIntro: true))
            defer { store.reset(); SaveStore(key: "RainShadow.QA.Lila.Bootstrap").reset() }
            let context = GameContext(saveStore: store)
            context.session.markCityTravelOpen()
            view.window?.setContentSize(CGSize(width: 1000, height: 750))
            context.router.start(in: view)
            view.window?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            try await Task.sleep(for: .seconds(1))
            func arrived(_ id: String) -> Bool {
                (view.scene as? GameAreaScene)?.area.id == AreaID(id) && !context.router.isTransitioning
            }
            func visit(_ id: String, _ entrance: String) async throws {
                context.router.travel(to: AreaID(id), entrance: entrance)
                try await waitUntil { arrived(id) }
            }
            func clickRegion(_ name: String) throws {
                guard let scene = view.scene as? GameAreaScene,
                      let region = scene.area.regions.first(where: { $0.id == name }) else {
                    throw Failure(message: "Missing region \(name)")
                }
                let p = CGPoint(x: region.polygon.map(\.x).reduce(0,+) / Double(region.polygon.count),
                                y: region.polygon.map(\.y).reduce(0,+) / Double(region.polygon.count))
                scene.recenterCamera(on: region.approachPoint!.cgPoint)
                let event = GamePointerEvent(location: p, kind: .touch)
                scene.handlePointerDown(event); scene.handlePointerUp(event)
            }
            try await visit("RS0500", "from.portal.lilaRooms")
            try clickRegion("portal.lilaRooms")
            try await waitUntil { arrived("RS0502") }
            try require(true, "Street door enters the new hall through pointer input")
            try capture("hall_in_game")
            try clickRegion("lila.stairs.up")
            try await waitUntil { arrived("RS0501") }
            try require(true, "Walking to the stair enters Lila's landing")
            try capture("rooms_landing_in_game")
            try clickRegion("portal.return")
            try await waitUntil { arrived("RS0502") }
            try require(true, "Landing returns down the stair")
            try clickRegion("lila.stairs.up")
            try await waitUntil { arrived("RS0501") }
            try clickRegion("lila.room.desk")
            try await waitUntil { context.session.inspectedHotspotIDs.contains("lila.room.desk") }
            try require(true, "Desk inspection walks through the warded doorway")
            try capture("rooms_desk_in_game")
            try clickRegion("lila.backstairs")
            try await waitUntil { arrived("RS0500") }
            try require(true, "Back stair returns to the separately authored street entrance")
            try capture("back_stair_return")
            try await visit("RS0502", "from.street")
            try clickRegion("portal.return")
            try await waitUntil { arrived("RS0500") }
            try require(true, "Front threshold returns to the main street doorway")
            try JSONSerialization.data(withJSONObject: ["passed":true,"checks":checks], options:[.prettyPrinted])
                .write(to: output.appendingPathComponent("report.json"))
        } catch {
            try? capture("failure")
            try? JSONSerialization.data(withJSONObject: ["passed":false,"checks":checks,"error":String(describing:error)], options:[.prettyPrinted])
                .write(to: output.appendingPathComponent("report.json"))
        }
        NSApp.terminate(nil)
    }
}
#endif
