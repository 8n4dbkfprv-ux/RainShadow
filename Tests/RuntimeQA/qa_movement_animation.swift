// Actual SpriteKit actor regression harness; link against the macOS Debug build.
// Build/run instructions: Documentation/MovementAnimationSep29.md.
// Creates isolated actor nodes: it does not launch a scene or read/write saves.
import AppKit
import SpriteKit
@testable import RainShadow

@main
struct ActorAnimationQA {
    @MainActor static func main() {
        _ = NSApplication.shared
        let map = NavigationMap(worldBounds: CGRect(x: 0, y: 0, width: 800, height: 600), obstacles: [],
            agentProfile: NavigationAgentProfile(halfWidth: 0, halfHeight: 0, circleSize: 1))
        let orders = MovementOrderQueue(navigation: map, actorID: "qa")
        let actor = DetectiveActorNode()
        actor.position = CGPoint(x: 80, y: 80)
        actor.attachNavigation(map, id: "qa")
        actor.beginOpenWorldStanding()
        actor.isAudioSilenced = true
        func frame(_ node: SKNode) -> String {
            node.children.compactMap { $0 as? IEAvatarNode }.first { !$0.isHidden && $0.currentFrame?.id != nil }!.currentFrame!.id!.name
        }
        var completed = 0
        actor.updateLocomotion(at: 100, worldIsPaused: false, movementOrders: orders)
        actor.issueOrder(via: orders, to: CGPoint(x: 600, y: 80)) { completed += 1 }
        actor.updateLocomotion(at: 100.1, worldIsPaused: false, movementOrders: orders)
        precondition(frame(actor) == "walk_e_00.png", frame(actor))
        actor.updateLocomotion(at: 100.2, worldIsPaused: false, movementOrders: orders)
        precondition(frame(actor) == "walk_e_01.png", frame(actor))
        let held = frame(actor)
        actor.updateLocomotion(at: 200, worldIsPaused: true, movementOrders: orders)
        actor.updateLocomotion(at: 500, worldIsPaused: true, movementOrders: orders)
        precondition(frame(actor) == held)
        actor.resetLocomotionClock()
        actor.updateLocomotion(at: 501, worldIsPaused: false, movementOrders: orders)
        precondition(frame(actor) == held)
        actor.beginMovementBackoff(ticks: 10)
        let position = actor.position
        actor.updateLocomotion(at: 501.1, worldIsPaused: false, movementOrders: orders)
        precondition(frame(actor).hasPrefix("idle_e_"), frame(actor))
        precondition(actor.position == position)
        actor.updateLocomotion(at: 501.2, worldIsPaused: false, movementOrders: orders)
        precondition(frame(actor) == "idle_e_01.png", frame(actor))
        var time = 501.2
        for _ in 0..<200 {
            time += 0.1
            actor.updateLocomotion(at: time, worldIsPaused: false, movementOrders: orders)
            if actor.state == .standingIdle { break }
        }
        precondition(completed == 1 && actor.state == .standingIdle)
        precondition(frame(actor).hasPrefix("idle_e_"))
        let facing = actor.currentFacing
        actor.issueOrder(via: orders, to: actor.position)
        precondition(actor.currentFacing == facing)
        print("PASS Voss: first walking frame, independent frame clock, pause/resume, animated READY fallback, stationary backoff, arrival, single completion, same-cell facing")
        let client = ClientActorNode()
        client.isAudioSilenced = true
        client.performExit(along: [CGPoint(x: 300, y: 100), CGPoint(x: 100, y: 300), CGPoint(x: 500, y: 300)]) {}
        var strips = Set<String>()
        for i in 0..<160 {
            client.updateLocomotion(at: 100 + Double(i) * 0.1, worldIsPaused: false)
            let name = frame(client)
            if name.hasPrefix("lila_departure_nw") { strips.insert("nw") }
            if name.hasPrefix("lila_departure_ne") { strips.insert("ne") }
        }
        precondition(strips == ["nw", "ne"], "Observed strips: \(strips)")
        precondition(client.children.compactMap { $0 as? IEAvatarNode }.count == 1)
        print("PASS Lila: NW/NE node-facing strips, no blend layer, natural exit")
    }
}
