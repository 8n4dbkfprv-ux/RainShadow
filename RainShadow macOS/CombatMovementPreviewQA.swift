#if DEBUG
import AppKit
import SpriteKit

@MainActor enum CombatMovementPreviewQA {
    static func run(in view: SKView, output: URL) async throws -> [String] {
        var checks: [String] = []
        func check(_ value: Bool, _ message: String) throws {
            guard value else { throw TacticalCombatQA.Failure(message: message) }
            checks.append(message)
        }
        func capture(_ node: SKNode, _ name: String) throws {
            guard let image = view.texture(from: node)?.cgImage(),
                  let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else {
                throw TacticalCombatQA.Failure(message: "Pathline capture failed")
            }
            try png.write(to: output.appendingPathComponent(name + ".png"))
        }
        let scene = view.scene as! CityDistrictScene
        let director = scene.combatDirector!
        let preview = director.movementPreview
        let before = director.combat
        let points = [CGPoint.zero, CGPoint(x: 80, y: 0), CGPoint(x: 80, y: 60)]
        let split = CombatMovementPreview.Geometry(points: points, allowance: 120)
        try check(split.distance == 160 && split.reachable.last == CGPoint(x: 80, y: 30),
                  "Budget split measures projected ground distance and keeps the route corner")
        try check(split.excess == [CGPoint(x: 80, y: 30), CGPoint(x: 80, y: 60)],
                  "Red segment starts exactly at the available movement boundary")
        try check(CombatMovementPreview.Geometry(points: points, allowance: 0).excess == points,
                  "Zero movement colours the entire route unavailable")
        try check(CombatMovementPreview.Geometry(points: points, allowance: 160).excess.isEmpty,
                  "Exact-budget destination remains reachable")
        try check(CombatMovementPreview.Geometry(points: [.zero, .zero], allowance: 0).distance == 0,
                  "Duplicate nodes do not introduce NaN lengths")
        try check(preview.childNode(withName: "combat.movementDestination") is SKShapeNode,
                  "Destination uses a simple circle without ornamental artwork")
        var route: Path?
        let origin = before.current.position
        scene.followCamera(); scene.gameCamera.position = origin
        // Find a real, visible ground destination, not a synthetic open-world route.
        for distance in [160.0, 240, 100] {
            for step in 0..<32 {
                let angle = Double(step) * .pi / 16
                let end = CGPoint(x: origin.x + cos(angle) * distance, y: origin.y + sin(angle) * distance * 0.75)
                guard let candidate = CombatNavigation.route(in: scene.navigation, actor: before.current, to: end, bear: before.isBear),
                      CombatNavigation.length(candidate, from: origin) <= before.budget.availableMovement(speed: before.movementSpeed(for: before.current)) else { continue }
                director.hover(at: scene.convert(candidate.destination!, from: scene.depthWorldRoot))
                if !preview.isHidden { route = candidate; break }
            }
            if route != nil { break }
        }
        guard let route, let end = route.destination else { throw TacticalCombatQA.Failure(message: "No visible route fixture") }
        try check(preview.geometry.points == [origin] + route.remainingPoints,
                  "Live preview uses every certified navigation point")
        try check(preview.geometry.endpoint == end && preview.canMove,
                  "Marker follows the actual route endpoint with an affordable cost")
        try check(abs(preview.geometry.distance - CombatNavigation.length(route, from: origin)) < 0.0001,
                  "Displayed movement cost equals combat's charged path length")
        try check(director.combat == before, "Hover never spends movement or mutates combat")
        try capture(scene, "pathline-reachable")
        let originalWidth = preview.childNode(withName: "combat.movementDestination")!.frame.width
        preview.advance(delta: 0.4, cameraScale: scene.playCameraScale * 2)
        try check(preview.geometry.endpoint == end && preview.childNode(withName: "combat.movementDestination")!.frame.width >= originalWidth,
                  "Zoom changes presentation without moving the destination")
        preview.advance(delta: 0, cameraScale: scene.playCameraScale)
        let sword = scene.hudRoot.childNode(withName: "//combat.melee")!
        director.hover(at: scene.convert(.zero, from: sword))
        try check(preview.isHidden, "Action-bar hover clears the movement route")
        director.hover(at: scene.convert(end, from: scene.depthWorldRoot))
        director.command(17)
        try check(preview.isHidden && director.selectingMelee, "Melee targeting clears the movement route")
        director.cancelTargeting()
        director.hover(at: scene.convert(end, from: scene.depthWorldRoot))
        scene.handleInventoryInput()
        try check(preview.isHidden && scene.inventoryIsPresented, "Inventory clears the route immediately")
        scene.handleInventoryInput()
        director.hover(at: scene.convert(end, from: scene.depthWorldRoot))
        scene.handleTacticalPauseInput()
        director.update(at: ProcessInfo.processInfo.systemUptime)
        try check(preview.isHidden, "Tactical pause clears the movement hint")
        scene.handleTacticalPauseInput()
        director.hover(at: scene.convert(CGPoint(x: -100000, y: -100000), from: scene.depthWorldRoot))
        try check(preview.isHidden, "Invalid ground leaves no stale route")
        // Compare explicitly dashed movement with an undashed out-of-range route.
        var sampleActor = before.current
        sampleActor.position = .zero
        let proof = SKNode()
        let paper = SKSpriteNode(texture: UIPaintedChrome.parchmentSurface())
        paper.size = CGSize(width: 740, height: 330); proof.addChild(paper)
        for (index, allowanceSpeed) in [120.0, 60.0].enumerated() {
            let sample = CombatMovementPreview()
            sample.zPosition = 1; sample.position = CGPoint(x: CGFloat(index) * 350 - 275, y: -65)
            proof.addChild(sample)
            var sampleBudget = CombatBudget()
            if index == 0 { _ = sampleBudget.dash(speed: allowanceSpeed) }
            sample.show(path: Path(points: points, from: .zero), actor: sampleActor,
                        budget: sampleBudget, speed: allowanceSpeed, cameraScale: 1)
            if index == 0 {
                try check(sample.canMove && sample.captionText.contains("20.0 ft"), "Dashed route shows the total projected cost")
                try check(!sampleBudget.canAttack, "Only an explicit Dash spends the attack action")
            } else {
                try check(!sample.canMove && !sample.geometry.excess.isEmpty, "Unreachable route retains both available and excess sections")
            }
        }
        try capture(proof, "pathline-detail")
        var limited = before.budget
        _ = limited.spend(4)
        preview.show(path: route, actor: before.current, budget: limited, speed: before.current.speed, cameraScale: scene.playCameraScale)
        try check(!preview.canMove, "Spent turn marks a valid route out of range")
        try capture(scene, "pathline-out-of-range")
        preview.clear()
        scene.followCamera(); scene.gameCamera.position = origin
        director.hover(at: scene.convert(end, from: scene.depthWorldRoot))
        let dash = scene.hudRoot.childNode(withName: "//combat.dash")!
        let allowance = director.combat.budget.availableMovement(speed: director.combat.movementSpeed(for: director.combat.current))
        director.pointer(at: scene.convert(.zero, from: dash))
        try check(!director.combat.canDash && !director.combat.budget.canAttack,
                  "Dash button explicitly consumes the action")
        try check(director.combat.budget.availableMovement(speed: director.combat.movementSpeed(for: director.combat.current))
                  == allowance + director.combat.movementSpeed(for: director.combat.current),
                  "Dash button adds exactly one movement speed")
        let dashed = director.combat
        director.pointer(at: scene.convert(.zero, from: dash))
        try check(director.combat == dashed, "Repeated Dash click cannot grant more movement")
        let dashDeadline = ProcessInfo.processInfo.systemUptime + 10
        while director.busy {
            guard ProcessInfo.processInfo.systemUptime < dashDeadline else { throw TacticalCombatQA.Failure(message: "Dash did not finish") }
            try await Task.sleep(for: .milliseconds(20))
        }
        director.hover(at: scene.convert(end, from: scene.depthWorldRoot))
        try capture(scene, "pathline-after-dash")
        director.pointer(at: scene.convert(end, from: scene.depthWorldRoot))
        try check(preview.isHidden && director.busy, "Accepted movement clears the preview before playback")
        return checks
    }
}
#endif
