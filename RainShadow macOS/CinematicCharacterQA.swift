#if DEBUG
import AppKit
import SpriteKit

/// Deterministic checks against production actor adapters and packaged art.
/// The launch hook bypasses GameBootstrap and never opens the player's save.
@MainActor enum CinematicCharacterQA {
    struct Failure: Error { let message: String }

    static func run(output: URL) {
        var checks: [String] = []
        func check(_ condition: Bool, _ message: String) throws {
            guard condition else { throw Failure(message: message) }
            checks.append(message)
        }
        func frame(_ actor: SKNode) -> String {
            actor.children.compactMap { $0 as? IEAvatarNode }
                .first { !$0.isHidden }?.currentFrame?.id?.name ?? "missing"
        }
        func map(wall: Bool = false) -> NavigationMap {
            let search = SearchMap(worldBounds: CGRect(x: 0, y: 0, width: 1280, height: 960),
                terrainIndices: Array(repeating: (wall ? SearchMapTerrain.wall : .stone).rawValue, count: 6400),
                columns: 80, rows: 80)
            return NavigationMap(searchMap: search)
        }
        func voss(_ navigation: NavigationMap, _ start: CGPoint) -> DetectiveActorNode {
            let actor = DetectiveActorNode()
            actor.position = start
            actor.isAudioSilenced = true
            actor.beginOpenWorldStanding()
            actor.attachNavigation(navigation, id: "detective")
            return actor
        }
        func lila(_ navigation: NavigationMap) -> ClientActorNode {
            let actor = ClientActorNode()
            actor.isAudioSilenced = true
            actor.attachNavigation(navigation, id: "client")
            return actor
        }
        do {
            try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
            try VossAnimationSet.validate(IEIndexedSprite.load(character: VossAnimationSet.character, bundle: .main))
            try LilaAnimationSet.validate(IEIndexedSprite.load(character: LilaAnimationSet.character, bundle: .main))
            try check(true, "Approved VossCHMF and LilaSentinel payload hashes and frames validate")
            let start = CGPoint(x: 320, y: 240)
            let end = CGPoint(x: 1000, y: 240)
            let navigation = map()
            let detective = voss(navigation, start)
            let client = lila(navigation)
            detective.cutsceneFollow(path: [start, end], style: .plain) {}
            client.cutsceneFollow(path: [start, end], style: .entering) {}
            for time in [1.0, 1.07, 1.14, 1.21, 1.28] {
                detective.updateLocomotion(at: time, worldIsPaused: false)
                client.updateLocomotion(at: time, worldIsPaused: false)
                try check(detective.position == client.position, "Same engine position at \(time)s")
            }
            try check(frame(detective) == "walk_e_03.png" && frame(client) == "walk_e_03.png",
                      "Both actors draw the post-advance cached walk phase")
            let held = detective.position
            let heldFrame = frame(detective)
            for time in [2.0, 3.0] {
                detective.updateLocomotion(at: time, worldIsPaused: true)
                client.updateLocomotion(at: time, worldIsPaused: true)
            }
            try check(detective.position == held && client.position == held && frame(detective) == heldFrame,
                      "Pause freezes root motion and animation")
            detective.cutsceneClearActions()
            client.cutsceneClearActions()
            detective.cutsceneFollow(path: [held, end], style: .plain) {}
            client.cutsceneFollow(path: [held, end], style: .plain) {}
            for time in [3.0, 3.07, 3.14] {
                detective.updateLocomotion(at: time, worldIsPaused: false)
                client.updateLocomotion(at: time, worldIsPaused: false)
            }
            try check(frame(detective) == frame(client) && frame(detective) != "walk_e_00.png",
                      "Restarting a walk retains the cached animation clock")

            // An eastbound arrival must stay east until an explicit Face action.
            let arriving = lila(map())
            var arrivals = 0
            arriving.performEntrance(along: [start, CGPoint(x: 360, y: 240)]) { arrivals += 1 }
            for tick in 0...40 { arriving.updateLocomotion(at: 10 + Double(tick) / 15, worldIsPaused: false) }
            try check(arrivals == 1 && frame(arriving).hasPrefix("idle_e_"),
                      "Arrival preserves the final path orientation and completes once")
            arriving.cutsceneFace(.northEast)
            try check(frame(arriving).hasPrefix("idle_ne_"), "Explicit Face switches to the authored direction")

            let blockedMap = map()
            blockedMap.registerActor(id: "blocker", kind: .player, at: CGPoint(x: 355, y: 240), isMoving: true)
            let blocked = lila(blockedMap)
            blocked.performEntrance(along: [start, end]) {}
            blocked.updateLocomotion(at: 20, worldIsPaused: false)
            blocked.updateLocomotion(at: 20.07, worldIsPaused: false)
            try check(blocked.position == start, "Lila backs off instead of walking through a moving actor")
            blockedMap.unregisterActor(id: "blocker")
            for tick in 2...40 { blocked.updateLocomotion(at: 20 + Double(tick) / 15, worldIsPaused: false) }
            try check(blocked.position.x > start.x, "Lila resumes after actor backoff expires")

            let walls = map(wall: true)
            let scripted = voss(walls, start)
            var scriptCompletions = 0
            scripted.cutsceneFollow(path: [start, end], style: .plain) { scriptCompletions += 1 }
            scripted.updateLocomotion(at: 30, worldIsPaused: false)
            scripted.updateLocomotion(at: 30.07, worldIsPaused: false)
            try check(scriptCompletions == 1 && scripted.position == start,
                      "A stopped scripted move releases its action queue")
            let ordinary = voss(walls, start)
            var interactions = 0
            ordinary.walk(path: Path(points: [end], from: start)) { interactions += 1 }
            ordinary.updateLocomotion(at: 30, worldIsPaused: false)
            ordinary.updateLocomotion(at: 30.07, worldIsPaused: false)
            try check(interactions == 0, "A failed gameplay approach does not trigger its interaction")

            let data = try JSONSerialization.data(withJSONObject: ["passed": true, "checks": checks], options: [.prettyPrinted])
            try data.write(to: output.appendingPathComponent("result.json"))
            print("Cinematic character QA passed: \(checks.count) checks")
        } catch {
            let report: [String: Any] = ["passed": false, "checks": checks, "error": String(describing: error)]
            if let data = try? JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted]) {
                try? data.write(to: output.appendingPathComponent("result.json"))
            }
            print("Cinematic character QA failed: \(error)")
        }
        NSApp.terminate(nil)
    }
}
#endif
